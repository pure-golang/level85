---
name: "x-database-patterns"
description: "Применяй когда проектируешь PostgreSQL-доступ в сервисе или адаптере: выбор `pgx`/`sqlx`, структура `repo`, общий `dbQuerier`, транзакции, named queries и обработка constraint errors"
compatibility: ../adapters
---

# PostgreSQL-паттерны

## Когда применять

Используй этот скилл, когда:
- выбираешь между `db/pg/pgx` и `db/pg/sqlx`
- проектируешь слой `repo`
- реализуешь транзакцию через несколько репозиториев
- обрабатываешь PostgreSQL constraint errors

Не применяй для:
- доменной логики без SQL
- разовых ad-hoc запросов в handler/service без отдельного репозитория

## 1. Сначала выбери драйвер

| Вариант | Когда брать |
|---|---|
| `db/pg/pgx` | новый проект, нативный pgx, pool, высокая нагрузка |
| `db/pg/sqlx` | нужен `database/sql`-совместимый стек, named queries, уже есть код на sqlx |

Для новых проектов по умолчанию выбирай `pgx`.

Не используй `JSONB` как основной способ моделирования прикладных данных. Если данные участвуют в поиске, фильтрации, join или constraint logic, проектируй отдельные таблицы и явную схему.

## 2. Спроектируй слой `repo`

В service-репозиториях ориентируйся на плоский паттерн: один пакет `repo`, несколько файлов по сущностям, общий `dbQuerier`.

Для naming conventions, транзакционных caveats, query timeout и более полных sqlx-примеров см. `references/repo-patterns.md`.

```text
internal/
  repo/
    db.go
    room.go
    participant.go
```

Общий контракт:

```go
type dbQuerier interface {
    Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
    Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
}
```

Такой интерфейс должен принимать и pool, и transaction.

Если репозиторий в сервисе один, допустим и более компактный вариант с одним основным `repo`-типом и общим `db`.

## 3. Конструктор репозитория

```go
type RoomRepo struct {
    db dbQuerier
}

func NewRoom(db dbQuerier) *RoomRepo {
    return &RoomRepo{db: db}
}
```

Конструктор:
- возвращает одно значение
- не делает I/O
- просто сохраняет зависимость

## 4. Транзакции

### `pgx`

Для кросс-репо операций создавай `tx` снаружи и передавай его в новые экземпляры репозиториев:

```go
return pool.BeginTxFunc(ctx, pgx.TxOptions{}, func(tx pgx.Tx) error {
    roomRepo := repo.NewRoom(tx)
    participantRepo := repo.NewParticipant(tx)
    // ...
    return nil
})
```

### `sqlx`

Используй `RunTx` из адаптера:

```go
err := db.RunTx(ctx, nil, func(ctx context.Context, tx *sqlx.Tx) error {
    // операции
    return nil
})
```

`RunTx` должен автоматически откатывать транзакцию при error и panic.

## 5. Обрабатывай constraint errors через хелперы

Для `sqlx`-адаптера используй:

```go
sqlx.IsUniqueViolation(err)
sqlx.IsForeignKeyViolation(err)
sqlx.IsCheckViolation(err)
sqlx.IsNotNullViolation(err)
sqlx.IsConstraintViolation(err)
```

## 6. Query timeout и named queries — только там, где они действительно упрощают код

Если в адаптере есть конфигурируемый `QueryTimeout`, оборачивай каждую операцию в `context.WithTimeout`, а не размазывай таймауты по вызывающему коду.

Если структура данных хорошо ложится на именованные параметры, `sqlx` может быть проще:

```go
_, err := db.NamedExec(ctx,
    "INSERT INTO users (name, age) VALUES (:name, :age)",
    user,
)
```

## Не делай

- не используй `JSONB` как замену нормальной схеме хранения
- не дроби service-репозитории на вложенные `repo/foo`, `repo/bar`, если им нужна общая транзакция
- не создавай репозиторий, который знает о конкретном pool и не принимает `tx`
- не размазывай SQL-доступ по service-слою
