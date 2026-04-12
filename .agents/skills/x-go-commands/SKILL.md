---
name: "x-go-commands"
description: "Справочник команд: запуск тестов, сборка, управление зависимостями Go-модуля"
---
# Go Commands

## Тестирование
```bash
# Запустить все тесты
go test .

# Пропустить интеграционные тесты (Docker)
go test -short .

# Тесты конкретного пакета
go test ./db/pg/sqlx
go test ./queue/rabbitmq
go test ./queue/kafka

# Подробный вывод
go test -v ./...

# Запустить один тест
go test -run TestFunctionName ./path/to/pkg
```

## Сборка
```bash
# Собрать модуль
go build ./...

# Проверить зависимости
go mod tidy
go mod verify
```

## Зависимости
```bash
# Скачать зависимости
go mod download

# Обновить зависимости
go get -u ./...
```

## Docker для интеграционных тестов
Интеграционные тесты используют `github.com/testcontainers/testcontainers-go`.

**Docker должен быть запущен** для прохождения интеграционных тестов:
```bash
docker ps  # проверить что Docker работает
```

Флаг `-short` пропускает интеграционные тесты (для CI/CD без Docker):
```bash
go test -short ./...
```
