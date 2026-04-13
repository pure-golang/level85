---
name: "x-log"
description: "Применяй при добавлении или изменении логирования в сервисе, адаптере, репозитории, клиенте, resolver или handler: `*slog.Logger` в структуре, `module`, `logger.FromContext(ctx)` и уровни логирования"
compatibility: ../platform, ../adapters
---
# Логирование

Этот skill — **канонический владелец** logging policy:
- `*slog.Logger` как поле структуры
- `module`
- выбор между `s.logger` и `logger.FromContext(ctx)`
- уровни логирования

Bootstrap monitoring/tracing/metrics принадлежит `x-observability`, а не этому skill.

## Когда применять

- добавляешь логирование в package-level компонент
- переносишь прямые вызовы `slog.*` в project path
- проверяешь naming `module`

## Core workflow

### 1. Добавляй logger только туда, где он реально используется

Если структура не логирует, поле `logger` не нужно.

### 2. Внутри методов не используй `slog` напрямую

- сервисы, репозитории, клиенты используют `s.logger`
- HTTP/gRPC handlers и middleware используют `logger.FromContext(ctx)`

### 3. Именуй `module` согласованно

- `internal/service/room` → `service.room`
- `internal/repo/user` → `repo.user`
- `internal/graph` → `graph`
- `pkg/fcm` → `pkg.fcm`
- `cmd/app` → `main`

Эталонные примеры см. `references/module-and-context.md`.

### 4. Выбирай уровень и поля осознанно

- `Debug` — детали отладки
- `Info` — значимые события
- `Warn` — нештатное, но не ошибка
- `Error` — ошибка

Правила:
- сообщения логов на английском
- ключи атрибутов в `snake_case`
- не дублируй одну и ту же ошибку и в логе, и в return-path без необходимости
- используй типизированные `slog.*` атрибуты

## Короткий чек-лист

- logger живёт в структуре, а не в прямых `slog.*` вызовах
- `module` назван по project path
- request-aware flow использует `logger.FromContext(ctx)`
- атрибуты типизированы

## References

- `references/module-and-context.md` — короткие эталонные паттерны `module`, `FromContext` и logger bootstrap

## Смежные skills

- `x-observability`
