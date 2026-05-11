---
name: "x-bdd-fake-green"
description: "Применяй при ревью или реализации BDD steps на godog или playwright-bdd, когда нужно выявить FAKE GREEN: stateful-заглушки, no-op шаги, self-fulfilling Then, локальную подстановку ошибок, When без observable effect и сценарии, которые проходят без проверки реальной реализации. Используй каждый раз при аудите BDD на честность, при переводе undefined/pending в green и в bdd-reviewer."
compatibility: github.com/cucumber/godog, playwright-bdd, Go and TypeScript BDD step definitions
---
# BDD Fake Green Audit

Этот skill — владелец правил поиска и устранения BDD fake green.

Fake green — это BDD-шаг или сценарий, который проходит зелёным, но не проверяет реальную реализацию. Типичный пример: `Given` записал значение в `ScenarioState`, `When` поменял другое поле в памяти, `Then` сравнил эти же поля и вернул `nil`.

Цель аудита — не сделать больше pending любой ценой, а убрать самообман. Если реальная проверка сейчас недоступна, шаг должен возвращать `godog.ErrPending`, а не зелёный `nil`.

## Область применения

Применяй при работе с:

- любыми godog step definitions в API BDD runner-е;
- любыми playwright-bdd step definitions в browser BDD runner-е;
- `.feature` сценариями, если проверяешь соответствие шагов реализации;
- BDD reviewer задачами;
- переводом `undefined -> pending -> green`;
- расследованием резкого падения числа pending/failed после правок.

Не применяй как замену:

- `x-bdd-api` для API BDD layout/naming/wiring;
- `x-bdd-browser` для browser BDD layout/wiring;
- `x-bdd-dev-workflow` для общего red-green-blue процесса;
- `x-testing-conventions` для общих правил test layer.

## Главный принцип

Зелёный BDD-сценарий должен падать, если сломать соответствующую бизнес-реализацию.

Если сценарий не упадёт при поломке сервиса, handler, repo, worker, queue consumer, внешнего adapter contract или другого production-path, это fake green либо слишком слабый тест.

## Что считать реальной проверкой

Шаг считается честным, если он делает хотя бы одно из этого и результат влияет на pass/fail:

- вызывает production API через gRPC/HTTP/GraphQL/CLI;
- выполняет реальное пользовательское действие через Playwright и проверяет видимый браузерный результат;
- проверяет запись или отсутствие записи в реальной test DB;
- наблюдает FakeSMTP/FakeWebhook/FakeQueue/FakeClock как test double внешней границы;
- проверяет ошибку, полученную от production call, а не созданную вручную в step;
- проверяет response/event/log/metric, который появился из production flow;
- создаёт данные через публичный API сервиса, если это часть бизнес-предусловия.

Прямой DB seed допустим только для `Given`, когда он создаёт фоновые данные, которые не являются проверяемым действием сценария. Если `When` заявляет «пользователь создаёт/обновляет/удаляет/отправляет», прямой `INSERT/UPDATE` вместо production path — fake green.

## Красные флаги

Считай подозрительным и проверяй вручную:

- `return nil` без assertion или observable effect;
- комментарии `no-op`, `мягко`, `считаем`, `имитируем`, `симулируем`, `декларативно`, `информационно`, `не проверяем`;
- `When` только пишет в `state.*`, `s.*`, `t.*`;
- `Then` проверяет поле, которое выставил предыдущий step, а не production output;
- локальная подстановка ошибок: `LastErr = fmt.Errorf(...)`, `LastErrorCode = "..."`, synthetic gRPC status;
- локальная подстановка успешного ответа: `AuthResp = ...`, `LastChannel.Status = ...`, `LastAlert.Status = ...`;
- проверка принимает любую ошибку как успех;
- проверка игнорирует неизвестные поля таблицы или placeholder без реальной альтернативной проверки;
- `Then` только проверяет `object != nil`, когда сценарий обещает конкретное бизнес-свойство;
- pending count резко падает без добавления production calls/assertions.

Для browser BDD дополнительно считай подозрительным:

- `Then` проверяет локальное поле page object вместо DOM, URL, browser state или network-visible результата;
- `When` только записывает состояние в fixture/world и не вызывает Playwright action;
- `Then` повторяет `When`, например снова кликает или заново отправляет форму вместо проверки результата;
- network mock подменяет именно то поведение, которое сценарий обещает проверить;
- `expect` проверяет наличие locator object, а не `toBeVisible`, `toHaveText`, `toHaveURL` или другой наблюдаемый результат.

## Допустимые исключения

Не помечай автоматически как fake green:

- `Given` сохраняет выбор пользователя для следующего реального `When`, например provider name перед OAuth call;
- `Given` seed-ит DB для фонового состояния, а сценарий потом реально вызывает сервис;
- helper агрегирует уже полученные ошибки/responses, например `lastError()`;
- step кэширует protobuf response в `ScenarioState` после реального call, чтобы последующий `Then` мог проверить его поля;
- test double на внешней границе получил запрос из production flow, например FakeSMTP/FakeWebhook.

Исключение должно быть понятно из кода. Если без устного контекста непонятно, почему `return nil` честный, усили проверку или оставь короткий комментарий.

## Аудит workflow

### 1. Сопоставь feature шаги и step definitions

Для затронутого эпика посмотри `.feature` и соответствующие step definition файлы. Их расположение определяй по текущему репозиторию и `x-bdd-api`/`x-bdd-browser`; этот skill не задаёт layout.

Классифицируй шаги:

- `Given`: setup или бизнес-предусловие;
- `When`: observable production action;
- `Then/And`: assertion over production output.

Особенно проверяй сценарии, где все шаги green, но `When` не вызывает production code.

