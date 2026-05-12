---
name: "x-bdd-browser"
description: "Применяй при написании или правке browser BDD: `features/` Gherkin-сценарии, `@browser` в monorepo, playwright-bdd поверх Playwright Test, TypeScript steps, fixtures и page objects"
compatibility: playwright-bdd, @playwright/test, TypeScript
---
# Browser BDD на Playwright

Этот skill — **канонический владелец** правил browser BDD-слоя про:
- `@browser` execution tag в monorepo/multi-channel проектах
- layout browser runner-а
- `playwright-bdd` поверх Playwright Test
- TypeScript step definitions
- fixtures и page objects для браузерных сценариев

Общий layout `.feature` файлов, naming и numbering сценариев задаёт `x-bdd-api`, потому что `features/` является общим каталогом Gherkin-спецификаций. Этот skill не переописывает правила `features/NN_epic/NN_story.feature`.

## Когда применять

- Добавляешь browser BDD runner.
- Пишешь или правишь TypeScript step definitions для browser BDD.
- Подключаешь `playwright-bdd`, Playwright fixtures, pages или browser reports.
- В monorepo работаешь со сценариями, помеченными `@browser`.
- Во frontend-only проекте работаешь с корневым BDD runner-ом `test/bdd/`.

Не применяй для:
- API BDD через Go/godog → `x-bdd-api`
- продуктового пути от PRD до готового `.feature` → `x-bdd-product-workflow`
- RGB-реализации готового `.feature` → `x-bdd-dev-workflow`
- mobile BDD → отдельный `x-bdd-mobile`, когда слой появится

## Core workflow

### 1. Определи тип проекта

| Тип проекта | Feature-файлы | Browser BDD runner |
|---|---|---|
| Monorepo | `features/NN_epic/NN_story.feature` | `frontend/test/bdd/` |
| Backend-only | `features/NN_epic/NN_story.feature` | Не применимо |
| Frontend-only | `features/NN_epic/NN_story.feature` | `test/bdd/` |

В monorepo `features/` может читаться несколькими runner-ами. Browser runner исполняет только сценарии с `@browser`.

В frontend-only проекте канал исполнения задан типом проекта, поэтому execution tags `@api`, `@browser`, `@mobile` не нужны: корневой `test/bdd/` исполняет все `features/**/*.feature`.

### 2. Держи спецификацию отдельно от runner-а

```text
{project-root}/
├── features/
│   └── 01_identity/
│       └── 01_email_login.feature
└── frontend/test/bdd/        # monorepo
    ├── bdd.config.ts
    ├── playwright.config.ts
    ├── steps_01_identity.ts
    ├── fixtures/
    │   └── app.fixture.ts
    ├── pages/
    │   └── login.page.ts
    └── support/
        └── world.ts
```

В frontend-only проекте runner живёт в корневом `test/bdd/`:

```text
{project-root}/
├── features/
│   └── 01_identity/
│       └── 01_email_login.feature
└── test/bdd/
    ├── bdd.config.ts
    ├── playwright.config.ts
    ├── steps_01_identity.ts
    ├── fixtures/
    ├── pages/
    └── support/
```

`.feature` файлы всегда живут в `features/NN_epic/`. Browser runner-директория владеет TypeScript-кодом, fixtures, pages и Playwright config, но не спецификацией.

### 3. Подключи playwright-bdd

`playwright-bdd` используется как Gherkin-слой поверх Playwright Test: сначала `bddgen` генерирует Playwright tests из `.feature`, затем `playwright test` запускает их обычным Playwright runner-ом.

Минимальная модель команд:

```bash
npx bddgen
npx playwright test
```

В `package.json` runner-а держи явные scripts:

```json
{
  "scripts": {
    "test:bdd": "bddgen && playwright test"
  }
}
```

Если в проекте есть `Taskfile`, добавь или обнови task только после проверки родительских/common tasks.

### 4. Настрой выбор сценариев

В monorepo browser runner должен читать общий `features/` и фильтровать `@browser`.

Концептуально:

