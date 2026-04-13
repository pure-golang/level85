# Конфигурационные паттерны для `mockery`

Короткие паттерны для проектного пути работы с `mockery v3`.

## Базовый паттерн с областью пакета

```yaml
filename: "{{.InterfaceName | snakecase}}.go"
dir: "{{.InterfaceDir}}/mocks"
structname: "{{.InterfaceName | firstUpper}}"
pkgname: mocks
template: testify
template-data:
  unroll-variadic: true
packages:
  your/module/internal/service:
    config:
      all: true
```

Это проектный дефолт:

- сгенерированный файл лежит рядом с пакетом интерфейса в `mocks/`
- конструктор создаётся как `New<Type>(t)`
- `EXPECT()` даётся шаблоном `testify`

## Когда добавлять пакет в `.mockery.yml`

Если интерфейс появился в новом пакете, сначала добавь пакет в `packages:`.
Если пакет уже указан с `all: true`, отдельный интерфейс туда дописывать не нужно.

## Проверка после генерации

После генерации проверь:

- пакет присутствует в `.mockery.yml`
- файл появился в `mocks/`
- есть `New<Type>(t)`
- есть `EXPECT()`
- сгенерированный файл не редактируется вручную
