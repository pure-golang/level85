---
name: "x-bdd-godog"
description: "Применяй при написании бизнес-тестов через godog: структура feature-файлов по каноническому Gherkin, нумерация сценариев, root-runner test/bdd, TestMain, step definitions и testcontainers"
compatibility: github.com/cucumber/godog, github.com/stretchr/testify v1+, github.com/testcontainers/testcontainers-go
---
# BDD на godog

Этот skill — **канонический владелец** правил BDD-слоя про:
- layout `test/bdd/**`
- именование epic/story/scenario
- wiring `godog.TestSuite`, `TestMain`, `State`
- размещение и регистрацию step definitions

`x-bdd-product-workflow`, `x-bdd-dev-workflow` и `bdd-reviewer` не должны переописывать эти правила, а должны ссылаться сюда.

## Когда применять

- Создаёшь или меняешь `.feature` в `test/bdd/NN_epic/`.
- Подключаешь или перестраиваешь `godog`-слой в `test/bdd/`.
- Проверяешь, соответствует ли BDD-слой проектному layout.

Не применяй для:
- продуктового пути от PRD до готового `.feature` → `x-bdd-product-workflow`
- RGB-реализации готового `.feature` → `x-bdd-dev-workflow`
- извлечения сценариев из legacy → `x-bdd-knowledge-harvest`

## Core workflow

### 1. Подтверди, что задача относится к BDD-слою

BDD здесь описывает поведение, видимое аналитику или заказчику. Если проверка формулируется на языке системы, а не бизнеса, это другой слой тестирования.

### 2. Собери файловую структуру по проектному layout

#### Физическая структура

```text
{project-root}/
└── test/
    └── bdd/
        ├── bdd_test.go          ← TestMain + Test<Name> по эпикам
        ├── state.go
        ├── stack.go
        ├── prefix.go
        ├── steps_common.go
        ├── helpers.go
        ├── runner.go
        ├── steps_NN_<name>.go   ← по одному на эпик
        ├── 01_delivery/
        │   ├── 01_copy.feature
        │   └── 02_forward.feature
        └── 02_billing/
            └── 01_subscription.feature
```

`.feature` файлы живут в директории своего эпика, а не в отдельном `features/` поддереве. Go runner и step definitions живут в корне `test/bdd/`, чтобы один `TestMain` поднимал инфраструктуру один раз на весь BDD-прогон.

#### Иерархия сущностей

| Уровень | Где живёт | Что означает |
|---|---|---|
| Epic | директория `NN_name/` | крупное продуктовое направление |
| Feature | файл `NN_name.feature` | одна user story |
| Scenario | `Scenario: NN_slug` | одна бизнес-проверка |

#### Naming rules

- Директория эпика: `NN_name`
- Файл feature: `NN_name.feature`
- Номер файла задаёт порядок story внутри эпика и не дублирует номер директории
- Файл шагов эпика: `test/bdd/steps_NN_<name>.go` (с номером, совпадающим с номером директории)
- Имя сценария: `NN_slug` для happy path или `NNA_slug` для corner/edge case того же use case
- Смысловая часть имени после номера пишется на английском в `snake_case`
- Формат совпадает с соглашением для имён кейсов в табличных тестах и удобен для поиска в выводе `go test`
- Регекс сценария: `^\d{2}[A-Z]?_[a-z0-9_]+$`

#### Numbering rules

- Happy path каждого use case использует базовый номер: `01`, `02`, `03`
- Corner/edge cases того же use case используют букву после базового номера: `01A`, `01B`, `02A`
- Уникальность номера обязательна только в рамках файла
- Пропуски допустимы: не перенумеровывай файл после удаления сценария
- Внешняя ссылка строится как `эпик/файл#номер`, например `01_delivery/01_copy.feature#02A`

#### Минимальный feature template

