# Когда unit-тесту не нужен `t.Parallel()`

Этот reference относится только к unit-тестам.
Для integration, bdd, e2e и smoke `t.Parallel()` не является нормой слоя и обычно не нужен.

`t.Parallel()` остаётся нормой для unit-тестов, пока тест изолирован.
Если тест меняет process-wide состояние или делит mutable fixture между несколькими сценариями, параллельность превращается из ускорения в источник паник, race conditions и флейков.

## Быстрая проверка

Перед `t.Parallel()` в unit-тесте спроси себя:

- меняет ли тест env процесса
- меняет ли тест текущую рабочую директорию
- трогает ли тест global OpenTelemetry singleton'ы
- делят ли parent test и subtests один и тот же mutable state

Если ответ "да" хотя бы на один пункт, запускай unit-тест последовательно или сначала изолируй fixture.

## 1. Изменение env процесса

`t.Setenv()` несовместим с `t.Parallel()`.
`os.Setenv()` и `os.Unsetenv()` формально не вызывают ту же панику, но меняют то же самое глобальное состояние процесса и создают те же гонки.

```go
func TestConfig(t *testing.T) {
    // без t.Parallel()

    // Arrange
    t.Setenv("APP_PORT", "8080")

    // Act
    cfg, err := LoadConfig()

    // Assert
    require.NoError(t, err)
    assert.Equal(t, 8080, cfg.Port)
}
```

## 2. Изменение cwd и загрузка `.env`

`os.Chdir()` тоже меняет состояние всего процесса.
Если тест проверяет загрузку `.env` из текущей директории, он часто одновременно меняет cwd и косвенно загрязняет env уже загруженными переменными.

Такие тесты:
- не запускай параллельно
- делай явный cleanup cwd и env
- по возможности держи их отдельно от обычных parsing/defaults тестов

## 3. Global OpenTelemetry state

Глобальные setter'ы OpenTelemetry влияют на весь процесс:
- `otel.SetTracerProvider`
- `otel.SetMeterProvider`
- `otel.SetTextMapPropagator`

Если helper вроде `SetupMonitoring` или `monitoring.InitDefault` внутри вызывает такие setter'ы, рассматривай его точно так же: тест должен быть последовательным.

```go
func TestSetupMonitoring(t *testing.T) {
    // без t.Parallel()

    // Arrange
    cleanup := SetupMonitoring(...)
    t.Cleanup(func() { _ = cleanup() })

    // Act
    // ...

    // Assert
    // ...
}
```

## 4. Shared mutable state в parent/subtests

Проблема не в самом `t.Run`, а в разделяемом mutable fixture.
Если parent test создаёт slice, logger, mock, context wrapper или структуру, которую потом меняют несколько parallel subtests, это риск гонки.

Плохо:

```go
func TestLogger(t *testing.T) {
    t.Parallel()

    records := []string{}

    t.Run("a", func(t *testing.T) {
        t.Parallel()
        records = append(records, "a")
    })
}
```

Лучше:

```go
func TestLogger(t *testing.T) {
    t.Run("a", func(t *testing.T) {
        t.Parallel()

        // Arrange
        records := []string{}

        // Act
        records = append(records, "a")

        // Assert
        assert.Equal(t, []string{"a"}, records)
    })
}
```

Правило:
- immutable table cases делить можно
- mutable fixture должен принадлежать конкретному subtest
- если изоляция дорогая или невозможна, убери `t.Parallel()`

## 5. Граница применения

- unit-тесты обычно начинают с `t.Parallel()`, если fixture изолирован
- integration / bdd тесты не нужно "ускорять" через `t.Parallel()`; их маркер слоя другой
- e2e / smoke тесты тоже не должны опираться на `t.Parallel()` как на соглашение

## 6. Что делать вместо слепого запрета

- оставь `t.Parallel()` только там, где тест реально изолирован
- разнеси env/cwd тесты отдельно от обычных unit-кейсов
- перенеси mutable fixture внутрь каждого `t.Run`
- для time/concurrency логики используй `references/special-techniques.md`, но не путай это с безопасностью process-wide state
