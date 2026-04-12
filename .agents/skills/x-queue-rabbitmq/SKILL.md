---
name: "x-queue-rabbitmq"
description: "Паттерны RabbitMQ: Topology/Definitions, Publisher, Subscriber (retry via x-death), MultiQueueSubscriber"
compatibility: git.korputeam.ru/newbackend/adapters
---
# Паттерны очередей (RabbitMQ)

## Фиксировать hostname для durable+persistent queues

RabbitMQ хранит данные по имени узла (`rabbit@<hostname>`).
Если hostname меняется при рестарте — узел не находит свои данные.

```yaml
# docker-compose.yml
rabbitmq:
  image: rabbitmq:3.12-management-alpine
  hostname: korpu-rabbitmq-node-1  # фиксированный hostname = стабильное имя узла
```

## Topology (Definitions)

`Definitions` повторяет формат JSON management API RabbitMQ:
- `.JSON()` → `rabbitmq_definitions.json` для docker-compose `load_definitions` / `rabbitmqctl import_definitions`
- `.applyDefinitions(ch *amqp.Channel)` → объявление напрямую через AMQP (вспомогательный метод только для тестов, определён в `topology_helpers_test.go`)

См. `queue/rabbitmq/README.md` для полного примера DLX топологии.

## Publisher

Сигнатура конструктора:
```go
NewPublisher(dialer, PublisherConfig{
    Exchange:     "my-exchange",
    RoutingKey:   "my.routing.key",
    Encoder:      encoders.JSON{},
    DeliveryMode: amqp.Persistent,
    MessageTTL:   30 * time.Second,
})
```

## Subscriber (одна очередь)

Логика retry через заголовок `x-death` (сохраняется после перезапуска процесса):

| Условие | Действие |
|---------|----------|
| ошибка + `x-death < MaxRetries` | публикация в `RetryQueueName` + Ack |
| ошибка + `x-death >= MaxRetries` | `Nack(requeue=false)` → DLQ через `x-dead-letter-*` binding |
| ошибка публикации в retry | fallback `Nack(requeue=true)` |

**Важно:** возвращаемый `bool` из обработчика **игнорируется** — retry всегда через DLX по заголовку x-death.

```go
sub := rabbitmq.NewSubscriber(dialer, "my-queue", rabbitmq.SubscriberOptions{
    MaxRetries:     3,
    RetryQueueName: "my-queue.retry", // по умолчанию: queueName+".retry"
    PrefetchCount:  1,
    MessageTimeout: 30 * time.Second, // 0 = без таймаута
})
defer sub.Close()
go sub.Listen(ctx, handler) // блокирует до отмены ctx или sub.Close()
```

## MultiQueueSubscriber (несколько очередей, один канал)

- Один канал с `Qos(N, global=true)` — ограничение prefetch по всем потребителям
- Один горутин-обработчик (паттерн fan-in)
- Подходит для CPU/IO-тяжёлых нагрузок где параллелизм нежелателен

```go
sub := rabbitmq.NewMultiQueueSubscriber(dialer, rabbitmq.MultiQueueOptions{
    PrefetchCount: 10,
    MaxRetries:    3,
})
defer sub.Close()
go sub.Listen(ctx, // блокирует до отмены ctx или sub.Close()
    rabbitmq.QueueHandler{QueueName: "queue-1", Handler: h1},
    rabbitmq.QueueHandler{QueueName: "queue-2", Handler: h2},
)
```

См. `queue/rabbitmq/README.md` для полного примера DLX топологии.
