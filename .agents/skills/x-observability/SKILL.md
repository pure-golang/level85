---
name: "x-observability"
description: "Что делать при добавлении новой операции или адаптера: трейсинг, логирование, метрики, порядок middleware"
---
# Observability

## Политика ошибок инициализации

Ошибка инициализации адаптера наблюдаемости (Tracing, Metrics) **не должна останавливать приложение**.

Вызывающий код обязан обработать её как `warn`, но не `fatal` — мониторинг не должен влиять на доступность сервиса.

```go
provider, err := tracing.New(cfg)
if err != nil {
    logger.Warn(ctx, "failed to init tracing", "error", err)
    // продолжаем без трейсинга
}
```

## Шаг 1: Добавь трейсинг

Объяви tracer как переменную пакета:
```go
var tracer = otel.Tracer("git.korputeam.ru/newbackend/adapters/db/pg/sqlx")
```

В каждом публичном методе создай span:
```go
ctx, span := tracer.Start(ctx, "packageName.OperationName")
defer span.End()
```

Именование: `packageName.Operation` — например `sqlx.Get`, `S3.Put`, `rabbitmq.Publish`.

Для операций с БД добавь стандартные атрибуты:
```go
span.SetAttributes(
    attribute.String("db.system", "postgresql"),
    attribute.String("db.operation", "Get"),
    attribute.String("db.statement", sqlQuery),
    attribute.Bool("db.transaction", isInTx),
)
```

## Шаг 2: Залогируй ошибки

> **Подробности логирования:** см. скилл `x-log` — инициализация, обёртки, именование модулей.

## Порядок middleware (HTTP)

Применяй когда **настраиваешь сервер**. Порядок — от внешнего к внутреннему:

1. **Monitoring** — трейсинг, метрики, логирование запросов
2. **Recovery** — перехват паник
3. **Auth / прикладные middleware**
4. **Обработчик приложения**

**Почему Monitoring снаружи Recovery:** если обработчик паникует, Recovery превращает панику в ответ 500. Monitoring снаружи видит этот 500 — паника попадает в метрики и трейсы. Если Recovery снаружи, Monitoring не увидит паниковавший запрос.

```go
amiddleware.Chain(
    mux,
    amiddleware.Monitoring("/other"),
    amiddleware.Recovery,
    platformjwt.NewMiddleware(cfg.Auth.JWTSecret, cfg.Auth.JWTExpiration,
        platformjwt.WithSkipPaths("/live", "/health", "/other"),
    ),
)
```

### gRPC — аналогичный порядок

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
