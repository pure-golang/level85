---
name: "x-database-patterns"
description: "Паттерны работы с PostgreSQL: подключение, транзакции, named queries, выбор драйвера, слой репозитория"
compatibility: git.korputeam.ru/newbackend/adapters
---
# Паттерны работы с базой данных

## Выбор драйвера

| Адаптер | Драйвер | Когда использовать |
|---------|---------|-------------------|
| `db/pg/sqlx` | `lib/pq` | Существующие проекты, простые запросы |
| `db/pg/pgx` | `jackc/pgx/v5` | Новые проекты, connection pooling, высокая нагрузка |

**pgx рекомендуется для новых проектов.**

---

## Слой репозитория: плоская структура

Все репозитории сервиса — в одном пакете `repo`, каждый в своём файле по имени сущности.
Вложенные подпакеты (`repo/room/`, `repo/participant/`) **запрещены**: они не позволяют передать одну `tx` сразу в несколько репозиториев.

```
internal/
  repo/
    db.go            ← dbQuerier интерфейс, общие ошибки
    room.go          ← RoomRepo
    participant.go   ← ParticipantRepo
```

### db.go — общий интерфейс (pgx)

```go
// dbQuerier реализуется как пулом (*pgxpool.Pool), так и транзакцией (pgx.Tx).
type dbQuerier interface {
    Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
    Exec(ctx context.Context, sql string, arguments ...any) (pgconn.CommandTag, error)
}
```

### Структура репозитория

```go
type RoomRepo struct{ db dbQuerier }

func NewRoom(db dbQuerier) *RoomRepo { return &RoomRepo{db: db} }
```

### Именование

| Что | Пример |
|-----|--------|
| Файл | `room.go` |
| Структура | `RoomRepo` |
| Конструктор | `NewRoom(db dbQuerier) *RoomRepo` |
| Tracer | `var roomTracer = otel.Tracer("…/repo/room")` |
| Ошибки пакета | `db.go` → `errDBNotConfigured` |
| Ошибки репозитория | тот же файл → `errRoomNotFound` |

---

## Подключение (sqlx)

```go
cfg := sqlx.Config{
    Host:           "localhost",
    Port:           5432,
    User:           "postgres",
    Password:       "secret",
    Database:       "mydb",
    SSLMode:        "disable",
    ConnectTimeout: 5,
    QueryTimeout:   10 * time.Second,
}

db, err := sqlx.Connect(context.Background(), cfg)
defer db.Close()
```

---

## Транзакции

### Кросс-репо транзакция (pgx)

```go
return pool.BeginTxFunc(ctx, pgx.TxOptions{}, func(tx pgx.Tx) error {
    roomRepo := repo.NewRoom(tx)
    participantRepo := repo.NewParticipant(tx)

    if err := roomRepo.Create(ctx, room); err != nil {
        return err
    }
    return participantRepo.Create(ctx, participant)
})
```

### RunTx (sqlx)

```go
err := db.RunTx(ctx, nil, func(ctx context.Context, tx *sqlx.Tx) error {
    _, err := tx.Exec(ctx, "UPDATE accounts SET balance = balance - $1 WHERE id = $2", 100, 1)
    if err != nil {
        return err  // автоматический откат при ошибке
    }
    _, err = tx.Exec(ctx, "UPDATE accounts SET balance = balance + $1 WHERE id = $2", 100, 2)
    return err  // коммит при nil, откат при ошибке
})
```

### Уровни изоляции (sqlx)

```go
opts := &sqlx.TxOptions{
    Isolation: sql.LevelRepeatableRead,
    ReadOnly:  false,
}
err := db.RunTx(ctx, opts, func(ctx context.Context, tx *sqlx.Tx) error {
    // операции
    return nil
})
```

**Заметки:**
- `RunTx()` автоматически откатывает транзакцию при ошибке или панике.
- Ручной `Rollback()` должен проверять `sql.ErrTxDone` (уже закоммичено/откачено).

---

## Named Queries (sqlx)

```go
type User struct {
    ID   int    `db:"id"`
    Name string `db:"name"`
    Age  int    `db:"age"`
}

user := User{Name: "John", Age: 30}
result, err := db.NamedExec(ctx,
    "INSERT INTO users (name, age) VALUES (:name, :age)",
    user)
```

---

## Проверка нарушений ограничений

```go
// Проверки ограничений PostgreSQL.
IsUniqueViolation(err)
IsForeignKeyViolation(err)
IsCheckViolation(err)
IsNotNullViolation(err)
IsConstraintViolation(err)
```

---

## Таймаут запросов

- Применяется через обёртку контекста (`WithTimeout()`).
- Дефолтный таймаут задаётся в `Config.QueryTimeout`.
- SQL-запросы автоматически получают таймаут через обёртку.

---

## Ограничения

- Запрещено использовать поля JSONB — они очень медленные.
- Вложенные подпакеты в `repo/` запрещены — ломают передачу `tx`.
