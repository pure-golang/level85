---
name: "x-bdd-api"
description: "Применяй при написании или правке API BDD через godog: общий каталог `features/`, теги `@api` в monorepo, layout API runner-а, TestMain, State, step definitions и testcontainers"
compatibility: github.com/cucumber/godog, github.com/stretchr/testify v1+, github.com/testcontainers/testcontainers-go
---
# API BDD на godog

Этот skill — **канонический владелец** правил API BDD-слоя про:
- общий layout Gherkin-сценариев в `features/**`
- naming и numbering epic/story/scenario
- `@api` execution tag в monorepo/multi-channel проектах
- layout API runner-а на `godog`
- wiring `godog.TestSuite`, `TestMain`, `State`
- размещение и регистрацию Go step definitions

`godog` — текущая реализация API BDD runner-а. Название skill-а описывает канал наблюдения: сценарии проверяют поведение через публичный API, сейчас через GraphQL supergraph `/graphql`.

`x-bdd-product-workflow`, `x-bdd-dev-workflow`, `x-bdd-knowledge-harvest`, `x-bdd-browser` и `bdd-reviewer` не должны переописывать эти правила, а должны ссылаться сюда.

## Когда применять

- Создаёшь или меняешь API BDD runner на `godog`.
- Пишешь или переносишь Go step definitions для API BDD.
- Проверяешь layout, naming, numbering и wiring API BDD.
- В monorepo работаешь со сценариями, помеченными `@api`.
- В backend-only проекте работаешь с корневым BDD runner-ом `test/bdd/`.

Не применяй для:
- browser BDD через Playwright → `x-bdd-browser`
- продуктового пути от PRD до готового `.feature` → `x-bdd-product-workflow`
- RGB-реализации готового `.feature` → `x-bdd-dev-workflow`
- извлечения сценариев из legacy → `x-bdd-knowledge-harvest`

## Core workflow

### 1. Определи тип проекта

| Тип проекта | Feature-файлы | API BDD runner |
|---|---|---|
| Monorepo | `features/NN_epic/NN_story.feature` | `backend/test/bdd/` |
| Backend-only | `features/NN_epic/NN_story.feature` | `test/bdd/` |
| Frontend-only | `features/NN_epic/NN_story.feature` | Не применимо |

В monorepo `features/` может читаться несколькими runner-ами. API runner исполняет только сценарии с `@api`.

В backend-only проекте канал исполнения задан типом проекта, поэтому execution tags `@api`, `@browser`, `@mobile` не нужны: корневой `test/bdd/` исполняет все `features/**/*.feature`.

### 2. Проверь структуру feature-файлов

#### Физическая структура

```text
{project-root}/
├── features/
│   ├── 01_delivery/
│   │   ├── 01_copy.feature
│   │   └── 02_forward.feature
│   └── 02_billing/
│       └── 01_subscription.feature
└── backend/test/bdd/        # monorepo
    ├── bdd_test.go
    ├── state.go
    ├── stack.go
    ├── prefix.go
    ├── steps_common.go
    ├── helpers.go
    ├── runner.go
    └── steps_NN_<name>.go
```

В backend-only проекте runner живёт в корневом `test/bdd/`:

```text
{project-root}/
├── features/
│   └── 01_identity/
│       └── 01_email_login.feature
└── test/bdd/
    ├── bdd_test.go
    ├── state.go
    ├── stack.go
    ├── runner.go
    └── steps_01_identity.go
```

`.feature` файлы всегда живут в `features/NN_epic/`. Runner-директории владеют Go-кодом, а не спецификацией.

#### Иерархия сущностей

| Уровень | Где живёт | Что означает |
|---|---|---|
| Epic | `features/NN_name/` | крупное продуктовое направление |
| Feature | `features/NN_name/NN_story.feature` | одна user story |
| Scenario | `Scenario: NN_slug` или `Scenario: NN[A-Z]_slug` | одна бизнес-проверка |

#### Naming rules

