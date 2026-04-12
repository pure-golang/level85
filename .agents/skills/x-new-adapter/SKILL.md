---
name: "x-new-adapter"
description: "Чеклист добавления нового адаптера: структура, doc.go, Config, интерфейс, тесты"
compatibility: git.korputeam.ru/newbackend/adapters
---
# Добавление нового адаптера

## Чеклист (выполнять по порядку)

1. **Структура директорий**: `{тип_адаптера}/{имя_адаптера}/`
   - Примеры: `queue/nats/`, `db/pg/pgxpool/`, `storage/gcs/`

2. **doc.go**: создай документацию пакета (см. скилл `x-doc-go` для формата)

3. **Config struct**: добавь теги `envconfig` для всех полей
   ```go
   type Config struct {
       Host    string        `envconfig:"MYSERVICE_HOST" default:"localhost"`
       Port    int           `envconfig:"MYSERVICE_PORT" default:"1234"`
       Timeout time.Duration `envconfig:"MYSERVICE_TIMEOUT" default:"10s"`
   }
   ```

4. **Интерфейс**: реализуй `Provider` (или `RunableProvider` для долгоживущих процессов)
   ```go
   type Provider interface {
       Start() error
       io.Closer
   }
   ```

5. **Конструктор**: экспортируй конструктор возвращающий конкретный тип (никогда не ошибку)
   - `New(cfg Config)` — если в пакете один основной тип
   - `New<Name>(cfg Config)` — если типов несколько (`NewReader`, `NewWriter` и т.п.)
   - Ошибки соединения/инициализации откладываются до `Start()` или `Connect()`

6. **Трейсинг OpenTelemetry**: добавь spans для всех операций (см. скилл `x-observability`)
   ```go
   var tracer = otel.Tracer("git.korputeam.ru/newbackend/adapters/{path}")
   // Именование span: packageName.Operation (например, "myadapter.Get")
   ```

7. **README.md**: примеры использования на русском

9. **Юнит-тесты**: покрой основную логику без внешних сервисов

10. **Интеграционные тесты**: используй `testcontainers-go` если нужен внешний сервис
    - См. скилл `x-integration-testing`

11. **Обнови AGENTS.md**: если введены новые паттерны — добавь ссылки
