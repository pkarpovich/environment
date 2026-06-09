---
name: css-baseline
description: Modern CSS (2026) style guide for plain CSS and CSS Modules. Apply automatically when writing, editing, or reviewing .css, .module.css, or .scss files. Targets Chrome (last 4) and Safari 26+. No fallbacks, no @supports hedges, no legacy support. Prescribes Grid/Flexbox over position:absolute for layout; intrinsic sizing (min-content, fit-content, clamp()) over fixed pixels; container queries for component-level responsive; CSS custom properties for every repeated value; OKLCH color space; light-dark() for theming; :has() and @scope over deep selector chains; @layer for cascade order over !important; native CSS Nesting; View Transitions API for navigation; scroll-driven animations via animation-timeline; anchor positioning for floating UI; text-wrap balance/pretty for typography; field-sizing for auto-resizing form controls; popover API for overlays. When editing existing CSS, apply these rules even if surrounding code is older - do not cargo-cult legacy patterns.
---

# Modern CSS (2026)

Apply these rules when writing, editing, or reviewing any CSS or CSS Modules code.

Target browsers: latest Chrome (last 4 versions) and Safari 26+ (iOS and macOS). Do not write `@supports` fallbacks, do not write vendor prefixes, do not pre-process with autoprefixer. Every feature listed here is supported in those targets.

## Rule 0: Do not cargo-cult existing CSS

When editing an existing `.css` or `.module.css` file, the surrounding code is **not** authoritative. If the existing code uses `position: absolute` for layout, hardcoded `width: 350px`, hex colors, or Bootstrap-style breakpoints, apply the rules below regardless. Match patterns from this guide, not from adjacent legacy code.

## 1. Layout

Use Grid and Flexbox as the primary layout system. `position: absolute` is only for true overlays (tooltips, popovers, dropdowns) - never for placing structural elements.

```css
.page {
  display: grid;
  grid-template-columns: 1fr min(70ch, 100%) 1fr;
  gap: 1rem;
}

.card {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}
```

Use **subgrid** when child grids must align with the parent track structure:

```css
.cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(20rem, 1fr));
  gap: 1rem;
}

.card {
  display: grid;
  grid-template-rows: subgrid;
  grid-row: span 3;
}
```

Always use **logical properties** (`inline-size`, `block-size`, `margin-inline`, `padding-block`, `border-inline-start`) over physical ones (`width`, `height`, `margin-left`, etc.). They work correctly with RTL/writing-mode out of the box.

WHY: physical properties break in RTL languages. Logical properties are the same syntax with strictly more coverage.

See `references/layout.md` for full patterns.

## 2. Sizing

Never hardcode pixel widths or heights for content. Use intrinsic sizing keywords or `clamp()` for fluid bounds.

```css
.card {
  inline-size: clamp(20rem, 50%, 40rem);
  max-inline-size: 100%;
}

.dialog {
  inline-size: min(40rem, calc(100% - 2rem));
}

.toolbar {
  inline-size: fit-content;
}
```

Viewport units: use `dvh`/`dvw`/`svh`/`svw`/`lvh`/`lvw` instead of `vh`/`vw`. The dynamic variants account for mobile browser chrome (address bar appearing/disappearing).

```css
.hero {
  block-size: 100dvh;
}
```

WHY: `vh` on mobile triggers the well-known "100vh too tall" bug when the address bar collapses. `dvh` solves it natively.

See `references/layout.md`.

## 3. Responsive

**Container queries first.** Components decide their own layout from their container width, not the viewport. Media queries are only for page-level concerns (sidebar collapsing, navigation switching, `prefers-*` features).

```css
.card-list {
  container-type: inline-size;
}

.card {
  display: grid;
  grid-template-columns: 1fr;

  @container (inline-size > 30rem) {
    grid-template-columns: 8rem 1fr;
  }
}
```

Use container query units (`cqi`, `cqw`, `cqb`) instead of `vw` for spacing inside a container:

```css
.card {
  padding: clamp(1rem, 4cqi, 2rem);
}
```

Use `clamp(min, fluid, max)` for fluid typography and spacing:

```css
:root {
  --font-size-h1: clamp(2rem, 4vw + 1rem, 4rem);
  --space-xl: clamp(2rem, 5vw, 4rem);
}
```

