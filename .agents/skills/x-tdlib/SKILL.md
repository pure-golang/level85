---
name: "x-tdlib"
description: "Применяй когда работаешь с TDLib-адаптером: `clientAdapter`, `telegramRepo` (consumer-side), тестовая стратегия, авторизация и lifecycle"
---

# TDLib-адаптер

Этот skill — канонический владелец контракта TDLib-адаптера и тестовой стратегии взаимодействия с Telegram.

## Когда применять

- добавляешь или меняешь метод в `internal/repo/telegram/`
- работаешь с consumer-side интерфейсом `telegramRepo`
- подключаешь реальный TDLib или меняешь тестовую стратегию
- затрагиваешь авторизационный flow

Не применяй для:
- бизнес-логики handler/service (там свои skills)
- общих тестовых соглашений (→ `x-testing-conventions`)

## Архитектура адаптера

### Структура пакета `internal/repo/telegram/`

| Файл | Назначение |
|---|---|
| `doc.go` | Контракт пакета, env-переменные |
| `repo.go` | `Repo` struct, lifecycle (`New`, `Start`, `Close`), авторизация |
| `client_adapter.go` | Интерфейс `clientAdapter` + реализации TDLib-методов |

### `clientAdapter` — внутренний контракт

```go
type clientAdapter interface {
    SendMessage(ctx context.Context, chatID domain.ChatID, content domain.InputMessageContent) (domain.MessageID, error)
    // ...остальные методы TDLib
}
```

`Repo` встраивает `clientAdapter`:

```go
type Repo struct {
    clientAdapter
    logger     *slog.Logger
    cfg        config.TelegramConfig
    clientDone chan struct{}
    updates    chan domain.Update
}
```

Роль `clientAdapter`:
- разделяет TDLib-методы и lifecycle-логику `Repo`
- при подключении реального TDLib — реализации методов заменяются на вызовы `client.Client`
- для моков в unit-тестах потребителей используется consumer-side `telegramRepo`, а не `clientAdapter`

### Consumer-side `telegramRepo`

Потребители (handler, facade, transform, term) объявляют частично применяемый интерфейс `telegramRepo` с только нужными им методами:

```go
// в handler/handler.go
type telegramRepo interface {
    SendMessage(ctx context.Context, chatID domain.ChatID, content domain.InputMessageContent) (domain.MessageID, error)
    ForwardMessages(ctx context.Context, fromChatID, toChatID domain.ChatID, messageIDs []domain.MessageID) ([]domain.MessageID, error)
    // ...только методы, реально используемые handler-ом
}
```

Соглашение по именованию:
- интерфейс: `telegramRepo` (не `telegramGateway`, не `telegramClient`)
- поле/параметр: `telegramRepo telegramRepo` (имя = тип)

## Тестовая стратегия

### Unit-тесты

Через mockery-моки consumer-side интерфейса `telegramRepo`:

```go
tg := mocks.NewTelegramRepo(t)
tg.EXPECT().SendMessage(mock.Anything, chatID, mock.Anything).Return(msgID, nil)
```

Unit-тесты **не зависят** от TDLib. Они проверяют логику компонентов-потребителей.

### BDD-тесты

Работают через живой TDLib с тестовым DC. BDD проверяет бизнес-сценарии на реальном Telegram — форвардинг, фильтрация, трансформация и т.д.

Нюансы поведения TDLib (асинхронность, различия типов чатов, rate limits) проявляются естественно в BDD-тестах и при ручном тестировании. Отдельный слой adapter-тестов для TDLib **не нужен** — это тестирование чужого продукта.

### FakeTelegram

`test/support/FakeTelegram` — строительные леса для начального этапа разработки без TDLib. Удаляется при подключении живого TDLib. Не поддерживается как долгосрочный test double — эмуляция нюансов TDLib создаёт ложное чувство безопасности и требует бесконечной синхронизации с реальным поведением.

## Авторизация

Авторизационный flow (`RunAuthFlow`) живёт в `repo.go`, потому что управляет состоянием `clientDone` канала `Repo`. Flow реализован как state machine с состояниями `WaitPhone → WaitCode → WaitPassword → Ready`.

Интерфейс `authService` абстрагирует UI авторизации (терминал, бот, и т.д.) от логики переходов.

## Короткий чек-лист

- TDLib-методы живут в `client_adapter.go`, lifecycle — в `repo.go`
- consumer-side интерфейс называется `telegramRepo`
- имя поля/параметра совпадает с именем типа
- unit-тесты используют mockery-моки
- BDD работает через живой TDLib
- нюансы TDLib не эмулируются в тестах

## Смежные skills

- `x-testing-conventions`
- `x-mockery`
- `x-doc-go`
- `x-env-config`
