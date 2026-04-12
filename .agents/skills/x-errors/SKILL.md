---
name: "x-errors"
description: "Паттерны работы с ошибками: оборачивание, создание, sentinel errors, форматирование"
---
# Ошибки

## Оборачивание существующей ошибки

Всегда использовать `fmt.Errorf` с `%w`:

```go
return fmt.Errorf("failed to create room: %w", err)
```

Использование `github.com/pkg/errors` запрещено — только стандартный пакет `errors`.

Проверка ошибок — только через `errors.Is` или `errors.As`, никогда `==`.

## Создание новой ошибки

| Сценарий | Использовать |
|---|---|
| Статичное сообщение | `errors.New("message")` |
| Сообщение с форматированием | `fmt.Errorf("user %q not found", userID)` |

## Форматирование строк в ошибках

Для строковых переменных использовать `%q`, не `%s` или `%v`:

```go
fmt.Errorf("user %q not found", userID)   // видны границы: "alice"
fmt.Errorf("user %s not found", userID)   // не видно границ: alice
```

`%q` делает видимой пустую строку, пробелы и спецсимволы.

## Sentinel errors

Не создавать экспортируемые sentinel error переменные:

```go
// запрещено — создаёт coupling между пакетами
var ErrNotFound = errors.New("not found")

// вызывающий код вынужден импортировать пакет ради сравнения
if err == mypkg.ErrNotFound { ... }
```

Вместо этого — использовать тип ошибки или возвращать обёрнутую ошибку и проверять через `errors.Is` / `errors.As`.
