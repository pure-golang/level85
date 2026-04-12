---
name: x-unit-test-partial-interface
description: "Применяй при написании юнит-тестов с внешними зависимостями: частичные интерфейсы, моки, виды тестов"
compatibility: github.com/stretchr/testify v1+, github.com/vektra/mockery v2+
---

## Что такое частично применяемый интерфейс

Каждый модуль объявляет у себя в пакете локальные интерфейсы, которые содержат **только те методы зависимости, которые реально используются** — не полный интерфейс зависимости, а его «частичное применение».

Это даёт: явные требования модуля, слабую связанность, и главное — **в тесте нужно мокировать только те методы, которые реально вызываются**.

```go
// someRepo — не весь интерфейс репозитория, а только нужные методы
//go:generate mockery --name=someRepo --exported
type someRepo interface {
    GetItem(id int64) (*entity.Item, error)
}

// конструктор принимает интерфейс, возвращает указатель на конкретный тип
func New(repo someRepo) *Service { ... }
```

## Принцип

Если написать тест сложно — это сигнал архитектурной проблемы. Тест не подстраивается под код; код должен быть написан так, чтобы тест писался легко. Обнаружил сложность — обсуди рефакторинг с пользователем до написания теста.

## Шаг 1: Объявить интерфейс и сгенерировать мок

См. скилл `x-mockery`.

## Шаг 2: Написать тест

### Выбор вида теста

| Ситуация | Вид теста |
|---|---|
| Один метод, одно поведение | Простой тест |
| Один метод, несколько наборов входных данных | Табличный тест |
| Разный сложный setup или verify для каждого кейса | Call-тест (`setup` / `verifyFunc`) |
| Shared setup/teardown для группы тестов | `suite.Suite` |

### Простой тест

```go
func TestMethodName(t *testing.T) {
    t.Parallel()

    // Arrange
    repo := mocks.NewSomeRepo(t)
    repo.EXPECT().GetItem(&GetItemRequest{Id: 1}).Return(&entity.Item{Id: 1}, nil)
    svc := New(repo)

    // Act
    result, err := svc.MethodName(1)

    // Assert
    require.NoError(t, err)
    assert.Equal(t, int64(1), result.Id)
}
```

### Тест на обработку ошибки

```go
func TestMethodName_error(t *testing.T) {
    t.Parallel()

    repo := mocks.NewSomeRepo(t)
    repo.EXPECT().GetItem(mock.Anything).Return(nil, assert.AnError)
    svc := New(repo)

    result, err := svc.MethodName(1)

    assert.Error(t, err)
    assert.Nil(t, result)
}
```

### Тест с assert.ErrorAs

```go
func TestMethodName_domainError(t *testing.T) {
    t.Parallel()

    repo := mocks.NewSomeRepo(t)
    repo.EXPECT().GetItem(mock.Anything).Return(nil, &DomainError{Code: "not_found"})
    svc := New(repo)

    _, err := svc.MethodName(99)

    var domainErr *DomainError
    assert.ErrorAs(t, err, &domainErr)
    assert.Equal(t, "not_found", domainErr.Code)
}
```

### Табличный тест

```go
func Test(t *testing.T) {
    t.Parallel()

    tests := []struct {
        name    string
        input   int64
        want    *entity.Item
        wantErr bool
    }{
        {
            name:  "success",
            input: 1,
            want:  &entity.Item{Id: 1},
        },
        {
            name:    "not_found",
            input:   99,
            wantErr: true,
        },
    }

    for _, tc := range tests {
        t.Run(tc.name, func(t *testing.T) {
            t.Parallel()

            repo := mocks.NewSomeRepo(t)
            if tc.wantErr {
                repo.EXPECT().GetItem(mock.Anything).Return(nil, assert.AnError)
            } else {
                repo.EXPECT().GetItem(tc.input).Return(tc.want, nil)
            }
            svc := New(repo)

            result, err := svc.MethodName(tc.input)

            if tc.wantErr {
                assert.Error(t, err)
                assert.Nil(t, result)
            } else {
                require.NoError(t, err)
                assert.Equal(t, tc.want.Id, result.Id)
            }
        })
    }
}
```

### Call-тест (сложный setup или verify)

```go
func Test(t *testing.T) {
    t.Parallel()

    tests := []struct {
        name       string
        setup      func(t *testing.T) *Service
        verifyFunc func(t *testing.T, result *entity.Item, err error)
    }{
        {
            name: "success",
            setup: func(t *testing.T) *Service {
                repo := mocks.NewSomeRepo(t)
                repo.EXPECT().GetItem(int64(1)).Return(&entity.Item{Id: 1}, nil)
                return New(repo)
            },
            verifyFunc: func(t *testing.T, result *entity.Item, err error) {
                require.NoError(t, err)
                assert.Equal(t, int64(1), result.Id)
            },
        },
        {
            name: "repo_error",
            setup: func(t *testing.T) *Service {
                repo := mocks.NewSomeRepo(t)
                repo.EXPECT().GetItem(mock.Anything).Return(nil, assert.AnError)
                return New(repo)
            },
            verifyFunc: func(t *testing.T, result *entity.Item, err error) {
                assert.Error(t, err)
                assert.Nil(t, result)
            },
        },
    }

    for _, tc := range tests {
        t.Run(tc.name, func(t *testing.T) {
            t.Parallel()

            svc := tc.setup(t)
            result, err := svc.MethodName(1)
            tc.verifyFunc(t, result, err)
        })
    }
}
```

### suite.Suite

```go
type ServiceSuite struct {
    suite.Suite
    repo *mocks.SomeRepo
    svc  *Service
}

func (s *ServiceSuite) SetupTest() {
    s.repo = mocks.NewSomeRepo(s.T())
    s.svc = New(s.repo)
}

func (s *ServiceSuite) TearDownTest() {
    // освобождение ресурсов при необходимости
}

func (s *ServiceSuite) TestSuccess() {
    s.repo.EXPECT().GetItem(int64(1)).Return(&entity.Item{Id: 1}, nil)

    result, err := s.svc.MethodName(1)

    s.NoError(err)
    s.Equal(int64(1), result.Id)
}

func TestServiceSuite(t *testing.T) {
    suite.Run(t, new(ServiceSuite))
}
```

## Смежные скиллы

- `x-testing-conventions` — базовые соглашения по тестам
- `x-mockery` — EXPECT() API для моков
- `x-unit-test-callbacks` — когда метод интерфейса принимает параметр-функцию (`type alias = func(...)`)
- `x-unit-test-synctest` — когда тестируемый код содержит горутины или зависит от времени
