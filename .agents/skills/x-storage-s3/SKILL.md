---
name: "x-storage-s3"
description: "Паттерны S3-совместимого хранилища (MinIO, Yandex Cloud, AWS S3): CRUD, range, presigned URLs, multipart"
compatibility: git.korputeam.ru/newbackend/adapters
---
# Паттерны S3/MinIO хранилища

## Базовые операции
```go
cfg := minio.Config{
    Endpoint:  "localhost:9000",
    AccessKey: "minioadmin",
    SecretKey: "minioadmin",
    Secure:    false,
}
storage, err := minio.NewDefault(cfg)
defer storage.Close()

// Записать объект
err = storage.Put(ctx, "my-bucket", "my-key", bytes.NewReader(data), &storage.PutOptions{
    ContentType: "application/json",
    Metadata:    map[string]string{"author": "user1"},
})

// Получить объект
reader, info, err := storage.Get(ctx, "my-bucket", "my-key")
defer reader.Close()

// Проверить существование
exists, err := storage.Exists(ctx, "my-bucket", "my-key")

// Удалить объект
err = storage.Delete(ctx, "my-bucket", "my-key")
```

## Range-запросы (частичное чтение)
```go
// GetFileHeader читает первые 4096 байт через range-запрос (opts.SetRange(0, 4095))
// Полезно для определения типа файла без скачивания целиком
header, err := storage.GetFileHeader(ctx, "my-bucket", "large-file.bin")
if err != nil {
    return err
}

fileType := http.DetectContentType(header)
```

## Presigned URLs
```go
// Генерация временной ссылки для прямого доступа клиента (минуя сервер)
url, err := storage.GetPresignedURL(ctx, "my-bucket", "my-key", &storage.PresignedURLOptions{
    Method: "GET",
    Expiry: 15 * time.Minute,
})
```

## Multipart Upload (файлы > 5МБ)
```go
upload, err := storage.CreateMultipartUpload(ctx, "bucket", "large-file.bin", nil)

parts := make([]storage.UploadedPart, 0)
for i := 0; i < numParts; i++ {
    part, err := storage.UploadPart(ctx, "bucket", "large-file.bin", upload.UploadID,
        int32(i+1), partReader)
    if err != nil {
        storage.AbortMultipartUpload(ctx, "bucket", "large-file.bin", upload.UploadID)
        return err
    }
    parts = append(parts, *part)
}

info, err := storage.CompleteMultipartUpload(ctx, "bucket", "large-file.bin",
    upload.UploadID, &storage.CompleteMultipartUploadOptions{Parts: parts})
```

## Список объектов
```go
result, err := storage.List(ctx, "my-bucket", &storage.ListOptions{
    Prefix:    "photos/2024/",
    Recursive: true,
    MaxKeys:   1000,
})

for _, obj := range result.Objects {
    fmt.Printf("%s (%d bytes)\n", obj.Key, obj.Size)
}
```

## Заметки
- Именование span: `S3.операция` (например, `S3.GetFileHeader`, `S3.Put`, `S3.Get`)
- Все операции поддерживают отмену контекста и трейсинг OpenTelemetry
- Multipart upload рекомендуется для файлов > 5МБ
- Presigned URLs для прямого доступа клиента — чтобы не проксировать через сервер
