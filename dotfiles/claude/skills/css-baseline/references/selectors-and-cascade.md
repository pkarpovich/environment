# Selectors and cascade

## `:has()` - parent and sibling selectors

`:has(...)` matches an element when its argument matches a descendant or sibling. It's the long-awaited "parent selector".

```css
/* Card layout depends on whether it has an image */
.card { display: grid; grid-template-columns: 1fr; }
.card:has(img) { grid-template-columns: 8rem 1fr; }

/* Form is invalid if any input failed validation */
.form:has(:user-invalid) .submit { opacity: 0.5; pointer-events: none; }

/* Sibling-aware: label following a checked input */
input[type="checkbox"]:checked + label { font-weight: 600; }

/* Subtree-aware: panel with no content */
.panel:not(:has(*)) { display: none; }

/* Multi-condition */
.toolbar:has(.search):has(.filter) { gap: var(--space-lg); }
```

`:has()` accepts any selector list, including complex selectors with combinators.

### Common patterns `:has()` replaces

| Old pattern | New |
|---|---|
| JS adds `.has-image` class to card when image renders | `.card:has(img)` |
| JS adds `.is-invalid` class to form when validation fails | `.form:has(:user-invalid)` |
| JS adds `.has-children` to nav items with submenus | `li:has(ul)` |
| BEM modifier `.card--with-footer` | `.card:has(.card__footer)` |

## `@scope` - component isolation

`@scope` bounds selectors to a region of the DOM without specificity wars. Two forms:

```css
/* Open scope - styles cascade down from the root */
@scope (.card) {
  h2 { font-size: var(--font-size-h2); }
  a { color: var(--color-accent); }
}

/* Bounded scope - "donut hole", styles don't leak past the boundary */
@scope (.card) to (.card-body, .nested-component) {
  h2 { font-size: var(--font-size-h2); }
}
```

The "donut hole" form is critical: it lets you style a card's children without touching nested components or sub-cards inside the body.

### Implicit `:scope`

Inside `@scope`, bare `&` or `:scope` refers to the scope root:

```css
@scope (.card) {
  & { padding: var(--space-md); }
  & > header { font-weight: 600; }
  :scope > footer { color: var(--color-text-muted); }
}
```

### Scope proximity over specificity

When two scoped rules match, the rule whose scope root is **closest** to the element wins, regardless of specificity. This is exactly the rule everyone wishes specificity worked by.

```css
@scope (.theme-light) { a { color: blue; } }
@scope (.theme-dark)  { a { color: cornflowerblue; } }

/* If both .theme-light and .theme-dark are ancestors, the closer one wins. */
```

### When to use `@scope` vs CSS Modules

- **Plain CSS**: use `@scope` for component isolation.
- **CSS Modules**: modules already scope class names structurally. `@scope` is rarely needed inside `.module.css`. Use `@scope` for non-class isolation needs (element selectors, descendant rules).

## `@layer` - explicit cascade order

`@layer` defines named layers in a fixed order. Later layers override earlier ones, regardless of selector specificity inside.

```css
@layer reset, base, components, utilities;

@layer reset {
  *, *::before, *::after { box-sizing: border-box; margin: 0; }
}

@layer base {
  body { font-family: system-ui, sans-serif; line-height: 1.6; }
}

@layer components {
  .button { padding: var(--space-sm) var(--space-md); }
}

@layer utilities {
  .hidden { display: none; }
  .text-center { text-align: center; }
}
```

Rules **outside any layer** beat all layered rules. Rules in a **later layer** beat all rules in earlier layers, even high-specificity ones.

### Why this kills `!important`

`!important` exists because pre-`@layer` CSS had no way to say "this utility class should win". Now utilities live in the last layer and win by ordering. Reserve `!important` for nothing.

### Nested layers

```css
@layer components {
  @layer base, themed;

  @layer base {
    .button { background: var(--color-surface); }
  }

  @layer themed {
    .button { background: var(--color-accent); }
  }
}
```

Inside `components`, `themed` beats `base`. But `components` as a whole still beats `reset` and `base` (the top-level layer above it).

### Third-party CSS in a layer

```css
@import url('https://cdn.example.com/lib.css') layer(third-party);

@layer third-party, reset, base, components, utilities;
```

Third-party styles go in their own layer, declared **first** in the layer order so your own styles always win.

## Native CSS Nesting

Use `&` for the parent reference. Use it explicitly when nesting:

```css
.card {
  padding: var(--space-md);

  & h2 { margin-block-end: var(--space-sm); }   /* descendant */
  &:hover { background: var(--color-surface-hover); }
  &.feature { background: var(--color-accent-tint); }
  &.compact { padding: var(--space-xs); }

  @container (inline-size > 30rem) {
    padding: var(--space-lg);
  }

  @media (prefers-reduced-motion: reduce) {
    transition: none;
  }
}
```

### Nesting rules

- **`&` is required** when the nested selector starts with an element type (`& h2`, not `h2`). Without `&`, the parser would think `h2` is a property.
- **Compound selectors** can be written without `&` if they start with a class, ID, attribute, or pseudo (`.feature {}`, `:hover {}` work nested). Adding `&` is still preferred for readability.
- **At-rules can be nested**: `@container`, `@media`, `@supports`, `@layer` all work inside a rule. The nested at-rule re-evaluates the parent selector in context.
- **Nesting doesn't inherit specificity tricks** - the parent is just a literal substitution.

### Sibling nesting

```css
.card {
  & + & { margin-block-start: var(--space-md); }
}
```

## Specificity hygiene

Even with nesting and layers, keep selectors flat:

```css
/* Good */
.card { /* ... */ }
.card-title { /* ... */ }
.card.compact { /* ... */ }

/* Avoid */
.section .container .card .card-body .card-title { /* ... */ }
```

Deep chains aren't needed when `@scope`/`@layer`/CSS Modules already handle isolation. Each chain link adds specificity, making future overrides harder.

## Pseudo-classes worth knowing

| Pseudo | Purpose |
|---|---|
| `:user-invalid` / `:user-valid` | Like `:invalid`/`:valid` but only after user interaction, so empty fields don't look broken on page load |
| `:focus-visible` | Only matches keyboard focus, not mouse focus. Use for outline styles. |
| `:focus-within` | Matches element when any descendant has focus |
| `:placeholder-shown` | Input is currently showing its placeholder |
| `:is(...)` / `:where(...)` | Selector list grouping. `:where()` has zero specificity (use for resets) |
| `:popover-open` | A `popover` element is currently open |
| `:open` | Element with `[open]` attribute (e.g. `<details>`, `<dialog>`) |

```css
input:user-invalid { border-color: var(--color-danger); }
.card:focus-within { outline: 2px solid var(--color-accent); }

:where(h1, h2, h3) { text-wrap: balance; }
```
