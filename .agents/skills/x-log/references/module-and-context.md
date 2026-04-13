# Модуль и контекст

Короткие эталоны по логированию, на которые стоит ориентироваться.

## `module` по пути пакета

Эталонные значения:

- `internal/service/room` → `service.room`
- `internal/graph` → `graph`
- `pkg/livekit` → `pkg.livekit`
- `cmd/app` → `main`

```go
type Client struct {
    logger *slog.Logger
}

func NewClient(cfg config.LiveKitConfig) *Client {
    return &Client{
        logger: slog.Default().With("module", "pkg.livekit"),
    }
}
```

```go
func New(...) *Service {
    return &Service{
        logger: slog.Default().With("module", "service.room"),
    }
}
```

## Когда брать `logger.FromContext(ctx)`

Хендлер-слой уже получает обогащённый логгер через контекст.
Эталонный API в скилле — `logger.FromContext(ctx)`.
В реальном коде алиас импорта может отличаться (`logger`, `alogger`), но сам приём остаётся тем же.

```go
func (c *Controller) ready(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()
    if err := pinger.Ping(ctx); err != nil {
        logger.FromContext(ctx).Error("dependency not ready", slog.Any("err", err))
    }
}
```

Правило:

- сервис / репозиторий / клиент → `s.logger`
- HTTP / gRPC handler → `logger.FromContext(ctx)`

## Когда уместен `slog.InfoContext(ctx, ...)`

`slog.InfoContext(ctx, ...)` и `slog.ErrorContext(ctx, ...)` не являются основным project path для handler flow, но остаются уместными как самостоятельный паттерн, когда код живёт вне request-handling слоя и готового project logger в контексте нет.

Типичный кейс:
- фоновая goroutine
- короткая служебная операция с `context.Context`
- код, где нужно пронести trace-aware context в запись лога, но `logger.FromContext(ctx)` там не инициализируется проектной middleware

```go
func runWarmup(ctx context.Context) {
    slog.InfoContext(ctx, "starting cache warmup")
}
```

Если код исполняется внутри HTTP / gRPC handler или middleware-цепочки, предпочитай `logger.FromContext(ctx)`, чтобы не потерять обогащение логгера полями запроса.

## Инициализация приложения

Если приложение поднимает monitoring через `../platform/monitoring`, logger инициализируется оттуда:

```go
cfg.Monitoring.Logger = logger.Config{
    Provider: provider,
    Level:    logger.INFO,
}

closeMonitoring := monitoring.InitDefault(cfg.Monitoring)
```

## Что особенно легко испортить

- поле `logger` есть, но ни один метод его не использует
- `module` не соответствует пути пакета
- в handler используется `s.logger`, и теряются поля из контекста запроса
- один и тот же `error` и логируется, и сразу возвращается вверх без добавочной ценности