```ts
export default defineBddConfig({
  paths: ['../../../features/**/*.feature'],
  tags: '@browser',
})
```

Во frontend-only проекте execution tag не нужен, поэтому runner читает все сценарии:

```ts
export default defineBddConfig({
  paths: ['../../features/**/*.feature'],
})
```

Путь к `features/` зависит от фактической глубины runner-а и расположения config-файла. Не копируй `.feature` в `test/bdd/` ради удобного glob-а.

### 5. Пиши steps как браузерную реализацию бизнес-шагов

Step definitions живут в runner-директории:

```text
frontend/test/bdd/steps_01_identity.ts
test/bdd/steps_01_identity.ts
```

Минимальный пример:

```ts
import { expect } from '@playwright/test'
import { createBdd } from 'playwright-bdd'

const { Given, When, Then } = createBdd()

Given('пользователь находится на странице входа', async ({ page }) => {
  await page.goto('/login')
})

When('пользователь входит с email {string} и паролем {string}', async ({ page }, email: string, password: string) => {
  await page.getByLabel('Email').fill(email)
  await page.getByLabel('Пароль').fill(password)
  await page.getByRole('button', { name: 'Войти' }).click()
})

Then('пользователь видит свой профиль', async ({ page }) => {
  await expect(page.getByRole('heading', { name: 'Профиль' })).toBeVisible()
})
```

Правила:
- шаг проверяет видимое браузерное поведение, а не внутреннее состояние page object;
- `Then` должен assertion-ом наблюдать UI, URL, network-visible result или browser state;
- `When` должен выполнять реальное пользовательское действие через Playwright;
- business steps остаются на языке пользователя; CSS selectors прячь внутри page objects только когда это улучшает читаемость.

### 6. Используй fixtures и pages без смешивания слоёв

`fixtures/` содержит test-owned окружение: browser context, test users, baseURL, auth state, backend seed через публичный API.

`pages/` содержит page objects для устойчивых UI-операций:
- locators;
- user actions;
- короткие ожидания видимого состояния.

Page object не должен становиться оракулом теста. Финальные assertions оставляй в step definitions или явно называемых assertion-методах, которые проверяют видимый UI через Playwright `expect`.

Если browser scenario требует seed-а, предпочитай публичный API или test fixture. Не ходи напрямую в DB из browser step, если это не отдельное согласованное исключение.

### 7. Границы с API BDD

Один business intent может иметь два сценарных канала в monorepo:

```gherkin
@api @browser
Scenario: 01_successful_email_login
```

API implementation проверяет тот же intent через публичный API (`x-bdd-api`), browser implementation — через браузер.

UI-технические сценарии в monorepo получают только `@browser`:

```gherkin
@browser
Scenario: 01A_login_form_validation_message
```

Во frontend-only проекте эти теги не нужны.

### 8. Антипаттерны

- `.feature` вне `features/NN_epic/`
- runner-owned feature files внутри `frontend/test/bdd/` или корневого `test/bdd/`
- дополнительный `features/` внутри runner-а: `frontend/test/bdd/features/`
- `@ui` или `@ui-only` вместо `@browser` в monorepo
- browser runner читает `backend/test/bdd/` или API step files
- API и browser steps живут в одном runner package
- step проверяет поле page object, которое сам же записал
- `Then` повторяет `When` вместо проверки наблюдаемого результата
- network mock подменяет именно то поведение, которое сценарий обещает проверить
- сценарий описывает layout/detail UI вместо пользовательского эффекта, если это не осознанный browser-only case

## Самопроверка

- `.feature` лежит в `features/NN_epic/NN_story.feature`.
- В monorepo browser-сценарии помечены `@browser`.
- Во frontend-only проекте execution tags не добавлены без отдельной причины.
- Browser runner лежит в `frontend/test/bdd/` для monorepo или `test/bdd/` для frontend-only.
- `playwright-bdd` запускается через Playwright Test runner.
- Steps, fixtures и pages не импортируют API BDD Go-код и не читают runner-owned `.feature`.
- Assertions проверяют видимое браузерное поведение.
