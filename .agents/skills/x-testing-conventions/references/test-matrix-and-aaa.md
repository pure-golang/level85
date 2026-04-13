# Самопроверка теста и call-test форма

Этот файл не повторяет базовые правила из `SKILL.md`, а помогает быстро проверить сложный тест перед завершением правки.

## Быстрая самопроверка

Перед завершением теста спроси себя:

- выбран ли правильный слой тестирования
- есть ли явные `// Arrange`, `// Act`, `// Assert`
- не меняет ли тест process-wide state через env, cwd или global OpenTelemetry
- не маскируется ли проблема через `t.Skip()`
- вынесен ли cleanup в `t.Cleanup`

## Call-test / setup-verify форма

Большие unit-тесты со многими сценариями часто используют call-test стиль:

- `setup func(t *testing.T) *Service`
- `verify func(t *testing.T, got Result, err error)`

Это полезно, когда:

- сценариев много
- Arrange очень разный
- табличный тест с inline logic уже нечитаем

Минимальный каркас:

```go
func TestService_Do(t *testing.T) {
    t.Parallel()

    tests := []struct {
        name   string
        setup  func(t *testing.T) *Service
        verify func(t *testing.T, got Result, err error)
    }{
        {
            name: "success_case",
            setup: func(t *testing.T) *Service {
                t.Helper()
                return New()
            },
            verify: func(t *testing.T, got Result, err error) {
                t.Helper()
                require.NoError(t, err)
                assert.Equal(t, expected, got)
            },
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()

            // Arrange
            svc := tt.setup(t)

            // Act
            got, err := svc.Do(context.Background())

            // Assert
            tt.verify(t, got, err)
        })
    }
}
```

## Типовые ошибки

- AAA есть только в одном примере скилла, а в остальных примерах исчезает
- integration-тест лежит рядом с unit-кодом без явного маркера слоя
- табличный тест уходит в inline-логику и перестаёт читаться
- `verify` начинает сам заново делать Arrange вместо проверки результата
