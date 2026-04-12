---
name: "x-bdd-godog"
description: "Применяй при написании бизнес-тестов через godog: структура feature-файлов по каноническому Gherkin, нумерация сценариев, step definitions, связь с testcontainers через test/support"
---
# BDD на godog

## Шаг 0: Когда применять

Скил описывает **слой бизнес-тестов** — проверку сценариев, видимых заказчику/аналитику. Бизнес-тесты живут в `test/bdd/` и запускаются через godog.

**Не применяй для:**
- Технических интеграционных тестов (проверка контракта функциональных модулей) → `x-integration-testing`
- Юнит-тестов → `x-testing-conventions`
- Тестов с реальными внешними сервисами (внешние API) → слой `test/e2e/`

**Принцип разграничения:** если проверка формулируется на языке бизнеса («пользователь получает письмо с подтверждением») — это BDD. Если на языке системы («репозиторий возвращает ErrNotFound при отсутствии записи») — это integration/unit.

**Канонический Gherkin:** скил следует оригинальной модели Cucumber без проектных надстроек над словарём тегов. Обязательных тегов нет — вся структура выражается через файловую иерархию и имена.

## Шаг 1: Физическая структура

```
{project-root}/
├── docs/
│   └── features → ../test/bdd/features   # symlink для навигации аналитиков
└── test/
    └── bdd/
        ├── features/                     # ФИЗИЧЕСКОЕ расположение .feature
        │   ├── 01_auth/                  # эпик
        │   │   ├── 01_login.feature      # Feature (user story)
        │   │   └── 02_password_reset.feature
        │   └── 02_billing/
        │       └── 01_subscription.feature
        └── steps/                        # реализация шагов
            ├── bdd_test.go               # godog.TestSuite + TestMain
            ├── context_test.go            # ScenarioContext
            └── NN_epic_steps_test.go     # шаги, сгруппированные по эпикам
```

**Иерархия:**

| Уровень | Где живёт | Что это |
|---|---|---|
| **Эпик** | директория `NN_name/` | группа связанных функций, крупное продуктовое направление |
| **Feature** | файл `NN_name.feature` с заголовком `Feature:` | конкретная функциональность, одна user story |
| **User story** | описательный блок `Как... Я хочу... Чтобы...` внутри `Feature:` | agile user story — зачем это нужно и кому |
| **Scenario** | `Scenario: NN. Имя` | конкретная проверка поведения |

**Правила именования:**
- Директория: `NN_name` (напр. `01_auth`). Номер задаёт порядок эпиков.
- Файл: `NN_name.feature` (напр. `01_login.feature`). Номер задаёт порядок user story **внутри эпика**, не дублирует номер эпика.
- Scenario: `NN. Имя` или `NNA. Имя` (варианты через суффикс-букву без разделителя, напр. `01A. Имя`).

**Symlink для навигации аналитиков:**
```bash
cd docs && ln -s ../test/bdd/features features
```
Создаётся один раз, коммитится в git. Физический источник файлов — `test/bdd/features/`, symlink даёт точку входа из документации.

## Шаг 2: Структура feature-файла

```gherkin
Feature: Вход пользователя

  Как зарегистрированный пользователь
  Я хочу войти по email и паролю
  Чтобы получить доступ к своему кабинету

  Scenario: 01. Успешный вход с корректными учётными данными
    Given зарегистрирован пользователь "user@example.com"
    When пользователь отправляет запрос на вход с email "user@example.com" и паролем "correct"
    Then пользователь получает доступ к личному кабинету

  Scenario: 02. Отказ при неверном пароле
    Given зарегистрирован пользователь "user@example.com"
    When пользователь отправляет запрос на вход с email "user@example.com" и паролем "wrong"
    Then система отвечает ошибкой "неверные учётные данные"

  Scenario: 02A. Отказ при пустом пароле
    Given зарегистрирован пользователь "user@example.com"
    When пользователь отправляет запрос на вход с email "user@example.com" и пустым паролем
    Then система отвечает ошибкой "пароль обязателен"

  Scenario: 03. Блокировка после 5 неудачных попыток подряд
    ...
```

**Обязательные элементы:**
- Заголовок `Feature:` — краткое имя функциональности.
- User story блок (`Как ... Я хочу ... Чтобы ...`) — три строки сразу после заголовка. Это классический agile user story формат, описывает **зачем** функциональность нужна и **кому**.
- Один или несколько `Scenario:` с нумерованными именами.

