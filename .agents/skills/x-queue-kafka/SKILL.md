---
name: "x-queue-kafka"
description: "Применяй когда проектируешь publisher/subscriber для Kafka через API `../adapters/queue/kafka`: `Dialer`, `Publisher`, `Subscriber`, topic, consumer group, retry через `(bool, error)`, `Balancer` и текущие дефолты адаптера"
compatibility: ../adapters
---

# Kafka

## Когда применять

Используй этот скилл, когда работаешь с Kafka topic и consumer group через `../adapters/queue/kafka`.

Не применяй для:
- RabbitMQ-style DLX/retry topology и сложной маршрутизации
- сценариев, где нужна broker-level dead-letter очередь из коробки

## Workflow

Для сводки по текущим API-дефолтам и compatibility caveats см. `references/publisher-subscriber-patterns.md`.

### 1. Создай `Dialer`

```go
cfg := kafka.Config{
    Brokers: []string{"localhost:9092"},
    GroupID: "my-consumer-group",
}

dialer := kafka.NewDialer(cfg, nil)
defer dialer.Close()
```

Если `GroupID` пустой, `Subscriber` использует своё имя как дефолтный group ID.

### 2. Создай `Publisher`

```go
pub := kafka.NewPublisher(dialer, kafka.PublisherConfig{
    Encoder:  encoders.JSON{},
    Balancer: &kafka.LeastBytes{},
})
```

`Balancer` выбирай осознанно:
- `LeastBytes` — безопасный дефолт
- `Hash` — если важна стабильная партиция по ключу
- `RoundRobin` — равномерное распределение

### 3. Создай `Subscriber`

```go
sub := kafka.NewSubscriber(dialer, "my-topic", kafka.SubscriberConfig{
    Name:          "my-subscriber",
    PrefetchCount: 1,
    MaxTryNum:     3,
    Backoff:       5 * time.Second,
})
defer sub.Close()
```

### 4. Реализуй handler по контракту `(bool, error)`

```go
go sub.Listen(ctx, func(ctx context.Context, msg queue.Delivery) (bool, error) {
    // false, nil  -> успех
    // true, err   -> retry
    // false, err  -> ошибка без retry
    return false, nil
})
```

Семантика:
- `false, nil` — сообщение успешно обработано
- `true, err` — повторять до `MaxTryNum`
- `false, err` — зафиксировать ошибку без retry

Если `MaxTryNum < 0`, адаптер уходит в бесконечный retry через рестарт consumer session.

## Практические правила

- `PrefetchCount=1` — безопасный дефолт для неидемпотентной или тяжёлой обработки
- если нужен ordered processing, помни: Kafka гарантирует порядок только внутри партиции
- если нужны явные DLQ semantics, проектируй их отдельно на уровне topic topology
- явно заполняй `queue.Message.Topic`: не опирайся на compatibility fallback в адаптере

## Не делай

- не переноси в Kafka mental model от RabbitMQ `x-death` / DLX
- не игнорируй выбор `GroupID`: он определяет распределение нагрузки между consumer'ами
- не рассчитывай на пустой `Topic` в publisher как на нормальный контракт
- не используй бесконечный retry (`MaxTryNum < 0`) без понятной стратегии идемпотентности и мониторинга

## Полезные ресурсы

- `references/publisher-subscriber-patterns.md` — сводка дефолтов `Publisher`/`Subscriber` и compatibility caveats текущего Kafka adapter API
