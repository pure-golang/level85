# Аудит references в x-* skills: риск неприменения примеров

## Проблема

References в skills загружаются агентом **по необходимости**, а не автоматически при активации скилла. Если reference содержит примеры кода с правильными паттернами, агент может их не прочитать и сгенерировать код по собственным знаниям, игнорируя project conventions.

Реальный кейс: `x-testing-conventions` содержит примеры с `require.NoError` в references, но агент генерировал `if err != nil { t.Fatalf(...) }`, потому что reference не был загружен.

## Scope

Аудит охватывает только `x-*` skills (project-specific). Служебные skills (playwright-cli, skill-creator, context7-cli, find-docs, find-skills, chrome-devtools) исключены.

## Критерии оценки

| Риск | Когда |
|------|-------|
| **Высокий** | Reference содержит Go-примеры с project-specific паттернами. Без них агент сгенерирует generic код |
| **Средний** | Reference содержит чеклисты/правила без кода, или код тривиальный |
| **Низкий** | Reference содержит справочную информацию, которую агент не мог бы применить неправильно |

## Результаты аудита

### Skills с высоким риском

Эти skills вынесли Go-примеры с project conventions в references, и агент может не прочитать их.

| Скилл | SKILL.md | refs | Итого | Проблема |
|-------|----------|------|-------|----------|
| x-testing-conventions | 88 | 231 | 319 | call-test форма, AAA в примерах, `t.Parallel()` safety — всё в references |
| x-unit-test-partial-interface | 90 | 238 | 328 | примеры partial interfaces и callback-style — основная ценность скилла в references |
| x-storage-s3 | 112 | 141 | 253 | примеры работы с S3 API вынесены в reference |
| x-bdd-godog | 77 | 167 | 244 | структура step definitions и примеры feature-файлов в references |
| x-database-patterns | 134 | 99 | 233 | примеры repo-паттернов в reference |

### Skills со средним риском

| Скилл | SKILL.md | refs | Итого | Проблема |
|-------|----------|------|-------|----------|
| x-queue-rabbitmq | 114 | 66 | 180 | примеры publisher/subscriber в reference |
| x-log | 69 | 89 | 158 | примеры логирования в reference |
| x-env-config | 100 | 46 | 146 | примеры конфигурации в reference |
| x-queue-kafka | 95 | 46 | 141 | примеры Kafka-паттернов в reference |
| x-observability | 83 | 53 | 136 | примеры middleware/metrics в reference |
| x-bdd-knowledge-harvest | 71 | 64 | 135 | примеры feature-файлов в reference |
| x-bdd-dev-workflow | 74 | 43 | 117 | workflow-пример в reference |

### Skills с низким риском

| Скилл | SKILL.md | refs | Итого | Причина |
|-------|----------|------|-------|---------|
| x-doc-go | 104 | 33 | 137 | reference содержит шаблон без Go-кода |
| x-bdd-product-workflow | 73 | 40 | 113 | reference — текстовый workflow, не код |
| x-mockery | 153 | 40 | 193 | reference — конфигурация `.mockery.yml`, не Go-код |

### x-* skills без references (проблемы нет)

| Скилл | Строк |
|-------|-------|
| x-test-matrix | 138 |
| x-integration-testing | 136 |
| x-commit | 122 |
| x-executor-cli | 98 |
| x-skill-bundles | 70 |
| x-new-adapter | 65 |
| x-troubleshooting | 22 |
| x-errors | 15 |
| x-go-commands | 13 |
| x-hyphen-vs-underscore | 13 |

## Сводка

| Категория | Кол-во skills | Действие |
|-----------|---------------|----------|
| Высокий риск | 5 | Инлайнить references в SKILL.md |
| Средний риск | 7 | Инлайнить references в SKILL.md |
| Низкий риск | 3 | Можно оставить как есть |
| Без references | 10 | Проблемы нет |

## Рекомендация

Для 12 skills с высоким и средним риском (итого каждый < 350 строк) — инлайнить references в SKILL.md. Три skills с низким риском можно оставить как есть: их references не содержат Go-примеров, которые агент мог бы применить неправильно.
