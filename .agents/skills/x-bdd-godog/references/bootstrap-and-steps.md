# Bootstrap и steps

## Минимальный `bdd_test.go`

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

## Bootstrap через `TestMain`

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

## `scenarioCtx`

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

## Регистрация шагов

- Один файл шагов на эпик: `01_auth_steps_test.go`, `02_billing_steps_test.go`
- Методы шагов живут на `scenarioCtx`
- Текст шагов остаётся на бизнес-языке
- Функции шагов возвращают только `error`

```go
func register01AuthSteps(ctx *godog.ScenarioContext, s *scenarioCtx) {
	ctx.Step(`^зарегистрирован пользователь "([^"]*)"$`, s.userRegistered)
	ctx.Step(`^пользователь получает доступ к личному кабинету$`, s.userHasAccess)
}
```

## Полезные команды

```bash
go test ./test/bdd/steps/...
go test ./test/bdd/steps/ -godog.name="^01[A-Z]?\\."
go test ./test/bdd/steps/ -godog.name="^02A\\."
task bdd:all
task bdd:pending
```