### 2. Найди текстовые маркеры

Используй `rg` как быстрый фильтр. Сначала собери список затронутых step-файлов в переменную или передай их явно:

```bash
rg -n 'мягк|считаем|имит|эмулир|симулир|заглуш|не провер|игнор|декларатив|информацион|No-op|no-op|return nil\s*//|TODO no-op|fake green|state-machine|локальн|фабрикац|допустим' $STEP_FILES
```

Не исправляй всё механически. Маркер в `pendingStep` или честном комментарии может быть нормальным; маркер рядом с `return nil` почти всегда требует ручной проверки.

### 3. Найди пустые шаги

```bash
rg -n 'func .*\\{\\n\\s*return nil\\n\\}' -U $STEP_FILES
```

Пустой `return nil` допустим редко. Для `Then` почти всегда неправильно. Для `Given` допустим только если это чистый alias на уже выполненный setup, но лучше сделать явную проверку состояния.

### 4. Найди state-only модели

Ищи пары write/read:

```bash
rg -n 'LastErr\\s*=|LastErrorCode\\s*=|AuthResp\\s*=|LastChannel\\.|LastAlert\\.|Status\\s*=|Enabled\\s*=|Verified\\s*=' $STEP_FILES
```

Проверь происхождение значения:

- если значение пришло из production response — нормально;
- если значение создано в step как ожидаемый результат — fake green;
- если ошибка создана вручную вместо вызова сервиса — fake green.

### 5. Сделай структурный pass

Когда grep недостаточен, используй маленький скрипт, который ищет функции с `return nil`, но без признаков production call/assertion. Пример:

```bash
python3 - <<'PY'
import re
import os
from pathlib import Path

files = [Path(p) for p in os.environ['STEP_FILES'].split()]
func_re = re.compile(r'func\s+(?:\([^)]*\)\s*)?(\w+)\s*\([^)]*\)\s*(?:\([^)]*\)|\w+)?\s*\{')
real = [
    'stack.', 'Client.', 'DB', 'ExecContext', 'Query', 'GetContext', 'SelectContext',
    'Fake', 'grpc', 'Register', 'Login', 'Validate', 'Create', 'Update', 'Delete',
    'List', 'Get', 'Invite', 'Accept', 'Revoke', 'Verify', 'status.FromError',
    'fmt.Errorf', 'godog.ErrPending', 'return err', 'protojson', 'strings.Contains',
]
state = ['state.', 's.state.', 't.state.', 'LastErr', 'LastErrorCode', 'AuthResp', 'LastChannel', 'LastAlert']

for p in files:
    text = p.read_text()
    for m in func_re.finditer(text):
        start = m.end()
        depth = 1
        i = start
        in_str = False
        quote = ''
        esc = False
        while i < len(text) and depth:
            c = text[i]
            if in_str:
                if esc:
                    esc = False
                elif c == '\\':
                    esc = True
                elif c == quote:
                    in_str = False
            else:
                if c in ('"', '`'):
                    in_str = True
                    quote = c
                elif c == '{':
                    depth += 1
                elif c == '}':
                    depth -= 1
            i += 1
        body = text[start:i-1]
        if 'return nil' not in body:
            continue
        has_real = any(x in body for x in real)
        has_state = any(x in body for x in state)
        calls = len(re.findall(r'\w+\s*\(', body))
        if (has_state and not has_real) or (calls <= 2 and not has_real):
            line = text.count('\n', 0, m.start()) + 1
            print(f'{p}:{line}:{m.group(1)}')
PY
```

Каждый результат проверь вручную. Скрипт — фильтр, не судья.

### 6. Проверь Then-шаги отдельно

Для каждого `Then`/assertion step задай вопросы:

- Что именно упадёт, если production implementation сломана?
- Проверяется ли конкретное поле/код/событие, а не просто факт `response != nil`?
- Не принимает ли проверка любой error как success?
- Не игнорирует ли таблицу полностью?
- Не сравнивает ли она ожидаемое значение с тем же значением, которое step сам записал ранее?

Если ответа нет, реализуй реальную проверку или верни `godog.ErrPending`.

### 7. Используй runtime/coverage методы для спорных мест

Когда код выглядит честно, но есть сомнения:

- временно сломай production path и проверь, падает ли сценарий;
- включи логирование gRPC/SQL/Fake-сервисов и убедись, что passed scenario сделал ожидаемые calls;
- запусти coverage по сервисным пакетам: passed scenario без покрытия соответствующего production code — сильный сигнал fake green;
- сравни `out.txt` до/после: резкое уменьшение pending без новых production calls требует ревью.

## Что делать при находке

Выбирай один из вариантов:

1. Реализуй настоящий production call или observable assertion.
2. Если реальная проверка требует отдельной инфраструктуры или функционала, верни `godog.ErrPending`.
3. Если это допустимый setup/helper, усили минимальной проверкой и оставь короткий комментарий, почему это не fake green.

Не заменяй fake green другой локальной моделью. Stateful модель сценария допустима только как кэш результатов production calls, а не как источник истины.

## Report format

При аудите сначала дай findings:

```text
❌ path/to/steps_file.go:123
Шаг "..." возвращает green после локальной подстановки LastErr, production call не выполняется.
Решение: вызвать реальный сервис или вернуть godog.ErrPending.
```

Если нарушений нет, явно напиши:

```text
Findings по fake green не обнаружены.
Остаточный риск: перечисли непроверенные runtime/coverage методы, если они не запускались.
```

В конце укажи:

- какие файлы просмотрены;
- какие методы поиска использованы: grep, structural pass, feature-to-step review, runtime trace, coverage;
- какие команды запускались;
- что не запускалось.
