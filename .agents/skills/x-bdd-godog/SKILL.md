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

#### Физическая структура

```text
{project-root}/
├── docs/
│   └── features -> ../test/bdd/features
└── test/
    └── bdd/
        ├── features/
        │   ├── 01_auth/
        │   │   ├── 01_login.feature
        │   │   └── 02_password_reset.feature
        │   └── 02_billing/
        │       └── 01_subscription.feature
        └── steps/
            ├── bdd_test.go
            ├── context_test.go
            └── 01_auth_test.go
```

#### Иерархия сущностей

| Уровень | Где живёт | Что означает |
|---|---|---|
| Epic | директория `NN_name/` | крупное продуктовое направление |
| Feature | файл `NN_name.feature` | одна user story |
| Scenario | `Scenario: NN. ...` | одна бизнес-проверка |

#### Naming rules

- Директория эпика: `NN_name`
- Файл feature: `NN_name.feature`
- Номер файла задаёт порядок story внутри эпика и не дублирует номер директории
- Имя сценария: `NN. Имя` или `NNA. Имя`
- Регекс сценария: `^\d{2}[A-Z]?\.\s+.+$`

#### Numbering rules

- Базовые happy-path и основные use cases используют `01`, `02`, `03`
- Варианты того же кейса используют `01A`, `01B`, `02A`
- Уникальность номера обязательна только в рамках файла
- Пропуски допустимы: не перенумеровывай файл после удаления сценария
- Внешняя ссылка строится как `эпик/файл#номер`, например `01_auth/01_login.feature#02A`

#### Минимальный feature template

```gherkin
Feature: Вход пользователя

  Как зарегистрированный пользователь
  Я хочу войти по email и паролю
  Чтобы получить доступ к своему кабинету

  Scenario: 01. Успешный вход с корректными учётными данными
    Given зарегистрирован пользователь "user@example.com"
    When пользователь отправляет запрос на вход с email "user@example.com" и паролем "correct"
    Then пользователь получает доступ к личному кабинету
```

#### Антипаттерны

- `.feature` вне `test/bdd/features/`
- файл вида `01_01_login.feature` внутри `01_auth/`
- несколько `Feature:` в одном файле
- отсутствие блока `Как / Я хочу / Чтобы`
- duplicate `Scenario: 01. ...` в одном файле
- технические детали в шагах вместо бизнес-языка

### 3. Подключи `godog` без локальной самодеятельности

- `bdd_test.go` держит `godog.TestSuite`
- shared bootstrap идёт через `TestMain` и `test/support`
- состояние сценария живёт в `scenarioCtx` и сбрасывается в `Before`
- step definitions группируются по эпикам, зеркалируя `features/`

#### Минимальный `bdd_test.go`

```go
func TestBDD(t *testing.T) {
	if testing.Short() {
		t.Skip("bdd test")
	}

	suite := godog.TestSuite{
		Name: "bdd",
		Options: &godog.Options{
			Format:   "pretty",
			Paths:    []string{"../features"},
			Output:   colors.Colored(os.Stdout),
			TestingT: t,
			Strict:   true,
		},
		ScenarioInitializer: initScenario,
	}

	if suite.Run() != 0 {
		t.Fatal("bdd suite failed")
	}
}
```

#### Bootstrap через `TestMain`

```go
func TestMain(m *testing.M) {
	if testing.Short() {
		os.Exit(m.Run())
	}

	ctx := context.Background()
	pg = support.StartPostgresBG(ctx)
	defer pg.Stop(ctx)

	amqp = support.StartRabbitMQBG(ctx)
	defer amqp.Stop(ctx)

	os.Exit(m.Run())
}
```

Не поднимай testcontainers прямо в step-файлах. Shared setup принадлежит `test/support`.

#### `scenarioCtx`

```go
type scenarioCtx struct {
	client   *httpclient.Client
	lastResp *http.Response
	lastErr  error
}

func (s *scenarioCtx) reset() {
	s.lastResp = nil
	s.lastErr = nil
}

func initScenario(ctx *godog.ScenarioContext) {
	s := &scenarioCtx{client: httpclient.New(apiURL)}

	ctx.Before(func(ctx context.Context, sc *godog.Scenario) (context.Context, error) {
		s.reset()
		return ctx, nil
	})

	register01AuthSteps(ctx, s)
}
```

#### Регистрация шагов

- Один файл шагов на эпик: `01_auth_test.go`, `02_billing_test.go`
- Методы шагов живут на `scenarioCtx`
- Текст шагов остаётся на бизнес-языке
- Функции шагов возвращают только `error`

```go
func register01AuthSteps(ctx *godog.ScenarioContext, s *scenarioCtx) {
	ctx.Step(`^зарегистрирован пользователь "([^"]*)"$`, s.userRegistered)
	ctx.Step(`^пользователь получает доступ к личному кабинету$`, s.userHasAccess)
}
```

#### Полезные команды

```bash
go test ./test/bdd/steps/...
go test ./test/bdd/steps/ -godog.name="^01[A-Z]?\."
go test ./test/bdd/steps/ -godog.name="^02A\."
task bdd
task bdd-pending
```

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

## Смежные skills

- `x-bdd-product-workflow`
- `x-bdd-dev-workflow`
- `x-bdd-knowledge-harvest`
- `x-integration-testing`
- `x-testing-conventions`
