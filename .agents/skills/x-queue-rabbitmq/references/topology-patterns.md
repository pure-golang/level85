# Паттерны топологии

## Базовый retry/DLQ паттерн

Нужны:
- основная очередь
- retry очередь с `x-message-ttl`
- DLQ
- binding'и и, при необходимости, отдельный DLX exchange

Идея:
- обработчик падает
- subscriber публикует сообщение в retry queue
- по TTL RabbitMQ возвращает его в основную очередь
- после исчерпания `MaxRetries` сообщение уходит в DLQ

## Hostname caveat для durable node

Для persistent RabbitMQ node hostname должен быть стабильным: имя узла выглядит как `rabbit@<hostname>`. Если hostname меняется между перезапусками контейнера, ожидания по сохранённому состоянию и recovery могут не совпасть с фактическим поведением.

Минимальный ориентир для compose:

```yaml
services:
  rabbitmq:
    hostname: rabbitmq
```

## Что проверить до запуска subscriber

- существует ли `RetryQueueName`
- есть ли route обратно в основную очередь
- настроен ли DLQ path
- совпадает ли `RoutingKey` publisher с topology

## Subscriber defaults

- `RetryQueueName == ""` → обычно `QueueName + ".retry"`
- `PrefetchCount == 0` → лучше не полагаться молча на адаптерный дефолт, а указывать явно
- `MessageTimeout == 0` → обработка без per-message timeout

## `Definitions` как JSON

`Definitions` полезны не только для тестов, но и как переносимый topology artifact:

```go
payload, err := definitions.JSON()
```

Дальше этот JSON можно:
- загрузить через management API
- использовать через `load_definitions`
- импортировать через `rabbitmqctl import_definitions`

## Когда нужен `MultiQueueSubscriber`

- несколько очередей
- один последовательный worker
- общий prefetch на канал
- общий `Qos(..., global=true)` для fan-in модели

Не брать его по инерции, если обработка может идти независимо и параллельно.

## Recovery behaviour

Recovery соединения полезен, но не отменяет явную проверку topology и retry path после reconnect. Если topology drift недопустим, проверяй его отдельно, а не считай reconnect достаточной гарантией.
