---
name: "x-bdd-godog"
description: "Применяй при написании бизнес-тестов через godog: структура feature-файлов по каноническому Gherkin, нумерация сценариев, step definitions, связь с testcontainers через test/support"
compatibility: github.com/cucumber/godog, github.com/stretchr/testify v1+, github.com/testcontainers/testcontainers-go
---
# BDD на godog

Этот skill — **канонический владелец** правил BDD-слоя про:
- layout `test/bdd/**` и symlink `docs/features`
- именование epic/story/scenario
- wiring `godog.TestSuite`, `TestMain`, `scenarioCtx`
- размещение и регистрацию step definitions

`x-bdd-product-workflow`, `x-bdd-dev-workflow` и `bdd-reviewer` не должны переописывать эти правила, а должны ссылаться сюда.

## Когда применять

- Создаёшь или меняешь `.feature` в `test/bdd/features/`.
- Подключаешь или перестраиваешь `godog`-слой в `test/bdd/steps/`.
- Проверяешь, соответствует ли BDD-слой проектному layout.

Не применяй для:
- продуктового пути от PRD до готового `.feature` → `x-bdd-product-workflow`
- RGB-реализации готового `.feature` → `x-bdd-dev-workflow`
- извлечения сценариев из legacy → `x-bdd-knowledge-harvest`

## Core workflow

### 1. Подтверди, что задача относится к BDD-слою

BDD здесь описывает поведение, видимое аналитику или заказчику. Если проверка формулируется на языке системы, а не бизнеса, это другой слой тестирования.

### 2. Собери файловую структуру по проектному layout

- `.feature` физически живут только в `test/bdd/features/`
- шаги живут только в `test/bdd/steps/`
- `docs/features` используется как symlink для навигации аналитиков
- numbering и naming берутся из `references/layout-and-numbering.md`

### 3. Подключи `godog` без локальной самодеятельности

- `bdd_test.go` держит `godog.TestSuite`
- shared bootstrap идёт через `TestMain` и `test/support`
- состояние сценария живёт в `scenarioCtx` и сбрасывается в `Before`
- step definitions группируются по эпикам, зеркалируя `features/`

Минимальные wiring-примеры и команды смотри в `references/bootstrap-and-steps.md`.

### 4. Держи границы ответственности

- layout, naming, numbering и wiring принадлежат этому skill
- продуктовые вопросы и состав сценариев принадлежат `x-bdd-product-workflow`
- порядок red → green → blue принадлежит `x-bdd-dev-workflow`

Если правило уже описано в другом skill как его owner-area, здесь оставляй только ссылку.

## Короткий чек-лист

- `.feature` лежит в `test/bdd/features/NN_epic/NN_story.feature`
- в файле ровно один `Feature:` и user story блок
- `Scenario:` имеют стабильные номера `NN.` или `NNA.`
- `godog.TestSuite` использует `Strict: true`
- `scenarioCtx.reset()` вызывается в `Before`
- testcontainers bootstrap не размазан по step-файлам

## References

- `references/layout-and-numbering.md` — файловая структура, naming, numbering, анти-паттерны
- `references/bootstrap-and-steps.md` — snippets для `godog`, `TestMain`, `scenarioCtx`, step registration и команд запуска

## Смежные skills

- `x-bdd-product-workflow`
- `x-bdd-dev-workflow`
- `x-bdd-knowledge-harvest`
- `x-integration-testing`
- `x-testing-conventions`
