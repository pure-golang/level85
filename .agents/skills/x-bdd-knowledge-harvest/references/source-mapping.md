# Источники и трансляция в `.feature`

## 1. `doc.go` и публичные API

- публичная функция или хэндлер может быть кандидатом в Feature
- описание пакета помогает собрать user story
- технический контракт остаётся в `doc.go`; в `.feature` уходит только наблюдаемое поведение

## 2. Существующие тесты

Правило трансляции:
- `Arrange` → `Given`
- `Act` → `When`
- `Assert` → `Then`

Пример:

```go
func TestLogin_InvalidPassword(t *testing.T) {
	user := createUser(t, "user@example.com", "correct")
	_, err := svc.Login(ctx, "user@example.com", "wrong")
	require.ErrorIs(t, err, ErrInvalidCredentials)
}
```

```gherkin
Scenario: 02. Отказ при неверном пароле
  Given зарегистрирован пользователь "user@example.com"
  When пользователь вводит "user@example.com" и неверный пароль
  Then система отвечает ошибкой "неверные учётные данные"
```

## 3. `docs/` и markdown-артефакты

- FAQ часто даёт готовые альтернативные сценарии
- changelog и how-to описывают скрытые правила
- фразы вида «если X, то Y» обычно превращаются в отдельный Scenario

## 4. Git history

- bugfix-коммиты дают регрессионные сценарии
- feature-коммиты показывают эволюцию правил

Полезные команды:

```bash
git log --grep="fix" --oneline --all
git show <sha>
git log --follow path/to/file.go
```

## 5. Интервью

Спрашивай:
- какие правила неочевидны из кода
- какие сценарии ломались в проде
- какие ограничения команда держит в голове, но не фиксирует

## Антипаттерны

- конвертировать в `.feature` каждый unit-тест подряд
- слепо копировать changelog без восстановления пользовательского эффекта
- делать harvest уже после рефакторинга
- оставлять SQL, endpoint names и internal errors в шагах
