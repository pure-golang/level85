---
name: "x-troubleshooting"
description: "Загружай когда тест, сборка или подключение не работает: Docker, context deadline, ошибки БД/RabbitMQ/S3"
---
# Troubleshooting

## Интеграционные тесты не проходят
```bash
# Проверить что Docker запущен
docker ps

# Проверить занятость порта
lsof -i :5432   # PostgreSQL
lsof -i :5672   # RabbitMQ
lsof -i :9000   # MinIO

# Подробный вывод тестов
go test -v ./...
```

## Context Deadline Exceeded
- Таймаут запроса слишком короткий → проверь `Config.QueryTimeout`
- Увеличь таймаут в конфиге или передай контекст с большим временем жизни
- В интеграционных тестах используй `context.WithTimeout(context.Background(), 5*time.Second)`

## Ошибки подключения к PostgreSQL
- Убедись что PostgreSQL запущен и доступен
- Формат DSN: `postgres://user:pass@host:port/dbname?sslmode=disable`
- Проверь правильность учётных данных и имени базы
- Проверь правила файрвола для порта 5432

## Ошибки подключения к RabbitMQ
- Убедись что RabbitMQ запущен и доступен
- Формат URL: `amqp://user:pass@host:port/`
- Проверь права пользователя и существование очереди/exchange
- Проверь правила файрвола для порта 5672

## Ошибки подключения к S3
- Убедись что S3-совместимое хранилище запущено
- Формат endpoint:
  - MinIO: `localhost:9000`
  - Yandex Cloud: `storage.yandexcloud.net`
  - AWS S3: `s3.amazonaws.com`
- Проверь access key и secret key
- Убедись что bucket существует и есть права доступа
- Проверь правила файрвола (MinIO: 9000, AWS/Yandex: 443)

## Чеклист быстрой диагностики
1. `docker ps` — Docker запущен?
2. Порт свободен? `lsof -i :{port}`
3. Учётные данные правильные в `.env`?
4. Случайно запустил `go test -short`? Убери флаг для интеграционных тестов.
