---
name: "x-testcontainers-go"
description: "Применяй каждый раз, когда интеграционный тест поднимает внешний сервис через testcontainers-go: PostgreSQL, RabbitMQ, Redis, Kafka, MongoDB, MinIO/S3; обычные Go integration tests и integration tests в BDD/godog-формате. Выбирай готовые modules вместо ручного контейнера, задавай context timeout и cleanup."
compatibility: github.com/testcontainers/testcontainers-go, github.com/stretchr/testify v1+
---
# Testcontainers-go

Применяй этот skill, когда интеграционный тест сам поднимает внешний сервис через `testcontainers-go`.
Форма запуска не меняет правило: обычный Go test/suite и BDD/godog используют один и тот же container bootstrap.

## Главное правило

Для популярных сервисов сначала используй готовые modules из `github.com/testcontainers/testcontainers-go/modules/...`.

- PostgreSQL: `modules/postgres`
- RabbitMQ: `modules/rabbitmq`
- Redis: `modules/redis`
- Kafka: `modules/kafka`
- MongoDB: `modules/mongodb`
- MinIO/S3: сначала проверь наличие актуального module в `testcontainers-go`

`testcontainers.GenericContainer` и другой ручной низкоуровневый setup допустимы только если:
- для сервиса нет готового module;
- готовый module не покрывает нужный нестандартный режим;
- тест проверяет нестандартный container contract, а не обычный запуск сервиса.

В таком helper-е оставь короткий комментарий, почему module не подходит.

## Пример PostgreSQL

```go
// test/support/postgres.go (package support, НЕ _test.go)
package support

import (
	"context"
	"testing"
	"time"

	"github.com/testcontainers/testcontainers-go/modules/postgres"
	"github.com/testcontainers/testcontainers-go/wait"
)

type Postgres struct {
	DSN       string
	container *postgres.PostgresContainer
}

// StartPostgres поднимает PostgreSQL и регистрирует tb.Cleanup для остановки.
func StartPostgres(tb testing.TB) *Postgres {
	tb.Helper()

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	container, err := postgres.Run(
		ctx,
		"postgres:15-alpine",
		postgres.WithDatabase("testdb"),
		postgres.WithUsername("postgres"),
		postgres.WithPassword("secret"),
		postgres.WithWaitStrategy(
			wait.ForLog("database system is ready to accept connections").WithOccurrence(2),
		),
	)
	if err != nil {
		tb.Fatalf("failed to start postgres: %v", err)
	}

	dsn, err := container.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		tb.Fatalf("failed to get postgres connection string: %v", err)
	}

	tb.Cleanup(func() {
		if err := container.Terminate(context.Background()); err != nil {
			tb.Logf("failed to terminate postgres: %v", err)
		}
	})

	return &Postgres{DSN: dsn, container: container}
}
```

**Ключевые моменты:**
- Параметр `testing.TB` — стандартный интерфейс, принимает `*testing.T` и другие реализации.
- `context.WithTimeout` ограничивает старт контейнера.
- `tb.Cleanup` останавливает контейнер после теста/suite.
- Пакет `support` НЕ попадает в production binary — ни один `main.go` его не импортирует. Build tags не нужны.