## Шаг 3: Нумерация сценариев

**Формат имени:** `NN. Имя` или `NNA. Имя`, где:
- `NN` — двузначный базовый номер (`01`, `02`, `03`...). Базовые номера без буквы — это **happy path** и основные use cases
- `A` — опциональный суффикс-буква для **corner cases** — вариаций того же кейса с другим входом (`02A`, `02B`, `02C`)

Регекс: `^\d{2}[A-Z]?\.\s+.+$`

**Правила:**
- **Уникальность в рамках файла обязательна.** Два `Scenario: 01. ...` в одном файле — ошибка.
- **Пропуски разрешены.** Если use case удалён, остальные номера не перенумеровываются — это ломает внешние ссылки на сценарий. Последовательность `01, 02, 04, 05` нормальна.
- **Варианты vs базовый номер — не дубли.** `01`, `01A`, `01B` — три разных сценария, не дубли.
- Уникальность между файлами **не требуется** — глобальная ссылка строится как `эпик/файл#номер`, напр. `01_auth/01_login.feature#02A`.

**Зачем номера:**
- Стабильная ссылка на сценарий извне (из Jira, коммита, ADR) — `01_auth/01_login.feature#02A` не меняется при переименовании.
- Порядок в отчёте godog определяется номерами.
- Фильтрация в CLI через регекс по имени (см. Шаг 7).

## Шаг 4: Подключение godog

Минимальный `test/bdd/steps/bdd_test.go`:

```go
package steps_test

import (
	"os"
	"testing"

	"github.com/cucumber/godog"
	"github.com/cucumber/godog/colors"
)

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
			Strict:   true, // pending-шаг = провал
		},
		ScenarioInitializer: initScenario,
	}

	if suite.Run() != 0 {
		t.Fatal("bdd suite failed")
	}
}
```

**Ключевые моменты:**
- `Paths` — захардкоженный относительный путь от `test/bdd/steps/` к `test/bdd/features/`. Это соглашение проекта.
- Селективный прогон — через нативный флаг `-godog.name` с регексом по имени сценария (см. Шаг 7).
- `Strict: true` — pending-шаг проваливает прогон. Без него в CI могут протечь нереализованные шаги.
- `TestingT: t` — интеграция с go test: `go test ./test/bdd/steps/...` работает как обычный тест, маркируется через `testing.Short()` единообразно со слоем `test/integration`.

## Шаг 5: Bootstrap и ScenarioContext

`godog.TestSuite` не совместима с `testify/suite` (у godog свой жизненный цикл), поэтому shared setup — через пакет `test/support` и обычный `TestMain`:

```go
// test/bdd/steps/bootstrap_test.go
package steps_test

import (
	"context"
	"os"
	"testing"

	"example.com/project/test/support"
)

var (
	pg   *support.Postgres
	amqp *support.RabbitMQ
)

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

`support.StartPostgresBG` — вариант функции без `testing.TB`, возвращает объект с методом `Stop(ctx)`. Shared-переменные пакета доступны в step-функциях через замыкания.

### ScenarioContext

Держит состояние одного сценария. Сбрасывается в `Before` хуке:

```go
// test/bdd/steps/context_test.go
package steps_test

type scenarioCtx struct {
	client     *httpclient.Client
	lastResp   *http.Response
	lastErr    error
	userTokens map[string]string
}

func (s *scenarioCtx) reset() {
	s.lastResp = nil
	s.lastErr = nil
	s.userTokens = make(map[string]string)
}
```

Регистрация:

```go
func initScenario(ctx *godog.ScenarioContext) {
	s := &scenarioCtx{client: httpclient.New(apiURL)}

	ctx.Before(func(ctx context.Context, sc *godog.Scenario) (context.Context, error) {
		s.reset()
		return ctx, nil
	})

	register01AuthSteps(ctx, s)
	// register02BillingSteps(ctx, s) — по мере роста
}
```

## Шаг 6: Регистрация шагов

Группируй шаги **по эпикам**, зеркалируя структуру `features/`. Один файл = один эпик (`01_auth_steps_test.go`, `02_billing_steps_test.go`), там лежат все шаги связанные с этим эпиком независимо от того `Given`, `When` или `Then`. Пока шагов мало — один файл `steps_test.go`.

```go
// test/bdd/steps/01_auth_steps_test.go
package steps_test

import "github.com/cucumber/godog"

