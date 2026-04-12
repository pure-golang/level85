#!/usr/bin/env python3
import json, os, re, sys, urllib.request, urllib.error

ZAI_API_KEY = os.environ.get("ZAI_API_KEY")
if not ZAI_API_KEY:
    print("Ошибка: ZAI_API_KEY не задан", file=sys.stderr)
    sys.exit(1)
ZAI_ENDPOINT = "https://api.z.ai/api/coding/paas/v4/chat/completions"
ZAI_MODEL = "glm-5"
_project_dir = os.environ.get("CI_PROJECT_DIR") or os.path.join(os.path.dirname(__file__), "..")
_mr_project_url = os.environ.get("CI_MERGE_REQUEST_PROJECT_URL", "")
_mr_source_branch = os.environ.get("CI_MERGE_REQUEST_SOURCE_BRANCH_NAME", "")

PROMPT = (
    "Ты — эксперт по backend-разработке. "
    "Ищи баги, проблемы с производительностью, безопасностью, асинхронностью. "
    "Отвечай кратко и по делу. Без emoji. Без заголовка Code Review, но применяй markdown. "
    "ВАЖНО: не выдумывай проблемы — указывай только то, "
    "что реально присутствует в активном (незакомментированном) коде. "
    "Не надо оценивать положительные моменты, только требующие исправления. "
    "Указывай (в обратных кавычках) ссылки на код в формате `путь:строка`, `путь:строка-строка` или `путь:строка,строка,строка`. "
    "Вставляй фрагменты кода в отчёт, чтобы было понятно, что именно требует исправления."
)
VERIFY=0 # 0/1 - выкл/вкл - experimental feature
VERIFY_PROMPT = (
    "Ты получил черновик ревью. Для каждого замечания проверь: действительно ли эта проблема существует "
    "в активном коде файлов, которые ты уже прочитал? Убери замечания, которые либо уже решены в коде, "
    "либо относятся к закомментированным блокам, либо ты не можешь подтвердить цитатой из кода. "
    "Верни итоговый ревью-отчёт."
)
TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "read_file",
            "description": "Читает содержимое файла",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "description": "Путь от корня репозитория"}
                },
                "required": ["path"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "read_code",
            "description": "Читает содержимое файла с номерами строк",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "description": "Путь от корня репозитория"}
                },
                "required": ["path"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "index_skills",
            "description": "Возвращает индекс скилов: название и описание каждого скила",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "description": "Путь от корня репозитория"}
                },
                "required": ["path"]
            }
        }
    }
]

def linkify(text):
    if not (_mr_project_url and _mr_source_branch):
        return text
    def make_link(path, lines):
        # lines — одна строка, диапазон (N-M) или список через запятую
        parts = [p.strip() for p in lines.split(",")]
        links = []
        for part in parts:
            if "-" in part:
                start, end = part.split("-", 1)
                anchor = f"L{start}-{end}"
                label = f"{path}:{start}-{end}"
            else:
                anchor = f"L{part}"
                label = f"{path}:{part}"
            url = f"{_mr_project_url}/-/blob/{_mr_source_branch}/{path}?ref_type=heads#{anchor}"
            links.append(f"[{label}]({url})")
        return ", ".join(links)
    return re.sub(
        r"`?([\w./\-]+\.\w+):(\d+(?:-\d+)?(?:,\s*\d+(?:-\d+)?)*)`?",
        lambda m: make_link(m.group(1), m.group(2)),
        text
    )

def _safe_resolve(rel_path):
    base = os.path.abspath(_project_dir)
    path = os.path.abspath(os.path.join(_project_dir, rel_path.lstrip("/")))
    if path != base and not path.startswith(base + os.sep):
        return None
    return path

def _read_file(rel_path, numbered=False):
    path = _safe_resolve(rel_path)
    if path is None:
        return "Ошибка: путь за пределами репозитория"
    if not os.path.exists(path):
        return f"Файл не найден: {rel_path}"
    with open(path, encoding="utf-8") as f:
        lines = f.readlines()
    if numbered:
        return "".join(f"{i+1:4} {line}" for i, line in enumerate(lines))
    return "".join(lines)

def call_tool(name, args):
    if name == "index_skills":
        path = _safe_resolve(args["path"])
        if path is None:
            return "Ошибка: путь за пределами репозитория"
        if not os.path.isdir(path):
            return f"Директория не найдена: {args['path']}"
        entries = sorted(os.listdir(path))
        lines = []
        for e in entries:
            entry_path = os.path.join(path, e)
            if os.path.isdir(entry_path):
                skill_file = os.path.join(entry_path, "SKILL.md")
                description = ""
                if os.path.isfile(skill_file):
                    with open(skill_file, encoding="utf-8") as sf:
                        in_frontmatter = False
                        for line in sf:
                            line = line.strip()
                            if line == "---":
                                if not in_frontmatter:
                                    in_frontmatter = True
                                    continue
                                else:
                                    break  # конец frontmatter
                            if in_frontmatter and line.startswith("description:"):
                                description = " — " + line[len("description:"):].strip().strip('"')
                                break
                lines.append(f"{e}/{description}")
            else:
                lines.append(e)
        return "\n".join(lines)
    if name == "read_file":
        return _read_file(args["path"])
    if name == "read_code":
        return _read_file(args["path"], numbered=True)
    return "Неизвестный инструмент"

