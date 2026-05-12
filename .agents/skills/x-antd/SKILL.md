---
name: "x-antd"
description: "Применяй при подключении, обновлении или кастомизации Ant Design во frontend: AntD v6, Tailwind CSS v4, cascade layers, scoped `.ant-*` overrides через `@layer components` и локальные Tailwind utilities в JSX"
---

# Ant Design + Tailwind CSS

Этот skill — канонический владелец проектных соглашений по кастомизации AntD через Tailwind CSS.

## Когда применять

- подключаешь или обновляешь AntD во `frontend`
- меняешь `frontend/src/styles.css`, `ThemeProvider`, `vite.config.ts` в части AntD/Tailwind
- кастомизируешь AntD-компоненты, их popup/overlay или внутренний DOM
- ревьюишь CSS/TSX на предмет `style={{ ... }}`, `ConfigProvider.theme`, `.ant-*` и длинных utility-строк

## База

- Целевой стек: AntD v6 + Tailwind CSS v4.
- AntD CSS подключай в `frontend/src/styles.css`, не в `main.tsx`.
- CSS layers держи в порядке: `theme`, `base`, `antd`, `components`, `utilities`.
- `ConfigProvider.theme` не используй для брендовой кастомизации. Допустимы только режимные настройки вроде `algorithm` и `zeroRuntime`.
- Dark class ставь на `document.documentElement`, чтобы `dark:*` работал и для AntD portals.

Минимальный CSS-каркас:

```css
@layer theme, base, antd, components, utilities;

@import "tailwindcss/theme.css" layer(theme);
@import "tailwindcss/preflight.css" layer(base);
@import "antd/dist/reset.css" layer(base);
@import "antd/dist/antd.css" layer(antd);
@import "tailwindcss/utilities.css" layer(utilities);

@custom-variant dark (&:where(.dark, .dark *));
```

## Граница ответственности

`@layer components` используй только для scoped overrides внутреннего DOM AntD: `.project-root .ant-*`, `.project-root > .ant-*` и близкие случаи, когда className/slot API не хватает.

Локальное применение живёт utility-классами в JSX:
- позиционирование конкретного экземпляра
- внешний отступ в конкретном layout
- ширина/колонки в конкретной сетке
- `flex`/`grid`-композиция вокруг компонента
- одноразовый вид AntD-компонента, если он используется в одном месте

Не заводи `.auth-card`, `.profile-card`, `.app-header` и похожие CSS-классы ради одного использования. Такие стили пиши прямо в `className`.

## Внутренний DOM AntD

Для кастомизации внутренних `.ant-*` узлов всегда задавай проектный root-класс и scoped selector.

```tsx
<Modal rootClassName="card-detail-window" />
```

```css
@layer components {
  .card-detail-window > .ant-modal-content {
    @apply overflow-auto rounded-[3px] bg-[var(--ds-surface-overlay,#f4f5f7)] p-0 !important;
  }
}
```

Правила:
- `.ant-*` без проектного scope запрещён
- overlay-компонентам давай `rootClassName`
- slot API (`classNames`, `styles`) используй, когда он точнее scoped selector
- `!important` ставь только когда AntD реально перебивает свойство

## Запреты

- Не писать глобальные `.ant-btn`, `.ant-card`, `.ant-layout` и другие `.ant-*`.
- Не класть в `@layer components` одноразовые классы без `.ant-*` override.
- Не использовать Less-переменные AntD.
- Не добавлять брендовые значения в `ConfigProvider.theme.token` и `ConfigProvider.theme.components`.
- Не использовать `style={{ ... }}` для статического внешнего вида.
