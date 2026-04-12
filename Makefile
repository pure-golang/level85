# Установка зависимостей проекта
.PHONY: all
all:
	go install github.com/go-task/task/v3/cmd/task@latest
	go install github.com/vektra/mockery/v2@v2.53.5
	go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest
	go install github.com/99designs/gqlgen@v0.17.89
	task mod
	task
	@echo ---
	@bash scripts/task-auto.sh
