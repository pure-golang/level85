---
name: "x-observability"
description: "Применяй когда добавляешь новую внешнюю операцию, adapter package или server middleware: bootstrap monitoring через `../platform/monitoring`, tracer/meter в пакете, метрики и порядок HTTP/gRPC/GraphQL observability"
compatibility: ../platform, ../adapters
---

# Observability

Этот skill — **канонический владелец** observability policy:
- app bootstrap через `monitoring.InitDefault`
- package-level tracer/meter
- span naming и технические атрибуты
- meaningful metrics
- порядок HTTP/gRPC/GraphQL middleware/interceptors

Логирование как таковое принадлежит `x-log`.

## Когда применять

- добавляешь новый adapter или внешний вызов
- инструментируешь HTTP/gRPC/GraphQL слой
- настраиваешь monitoring bootstrap

## Core workflow

### 1. Инициализируй monitoring на уровне приложения

Ориентируйся на `../platform/monitoring`:

```go
closeMonitoring := monitoring.InitDefault(cfg)
defer func() {
    if err := closeMonitoring(); err != nil {
        slog.Default().Warn("failed to close monitoring", slog.Any("err", err))
    }
}()
```

Сбой telemetry не должен останавливать приложение.

### 2. В пакете объявляй один tracer и один meter

```go
var tracer = otel.Tracer("github.com/pure-golang/project/internal/repo")
var meter = otel.Meter("github.com/pure-golang/project/internal/repo")
```

Span name: `packageName.Operation`, например `sqlx.Get`, `S3.Put`, `rabbitmq.Publish`.

### 3. Добавляй только meaningful сигналы

- span для внешней операции
- технические атрибуты там, где они реально помогают расследованию
- метрики только там, где пакет владеет meaningful request/error/latency signal

### 4. Соблюдай порядок server observability

- HTTP: monitoring внешний, recovery после него
- gRPC: следуй project middleware order из `../adapters/grpc/middleware`
- GraphQL: не теряй parent HTTP span, если GraphQL сидит поверх HTTP

Короткая самопроверка для server layers — `references/http-grpc-graphql.md`.

### 5. Помни о process-wide state в тестах

Если unit-тест меняет global OpenTelemetry state, не ставь `t.Parallel()`. Общие правила test-layer принадлежат `x-testing-conventions`.

## Короткий чек-лист

- monitoring bootstrap собран через `monitoring.InitDefault`
- tracer/meter не создаются на каждый вызов
- span name согласован с `packageName.Operation`
- метрики добавлены только там, где сигнал действительно принадлежит пакету
- middleware order не придуман вручную

## References

- `references/http-grpc-graphql.md`

## Смежные skills

- `x-log`
- `x-testing-conventions`
