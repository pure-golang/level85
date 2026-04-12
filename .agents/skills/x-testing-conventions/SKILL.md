---
name: "x-testing-conventions"
description: "Что делать при написании любого теста: маркер типа, структура файла, AAA, assertions, именование"
---
# Testing Conventions

## Шаг 1: Определи тип теста и поставь маркер

Четыре слоя тестирования в проекте:

| Слой | Расположение | Что тестирует | Маркер |
|---|---|---|---|
| **unit** | `*_test.go` рядом с кодом | алгоритмы, чистые функции, компоненты с моками | `t.Parallel()` |
| **integration** | `test/integration/` | технический контракт адаптеров/репо с testcontainers | `testing.Short()` |
| **bdd** | `test/bdd/steps/` | бизнес-сценарии через godog + testcontainers | `testing.Short()` |
| **e2e** | `test/e2e/` | интеграция с реальными staging-сервисами | `//go:build e2e` |
| **smoke** | `test/smoke/` | liveness/readiness собранного стека через docker-compose | `//go:build smoke` |

**Юнит-тест** — первая строка `t.Parallel()`:
```go
func TestSomething(t *testing.T) {
    t.Parallel()
    // ...
}
```

**Интеграционный или BDD тест** — первые строки skip-маркер:
```go
func TestSomethingIntegration(t *testing.T) {
    if testing.Short() {
        t.Skip("integration test")
    }
    // ...
}
```

**E2E и smoke** — через build tags (в верхней части файла):
```go
//go:build e2e

package e2e_test
```
```go
//go:build smoke

package smoke_test
```
E2E и smoke не запускаются при обычном `go test ./...` — для их прогона нужен явный флаг: `go test -tags e2e ./test/e2e/...` или `go test -tags smoke ./test/smoke/...`.

## Шаг 2: Выбери расположение файла

- **unit**: `*_test.go` рядом с тестируемым файлом
- **integration**: `test/integration/*_test.go`
- **bdd**: `test/bdd/steps/*_test.go` + `.feature` в `test/bdd/features/`
- **e2e**: `test/e2e/*_test.go` с `//go:build e2e`
- **smoke**: `test/smoke/*_test.go` с `//go:build smoke`
- Не используй слова "unit" и "integration" в именах файлов
- Если файл содержит оба типа — перенеси интеграционные в `test/`

## Шаг 3: Назови тест и кейсы правильно

Имена тест-функций:
```
Test               // пакетный smoke
TestPublicMethod   // публичный метод
Test_privateMethod // приватный метод
```
Без имени структуры или объекта в названии.

Имена табличных кейсов — `snake_case`, допустимы дефисы, без пробелов и заглавных букв (на английском с маленькой буквы):
```go
{"success_case", ...},
{"error-on-empty-input", ...},
```

Порядок тестов в файле: от общего к частному. Первый тест — основной success-кейс.

## Шаг 4: Применяй цикл RGB (Red → Green → Blue)

RGB — техника TDD, применимая ко всем слоям тестирования:

1. **Red** — напиши падающий тест (или pending-шаг в BDD). Убедись, что он действительно падает.
2. **Green** — напиши минимальный код, чтобы тест прошёл. Не больше.
3. **Blue** (Refactor) — улучши код под зелёными тестами. Ни один тест не должен стать красным.

Что даёт «красное» в каждом слое:

| Слой | Red |
|---|---|
| unit | падающий юнит-тест |
| integration | падающий тест контракта с контейнером |
| bdd | pending godog-шаг (`godog.ErrPending`) |
| e2e | падающий тест со staging |

**Правило:** один тест/сценарий до зелёного перед переходом к следующему. Не разбрасывай реализацию.

Детали RGB-цикла для BDD — в `x-bdd-dev-workflow`.

## Шаг 5: Структурируй тест по AAA

**Обязательно.** Каждый тест (включая подтесты в `t.Run`) должен содержать комментарии `// Arrange`, `// Act`, `// Assert`, разделённые пустыми строками.

