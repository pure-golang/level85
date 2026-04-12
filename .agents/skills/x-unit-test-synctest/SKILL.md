---
name: x-unit-test-synctest
description: "Применяй когда тестируемый код использует time.Sleep/Ticker, запускает горутины или зависит от тайминга"
compatibility: Go 1.25+ (стандартная библиотека, GOEXPERIMENT не нужен)
---

## Базовая структура

```go
func TestSomething(t *testing.T) {
    t.Parallel()

    ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
    t.Cleanup(cancel)

    // synctest.Test передаёт *testing.T внутрь изоляции
    synctest.Test(t, func(t *testing.T) {
        // Arrange
        svc := New(...)

        // Act — time.Sleep здесь мгновенный, продвигает виртуальные часы
        svc.DoSomething(ctx)
        synctest.Wait() // ждёт пока все горутины внутри sandbox заблокируются

        // Assert
        assert.Equal(t, expected, svc.State())

        cancel() // завершение контекста внутри synctest.Test
    })
}
```

## Ключевые правила

- `synctest.Test(t, f)` создаёт изолированную среду с виртуальными часами; `t` передаётся внутрь — `t.Cleanup`, `t.Log` и другие методы работают корректно
- `time.Sleep` внутри `synctest.Test` — не блокирует реально, продвигает виртуальное время
- `synctest.Wait()` — ждёт пока все горутины внутри sandbox перейдут в заблокированное состояние
- `context.WithTimeout` задаёт реальный таймаут защиты теста от зависания
- Горутины, запущенные внутри `synctest.Test`, должны завершаться до выхода из него
- Запись в канал, созданный **вне** `synctest.Test`, вызывает панику — каналы и таймеры создавать только внутри изоляции

## Пример: проверка тайминга

```go
synctest.Test(t, func(t *testing.T) {
    svc := New()
    start := time.Now()

    svc.WaitForNext(ctx, id) // первый вызов — без задержки
    assert.Equal(t, 0*time.Second, time.Since(start))

    svc.WaitForNext(ctx, id) // второй — ждёт N секунд (виртуально)
    assert.Equal(t, 3*time.Second, time.Since(start))

    cancel()
})
```

## Пример: проверка горутин и каналов

```go
synctest.Test(t, func(t *testing.T) {
    results := make(chan string, 1)

    go func() {
        time.Sleep(1 * time.Second)
        results <- "done"
    }()

    synctest.Wait()

    assert.Equal(t, "done", <-results)
})
```

## Пример: несколько подписчиков / конкурентные вызовы

```go
synctest.Test(t, func(t *testing.T) {
    svc := New(...)

    const n = 3
    var counts [n]int64
    for i := range n {
        svc.Subscribe(func(event Event) {
            atomic.AddInt64(&counts[i], 1)
        })
    }

    svc.Emit(someEvent)
    synctest.Wait()

    for i := range n {
        assert.Equal(t, int64(1), atomic.LoadInt64(&counts[i]))
    }

    cancel()
})
```

## Смежные скиллы

- `x-testing-conventions` — базовые соглашения по тестам