func register01AuthSteps(ctx *godog.ScenarioContext, s *scenarioCtx) {
	ctx.Step(`^зарегистрирован пользователь "([^"]*)"$`, s.userRegistered)
	ctx.Step(`^пользователь отправляет запрос на вход с email "([^"]*)" и паролем "([^"]*)"$`, s.userLogsIn)
	ctx.Step(`^пользователь получает доступ к личному кабинету$`, s.userHasAccess)
}

func (s *scenarioCtx) userRegistered(email string) error {
	if _, err := pg.DB.Exec(`INSERT INTO users (email) VALUES ($1)`, email); err != nil {
		return fmt.Errorf("failed to insert user: %w", err)
	}
	return nil
}
```

**Правила:**
- Функции шагов — методы на `scenarioCtx`, имя глаголом без приставки: `givenUserRegistered`, `whenUserLogsIn`, `thenResponseContainsToken`.
- Regex на русском (текст шагов на русском). Параметры: `"([^"]*)"` для строк, `(\d+)` для чисел.
- Возвращают только `error` — без `*testing.T` внутри шагов.

**Параметры из DocString и DataTable:**

```gherkin
When пользователь создаёт монитор с параметрами:
  | name | API Service             |
  | url  | https://api.example.com |
```

```go
func (s *scenarioCtx) whenUserCreatesMonitor(table *godog.Table) error {
	params := make(map[string]string)
	for _, row := range table.Rows {
		params[row.Cells[0].Value] = row.Cells[1].Value
	}
	// ...
}
```

## Шаг 7: Taskfile команды

```yaml
tasks:
  bdd:
    desc: "Run all BDD scenarios"
    cmd: go test ./test/bdd/steps/...

  bdd:pending:
    desc: "Show pending (unimplemented) steps"
    cmd: go test ./test/bdd/steps/ -godog.format=pretty 2>&1 | grep -i pending
```

**Селективный прогон** — через нативный godog-флаг `-godog.name` с регексом по имени сценария:
```bash
# Все сценарии (по умолчанию)
go test ./test/bdd/steps/...

# Только сценарии с базовым номером 01 и вариантами (01, 01A, 01B...)
go test ./test/bdd/steps/ -godog.name="^01[A-Z]?\."

# Конкретный вариант
go test ./test/bdd/steps/ -godog.name="^02A\."
```

## Антипаттерны

❌ **Feature-файлы вне `test/bdd/features/`** — ломает layout, symlink из `docs/features` не работает.

❌ **Дубль номера эпика в имени файла** (`01_01_login.feature` в `01_auth/`) — префикс эпика уже задан директорией. Правильно: `01_login.feature`.

❌ **Несколько `Feature:` в одном файле** — канонический Gherkin требует ровно одну. Разные функции — разные файлы.

❌ **User story блок отсутствует** — «Как... Я хочу... Чтобы...» обязателен после `Feature:`. Без него теряется контекст «зачем».

❌ **Технические детали в шагах:**
```gherkin
# ПЛОХО
When запрос INSERT INTO users выполнен успешно
# ХОРОШО
When пользователь зарегистрирован
```

❌ **Дублирование номеров сценариев в одном файле** — `Scenario: 01. ...` и `Scenario: 01. ...` это ошибка. Варианты (`01A`, `01B`) — не дубли.

❌ **Перенумерация при удалении сценария** — ломает внешние ссылки. Оставь пропуск в последовательности.

❌ **Дублирование testcontainers-кода в `test/bdd/steps/`** — поднимай через `test/support`, это единая точка.

❌ **Pending-шаги в main-ветке** — `Strict: true` их ловит. Pending допустимы только в feature-branch на этапе red.

❌ **Глобальное состояние между сценариями** — `scenarioCtx.reset()` в `Before` обязателен.

❌ **Проектный словарь тегов** — канонический Gherkin не требует обязательных тегов. Если проект хочет ввести метки (`@wip`, `@slow`, `@JIRA-1234`) — это локальное соглашение, но скил ничего не навязывает.

## Смежные скиллы

- `x-bdd-product-workflow` — откуда берутся `.feature` (PRD → интервью → драфт)
- `x-bdd-dev-workflow` — процесс реализации шагов (red → green → blue)
- `x-bdd-knowledge-harvest` — конвертация legacy-знаний в `.feature`
- `x-integration-testing` — технический слой, переиспользует `test/support`
- `x-testing-conventions` — общие соглашения (AAA, assertions, маркеры)
- `bdd-reviewer` (агент) — проверяет структуру, нумерацию и layout
