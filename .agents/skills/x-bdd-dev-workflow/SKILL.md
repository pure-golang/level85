---
name: "x-bdd-dev-workflow"
description: "Применяй при реализации функционала по готовому .feature: скелет шагов (red) → реализация до green → рефакторинг (blue)"
---
# BDD Dev Workflow

Этот skill — **канонический владелец** разработческого RGB-цикла по готовому `.feature`.

Он не владеет layout, naming и numbering BDD-файлов. За это отвечает `x-bdd-api`.

## Когда применять

- Реализуешь фичу по уже согласованному `.feature`.
- Добиваешься green для готового сценария из `features/`.
- Рефакторишь BDD-реализацию после зелёного прогона.

Не применяй для:
- составления требований и продуктового ревью → `x-bdd-product-workflow`
- layout и wiring API runner-а → `x-bdd-api`
- layout и wiring browser runner-а → `x-bdd-browser`
- извлечения legacy-сценариев → `x-bdd-knowledge-harvest`

## Core workflow

### 1. Подтверди вход

Перед началом убедись, что `.feature` уже согласован, лежит в `features/` и соответствует `x-bdd-api`. Если во время реализации всплывает продуктовая неоднозначность, вернись в `x-bdd-product-workflow`, а не переписывай сценарии на лету.

Определи канал исполнения:
- monorepo: `@api` реализуется через `x-bdd-api`, `@browser` через `x-bdd-browser`;
- monorepo: если у сценария оба тега, оба runner-а должны получить честное покрытие;
- backend-only: корневой `test/bdd/` реализует все сценарии через API runner;
- frontend-only: корневой `test/bdd/` реализует все сценарии через browser runner.

### 2. Red: заведи скелет шагов

- сгенерируй или выпиши missing step definitions
- перенеси их в runner-директорию по layout из `x-bdd-api` или `x-bdd-browser`
- зафиксируй полный список pending/missing шагов

Запусти BDD-прогон и собери отсутствующие шаги:

```bash
task test-bdd # (или `task backend:test-bdd` для monorepo)
task bdd-out # (или `task backend:bdd-out` для monorepo)
```

Типичный pending-snippet:

```go
func (s *scenarioCtx) userRegistered(email string) error {
	return godog.ErrPending
}
```

### 3. Green: веди сценарии по одному

- начинай с `01. ...`
- затем проходи остальные базовые сценарии
- буквенные варианты добивай после базового кейса
- не распараллеливай незелёные сценарии

Pending переводится в реальный шаг и код за ним:

```bash
BDD_PATHS=features/01_delivery/01_copy.feature go test -run TestDelivery ./backend/test/bdd/ -godog.name="^01[A-Z]?_some_use_case"
npx bddgen && npx playwright test --grep "01_successful_login"
task test-bdd # (или `task backend:test-bdd` для monorepo)
```

### 4. Blue: рефактори под зелёными BDD-тестами

- убирай дубли в step helpers и `test/support`
- выноси дубли в `helpers_test.go` или `test/support`
- не меняй `.feature` как часть blue-фазы
- после каждого значимого шага перепроверяй сценарии
- регулярно гоняй полный BDD-набор

### 5. Заверши цикл

- полный BDD-прогон зелёный
- pending-шагов не осталось
- в monorepo все execution tags сценария реализованы соответствующими runner-ами
- `bdd-reviewer` можно запускать как финальную read/check/report-проверку

## Запреты

- pending/missing шаги в целевой ветке
- пропуск red-фазы
- параллельная реализация нескольких незелёных сценариев
- несанкционированное изменение `.feature` во время dev-цикла
- реализация только одного runner-а для monorepo-сценария, у которого несколько execution tags

## Короткий чек-лист

- входной `.feature` согласован
- сценарий читается из `features/`
- канал исполнения определён по типу проекта и execution tags
- red-фаза зафиксирована до реализации
- сценарии доводятся до green последовательно
- refactoring не меняет бизнес-контракт `.feature`
- в целевой ветке не остаётся `godog.ErrPending` или missing steps

## Смежные skills

- `x-bdd-api`
- `x-bdd-browser`
- `x-bdd-product-workflow`
- `x-testcontainers-go`
- `x-errors`
- `x-log`
- `x-observability`
