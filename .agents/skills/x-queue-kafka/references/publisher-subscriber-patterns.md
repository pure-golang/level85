# Паттерны publisher/subscriber

Короткая памятка по текущему API `../adapters/queue/kafka`.

## `Dialer`

- `GroupID` задаёт consumer group для subscriber'ов
- если `GroupID` пустой, адаптер использует `SubscriberConfig.Name`

## `Publisher`

Текущие дефолты из `../adapters/queue/kafka/publisher.go`:

- `Encoder == nil` → `encoders.JSON{}`
- `Balancer == nil` → `&kafka.LeastBytes{}`

Важно: всегда заполняй `queue.Message.Topic`.
В текущем адаптере есть compatibility fallback для пустого topic, но это не тот контракт, на который нужно опираться.

## `Subscriber`

Текущие дефолты из `../adapters/queue/kafka/subscriber.go`:

- `Name == ""` → случайный UUID
- `PrefetchCount <= 0` → `1`
- `MaxTryNum == 0` → `3`
- `Backoff == 0` → `5s`

## Семантика handler

```go
func(ctx context.Context, msg queue.Delivery) (bool, error)
```

- `false, nil` — успех
- `true, err` — retry
- `false, err` — ошибка без retry

Если `MaxTryNum < 0`, адаптер уходит в бесконечный retry через reconnect consumer session. Используй это только для идемпотентных операций с понятным monitoring.

## Что особенно легко пропустить

- Kafka не даёт RabbitMQ-style DLX semantics из коробки
- `PrefetchCount=1` часто лучший старт для тяжёлого handler
- порядок гарантирован только внутри одной partition
- выбор `Balancer` влияет на распределение ключей между partition
