#!/bin/bash
set -e             # Выход при любой ошибке
set -o pipefail    # Выход при ошибке в любой команде пайплайна

mkdir -p .coverage

# Запускаем все тесты (unit + integration) с инструментацией всех пакетов
go test -covermode=atomic -coverprofile=.coverage/.out -coverpkg=./... ./...

# Файлы, исключаемые из отчёта покрытия
COVERAGE_EXCLUDE=(
  "/mocks/"                      # Сгенерированные моки
  "doc.go"                       # Документация пакетов
  "internal/graph/generated.go"  # Автогенерация gqlgen
  "internal/graph/model.go"      # Автогенерация gqlgen
  "internal/graph/federation.go" # Автогенерация gqlgen
  "/pb/"                         # Protobuf
)

# Экранируем точки и собираем regex-паттерн для grep -vE
PATTERN=$(printf '%s\n' "${COVERAGE_EXCLUDE[@]}" | sed 's/\./\\./g' | tr '\n' '|' | sed 's/|$//')

# Оставляем только production-код (internal/, pkg/), исключаем автогенерацию и моки
FILTERED=$(grep -E "(internal/|pkg/)" .coverage/.out | grep -vE "($PATTERN)")

# Копируем заголовок "mode: atomic" — go tool cover требует его первой строкой
head -1 .coverage/.out > .coverage/.txt

# Мержим дубликаты: -coverpkg=./... генерирует N записей на строку (по одной на test binary).
# Для каждой уникальной строки берём максимальный count — иначе go tool cover занижает покрытие.
echo "$FILTERED" | awk '{
  key=$1" "$2; count=$3+0
  if(count > max[key]+0) max[key]=count
  stmt[key]=$2
}
END {
  for(k in stmt) {
    split(k, parts, " ")
    printf "%s %s %d\n", parts[1], stmt[k], max[k]
  }
}' >> .coverage/.txt
rm .coverage/.out
