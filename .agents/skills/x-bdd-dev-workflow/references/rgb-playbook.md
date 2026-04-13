# RGB playbook

## Red

Запусти BDD-прогон и собери отсутствующие шаги:

```bash
task bdd:all
task bdd:pending
```

Типичный pending-snippet:

```go
func (s *scenarioCtx) userRegistered(email string) error {
	return godog.ErrPending
}
```

## Green

Иди по одному сценарию:

```bash
go test ./test/bdd/steps/ -godog.name="^01\\."
BDD_STORY=01_auth/01_login task bdd:story
BDD_EPIC=01_auth task bdd:epic
```

Pending переводится в реальный шаг и код за ним.

## Blue

- выноси дубли в `helpers_test.go` или `test/support`
- держи `.feature` неизменным
- регулярно гоняй полный BDD-набор

## Запреты

- pending-шаги в целевой ветке
- пропуск red-фазы
- параллельная реализация нескольких незелёных сценариев
- несанкционированное изменение `.feature` во время dev-цикла
