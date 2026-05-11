---
name: "x-troubleshooting"
description: "Краткий runbook для первичной диагностики test/env/service проблем; основная ценность — локальный diagnostic script"
---

# Диагностика

Этот skill понижен до runbook-уровня.

Используй его, когда нужно быстро снять первичный симптом:
- окружение и `.env`
- доступность Docker и внешних сервисов
- порты, readiness и timeout
- расхождение между process-wide state и ожиданиями теста
- проблемы API BDD runner-а → см. `x-bdd-api`
- проблемы browser BDD runner-а → см. `x-bdd-browser`
- в monorepo проблемы тегов/поиска сценариев проверяй через `features/` и tag filters

Главный локальный артефакт:

```bash
bash .agents/skills/x-troubleshooting/scripts/collect-diagnostics.sh 5432 5672 9000 9092
```

Полную стратегию диагностики строй по контексту конкретной задачи, а не по длинному универсальному туториалу.
