#!/bin/bash
set -e             # Выход при любой ошибке
set -o pipefail    # Выход при ошибке в любой команде пайплайна

mkdir -p .coverage

# Запускаем все тесты (unit + integration) с инструментацией всех пакетов
go test -p 8 -timeout 20m -covermode=atomic -coverprofile=.coverage/.out -coverpkg=./... ./...

# Файлы, исключаемые из отчёта покрытия
COVERAGE_EXCLUDE=(
  "internal/repo/telegram/client_adapter.go"
  "mocks/"                         # Сгенерированные моки
  "doc.go"                         # Документация пакетов
  "internal/transport/http/graph/" # Автогенерация gqlgen
  "internal/transport/grpc/pb/"    # Автогенерация protobuf
  "test/"                          # Содержимое папок test
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
