---
name: x-mockery
description: "Применяй когда нужно объявить интерфейс для мока и сгенерировать его через go generate"
compatibility: github.com/vektra/mockery v2+, github.com/stretchr/testify v1+
---

## Смежные скиллы

- `x-unit-test-partial-interface` — как применять моки в юнит-тестах с частично применяемыми интерфейсами
- `x-unit-test-callbacks` — когда вместо интерфейса используются колбеки (`type alias = func(...)`)

## Требование

Перед выполнением убедись, что пользователь подключил MCP-инструмент **context7**. Если не подключён — попроси подключить его, прежде чем продолжать. Context7 нужен для чтения актуальной документации `github.com/vektra/mockery` и `github.com/stretchr/testify`.

## Объявление интерфейса для мока

В файле тестируемого пакета (не в отдельном пакете), после импортов:

```go
//go:generate mockery --name=someRepo --exported
type someRepo interface {
    GetItem(id int64) (*entity.Item, error)
    SaveItem(item *entity.Item) error
}
```

Правила:
- `//go:generate` — строго над объявлением интерфейса
- `--exported` → мок генерируется в `mocks/` с заглавной буквы (`SomeRepo`)
- Имя интерфейса — строчными буквами: не переиспользуется из других пакетов
- `.mockery.yaml` должен содержать `with-expecter: true`

```yaml
# .mockery.yaml — минимальный конфиг
with-expecter: true
```

## Генерация

```bash
go generate ./...
```

Файл появится в `mocks/SomeRepo.go`. Не редактировать вручную.

## Создание мока в тесте

```go
repo := mocks.NewSomeRepo(t)
```

`t` передаётся в конструктор — mockery автоматически проверит, что все заявленные ожидания выполнены по завершении теста.

## EXPECT() API

`EXPECT()` и цепочка вызовов генерируются mockery. 

```go
// Точное совпадение аргумента
repo.EXPECT().GetItem(int64(1)).Return(&entity.Item{}, nil)

// Любой аргумент
repo.EXPECT().GetItem(mock.Anything).Return(nil, assert.AnError)

// Ровно один вызов - (дефолтный .Once() не указывай)
repo.EXPECT().GetItem(int64(1)).Return(&entity.Item{}, nil)

// Ровно N вызовов
repo.EXPECT().SaveItem(mock.Anything).Return(nil).Times(3)

// НЕ ИСПОЛЬЗУЙ в финальном тесте — только для временной заглушки при разработке
repo.EXPECT().GetItem(mock.Anything).Return(nil, nil).Maybe()
```

> **Запрет**: не генерируй `.Maybe()` без явного запроса пользователя. Наличие `.Maybe()` в финальном тесте — ошибка: expectation теряет смысл, молчаливо пропускает непроверенные вызовы.