Use `prefers-*` media queries for accessibility and theming preferences:

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { animation-duration: 0.01ms !important; transition-duration: 0.01ms !important; }
}
```

WHY: viewport-driven breakpoints (768/992/1200) decoupled components from their actual container. The same card looks identical whether placed in a sidebar or a hero section - until container queries existed. Now layout follows context, which is what "responsive" actually means.

See `references/responsive.md` and `references/container-queries.md`.

## 4. Custom properties & theming

Every repeated value (color, spacing, radius, font-size, font-family, shadow, transition) lives in a CSS custom property. No magic numbers in component rules.

```css
:root {
  --space-2xs: 0.25rem;
  --space-xs: 0.5rem;
  --space-sm: 0.75rem;
  --space-md: 1rem;
  --space-lg: 1.5rem;
  --space-xl: 2rem;
  --space-2xl: 3rem;

  --radius-sm: 0.25rem;
  --radius-md: 0.5rem;
  --radius-full: 9999px;

  --color-surface: oklch(98% 0.01 240);
  --color-text: oklch(20% 0.02 240);
  --color-accent: oklch(60% 0.18 250);
}
```

Use `@property` for typed custom properties when the value participates in animation, gradients, or inheritance:

```css
@property --tilt-angle {
  syntax: '<angle>';
  inherits: false;
  initial-value: 0deg;
}

