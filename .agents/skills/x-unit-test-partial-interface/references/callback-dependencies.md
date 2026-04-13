# Callback-зависимости

Если зависимость выражается функцией, не создавай интерфейс только ради теста.

## Когда брать callback

- API уже принимает функцию
- зависимость слишком маленькая для отдельного интерфейса
- мок через `mockery` только усложнит код

## Базовый паттерн

```go
type notify = func(state AuthorizationState)
```

Правила:
- alias через `=`
- имя callback — глагол
- callback остаётся локальным, если не нужен снаружи

## Тестирование

Тестируй callback обычным замыканием:

```go
var received AuthorizationState
mockNotify := func(state AuthorizationState) {
    received = state
}
```

Если callback строится из зависимостей, оформи `NewFunc...` и мокируй уже эти зависимости, а не сам callback.
