---
name: "x-log"
description: "Что делать при добавлении логирования: logger в структуре, именование модуля, FromContext в хэндлерах"
---
# Логирование

## Правило: никогда не использовать `slog` напрямую в методах

В каждом компоненте (сервис, репозиторий, клиент, резолвер) — собственный `*slog.Logger` как поле структуры.
Прямые вызовы `slog.Info(...)` / `slog.Error(...)` запрещены внутри методов — только через `s.logger` или `logger.FromContext(ctx)` (для хендлеров, см. ниже).

## Когда добавлять logger

Logger добавляется только если структура реально логирует. Не добавляй `*slog.Logger` "для единообразия" или "на будущее" — если ни один метод не вызывает `s.logger`, поле не нужно.

## Шаг 1: Объяви logger в структуре первым полем

```go
type Service struct {
    logger          *slog.Logger
    roomRepo        roomRepo
}
```

## Шаг 2: Инициализируй в конструкторе

```go
func NewService(roomRepo roomRepo) *Service {
    return &Service{
        logger:          slog.Default().With("module", "service.room"),
        roomRepo:        roomRepo,
    }
}
```

### Именование модуля

Формат: `slog.Default().With("module", "<namespace>.<name>")`

| Расположение пакета       | Значение module   |
|---------------------------|-------------------|
| `internal/repo/room`      | `repo.room`       |
| `internal/service/push`   | `service.push`    |
| `internal/graph`          | `graph`           |
| `pkg/fcm`                 | `pkg.fcm`         |
| `pkg/apns`                | `pkg.apns`        |
| `cmd/app`                 | `main`            |

Правила:
- `internal/` — убирается из префикса. Остаток пути становится namespace: `internal/service/room` → `service.room`
- Если пакет прямо под `internal/` (одноуровневый) — namespace не нужен: `internal/graph` → `graph`
- `pkg/` — **сохраняется** как namespace: `pkg/fcm` → `pkg.fcm`
- `<name>` всегда совпадает с именем Go-пакета (последний сегмент пути)

## Шаг 3: Используй logger в методах структуры

```go
func (s *Service) CreateRoom(ctx context.Context, req *dto.CreateRoomRequest) (*dto.CreateRoomResponse, error) {
    resp, err := s.roomRepo.Create(ctx, req)
    if err != nil {
        s.logger.Error("failed to create room", slog.Any("err", err))
        return nil, fmt.Errorf("failed to create room: %w", err)
    }
    s.logger.Info("room created", slog.String("room_id", resp.RoomID))
    return resp, nil
}
```

## Шаг 4: В хэндлерах используй `logger.FromContext`

В HTTP-хэндлерах и middleware контекст запроса уже содержит обогащённый логгер (trace ID, request ID).
Используй `logger.FromContext(ctx)` вместо `s.logger`:

```go
func (c *Controller) HandleRequest(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()
    userID, _ := GetUserID()
    logger.FromContext(ctx).Info("processing request",
        slog.Int("user_id", userID),
    )
}
```

### `slog.InfoContext` — логирование с контекстом

Для передачи контекста в логгер (trace propagation) используй `slog.InfoContext`:

```go
slog.InfoContext(ctx, "processing request",
    slog.Int("user_id", userID),
)
```

### Передача логгера через контекст

```go
ctx = logger.NewContext(ctx, customLogger)
```

## Когда `s.logger`, когда `logger.FromContext`

| Контекст                          | Метод                       |
|-----------------------------------|-----------------------------|
| Сервис, репозиторий, клиент       | `s.logger`                  |
| HTTP-хэндлер, middleware          | `logger.FromContext(ctx)`   |
| gRPC-хэндлер                      | `logger.FromContext(ctx)`   |

## Уровни логирования

```go
s.logger.Debug("fetching room", slog.String("room_id", roomID))   // детали для отладки
s.logger.Info("room created", slog.String("room_id", resp.ID))    // значимые события
s.logger.Warn("retry attempt", slog.Int("attempt", n))            // нештатное, но не ошибка
s.logger.Error("failed to publish event", slog.Any("err", err))   // ошибки
```

Правила:
- Error message — английский, строчная первая буква: `"failed to create room"`, не `"Failed to create room"`
- Ключи атрибутов — snake_case: `"room_id"`, `"user_id"`, `"attempt"`
- Никогда не логируй и не возвращай ошибку одновременно — только одно из двух

## Обёртки для атрибутов

Обязательно использовать типизированные обёртки `slog.*` вместо пар `"key", value`:

```go
slogger.Info("user action",
    slog.Int("user_id", userID),
    slog.String("message", message),
    slog.String("action", action),
)
```

Доступные обёртки:
- `slog.String(key, value string)`
- `slog.Int(key, value int)`
- `slog.Int64(key, value int64)`
- `slog.Uint64(key, value uint64)`
- `slog.Float64(key, value float64)`
- `slog.Bool(key, value bool)`
- `slog.Time(key, value time.Time)`
- `slog.Duration(key, value time.Duration)`
- `slog.Any(key, value any)`

## Инициализация логгера в main.go

```go
import (
    "log/slog"

    "git.korputeam.ru/newbackend/adapters/logger"
    "git.korputeam.ru/<project>/internal/config"
)

func run() error {
    // ...

    var cfg config.Config
    if err := env.InitConfig(&cfg); err != nil {
        return err
    }

    provider := logger.ProviderStdJson
    if cfg.Environment == "development" {
        provider = logger.ProviderDevSlog
    }

    logger.InitDefault(logger.Config{
        Provider: provider,
        Level:    logger.INFO,
    })
    logger := slog.Default().With("module", "main")

    // ...
}
```

### С мониторингом (трейсинг, метрики)

Когда сервис использует `monitoring.InitDefault` — конфиг логгера передаётся через `cfg.Monitoring.Logger`, а не вызовом `logger.InitDefault` напрямую. Мониторинг сам инициализирует логгер внутри.

```go
import (
    "log/slog"

    "git.korputeam.ru/newbackend/adapters/logger"
    "git.korputeam.ru/newbackend/platform/monitoring"
    "git.korputeam.ru/<project>/internal/config"
)

func run() error {
    // ...

    var cfg config.Config
    if err := env.InitConfig(&cfg); err != nil {
        return err
    }

    provider := logger.ProviderStdJson
    if cfg.Environment == "development" {
        provider = logger.ProviderDevSlog
    }

    cfg.Monitoring.Logger = logger.Config{
        Provider: provider,
        Level:    logger.INFO,
    }

    // Инициализация мониторинга (логгер, трейсинг, метрики)
    closeMonitoring := monitoring.InitDefault(cfg.Monitoring)
    logger := slog.Default().With("module", "main")
    defer func() {
        if err := closeMonitoring(); err != nil {
            logger.Error("failed to close monitoring", slog.Any("err", err))
        }
    }()

    // ...
}
```

### Провайдеры логгера

| Пакет | Когда |
|-------|-------|
| `logger/stdjson` | Продакшн — структурированный JSON |
| `logger/devslog` | Разработка — читаемый вывод |
| `logger/noop` | Тесты — отбрасывает вывод |

