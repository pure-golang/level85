---
name: "x-bdd-dev-workflow"
description: "Применяй при реализации функционала по готовому .feature: скелет шагов (red) → реализация до green → рефакторинг (blue)"
---
# BDD Dev Workflow

Этот skill — **канонический владелец** разработческого RGB-цикла по готовому `.feature`.

Он не владеет layout, naming и numbering BDD-файлов. За это отвечает `x-bdd-godog`.

## Когда применять

- Реализуешь фичу по уже согласованному `.feature`.
- Добиваешься green в `test/bdd/steps/`.
- Рефакторишь BDD-реализацию после зелёного прогона.

Не применяй для:
- составления требований и продуктового ревью → `x-bdd-product-workflow`
- layout и wiring `godog` → `x-bdd-godog`
- извлечения legacy-сценариев → `x-bdd-knowledge-harvest`

## Core workflow

### 1. Подтверди вход

Перед началом убедись, что `.feature` уже согласован и соответствует `x-bdd-godog`. Если во время реализации всплывает продуктовая неоднозначность, вернись в `x-bdd-product-workflow`, а не переписывай сценарии на лету.

### 2. Red: заведи скелет шагов

- сгенерируй или выпиши missing step definitions
- перенеси их в `test/bdd/steps/` по layout из `x-bdd-godog`
- зафиксируй полный список pending/missing шагов

Примеры команд и pending-snippets смотри в `references/rgb-playbook.md`.

### 3. Green: веди сценарии по одному

- начинай с `01. ...`
- затем проходи остальные базовые сценарии
- буквенные варианты добивай после базового кейса
- не распараллеливай незелёные сценарии

### 4. Blue: рефактори под зелёными BDD-тестами

- убирай дубли в step helpers и `test/support`
- не меняй `.feature` как часть blue-фазы
- после каждого значимого шага перепроверяй сценарии

### 5. Заверши цикл

- полный BDD-прогон зелёный
- pending-шагов не осталось
- `bdd-reviewer` можно запускать как финальную read/check/report-проверку

## Короткий чек-лист

- входной `.feature` согласован
- red-фаза зафиксирована до реализации
- сценарии доводятся до green последовательно
- refactoring не меняет бизнес-контракт `.feature`
- в целевой ветке не остаётся `godog.ErrPending`

## References

- `references/rgb-playbook.md` — red/green/blue playbook, команды, snippets и запреты

## Смежные skills

- `x-bdd-godog`
- `x-bdd-product-workflow`
- `x-integration-testing`
- `x-errors`
- `x-log`
- `x-observability`
