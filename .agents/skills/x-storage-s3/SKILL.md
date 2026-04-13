---
name: "x-storage-s3"
description: "Применяй когда работаешь с S3-совместимым хранилищем через `../adapters/storage/minio`: выбор между `Put/Get/Delete`, `GetFileHeader`, presigned URL, multipart upload и `storage` error helpers"
compatibility: ../adapters
---

# S3-совместимое хранилище

## Когда применять

Используй этот скилл, когда работаешь с MinIO, Yandex Cloud Storage, AWS S3 или другим S3-compatible storage через `storage/minio`.

Не применяй для:
- локальной файловой системы
- tiny utility files, которые не требуют отдельного storage adapter

## Workflow

### 1. Выбери конструктор

Простой путь:

```go
storage, err := minio.NewDefault(cfg)
if err != nil {
    return err
}
defer func() {
    if err := storage.Close(); err != nil {
        // обработка
    }
}()
```

### 2. Выбери операцию по задаче

| Нужно | Операция |
|---|---|
| записать объект | `Put` |
| получить объект целиком/потоком | `Get` |
| проверить наличие | `Exists` |
| удалить | `Delete` |
| прочитать только начало файла | `GetFileHeader` |
| дать клиенту прямой доступ | `GetPresignedURL` |
| загрузить большой файл по частям | multipart API |
| получить список | `List` |

### 3. Обрабатывай `Get` и multipart аккуратно

Для `Get`:
- всегда закрывай `io.ReadCloser`
- ошибку `Close()` не игнорируй

Для multipart:
- при падении части вызывай `AbortMultipartUpload`
- собирай `UploadedPart` и только потом делай `CompleteMultipartUpload`

## Типовые паттерны

Для короткой матрицы выбора операции см. `references/operation-selection.md`.

### `GetFileHeader`

Используй для определения типа файла без скачивания всего объекта:

```go
header, err := storage.GetFileHeader(ctx, bucket, key)
fileType := http.DetectContentType(header)
```

### Presigned URL

Используй, когда клиент должен читать или писать объект напрямую, минуя ваш backend:

```go
url, err := storage.GetPresignedURL(ctx, bucket, key, &storage.PresignedURLOptions{
    Method: "GET",
    Expiry: 15 * time.Minute,
})
```

### Multipart

Используй для больших объектов и потоковой загрузки:

```go
upload, err := storage.CreateMultipartUpload(ctx, bucket, key, nil)
// UploadPart...
// CompleteMultipartUpload...
```

## Ошибки

Если проверяешь семантику ошибки, используй хелперы из `storage`:

```go
if storage.IsNotFound(err) {
    // объект не найден
}
```

## Практические правила

- если bucket пустой, адаптер может использовать `DefaultBucket`
- все операции поддерживают `context.Context`
- tracing и логирование уже встроены в адаптер

## Не делай

- не проксируй через backend большие клиентские скачивания, если достаточно presigned URL
- не забывай `AbortMultipartUpload` на error path
- не проверяй not-found через текст ошибки, если доступен helper
