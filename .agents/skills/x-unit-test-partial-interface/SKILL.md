---
name: x-unit-test-partial-interface
description: "Применяй при написании юнит-тестов с внешними зависимостями: частично применяемые интерфейсы, локальные контракты потребителя, callback-зависимости и mock workflow"
compatibility: github.com/stretchr/testify v1+, github.com/vektra/mockery v3+
---

# Частично применяемые интерфейсы

Этот skill — **канонический владелец** unit-dependency паттерна:
- локальные consumer-side interfaces
- выбор между интерфейсом и callback alias
- связь с `mockery`

`x-mockery` не должен повторять эти правила, а должен ссылаться сюда.

## Когда применять

- код зависит от внешнего repo/client/adapter, но тест должен остаться unit
- зависимость естественно выражается callback-функцией, а не интерфейсом

Не применяй для:
- integration-тестов с реальными внешними сервисами
- случаев, где нужен технический контракт SQL/HTTP/AMQP, а не unit isolation

## Core workflow

### 1. Объяви зависимость у потребителя

По умолчанию зависимость оформляется как локальный интерфейс рядом с тестируемым кодом:

```go
type itemRepo interface {
    GetItem(ctx context.Context, id int64) (*entity.Item, error)
}
```

Правила:
- интерфейс объявляется у потребителя, а не у поставщика зависимости
- имя обычно неэкспортируемое
- только реально используемые методы

### 2. Если интерфейс не нужен, выбери callback alias

Если API естественно принимает функцию, используй callback alias:

```go
type notify = func(state AuthorizationState)
```

Короткие правила:
- используй alias через `=`, а не новый named type
- имя callback — глагол в нижнем регистре
- callback тестируется обычным замыканием, а не `mockery`

Подробности и примеры — `references/callback-dependencies.md`.

### 3. Для интерфейса генерируй mock через `x-mockery`

Если выбрана interface-зависимость:
- оставь локальный consumer-side contract
- сгенерируй mock по `x-mockery`
- не мокируй callback-типы через `mockery`

### 4. Выбери форму теста

Для примеров форм тестов см. `references/test-forms.md`.

| Ситуация | Форма |
|---|---|
| Один сценарий | простой тест |
| Несколько наборов входных данных | табличный тест |
| Сложный setup / verify | call-тест |
| Общий fixture для группы тестов | `suite.Suite` |

## Короткий чек-лист

- dependency contract объявлен у потребителя
- в интерфейс не попали методы "на всякий случай"
- callback-case не насилуется через `mockery`
- если тест стал тяжёлым, это сигнал к обсуждению архитектуры, а не к молчаливому рефакторингу

## References

- `references/test-forms.md` — формы unit-тестов с моками
- `references/callback-dependencies.md` — callback alias и `NewFunc...` pattern

## Смежные skills

- `x-testing-conventions`
- `x-mockery`
