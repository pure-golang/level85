---
name: "x-unit-test-snapshot"
description: "Применяй когда нужно зафиксировать сложный вывод (JSON, логи, сериализация) и сравнивать с эталоном при каждом прогоне"
---
# Snapshot-тесты (go-snaps)

## Когда применять

Snapshot-тесты полезны, когда проверяемое значение:
- **Сложное для ручного описания** — длинный JSON, многострочный лог, сериализованная структура
- **Стабильное по формату, но не по содержанию** — callstack, форматированный отчёт
- **Легко проверяется визуально** — при обновлении снапшота человек видит diff и подтверждает

**Не применяй для:**
- Простых значений (`assert.Equal` достаточно)
- Нестабильного вывода (timestamps, UUID, random) — без предварительной нормализации
- Бизнес-логики, где важны конкретные поля — лучше явные assertions

## Шаг 1: Добавь зависимость

```bash
go get github.com/gkampitakis/go-snaps
```

## Шаг 2: Структура файлов

```
package/
├── handler.go
├── handler_test.go
└── __snapshots__/          # создаётся автоматически
    └── handler_test.snap   # имя = имя тест-файла
```

Директория `__snapshots__/` и `.snap` файлы **коммитятся в git** — это эталон.

## Шаг 3: Базовое использование

```go
package handler_test

import (
	"testing"

	"github.com/gkampitakis/go-snaps/snaps"
)

func TestRenderResponse(t *testing.T) {
	t.Parallel()

	result := renderResponse(input)

	snaps.MatchSnapshot(t, result)
}
```

При первом запуске go-snaps создаёт `.snap` файл с эталоном. При последующих — сравнивает.

### Формат .snap файла

```
[TestRenderResponse - 1]
{"status":"ok","data":{"id":42,"name":"test"}}
---

[TestRenderResponse - 2]
{"status":"error","message":"not found"}
---
```

Каждая запись: `[ИмяТеста - N]`, тело, `---`.

## Шаг 4: Варианты API

```go
// Произвольное значение — сериализуется через fmt.Sprint
snaps.MatchSnapshot(t, value)

// JSON — форматирует и сравнивает как JSON
snaps.MatchJSON(t, jsonString)

// YAML
snaps.MatchYAML(t, yamlString)

// Standalone — один снапшот в отдельном файле (для больших значений)
snaps.MatchStandaloneSnapshot(t, largeOutput)
```

## Шаг 5: Обновление снапшотов

Когда формат вывода **намеренно изменился**:

```bash
# Обновить все снапшоты
UPDATE_SNAPS=true go test ./...

# Обновить снапшоты конкретного пакета
UPDATE_SNAPS=true go test ./internal/handler/...
```

После обновления — **обязательно просмотри diff** (`git diff __snapshots__/`) перед коммитом.

## Шаг 6: Очистка неиспользуемых снапшотов

В `TestMain` добавь вызов `Clean` — удаляет записи, на которые больше нет тестов:

```go
func TestMain(m *testing.M) {
	v := m.Run()
	snaps.Clean(m)
	os.Exit(v)
}
```

## Шаг 7: Нормализация нестабильных значений

Если в выводе есть timestamps, UUID или другие нестабильные части — нормализуй **перед** снапшотом:

```go
func TestLogOutput(t *testing.T) {
	t.Parallel()

	output := captureLog()

	// нормализуем нестабильные части
	normalized := timestampRe.ReplaceAllString(output, "<TIMESTAMP>")

	snaps.MatchSnapshot(t, normalized)
}

var timestampRe = regexp.MustCompile(`\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}`)
```

Для JSON есть встроенные matchers:
```go
snaps.MatchJSON(t, jsonStr,
	match.Any("id"),          // игнорировать значение поля
	match.Any("created_at"),
)
```

## Антипаттерны

- **Снапшот вместо явной проверки** — если важно конкретное поле, используй `assert.Equal`. Снапшот — для «общей картины», а не для точечных assertions
- **UPDATE_SNAPS в CI** — снапшоты обновляются только локально, в CI должны только сравниваться
- **Снапшот нестабильного вывода без нормализации** — flaky тесты
- **Огромные снапшоты** — если `.snap` файл > 100 строк, подумай о `MatchStandaloneSnapshot` или о том, чтобы тестировать меньшую часть

## Интеграция с testify

go-snaps работает рядом с testify — используй оба:

```go
func TestHandler(t *testing.T) {
	t.Parallel()

	resp, err := handler.Do(ctx, req)

	require.NoError(t, err)                    // точечная проверка
	assert.Equal(t, http.StatusOK, resp.Code)   // точечная проверка
	snaps.MatchJSON(t, resp.Body.String())       // полная картина тела
}
```

## Смежные скиллы

- `x-testing-conventions` — общие соглашения (AAA, assertions, маркеры, RGB)
- `x-unit-test-partial-interface` — юнит-тесты с моками
- `x-unit-test-synctest` — тесты с горутинами и таймингом
