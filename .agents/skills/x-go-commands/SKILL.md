---
name: "x-go-commands"
description: "Краткий appendix по выбору raw Go-команды: минимальный scope сначала, затем эскалация; если в репозитории есть Taskfile, предпочитай его"
---

# Go-команды

Этот skill больше не считается owner-skill.

Оставшиеся project-specific reminders:
- если в репозитории есть `Taskfile` или project wrapper, предпочитай его raw `go` командам
- начинай с минимального scope и эскалируй только при необходимости
- `-short` не используется для сокрытия падающих тестов
