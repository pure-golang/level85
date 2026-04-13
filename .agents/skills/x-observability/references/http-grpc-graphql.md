# Самопроверка по HTTP, gRPC и GraphQL

Этот файл не повторяет workflow из `SKILL.md`, а даёт быстрый checklist по трём самым частым точкам интеграции.

## HTTP

- `Monitoring` ставь снаружи `Recovery`
- `Monitoring` должен видеть финальный HTTP status
- если нужен trace ID в ответе, добавляй его на HTTP-слое, а не в бизнес-логике
- исключения для health/metrics paths принимай осознанно, а не по инерции
- `/graphql` не исключай, если GraphQL observability должна строиться как child span от HTTP span
- если операция внутри handler сама владеет внешним вызовом, дочерний span именуй как `packageName.Operation`

## gRPC

- если используешь готовый bootstrap, держись `SetupMonitoring`
- если собираешь цепочку вручную, держи порядок `recovery -> tracing -> logging -> metrics`
- recovery, tracing, metrics и logging должны работать как согласованный стек, а не как набор случайных interceptors
- если добавляешь свой interceptor, проверь, не ломает ли он propagation `context` и span attributes

Минимальная ручная цепочка:

```go
grpc.NewServer(
    grpc.ChainUnaryInterceptor(
        recovery.UnaryServerInterceptor(),
        tracing.UnaryServerInterceptor(),
        logging.UnaryServerInterceptor(),
        metrics.UnaryServerInterceptor(),
    ),
)
```

## GraphQL

- GraphQL observability должна дополнять уже существующий HTTP span
- operation name/type полезнее писать и в span, и в logger context
- child span на operation — нормальный дефолт
- не тащи transport-level поля в business resolvers только ради логов

## DB spans

- для SQL-пакетов используй `packageName.Operation` как имя span
- пиши `db.system`, `db.operation`, `db.transaction`, если пакет сам владеет этими сигналами
- `db.statement` используй только для безопасного нормализованного SQL
- имя запроса удобнее выносить в отдельный атрибут вроде `db.query_name`
- не пиши чувствительные данные в span attributes

Ориентиры в экосистеме:
- `../platform/monitoring`
- `../adapters/httpserver/middleware`
- `../adapters/grpc/middleware`
- `../adapters/graphql/interceptor/observability.go`
