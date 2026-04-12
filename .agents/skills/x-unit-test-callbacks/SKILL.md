---
name: x-unit-test-callbacks
description: "Применяй когда зависимость передаётся как функция (type alias = func(...)), а не интерфейс"
compatibility: github.com/stretchr/testify v1+, github.com/vektra/mockery v2+
---

Для мокирования зависимостей замыканий используй скилл `x-mockery`. Базовые соглашения по тестам — скилл `x-testing-conventions`.

## Контекст

В Go два интерфейса с одинаковыми методами совместимы, но типы функций с разными именованными типами в сигнатуре — нет. Поэтому нельзя использовать интерфейсы в качестве параметров методов других интерфейсов. Решение — колбеки: типовые алиасы функций (`type alias = func(...)`).

## Объявление колбека

```go
// type alias (= обязателен — это алиас, не новый тип)
type notify = func(state AuthorizationState)
type checkBalance = func(data interface{}) error
```

Правила именования:
- Глагол в нижнем регистре + опциональное существительное
- Строчные буквы — не переиспользуется вне пакета
- `=` обязателен (alias, не определение нового типа)

## NewFunc-конструктор

Для создания замыкания, реализующего колбек, используй конструктор с префиксом `NewFunc`:

```go
func NewFuncNotify(logger Logger) notify {
    return func(state AuthorizationState) {
        logger.Log(state)
    }
}
```

Правило именования: `NewFunc` + глагол с заглавной буквы.

## Тестирование колбека

Колбеки не мокируются через mockery. Передавай простое замыкание прямо в тесте:

```go
func TestSubscribe(t *testing.T) {
    t.Parallel()

    svc := New(...)

    // Arrange
    var received AuthorizationState
    mockNotify := func(state AuthorizationState) {
        received = state
    }

    // Act
    svc.Subscribe(mockNotify)
    svc.broadcast(&AuthorizationStateWaitPhoneNumber{})

    // Assert
    assert.NotNil(t, received)
}
```

Для проверки количества вызовов используй счётчик:

```go
var callCount int
mockNotify := func(state AuthorizationState) {
    callCount++
}
// ...
assert.Equal(t, 3, callCount)
```

## Тестирование NewFunc-конструктора

Зависимости замыкания мокируются стандартно через mockery — см. скилл `x-mockery`.

Проверяй поведение замыкания, передавая в него мокированные зависимости:

```go
func TestNewFuncNotify(t *testing.T) {
    t.Parallel()

    // Arrange
    logger := mocks.NewLogger(t)
    logger.EXPECT().Log(mock.Anything)
    notify := NewFuncNotify(logger)

    // Act
    notify(&AuthorizationStateWaitPhoneNumber{})

    // Assert — проверяется неявно через дефолтный EXPECT().Once()
}
```