```go
func TestSomething(t *testing.T) {
    t.Parallel()

    // Arrange
    svc := New(cfg)

    // Act
    result, err := svc.Do(ctx)

    // Assert
    require.NoError(t, err)
    assert.Equal(t, expected, result)
}
```

В табличных тестах AAA-комментарии ставятся внутри `t.Run`:
```go
for _, tt := range tests {
    t.Run(tt.name, func(t *testing.T) {
        t.Parallel()

        // Arrange
        svc := New(tt.cfg)

        // Act
        got, err := svc.Do(ctx)

        // Assert
        require.NoError(t, err)
        assert.Equal(t, tt.want, got)
    })
}
```

**Проверка** — найди тест-файлы без AAA-комментариев:
```
grep -rL "// Arrange\|// Act\|// Assert" --include="*_test.go" . | grep -v "/mocks/"
```

## Шаг 6: Используй правильные assertions

```go
// Стоп при провале — setup и preconditions
require.NoError(t, err)
require.Equal(t, expected, actual)

// Продолжить тест — независимые проверки поведения
assert.NoError(t, err)
assert.Equal(t, expected, actual)

// Проверка типа ошибки
assert.ErrorIs(t, err, expectedErr)
assert.ErrorAs(t, err, &target)

// Заглушка ошибки в тесте (не errors.New("some error"))
assert.AnError
```

## Шаг 7: Используй t.Cleanup вместо defer

```go
db, err := connect()
require.NoError(t, err)
t.Cleanup(func() { db.Close() })
```

## Когда нужен suite

Используй `testify/suite` когда нужен общий setup/teardown для группы связанных тестов:
```go
func TestMySuite(t *testing.T) {
    if testing.Short() {
        t.Skip("integration test")
    }
    suite.Run(t, new(MySuite))
}

func (s *MySuite) SetupSuite()    { /* запуск контейнера */ }
func (s *MySuite) TearDownSuite() { /* остановка контейнера */ }
func (s *MySuite) SetupTest()     { /* перед каждым тестом — свежие моки */ }
```

## Когда нужен TestMain

Используй для однократной инициализации окружения перед всеми тестами пакета:
```go
func TestMain(m *testing.M) {
    // однократная инициализация для всех тестов пакета
    initConfig()
    os.Exit(m.Run())
}
```

## Запрещено

**Никогда не используй `t.Skip()` для обхода падающих тестов:**
```go
// ЗАПРЕЩЕНО — скрывает проблему конфигурации
if os.Getenv("DB_DSN") == "" {
    t.Skip("DB_DSN not set")
}

// ЗАПРЕЩЕНО — маскирует ошибку вместо её исправления
t.Skip("flaky test")
```

`t.Skip()` допустим **только** как маркер типа теста через `testing.Short()`:
```go
// Разрешено — явный маркер интеграционного теста
if testing.Short() {
    t.Skip("integration test")
}
```

Если тест падает из-за отсутствия переменных окружения — **настрой окружение**, а не пропускай тест. 

Тест, помеченный `t.Skip()` без `testing.Short()`, создаёт ложное ощущение зелёного CI.

## Смежные скиллы

- `x-integration-testing` — запуск контейнеров через testcontainers-go, shared `test/support`
- `x-bdd-godog` — бизнес-тесты через godog, таксономия тегов, структура feature-файлов
- `x-bdd-product-workflow` — продуктовая ветка BDD (PRD → `.feature`)
- `x-bdd-dev-workflow` — разработческая ветка BDD (red → green → blue)
- `x-bdd-knowledge-harvest` — конвертация legacy-знаний в `.feature`
- `x-unit-test-partial-interface` — юнит-тесты с частичными интерфейсами и моками
- `x-unit-test-callbacks` — тестирование колбеков (`type alias = func(...)`)
- `x-unit-test-synctest` — тестирование конкурентного и time-зависимого кода
- `x-unit-test-snapshot` — snapshot-тесты через go-snaps (фиксация сложного вывода)
- `x-mockery` — генерация моков и EXPECT() API