.card:hover {
  --tilt-angle: 6deg;
  transition: --tilt-angle 200ms ease;
  transform: rotate(var(--tilt-angle));
}
```

For dark mode, use `light-dark()` with `color-scheme`:

```css
:root {
  color-scheme: light dark;
  --color-bg: light-dark(white, #111);
  --color-text: light-dark(#111, #eee);
}
```

WHY: `light-dark()` removes the need for duplicated `@media (prefers-color-scheme: dark)` blocks scattered across components. `@property` makes custom properties animatable and gives them runtime type-checking.

See `references/custom-properties.md`.

## 5. Colors

`oklch()` is the default color space. Avoid `rgb()`, `hsl()`, and hex literals for anything beyond legacy interop.

```css
:root {
  --color-accent: oklch(60% 0.18 250);
  --color-accent-hover: oklch(from var(--color-accent) calc(l - 0.1) c h);
  --color-accent-muted: color-mix(in oklch, var(--color-accent) 30%, transparent);
}
```

Use `color-mix()` for variants instead of declaring a parallel palette. Use **relative color syntax** (`oklch(from var(--c) ...)`) to derive a color from another.

WHY: OKLCH is perceptually uniform - interpolation in gradients and animations looks correct (no muddy mid-points). Color-mix and relative colors let one accent color generate a whole component family.

See `references/colors.md`.

## 6. Selectors & cascade

Use `:has()` whenever you need a parent or sibling-based selector. No more JS-driven class toggling for "form has invalid input" or "card has image":

```css
.card:has(img) {
  grid-template-columns: 8rem 1fr;
}

.form:has(:user-invalid) .submit {
  opacity: 0.5;
}
```

Use `@scope` to isolate component styles from descendants without specificity wars:

```css
@scope (.card) to (.card-body) {
  h2 { font-size: var(--font-size-h2); }
  a { color: var(--color-accent); }
}
```

Use `@layer` for cascade order. No `!important`, ever:

```css
@layer reset, base, components, utilities;

@layer base {
  body { font-family: system-ui, sans-serif; }
}

@layer components {
  .button { /* ... */ }
}
```

Use **native CSS nesting** (`&` selector). No preprocessor required:

```css
.card {
  padding: var(--space-md);

  & h2 {
    margin-block-end: var(--space-sm);
  }

  &:hover {
    background: var(--color-surface-hover);
  }

  @container (inline-size > 30rem) {
    padding: var(--space-lg);
  }
}
```

WHY: `:has()` collapses dozens of "JS adds a class to parent" patterns into pure CSS. `@scope` removes the need for BEM-prefix-everything when CSS Modules are not in use. `@layer` makes cascade order explicit and removes the `!important` arms race.

See `references/selectors-and-cascade.md`.

## 7. Animations

Use the View Transitions API for navigation animations. SPA: `document.startViewTransition()`. MPA: `@view-transition { navigation: auto; }`.

```css
@view-transition { navigation: auto; }

.hero-image { view-transition-name: hero; }

::view-transition-old(hero) { animation: 200ms ease-out fade-out; }
::view-transition-new(hero) { animation: 300ms ease-out fade-in; }
```

Use **scroll-driven animations** via `animation-timeline` for scroll-linked effects. No `IntersectionObserver`, no `scroll` event listeners:

```css
.progress-bar {
  animation: grow linear;
  animation-timeline: scroll(root block);
}

@keyframes grow { from { scale: 0 1; } to { scale: 1 1; } }
```

Use `interpolate-size: allow-keywords` to animate to and from `auto`/`min-content`/`max-content`:

```css
:root { interpolate-size: allow-keywords; }

details::details-content {
  block-size: 0;
  overflow: hidden;
  transition: block-size 200ms ease, content-visibility 200ms ease allow-discrete;
}
details[open]::details-content { block-size: auto; }
```

Always animate specific properties, never `transition: all`.

WHY: View Transitions removes a class of fragile JS-driven animation code. Scroll-driven animations remove the perf cost of scroll listeners.

See `references/animations.md`.

## 8. Typography

**Never** set a fixed pixel font-size on `html` or `body`. It overrides the user's browser default and breaks accessibility (low-vision users often raise the default above 16px). Body font-size stays plain `1rem`. Only headings and display copy use `clamp()` to scale fluidly. Always anchor the `clamp()` preferred value with a `rem` term (`+ 1rem`) so it respects user zoom at small viewports.

```css
:root {
  --font-size-body: 1rem;
  --font-size-h1: clamp(2.25rem, 1rem + 4vw, 3.5rem);
  --font-size-h2: clamp(1.75rem, 1rem + 2.4vw, 2.5rem);
  --line-height-body: 1.6;
  --line-height-heading: 1.15;
}

body { font-size: var(--font-size-body); line-height: var(--line-height-body); }
h1   { font-size: var(--font-size-h1); line-height: var(--line-height-heading); }
```

Line-height is **unitless** (a ratio). `line-height: 24px` is wrong - it doesn't scale with font-size.

Use `text-wrap: balance` for headings and short text. Use `text-wrap: pretty` for paragraphs:

```css
h1, h2, h3 { text-wrap: balance; }
p { text-wrap: pretty; }
```

Use `text-box` shorthand to trim leading/trailing visual space above and below text (heading alignment):

```css
h1 { text-box: trim-both cap alphabetic; }
```

WHY: unitless line-height inherits proportionally to font-size, fixed `px` line-height breaks at responsive font scales. `text-wrap: balance` solves the "orphan word on its own line" problem natively. `text-box` lets headings sit flush against borders without manual `margin-top: -0.2em` hacks.

See `references/typography.md`.

## 9. Forms & overlays

Use `field-sizing: content` to make inputs and textareas size to their content:

```css
input, textarea { field-sizing: content; }
```

Use the **Popover API** for menus, tooltips, dropdowns, dialogs that are not full modals. No JS for show/hide; the browser handles top-layer, light-dismiss, and focus:

```html
<button popovertarget="menu">Open</button>
<div id="menu" popover>...</div>
```

```css
[popover] {
  &:popover-open { display: grid; }
  &::backdrop { background: oklch(0% 0 0 / 0.4); }
}
```

Use **anchor positioning** for popovers, tooltips, dropdowns that must follow another element:

```css
.button { anchor-name: --action; }

.tooltip {
  position: fixed;
  position-anchor: --action;
  position-area: block-end;
  margin-block-start: 0.5rem;
  position-try-fallbacks: block-start, inline-end, inline-start;
}
```

WHY: `field-sizing: content` removes the entire category of "auto-resize textarea" JS libraries. Popover API + anchor positioning together replace Floating UI / Popper / Tippy.js for most use cases.

See `references/forms-and-overlays.md`.

## 10. CSS Modules

When the file extension is `.module.css`, class names are locally scoped automatically. Implications:

- Do **not** use BEM. `.button__icon--large` becomes just `.icon` because scoping is structural.
- Do **not** wrap selectors in extra parent classes to fight specificity. Selectors stay flat.
- Use `composes` to share class behaviour without duplicating declarations:

```css
/* button.module.css */
.base {
  padding: var(--space-sm) var(--space-md);
  border-radius: var(--radius-md);
}

.primary {
  composes: base;
  background: var(--color-accent);
  color: var(--color-on-accent);
}
```

- Use `:global()` for the rare cases where a class must escape the module scope (e.g. third-party library hooks). Default to scoped.
- CSS custom properties are **not** scoped by CSS Modules. Declare design tokens in a global `.css` file (typically `app.css` or `tokens.css`) imported once at the app root.

WHY: modules remove the specificity-vs-naming tradeoff that BEM was invented to solve. Composes keeps style sharing structural instead of inheritance-based.

See `references/css-modules.md`.

---

## References index

- `references/layout.md` - Grid, Flexbox, subgrid, intrinsic sizing, logical properties, viewport units.
- `references/responsive.md` - clamp() patterns, fluid scales, page-level vs component-level responsive.
- `references/container-queries.md` - `@container`, container types, units (cqi/cqw/cqb), style queries.
- `references/colors.md` - OKLCH, color-mix, relative color syntax, light-dark, color-scheme.
- `references/custom-properties.md` - var(), @property, theming, runtime updates.
- `references/selectors-and-cascade.md` - `:has()`, `@scope`, `@layer`, native nesting.
- `references/animations.md` - View Transitions (SPA + MPA), scroll-driven, interpolate-size, transition specifics.
- `references/typography.md` - clamp font scales, balance/pretty, text-box, unit-less line-height.
- `references/forms-and-overlays.md` - field-sizing, Popover API, anchor positioning patterns.
- `references/css-modules.md` - scoping, composes, :global, design tokens.
