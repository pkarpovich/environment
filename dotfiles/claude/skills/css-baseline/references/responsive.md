# Responsive

## Three layers of responsive

Modern responsive design has three concerns, each with its own tool:

| Concern | Tool |
|---|---|
| **Component layout** (this card needs to switch from stacked to side-by-side at some component width) | Container queries |
| **Page layout** (the sidebar collapses, navigation moves to a hamburger) | Media queries (viewport) |
| **User preferences** (reduce motion, dark mode, high contrast, pointer type) | Media queries (`prefers-*`) |
| **Fluid sizing within a range** (font-size grows smoothly from 16px to 22px) | `clamp()` |

Container queries are the default for component-level responsive. Reach for viewport media queries only when the change is genuinely about the page, not the component.

## clamp() for fluid values

`clamp(MIN, PREFERRED, MAX)` returns `PREFERRED` clipped to `[MIN, MAX]`. Use it whenever a value should scale smoothly within bounds.

```css
--font-size-h1: clamp(2rem, 4vw + 1rem, 4rem);
--space-section: clamp(3rem, 8vw, 8rem);
.card { padding: clamp(1rem, 4cqi, 2rem); }
```

The preferred value should always include a viewport-relative or container-relative unit (`vw`, `vi`, `cqi`, etc.) plus an optional `rem` offset. A `clamp()` with a static preferred value is just `min(max(...))` with extra steps.

### Anchoring with `+ 1rem`

The preferred value should include a rem floor (`+ 1rem` or similar) plus a viewport/container component. Without the rem floor, the value collapses to near-zero at small viewports and ignores user zoom prefs.

```css
/* Wrong - no rem floor, breaks user zoom */
font-size: clamp(1rem, 2vw, 2rem);

/* Right - rem floor anchors the value to user-default */
font-size: clamp(1rem, 1rem + 1vw, 2rem);
```

For font-size specifically, see `typography.md` - it has the full Utopia formula for deriving the preferred value mathematically and notes on respecting user agency.

## When media queries are still right

```css
/* Page-level: nav switches to hamburger */
@media (max-width: 48rem) {
  .site-nav { display: none; }
  .nav-toggle { display: block; }
}

/* User preference: reduced motion */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}

/* User preference: pointer type */
@media (hover: hover) {
  .button:hover { background: var(--color-accent-hover); }
}

@media (any-pointer: coarse) {
  /* Larger tap targets on touch */
  .icon-button { min-block-size: 2.75rem; min-inline-size: 2.75rem; }
}
```

`prefers-color-scheme` is **not** in this list - use `light-dark()` and `color-scheme` instead. See `colors.md`.

## When container queries are right

Anywhere a component has multiple plausible layouts based on the space it's given. The component shouldn't know whether it's in a sidebar, a hero, or a footer; it just queries its own container.

```css
.product-card-list {
  container-type: inline-size;
}

.product-card {
  display: grid;
  grid-template-columns: 1fr;
  gap: var(--space-sm);
}

@container (inline-size > 24rem) {
  .product-card {
    grid-template-columns: 8rem 1fr;
  }
}

@container (inline-size > 48rem) {
  .product-card {
    grid-template-columns: 12rem 1fr auto;
  }
}
```

See `container-queries.md` for the full reference.

## RTL and writing modes

Logical properties handle RTL automatically. The only manual concern is direction-tied iconography (chevrons, arrows). Use logical CSS where possible:

```css
.back-arrow {
  /* Auto-flips in RTL because translateX is overridden by [dir] */
}

[dir="rtl"] .back-arrow {
  transform: scaleX(-1);
}
```

Or use a logical-aware approach with `rotate` (which inherits writing direction less consistently - check per browser).

## Don't break zoom

Never use `font-size` in `px` for body copy. Users who zoom expect 1em to scale with their browser setting. Use `rem` for typography.

Never use `user-scalable=no` or `maximum-scale=1` in the viewport meta tag - it breaks accessibility.

```html
<!-- Right -->
<meta name="viewport" content="width=device-width, initial-scale=1">

<!-- Wrong, do not write -->
<meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
```

## Responsive images and grids on very large screens

On 4K+ displays, content scaled by raw `vw` becomes uncomfortable to read. Cap fluid scales at sensible maxima:

```css
:root {
  --content-max: 75ch;
  --gutter: clamp(1rem, 4vw, 4rem);
}

.page {
  display: grid;
  grid-template-columns:
    [full-start] var(--gutter)
    [content-start] minmax(0, var(--content-max)) [content-end]
    var(--gutter) [full-end];
  justify-content: center;
}
```

Hero images on very large screens: use `object-fit` and limit the wrapper height:

```css
.hero img {
  inline-size: 100%;
  block-size: clamp(20rem, 60dvh, 50rem);
  object-fit: cover;
  object-position: center;
}
```
