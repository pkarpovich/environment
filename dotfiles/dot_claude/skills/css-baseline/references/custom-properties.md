# Custom properties (CSS variables)

## Two kinds of custom properties

| Kind | Naming convention | Scope | Example |
|---|---|---|---|
| **Design tokens** (global) | semantic: `--color-accent`, `--space-md`, `--font-size-h1` | `:root` or theme-scope | `--color-bg: oklch(98% 0.01 250);` |
| **Component locals** | descriptive of the role inside the component: `--card-padding`, `--button-gap` | the component selector | `.card { --card-padding: var(--space-md); padding: var(--card-padding); }` |

Tokens are the API of your design system. Locals are how a component uses tokens (and lets parents override).

## Token taxonomy

Two layers: primitives and semantics. Components reference semantic names, not primitives.

```css
:root {
  /* Primitives - the raw scale */
  --blue-50: oklch(98% 0.02 250);
  --blue-100: oklch(95% 0.04 250);
  --blue-500: oklch(60% 0.18 250);
  --blue-900: oklch(25% 0.10 250);

  --gray-50: oklch(98% 0.005 250);
  --gray-500: oklch(60% 0.01 250);
  --gray-900: oklch(15% 0.01 250);

  /* Semantics - what components reference */
  color-scheme: light dark;
  --color-bg: light-dark(var(--gray-50), var(--gray-900));
  --color-text: light-dark(var(--gray-900), var(--gray-50));
  --color-accent: light-dark(var(--blue-500), var(--blue-100));
  --color-on-accent: light-dark(var(--blue-50), var(--blue-900));
}
```

A new theme = swap the semantic layer. Components don't change.

## Fallbacks via `var(--x, fallback)`

```css
.button {
  background: var(--button-bg, var(--color-accent));
  padding: var(--button-padding, var(--space-sm) var(--space-md));
}
```

The fallback runs when `--button-bg` is unset (not when it's invalid). A parent can override `--button-bg` to specialise the component without redeclaring rules.

## `@property` for typed custom properties

Native custom properties have no type and don't animate. `@property` adds both:

```css
@property --tilt-angle {
  syntax: '<angle>';
  inherits: false;
  initial-value: 0deg;
}

.card {
  transform: rotate(var(--tilt-angle));
  transition: --tilt-angle 200ms ease;
}

.card:hover { --tilt-angle: 6deg; }
```

### When to use `@property`

- **Animatable custom properties** (gradients, transforms, colors that animate via `transition`).
- **Type-checked tokens** that should reject invalid values (e.g. a `--radius` token that must be a `<length>`).
- **Initial values for unset locals** (avoids needing fallback in `var()` everywhere).

```css
@property --gradient-stop {
  syntax: '<percentage>';
  inherits: false;
  initial-value: 0%;
}

.progress {
  background: linear-gradient(to right,
    var(--color-accent) var(--gradient-stop),
    var(--color-surface) var(--gradient-stop));
  transition: --gradient-stop 300ms ease;
}
```

### `syntax` values

| Syntax | Accepts |
|---|---|
| `'*'` | Anything (no type-check, no animation) |
| `'<length>'` | `1px`, `1em`, `calc(...)` |
| `'<percentage>'` | `50%` |
| `'<length-percentage>'` | either |
| `'<number>'` | `1.5`, `0` |
| `'<integer>'` | `1`, `5` |
| `'<color>'` | any color function |
| `'<image>'` | `url(...)`, gradients |
| `'<angle>'` | `45deg`, `1turn`, `1rad` |
| `'<time>'` | `300ms`, `0.5s` |

Multiple types: `'<length> \| <percentage>'`.

### `inherits`

`true` lets child elements pick up the value. `false` (typical for component-local properties) keeps the property tied to the declaring element.

## Patterns

### Component API via locals

```css
.card {
  --card-padding: var(--space-md);
  --card-gap: var(--space-sm);
  --card-bg: var(--color-surface);

  padding: var(--card-padding);
  gap: var(--card-gap);
  background: var(--card-bg);
}

/* Specialised variant overrides locals, not rules */
.card.compact { --card-padding: var(--space-xs); --card-gap: var(--space-2xs); }
.card.feature { --card-bg: var(--color-accent-tint); }
```

The variant doesn't restate `padding`/`background`/`gap` rules. It only updates the inputs.

### Runtime updates via JS

```js
element.style.setProperty('--tilt-angle', `${angle}deg`);
```

Combined with `@property`, this animates smoothly.

### Computed values via calc()

```css
:root {
  --space-base: 0.25rem;
  --space-2xs: calc(var(--space-base) * 1);   /* 0.25rem */
  --space-xs:  calc(var(--space-base) * 2);   /* 0.5rem */
  --space-sm:  calc(var(--space-base) * 3);   /* 0.75rem */
  --space-md:  calc(var(--space-base) * 4);   /* 1rem */
  --space-lg:  calc(var(--space-base) * 6);   /* 1.5rem */
  --space-xl:  calc(var(--space-base) * 8);   /* 2rem */
  --space-2xl: calc(var(--space-base) * 12);  /* 3rem */
  --space-3xl: calc(var(--space-base) * 16);  /* 4rem */
}
```

Changing `--space-base` rescales everything.

## CSS Modules and custom properties

Custom properties are **not** locally-scoped by CSS Modules. They cascade globally regardless of the file they're declared in. This is the right behaviour - tokens are global, modules just scope class names.

Declare tokens in a single global stylesheet (e.g. `src/styles/tokens.css`) imported once at the app root. Don't redeclare them inside `.module.css` files.

```css
/* tokens.css - imported in app entry */
:root {
  --color-accent: oklch(60% 0.18 250);
  /* ... */
}
```

```css
/* button.module.css */
.button {
  background: var(--color-accent);  /* References the global token */
}
```
