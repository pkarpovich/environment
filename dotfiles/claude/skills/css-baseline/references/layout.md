# Layout

## Grid as the default page layout

Three-column "holy grail" with content max-width and gutter columns:

```css
.page {
  display: grid;
  grid-template-columns:
    [full-start] minmax(1rem, 1fr)
    [content-start] min(70ch, 100%) [content-end]
    minmax(1rem, 1fr) [full-end];
  row-gap: var(--space-lg);
}

.page > * { grid-column: content; }
.page > .bleed { grid-column: full; }
```

This pattern handles full-bleed sections (images, hero, footer) without nested wrappers.

## Auto-fit grid (cards, tiles)

```css
.cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(min(20rem, 100%), 1fr));
  gap: var(--space-md);
}
```

The `min(20rem, 100%)` prevents the minimum from overflowing on narrow viewports.

## Subgrid for nested alignment

When cards have variable internal content (title + image + body + footer) but must align across the grid:

```css
.cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(20rem, 1fr));
  gap: 1rem;
}

.card {
  display: grid;
  grid-template-rows: subgrid;
  grid-row: span 4;
  gap: 0.5rem;
}
```

Now title, image, body, footer all align to identical horizontal lines across all cards.

## Flexbox for one-dimensional layout

```css
.toolbar {
  display: flex;
  gap: var(--space-sm);
  align-items: center;
}

.toolbar > .spacer { flex: 1; }
```

For wrap-or-stack toolbars:

```css
.actions {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-sm);
}

.actions > * { flex: 1 1 min(15rem, 100%); }
```

Each action grows to fill, but wraps when it can't be at least 15rem wide.

## Centering

```css
.centered {
  display: grid;
  place-items: center;
  min-block-size: 100dvh;
}
```

Or with flex:

```css
.centered { display: flex; place-content: center; }
```

`place-items` is shorthand for `align-items + justify-items`. `place-content` is for `align-content + justify-content`.

## Intrinsic sizing keywords

| Keyword | Meaning |
|---|---|
| `min-content` | Smallest size the content can take without overflow (longest word for text) |
| `max-content` | Size the content would take if given infinite room |
| `fit-content` | Equivalent to `min(max-content, max(min-content, available))` |
| `fit-content(20rem)` | Like fit-content but capped at 20rem |
| `auto` | Browser-default (usually max-content for flex/grid items, varies elsewhere) |

Use cases:

```css
/* Button is as wide as its label, no more */
button { inline-size: fit-content; }

/* Sidebar is as wide as its widest item, capped at 20rem */
.sidebar { inline-size: fit-content(20rem); }

/* Tooltip wraps long content but is no wider than its content */
.tooltip { inline-size: max-content; max-inline-size: 20rem; }
```

## Logical properties

Use the logical equivalents universally. Physical names only appear when explicitly tied to viewport orientation (e.g. `transform: translateX()` is fine because X is a literal axis, but `margin-left` is not).

| Physical | Logical |
|---|---|
| `width` | `inline-size` |
| `height` | `block-size` |
| `max-width` | `max-inline-size` |
| `margin-left` / `margin-right` | `margin-inline-start` / `margin-inline-end` (or shorthand `margin-inline`) |
| `margin-top` / `margin-bottom` | `margin-block-start` / `margin-block-end` (or shorthand `margin-block`) |
| `padding-left` etc. | `padding-inline-start` etc. (and shorthands) |
| `border-left` | `border-inline-start` |
| `border-radius` corners | `border-start-start-radius`, `border-end-end-radius`, etc. |
| `left` / `right` / `top` / `bottom` | `inset-inline-start`, `inset-block-end`, etc. (or shorthand `inset-inline`, `inset-block`, `inset`) |
| `text-align: left/right` | `text-align: start/end` |

## Viewport units

| Unit | Use |
|---|---|
| `dvh` / `dvw` | Dynamic - accounts for browser chrome that appears/disappears (mobile address bar). Default choice for full-viewport sizing. |
| `svh` / `svw` | Small - viewport when all UI is shown (smallest possible). Use when you must guarantee content fits even with browser chrome visible. |
| `lvh` / `lvw` | Large - viewport when all UI is hidden (largest possible). Rarely the right choice. |
| `vh` / `vw` | Static - the legacy unit. Avoid - causes the "100vh too tall" bug on mobile when chrome collapses. |
| `vi` / `vb` | Inline / block axis equivalents of `vw` / `vh`. Use for writing-mode-aware sizing. |

```css
.hero { block-size: 100dvh; }
.modal { max-block-size: calc(100svh - 4rem); }
```

## Absolute positioning rules

`position: absolute` is **only** for:
- Tooltips, popovers, dropdowns (paired with anchor positioning)
- Overlay decorations (badges, icons placed relative to a parent)
- Visually-hidden elements (`.sr-only`)

It is **never** for placing structural elements (sidebars, cards, hero content). Use Grid for those.
