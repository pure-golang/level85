# Формы unit-тестов с моками

## Mock import alias

Если нужен alias для импорта моков, предпочитай понятное имя вроде `repoMock` или `clientMock`, а не общее `m`.

## Табличный тест с условным EXPECT

```go
func TestService_GetItem(t *testing.T) {
    t.Parallel()

    tests := []struct {
        name    string
        id      int64
        prepare func(repo *mocks.ItemRepo)
        wantErr error
        wantNil bool
        wantID  int64
    }{
        {
            name: "success_case",
            id:   1,
            prepare: func(repo *mocks.ItemRepo) {
                repo.EXPECT().
                    GetItem(mock.Anything, int64(1)).
                    Return(&entity.Item{ID: 1}, nil)
            },
            wantID: 1,
        },
        {
            name: "repo_error",
            id:   2,
            prepare: func(repo *mocks.ItemRepo) {
                repo.EXPECT().
                    GetItem(mock.Anything, int64(2)).
                    Return(nil, assert.AnError)
            },
            wantErr: assert.AnError,
            wantNil: true,
        },
    }

    for _, tt := range tests {
        tt := tt
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()

            // Arrange
            repo := mocks.NewItemRepo(t)
            tt.prepare(repo)
            svc := New(repo)

            // Act
            got, err := svc.MethodName(context.Background(), tt.id)

            // Assert
            assert.ErrorIs(t, err, tt.wantErr)
            if tt.wantNil {
                assert.Nil(t, got)
                return
            }
            require.NotNil(t, got)
            assert.Equal(t, tt.wantID, got.ID)
        })
    }
}
```

## Call-test с моками

```go
func TestService_Create(t *testing.T) {
    t.Parallel()

    tests := []struct {
        name   string
        setup  func(t *testing.T) *Service
        verify func(t *testing.T, got *entity.Item, err error)
    }{
        {
            name: "success_case",
            setup: func(t *testing.T) *Service {
                t.Helper()

                repo := mocks.NewItemRepo(t)
                repo.EXPECT().
                    Save(mock.Anything, mock.Anything).
                    Return(nil)

                return New(repo)
            },
            verify: func(t *testing.T, got *entity.Item, err error) {
                t.Helper()
                require.NoError(t, err)
                require.NotNil(t, got)
            },
        },
    }

    for _, tt := range tests {
        tt := tt
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()

            // Arrange
            svc := tt.setup(t)

            // Act
            got, err := svc.Create(context.Background())

            // Assert
            tt.verify(t, got, err)
        })
    }
}
```

## `suite.Suite`

```go
type ServiceSuite struct {
    suite.Suite
    repo *mocks.ItemRepo
    svc  *Service
}

func (s *ServiceSuite) SetupTest() {
    s.repo = mocks.NewItemRepo(s.T())
    s.svc = New(s.repo)
}

func (s *ServiceSuite) TestMethodName() {
    // Arrange
    s.repo.EXPECT().
        GetItem(mock.Anything, int64(1)).
        Return(&entity.Item{ID: 1}, nil)

    // Act
    got, err := s.svc.MethodName(context.Background(), 1)

    // Assert
    s.Require().NoError(err)
    s.Require().NotNil(got)
}

func TestServiceSuite(t *testing.T) {
    t.Parallel()
    suite.Run(t, new(ServiceSuite))
}
```

## Error case

```go
func TestMethodName_error(t *testing.T) {
    t.Parallel()

    // Arrange
    repo := mocks.NewItemRepo(t)
    repo.EXPECT().
        GetItem(mock.Anything, mock.Anything).
        Return(nil, assert.AnError)

    svc := New(repo)

    // Act
    got, err := svc.MethodName(context.Background(), 1)

    // Assert
    assert.Error(t, err)
    assert.ErrorIs(t, err, assert.AnError)
    assert.Nil(t, got)
}
```

## `errors.As`

```go
func TestMethodName_domainError(t *testing.T) {
    t.Parallel()

    // Arrange
    repo := mocks.NewItemRepo(t)
    repo.EXPECT().
        GetItem(mock.Anything, mock.Anything).
        Return(nil, &DomainError{Code: "not_found"})

    svc := New(repo)

    // Act
    _, err := svc.MethodName(context.Background(), 1)

    // Assert
    var domainErr *DomainError
    require.Error(t, err)
    require.ErrorAs(t, err, &domainErr)
    assert.Equal(t, "not_found", domainErr.Code)
}
```

## Архитектурный сигнал

Если unit-тест трудно написать без громоздкого setup, большого числа моков или копирования почти всего внешнего контракта, это признак архитектурной проблемы. Обычно это означает, что зависимость слишком крупная или сервис знает о слишком многих деталях.
Если увидел такой сигнал, не рефактори архитектуру молча только ради теста: сначала обсуди это с пользователем и зафиксируй, что именно стоит упростить в контракте.