```gherkin
Feature: Вход пользователя

  Как зарегистрированный пользователь
  Я хочу войти по email и паролю
  Чтобы получить доступ к своему кабинету

  Scenario: 01_successful_login_with_valid_credentials
    Given зарегистрирован пользователь "user@example.com"
    When пользователь отправляет запрос на вход с email "user@example.com" и паролем "correct"
    Then пользователь получает доступ к личному кабинету
```

#### Антипаттерны

- `.feature` вне директории своего эпика (`test/bdd/NN_epic/`)
- файл вида `01_01_login.feature` внутри `01_auth/`
- несколько `Feature:` в одном файле
- отсутствие блока `Как / Я хочу / Чтобы`
- duplicate `Scenario: 01_...` в одном файле
- технические детали в шагах вместо бизнес-языка

### 3. Подключи `godog` без локальной самодеятельности

Раскладка BDD-кода: **один test-пакет `test/bdd`** плюс feature-директории эпиков.

```
test/bdd/
  bdd_test.go             ← TestMain + Test<Name> по эпикам; //go:build bdd
  stub.go                 ← пустой package stub; //go:build !bdd
  state.go                ← type State, Reset; //go:build bdd
  stack.go                ← startStack, liveStack, testcontainers, сервисы; //go:build bdd
  prefix.go               ← GeneratePrefix, scenarioSeq, если нужен; //go:build bdd
  steps_common.go         ← RegisterCommonSteps, RegisterAllSteps; //go:build bdd
  helpers.go              ← общие BDD-хелперы, если нужны; //go:build bdd
  runner.go               ← runEpic, featurePaths, godog.TestSuite; //go:build bdd
  steps_NN_<name>.go      ← Register<Name>Steps (по одному на эпик); //go:build bdd
  01_delivery/
    *.feature             ← feature-файлы эпика
  02_filters/
    *.feature
  …
  06_auto/
    *.feature
```

- Корневой `test/bdd/bdd_test.go` содержит `TestMain(m *testing.M)` и `Test<Name>` по каждому эпику.
- Per-epic `test/bdd/NN_epic/bdd_test.go` не создавай: он запускает отдельный test binary и будет перезапускать контейнеры.
- Все `Register<Name>Steps` живут в `test/bdd/steps_NN_*.go` и регистрируются вместе, потому что feature-файлы разных эпиков могут переиспользовать шаги друг друга.
- `State`, stack, common Given-шаги и helpers живут в `test/bdd`; приватные хелперы конкретного эпика остаются file-local в `steps_NN_<name>.go`.

**Зачем один package:** BDD-прогон поднимает тяжёлый black-box stack. Один package `test/bdd` даёт один `TestMain`, один набор контейнеров и сервисов на все эпики и одну кешируемую запись `go test` для полного BDD-прогона.

**Ограничения:**
- Правка любого step-файла инвалидирует BDD-cache всего пакета.
- `task test-bdd` должен запускать один пакет: `go test -timeout 20m -v -failfast -tags bdd ./test/bdd/`.
- Для проверки без кеша используй ручной `go test -count=1 ...`, но task по умолчанию может оставаться кешируемым.
- Build tag `bdd` должен стоять на всех `.go` файлах с BDD-runner, stack и steps, чтобы обычный `go test ./test/bdd/` не компилировал BDD stack и testcontainers-зависимости.
- Если в пакете без tag не остаётся файлов, добавь лёгкий `stub.go` с `//go:build !bdd` и только `package bdd`.
- Build tag `bdd` отделяет BDD от короткой unit-петли; отдельный `testing.Short()` guard в BDD runner не нужен.

#### Минимальный `bdd_test.go` в `test/bdd`

`TestMain` владеет boot/shutdown общего stack. Каждый эпик запускается отдельным test-функцией:

```go
//go:build bdd

package bdd

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"
)

func TestMain(m *testing.M) {
	chdirOnce.Do(chdirProjectRoot)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	stackOnce.Do(func() {
		liveStack, liveStackErr = startStack(ctx)
	})
	cancel()

	if liveStackErr != nil {
		fmt.Fprintf(os.Stderr, "BDD stack init: %v\n", liveStackErr)
		os.Exit(1)
	}

	code := m.Run()

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
	liveStack.Close(shutdownCtx)
	shutdownCancel()

	os.Exit(code)
}

func TestDelivery(t *testing.T) {
	runEpic(t, "01_delivery")
}
```

`runEpic` остаётся приватным helper в `runner.go`; публичный `RunEpic` не нужен.

**`BDD_PATHS` для дебага:** указывает на конкретную директорию или `.feature`-файл (несколько через запятую), нужен только при локальном прогоне; ответственность за сочетание c правильным `-run` и целевой директорией пакета — на пользователе:
```bash
BDD_PATHS=test/bdd/01_delivery/01_copy.feature \
  go test -tags bdd -run TestDelivery ./test/bdd/
```

#### Bootstrap через `TestMain`

Не поднимай testcontainers прямо в step-файлах. Shared setup принадлежит `TestMain`/`stack.go` в `test/bdd`.
Если BDD-сценарий является интеграционным тестом и поднимает внешние сервисы через testcontainers-go, правила запуска контейнеров см. `x-testcontainers-go`.

#### `State`

```go
type State struct {
	client   *httpclient.Client
	lastResp *http.Response
	lastErr  error
}

func (s *State) Reset() {
	s.lastResp = nil
	s.lastErr = nil
}

func initScenario(ctx *godog.ScenarioContext) {
	s := &State{client: httpclient.New(apiURL)}

	ctx.Before(func(ctx context.Context, sc *godog.Scenario) (context.Context, error) {
		s.Reset()
		return ctx, nil
	})

	register01AuthSteps(ctx, s)
}
```

#### Регистрация шагов

- Один файл шагов на эпик: `test/bdd/steps_01_auth.go`, `test/bdd/steps_02_billing.go`
- Методы шагов живут на `State`
- Текст шагов остаётся на бизнес-языке
- Функции шагов возвращают только `error`

```go
func register01AuthSteps(ctx *godog.ScenarioContext, s *State) {
	ctx.Step(`^зарегистрирован пользователь "([^"]*)"$`, s.userRegistered)
	ctx.Step(`^пользователь получает доступ к личному кабинету$`, s.userHasAccess)
}
```

#### Полезные команды

- для 01_epic -> 01_story выполнить все "^01[A-Z]?_some_use_case"
```bash
BDD_PATHS=test/bdd/01_epic/01_story.feature go test -count=1 -tags bdd ./test/bdd/ -godog.name="^01[A-Z]?_some_use_case"
```

- выполнить `TestSomeEpic()`
```bash
go test -count=1 -tags bdd ./test/bdd/ -run TestSomeEpic 
```

- Taskfile.yml
```bash
task test-bdd # Run BDD scenarios
task bdd-out # Show pending and undefined BDD steps
task bdd-inventory # Group pending and undefined BDD steps by epic
```

### 4. Держи границы ответственности

- layout, naming, numbering и wiring принадлежат этому skill
- продуктовые вопросы и состав сценариев принадлежат `x-bdd-product-workflow`
- порядок red → green → blue принадлежит `x-bdd-dev-workflow`

Если правило уже описано в другом skill как его owner-area, здесь оставляй только ссылку.

## Короткий чек-лист

- `.feature` лежит в `test/bdd/NN_epic/NN_story.feature`
- в файле ровно один `Feature:` и user story блок
- `Scenario:` имеют стабильные имена на английском: `NN_slug` для happy path, `NNA_slug` для corner/edge case
- `godog.TestSuite` использует `Strict: true`
- `State.Reset()` вызывается в `Before`
- testcontainers bootstrap не размазан по step-файлам

## Смежные skills

- `x-bdd-product-workflow`
- `x-bdd-dev-workflow`
- `x-bdd-knowledge-harvest`
- `x-testcontainers-go`
- `x-testing-conventions`