def chat(messages, retries=3, timeouts=(300, 300, 600)):
    body = json.dumps({
        "model": ZAI_MODEL,
        "messages": messages,
        "tools": TOOLS,
        "temperature": 0.0
    }).encode()
    for attempt in range(retries):
        timeout = timeouts[attempt] if attempt < len(timeouts) else timeouts[-1]
        req = urllib.request.Request(ZAI_ENDPOINT, data=body, headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {ZAI_API_KEY}"
        })
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read())
        except urllib.error.HTTPError as e:
            error_body = e.read().decode('utf-8', errors='replace')
            e.close()
            print(f"Ошибка: API вернул HTTP {e.code}: {error_body}", file=sys.stderr)
            sys.exit(1)
        except urllib.error.URLError as e:
            if isinstance(e.reason, TimeoutError):
                print(f"Ошибка: таймаут ({timeout}с), попытка {attempt + 1}/{retries}", file=sys.stderr)
                continue
            print(f"Ошибка: сетевая ошибка: {e.reason}", file=sys.stderr)
            sys.exit(1)
        except TimeoutError:
            print(f"Ошибка: таймаут ({timeout}с), попытка {attempt + 1}/{retries}", file=sys.stderr)
            continue
    print("Ошибка: все попытки исчерпаны, API не ответил вовремя", file=sys.stderr)
    sys.exit(1)

def run_tool_loop(messages, max_iter=10):
    """Выполняет цикл запросов к модели, обрабатывая tool_calls. Возвращает финальный текст."""
    for iteration in range(max_iter):
        print(f"[debug] iter {iteration}, отправляем запрос...", file=sys.stderr)
        resp = chat(messages)
        try:
            msg = resp["choices"][0]["message"]
        except (KeyError, IndexError, TypeError) as e:
            print(f"Ошибка: неожиданный формат ответа API: {e}", file=sys.stderr)
            sys.exit(1)
        messages.append(msg)

        if not msg.get("tool_calls"):
            return msg.get("content", "")

        for tc in msg["tool_calls"]:
            fn = tc["function"]["name"]
            try:
                args = json.loads(tc["function"]["arguments"])
            except (json.JSONDecodeError, KeyError) as e:
                print(f"Ошибка: невалидные аргументы tool call {fn}: {e}", file=sys.stderr)
                sys.exit(1)
            print(f"[debug] tool: {fn}({args})", file=sys.stderr)
            result = call_tool(fn, args)
            messages.append({
                "role": "tool",
                "tool_call_id": tc["id"],
                "content": result
            })
    print("Ошибка: превышено максимальное число итераций, возвращаю последний ответ", file=sys.stderr)
    last_content = messages[-1].get("content", "") if messages else ""
    for m in reversed(messages):
        if m.get("role") in ("assistant", None) and m.get("content"):
            last_content = m["content"]
            break
    return last_content

diff = sys.stdin.read().strip()
if not diff:
    print("Нет изменений для ревью", file=sys.stderr)
    sys.exit(1)

if not os.path.isfile(os.path.join(_project_dir, "AGENTS.md")):
    print("Ошибка: файл AGENTS.md не найден", file=sys.stderr)
    sys.exit(1)

# Шаг 1: модель читает стандарты проекта
messages = [
    {
        "role": "system",
        "content": PROMPT
    },
    {
        "role": "user",
        "content": (
            "Прочитай `AGENTS.md` через read_file, "
            "затем вызови index_skills для `.agents/skills/`. "
            "Подтверди: какие стандарты усвоил и какие скилы доступны."
        )
    }
]
print("[debug] предварительный промпт: чтение стандартов...", file=sys.stderr)
_pre_reply = run_tool_loop(messages)
print(f"[debug] модель подтвердила:\n{_pre_reply}", file=sys.stderr)

# Шаг 2: ревью диффа — модель сама выбирает нужные скилы после прочтения diff
_changed_files = re.findall(r"^@@@ (.+)$", diff, re.MULTILINE)
_files_list = "\n".join(f"- {f}" for f in _changed_files)
messages.append(
    {
        "role": "user",
        "content": (
            f"Сделай ревью этого диффа.\n\n"
            "Перед ревью:\n"
            f"1. Прочитай (через read_code) каждый из изменённых файлов, чтобы видеть полный контекст:\n{_files_list}\n"
            "2. Прочитай (через read_file) SKILL.md тех скилов из индекса, "
            "которые релевантны изменениям в диффе (включая смежные скилы, если нужно).\n\n"
            f"{diff}"
        )
    }
)
draft = run_tool_loop(messages)

# Шаг 3: проверка (опционально)
if int(os.environ.get("VERIFY", VERIFY)):
    print("[debug] верификация...", file=sys.stderr)
    messages.append({"role": "user", "content": VERIFY_PROMPT})
    draft = run_tool_loop(messages)

print(linkify(draft))
