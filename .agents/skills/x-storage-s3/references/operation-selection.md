# Выбор операции S3

## Что выбрать

| Задача | Операция |
|---|---|
| сохранить объект | `Put` |
| прочитать объект | `Get` |
| проверить наличие | `Exists` |
| удалить | `Delete` |
| определить тип файла без полного скачивания | `GetFileHeader` |
| дать клиенту временный прямой доступ | `GetPresignedURL` |
| загрузить большой файл частями | multipart API |
| перечислить объекты | `List` |

## Presigned URL

Выбирай, когда:
- backend не должен проксировать трафик
- клиент может ходить в storage напрямую
- доступ нужно ограничить по времени

## Multipart

Выбирай, когда:
- файл большой
- загрузка идёт кусками
- нужен контролируемый abort/retry

Для файлов заметно больше `5MB` multipart обычно безопаснее, чем один большой `Put`.

Всегда проектируй error path с `AbortMultipartUpload`.

## Стартовый конфиг

```go
cfg := minio.Config{
    Endpoint:  "localhost:9000",
    AccessKey: "minioadmin",
    SecretKey: "minioadmin",
    Secure:    false,
}
```

## Базовые операции

### `Put`

```go
err := storage.Put(ctx, bucket, key, bytes.NewReader(data), &storage.PutOptions{
    ContentType: "application/json",
    Metadata: map[string]string{
        "source": "api",
    },
})
```

### `Get`

```go
reader, info, err := storage.Get(ctx, bucket, key)
if err != nil {
    return err
}

data, readErr := io.ReadAll(reader)
closeErr := reader.Close()
if readErr != nil {
    return readErr
}
if closeErr != nil {
    return fmt.Errorf("failed to close object reader: %w", closeErr)
}

_ = info
_ = data
```

### `Exists` и `Delete`

```go
exists, err := storage.Exists(ctx, bucket, key)
if err != nil {
    return err
}
if !exists {
    return nil
}

if err := storage.Delete(ctx, bucket, key); err != nil {
    return err
}
```

### `List`

```go
result, err := storage.List(ctx, bucket, &storage.ListOptions{
    Prefix:    "photos/2026/",
    Recursive: true,
    MaxKeys:   1000,
})
if err != nil {
    return err
}

for _, obj := range result.Objects {
    _ = obj.Key
}
```

## Полный multipart flow

```go
upload, err := storage.CreateMultipartUpload(ctx, bucket, key, nil)
if err != nil {
    return err
}

parts := make([]storage.UploadedPart, 0, len(chunks))
for i, chunk := range chunks {
    part, err := storage.UploadPart(ctx, bucket, key, upload.UploadID, int32(i+1), bytes.NewReader(chunk))
    if err != nil {
        if abortErr := storage.AbortMultipartUpload(ctx, bucket, key, upload.UploadID); abortErr != nil {
            return errors.Join(err, abortErr)
        }
        return err
    }
    parts = append(parts, *part)
}

_, err = storage.CompleteMultipartUpload(ctx, bucket, key, upload.UploadID, &storage.CompleteMultipartUploadOptions{
    Parts: parts,
})
if err != nil {
    if abortErr := storage.AbortMultipartUpload(ctx, bucket, key, upload.UploadID); abortErr != nil {
        return errors.Join(err, abortErr)
    }
    return err
}
```
