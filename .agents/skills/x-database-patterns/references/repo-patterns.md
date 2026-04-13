# Паттерны слоя репозитория

## Пакет репозиториев сервиса

Эталонный паттерн для репозиториев сервиса:
- один пакет `repo`
- один файл на сущность
- общий `dbQuerier`
- конструкторы без I/O

Если нескольким репозиториям нужна одна транзакция, вложенные подпакеты `repo/foo`, `repo/bar` для сервисного слоя не используй.

## Naming conventions

| Что | Паттерн |
|---|---|
| файл сущности | `room.go` |
| общий файл контракта | `db.go` или `errors.go` |
| структура репозитория | `RoomRepo` или компактный `repo` |
| конструктор | `NewRoom(db dbQuerier)` |
| tracer | `var roomTracer = otel.Tracer(".../repo/room")` |
| ошибка пакета | `errDBNotConfigured` |
| ошибка сущности | `errRoomNotFound` |

## Когда допустим один репозиторий на пакет

Если сервис маленький и пакет фактически реализует один адаптер хранения, допустим более компактный вариант:
- один пакет
- один основной тип репозитория
- общий адаптер извне

## Транзакционное правило

Если в одной операции участвуют несколько репозиториев, они должны принимать одну и ту же транзакционную зависимость, а не открывать соединения сами.

### `RunTx` и rollback

- `RunTx` должен автоматически откатывать транзакцию при error и panic
- если пишешь ручной `Rollback`, проверяй `sql.ErrTxDone`, чтобы не считать уже завершённую транзакцию новой ошибкой

Пример isolation level:

```go
opts := &sqlx.TxOptions{
    Isolation: sql.LevelRepeatableRead,
}

err := db.RunTx(ctx, opts, func(ctx context.Context, tx *sqlx.Tx) error {
    return nil
})
```

## Query timeout

Если у адаптера есть `Config.QueryTimeout`, оборачивай запросы в локальный `context.WithTimeout`:

```go
func WithTimeout(ctx context.Context, timeout time.Duration) (context.Context, context.CancelFunc) {
    if timeout <= 0 {
        return ctx, func() {}
    }
    return context.WithTimeout(ctx, timeout)
}
```

Таймаут должен жить рядом с SQL-адаптером, а не размазываться по service-коду.

## `sqlx.Connect()` стартовый пример

```go
cfg := sqlx.Config{
    Host:           "localhost",
    Port:           5432,
    User:           "postgres",
    Password:       "secret",
    Database:       "app",
    SSLMode:        "disable",
    ConnectTimeout: 5 * time.Second,
    QueryTimeout:   10 * time.Second,
}
```

## Named queries

```go
type User struct {
    Name string `db:"name"`
    Age  int    `db:"age"`
}

_, err := db.NamedExec(ctx,
    "INSERT INTO users (name, age) VALUES (:name, :age)",
    User{Name: "John", Age: 30},
)
```

## Constraint helpers

Если нужно проверить обобщённый случай, используй `sqlx.IsConstraintViolation(err)` как верхнеуровневый helper поверх более узких `IsUniqueViolation` / `IsForeignKeyViolation` / `IsCheckViolation` / `IsNotNullViolation`.