- Директория эпика: `NN_name`
- Файл feature: `NN_name.feature`
- Номер файла задаёт порядок story внутри эпика и не дублирует номер директории.
- Файл шагов эпика: `steps_NN_<name>.go` в директории API runner-а. Номер совпадает с номером директории эпика.
- Имя сценария: `NN_slug` для базового happy/base path.
- Имя сценария: `NN[A-Z]_slug` только для edge/corner/negative вариантов базового use case с тем же номером.
- Смысловая часть имени после номера пишется на английском в `snake_case`.
- Регекс сценария: `^\d{2}[A-Z]?_[a-z0-9_]+$`
- Внешняя ссылка на сценарий: `features/NN_epic/NN_story.feature#NN[A-Z]_case`

Пример:

```text
features/01_identity/01_email_login.feature#01_successful_login
features/01_identity/01_email_login.feature#01A_expired_code
```

#### Numbering rules

- Happy/base path каждого use case использует базовый номер: `01`, `02`, `03`.
- Edge/corner/negative cases того же use case используют букву после базового номера: `01A`, `01B`, `02A`.
- Уникальность номера обязательна только в рамках файла.
- Пропуски допустимы: не перенумеровывай файл после удаления сценария.

#### Минимальный feature template

В monorepo сценарий API-канала помечается `@api`:

```gherkin
Feature: Вход пользователя

  Как зарегистрированный пользователь
  Я хочу войти по email и паролю
  Чтобы получить доступ к своему кабинету

  @api
  Scenario: 01_successful_login_with_valid_credentials
    Given зарегистрирован пользователь "user@example.com"
    When пользователь входит с email "user@example.com" и паролем "correct"
    Then пользователь получает доступ к личному кабинету
```

В backend-only проекте тег канала не нужен:

```gherkin
Feature: Вход пользователя

  Как зарегистрированный пользователь
  Я хочу войти по email и паролю
  Чтобы получить доступ к своему кабинету

  Scenario: 01_successful_login_with_valid_credentials
    Given зарегистрирован пользователь "user@example.com"
    When пользователь входит с email "user@example.com" и паролем "correct"
    Then пользователь получает доступ к личному кабинету
```

#### Антипаттерны

- `.feature` вне `features/NN_epic/`
- runner-owned feature files: `.feature` внутри `backend/test/bdd/` или корневого `test/bdd/`
- дополнительный `features/` внутри runner-а: `backend/test/bdd/features/`
- файл вида `01_01_login.feature` внутри `features/01_auth/`
- несколько `Feature:` в одном файле
- отсутствие блока `Как / Я хочу / Чтобы`
- duplicate `Scenario: 01_...` в одном файле
- буквенный сценарий `02A_...` без базового `02_...`, если это не осознанный gap после удаления
- технические детали в шагах вместо бизнес-языка

### 3. Подключи godog runner без локальной самодеятельности

Раскладка API BDD runner-а: **один test-пакет** плюс общий каталог `features/`.

```text
backend/test/bdd/             # monorepo
  bdd_test.go                 # TestMain + Test<Name> по эпикам; //go:build bdd
  stub.go                     # пустой package; //go:build !bdd
  state.go                    # type State, Reset; //go:build bdd
  stack.go                    # startStack, liveStack, testcontainers, сервисы; //go:build bdd
  prefix.go                   # GeneratePrefix, scenarioSeq, если нужен; //go:build bdd
  steps_common.go             # RegisterCommonSteps, RegisterAllSteps; //go:build bdd
  helpers.go                  # общие BDD-хелперы, если нужны; //go:build bdd
  runner.go                   # runEpic, featurePaths, godog.TestSuite; //go:build bdd
  steps_NN_<name>.go          # Register<Name>Steps по одному на эпик; //go:build bdd
```

В backend-only проекте тот же состав файлов живёт в `test/bdd/`.

- Корневой `bdd_test.go` содержит `TestMain(m *testing.M)` и `Test<Name>` по каждому эпику.
- Per-epic `bdd_test.go` не создавай: он запускает отдельный test binary и будет перезапускать контейнеры.
- Все `Register<Name>Steps` живут в одном runner package и регистрируются вместе, потому что feature-файлы разных эпиков могут переиспользовать шаги друг друга.
- `State`, stack, common Given-шаги и helpers живут в runner package; приватные хелперы конкретного эпика остаются file-local в `steps_NN_<name>.go`.
- `featurePaths` читает `features/NN_epic`, а не директорию runner-а.

