---
name: "x-testing-conventions"
description: "Применяй при написании или правке любого теста в проекте: выбор слоя (`unit`/`integration`/`bdd`/`e2e`/`smoke`), `t.Parallel()`, `testing.Short()`, AAA и базовая структура проверки"
---
# Testing Conventions

Этот skill — **канонический владелец** общих правил тестового слоя:
- layer selection и физическое расположение теста
- маркеры слоя (`t.Parallel()`, `testing.Short()`, build tags)
- AAA-структура
- базовые требования к именованию и cleanup

Другие testing-skills не должны переописывать эти правила, а должны ссылаться сюда.

## Когда применять

- пишешь новый тест
- переносишь тест между слоями
- ревьюишь структуру существующего теста

## Core workflow

### 1. Сначала определи слой теста

| Слой | Где живёт | Маркер |
|---|---|---|
| unit | `*_test.go` рядом с кодом | `t.Parallel()` по умолчанию |
| integration | `test/integration/` | `if testing.Short() { t.Skip(...) }` |
| bdd | `test/bdd/steps/` | `if testing.Short() { t.Skip(...) }` |
| e2e | `test/e2e/` | `//go:build e2e` |
| smoke | `test/smoke/` | `//go:build smoke` |

Если тест проверяет систему на языке бизнеса, смотри BDD-skills. Если проверка техническая и использует реальные внешние зависимости, это integration/e2e/smoke, а не unit.

### 2. Поставь правильный маркер слоя

- unit-тест обычно начинает с `t.Parallel()`
- если unit-тест меняет process-wide state, `t.Parallel()` не ставь
- integration и bdd маркируются через `testing.Short()`, а не через `t.Parallel()`
- e2e и smoke маркируются build tags

Для безопасных случаев без `t.Parallel()` см. `references/parallel-safety.md`.

### 3. Держи тест в форме AAA

Каждый тест и каждый `t.Run` содержит:
- `// Arrange`
- `// Act`
- `// Assert`

AAA — обязательный project convention. Для примеров форм тестов см. `references/test-matrix-and-aaa.md`.

### 4. Соблюдай минимальные naming/cleanup правила

- имена кейсов в таблицах — `snake_case` или lowercase-with-hyphen
- `t.Cleanup(...)` предпочитай `defer` для test-owned ресурсов
- integration/bdd/e2e/smoke не используют `t.Parallel()` как маркер слоя
- `t.Skip()` не используется для сокрытия падающего теста; допустим только слой-маркер через `testing.Short()`

### 5. Для специальных техник подключай только нужное

- unit dependencies, local interfaces, callback-style зависимости → `x-unit-test-partial-interface`
- testcontainers/shared setup → `x-integration-testing`
- snapshot и `synctest` техники → `references/special-techniques.md`
- BDD lifecycle `red -> green -> blue` → `x-bdd-dev-workflow`

## Короткий чек-лист

- выбран правильный слой теста
- маркер слоя соответствует слою
- AAA присутствует
- `t.Parallel()` не конфликтует с process-wide state
- cleanup оформлен явно

## References

- `references/parallel-safety.md` — когда unit-тест не должен быть параллельным
- `references/test-matrix-and-aaa.md` — формы AAA и self-check
- `references/special-techniques.md` — snapshot и `synctest` как вспомогательные техники

## Смежные skills

- `x-integration-testing`
- `x-bdd-godog`
- `x-bdd-dev-workflow`
- `x-unit-test-partial-interface`
- `x-test-matrix`
