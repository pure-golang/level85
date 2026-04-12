---
name: "x-env-config"
description: "Что делать при добавлении конфигурации: Config struct, envconfig-теги, загрузка из .env"
compatibility: git.korputeam.ru/newbackend/adapters
---
# Environment Configuration

## Шаг 1: Объяви Config struct

Каждое поле — с тегами `envconfig`, `default` или `required`:

```go
type Config struct {
    Host    string        `envconfig:"SERVICE_HOST"     default:"localhost"`
    Port    int           `envconfig:"SERVICE_PORT"     default:"5432"`
    Password string       `envconfig:"SERVICE_PASSWORD" required:"true"`
    Timeout time.Duration `envconfig:"SERVICE_TIMEOUT"  default:"10s"`
}
```

Теги:
- `envconfig:"VAR_NAME"` — имя переменной окружения
- `required:"true"` — падать если не задана
- `default:"value"` — значение по умолчанию

## Шаг 2: Загрузи конфиг

```go
var cfg Config
if err := env.InitConfig(&cfg); err != nil {
    // handle error
}
```

`env.InitConfig` загружает `.env` из корня проекта (через `godotenv`), затем парсит переменные через `envconfig`.

## Шаг 3: Добавь переменные в .env

Паттерн именования: `COMPONENT_FIELD`:

```bash
# Пример
SERVICE_HOST=localhost
SERVICE_PORT=5432
SERVICE_PASSWORD=secret
SERVICE_TIMEOUT=10s
```

## Шаг 4: Задокументируй в doc.go

Все переменные из Config struct должны быть перечислены в секции `Конфигурация:` файла `doc.go` пакета. См. скилл `x-doc-go`.