**Зачем один package:** BDD-прогон поднимает тяжёлый black-box stack. Один package даёт один `TestMain`, один набор контейнеров и сервисов на все эпики и одну кешируемую запись `go test` для полного BDD-прогона.

**Ограничения:**
- Правка любого step-файла инвалидирует BDD-cache всего runner package.
- `task test-bdd` (или `task backend:test-bdd` для monorepo) должен запускать один package API runner-а.
- Для проверки без кеша используй ручной `go test -count=1 ...`, но task по умолчанию может оставаться кешируемым.
- Build tag `bdd` должен стоять на всех `.go` файлах с BDD-runner, stack и steps, чтобы обычный `go test ./...` не компилировал BDD stack и testcontainers-зависимости.
- Если в пакете без tag не остаётся файлов, добавь лёгкий `stub.go` с `//go:build !bdd` и только `package bdd`.
- Build tag `bdd` отделяет BDD от короткой unit-петли; отдельный `testing.Short()` guard в BDD runner не нужен.

#### Минимальный `bdd_test.go`

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

#### `BDD_PATHS` для дебага

`BDD_PATHS` указывает на конкретную директорию или `.feature`-файл из `features/` (несколько через запятую). Он нужен только при локальном прогоне.

Monorepo:

```bash
BDD_PATHS=features/01_delivery/01_copy.feature \
  go test -tags bdd -run TestDelivery ./backend/test/bdd/
```

Backend-only:

```bash
BDD_PATHS=features/01_delivery/01_copy.feature \
  go test -tags bdd -run TestDelivery ./test/bdd/
```

#### Tag filter

В monorepo API runner должен фильтровать сценарии по `@api`. В backend-only проекте фильтр execution channel не нужен.

### 4. Bootstrap через TestMain

Не поднимай testcontainers прямо в step-файлах. Shared setup принадлежит `TestMain`/`stack.go` в runner package.

Если BDD-сценарий поднимает внешние сервисы через testcontainers-go, правила запуска контейнеров см. `x-testcontainers-go`.

### 5. `State`

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

### 6. Регистрация шагов

- Один файл шагов на эпик: `steps_01_auth.go`, `steps_02_billing.go`.
- Методы шагов живут на `State`.
- Текст шагов остаётся на бизнес-языке.
- Функции шагов возвращают только `error`.

```go
func register01AuthSteps(ctx *godog.ScenarioContext, s *State) {
	ctx.Step(`^зарегистрирован пользователь "([^"]*)"$`, s.userRegistered)
	ctx.Step(`^пользователь получает доступ к личному кабинету$`, s.userHasAccess)
}
```

### 7. Полезные команды

Monorepo:

```bash
BDD_PATHS=features/01_epic/01_story.feature \
  go test -count=1 -tags bdd ./backend/test/bdd/ -godog.name="^01[A-Z]?_some_use_case"

go test -count=1 -tags bdd ./backend/test/bdd/ -run TestSomeEpic
task backend:test-bdd
```

Backend-only:

```bash
BDD_PATHS=features/01_epic/01_story.feature \
  go test -count=1 -tags bdd ./test/bdd/ -godog.name="^01[A-Z]?_some_use_case"

go test -count=1 -tags bdd ./test/bdd/ -run TestSomeEpic
task test-bdd
```

## Самопроверка

- `.feature` лежит в `features/NN_epic/NN_story.feature`.
- В monorepo API-сценарии помечены `@api`.
- В backend-only проекте execution tags не добавлены без отдельной причины.
- Go runner лежит в `backend/test/bdd/` для monorepo или `test/bdd/` для backend-only.
- `TestMain` один на весь API BDD runner package.
- Step definitions не поднимают инфраструктуру сами.
- Сценарии названы по `^\d{2}[A-Z]?_[a-z0-9_]+$`.
- Буквенные suffix `A-Z` используются только для edge/corner/negative вариантов базового use case.
