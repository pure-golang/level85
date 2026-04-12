---
name: "x-queue-kafka"
description: "Паттерны Kafka: dialer, publisher, subscriber с retry и backoff"
compatibility: git.korputeam.ru/newbackend/adapters
---
# Паттерны очередей (Kafka)

```go
// Создать Kafka dialer
cfg := kafka.Config{
    Brokers: []string{"localhost:9092"},
    GroupID: "my-consumer-group",
}
dialer := kafka.NewDialer(cfg, nil)

// Создать publisher
pub := kafka.NewPublisher(dialer, kafka.PublisherConfig{
    Encoder: encoders.JSON{},
})

// Опубликовать сообщение
msg := queue.Message{
    Topic: "my-topic",
    Body:  map[string]string{"key": "value"},
}
err := pub.Publish(ctx, msg)

// Создать subscriber
sub := kafka.NewSubscriber(dialer, "my-topic", kafka.SubscriberConfig{
    Name:          "my-subscriber",
    PrefetchCount: 1,
    MaxTryNum:     3,
    Backoff:       5 * time.Second,
})

defer sub.Close()
// Получать сообщения (блокирует до отмены ctx или sub.Close())
go sub.Listen(ctx, func(ctx context.Context, msg queue.Delivery) (bool, error) {
    fmt.Println("Received:", string(msg.Body))
    return false, nil  // false = успех, true = retry
})
```

## Возвращаемые значения обработчика
- `false, nil` — успех, зафиксировать offset
- `true, err` — retry (до `MaxTryNum` раз с задержкой `Backoff`)
- `false, err` — пропустить сообщение (без retry), залогировать ошибку
