---
name: "x-executor-cli"
description: "Паттерн CLI Executor: запуск внешних команд с контекстом, логированием и трейсингом"
compatibility: git.korputeam.ru/newbackend/adapters
---
# CLI Executor

```go
// Создать CLI executor
cfg := cli.Config{
    Command: "ffmpeg",
}
executor := cli.New(cfg, nil, nil)
defer executor.Close()

// Выполнить команду с аргументами
ctx := context.Background()
output, err := executor.Execute(ctx,
    "-i", "input.mp4",
    "-c:v", "libx264",
    "-c:a", "aac",
    "-y", "output.mp4",
)
if err != nil {
    log.Fatal(err)
}
```

## Заметки
- Использует стандартную библиотеку `os/exec`
- Реализует интерфейс `Executor`
- Поддерживает отмену через контекст
- Logger и tracer — опциональные второй и третий аргументы: `cli.New(cfg, logger, tracer)`
- Квотирование `%q` в сообщениях об ошибках: `fmt.Errorf("command %q not found: %w", e.cmd, err)`
