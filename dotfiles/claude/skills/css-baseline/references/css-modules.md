# CSS Modules

## What modules give you

A `.module.css` file has its class names rewritten by the bundler into unique scoped identifiers. Two implications:

1. Class names are **structurally scoped** - `.button` in `card.module.css` never collides with `.button` in `nav.module.css`.
2. The CSS doesn't need defensive prefixes (BEM, namespacing, parent-class chains). Selectors stay flat.

```css
/* button.module.css */
.button {
  padding: var(--space-sm) var(--space-md);
  border-radius: var(--radius-md);
  background: var(--color-accent);
  color: var(--color-on-accent);
}

.icon {
  inline-size: 1.25em;
  block-size: 1.25em;
}
```

```tsx
import styles from './button.module.css';

<button className={styles.button}>
  <Icon className={styles.icon} />
</button>
```

Bundler output: `.button` becomes something like `.button_a1b2c3` - unique per file.

## Naming inside a module

Single nouns for the role inside the component. No BEM, no prefixes:

```css
/* Right: card.module.css */
.card { /* ... */ }
.header { /* ... */ }
.title { /* ... */ }
.body { /* ... */ }
.footer { /* ... */ }
.primary { /* variant */ }
.compact { /* variant */ }

/* Wrong: BEM applied inside a module is redundant */
.card__header { /* ... */ }
.card__title { /* ... */ }
.card--primary { /* ... */ }
```

## `composes` - share class behaviour

Use `composes` to inherit one class's declarations into another. The compiled output applies both classes to the element.

### Within the same file

```css
.base {
  padding: var(--space-sm) var(--space-md);
  border-radius: var(--radius-md);
  border: 1px solid transparent;
}

.primary {
  composes: base;
  background: var(--color-accent);
  color: var(--color-on-accent);
}

.secondary {
  composes: base;
  background: transparent;
  border-color: var(--color-border);
  color: var(--color-text);
}
```

### From another file

```css
/* base.module.css */
.interactive {
  cursor: pointer;
  user-select: none;
  transition: opacity 150ms ease;
}
```

```css
/* button.module.css */
.button {
  composes: interactive from './base.module.css';
  padding: var(--space-sm) var(--space-md);
}
```

### From a global stylesheet

```css
.button {
  composes: visually-hidden from global;
}
```

`from global` references unscoped class names.

### Multiple composes

```css
.danger-button {
  composes: base interactive from './base.module.css';
  background: var(--color-danger);
}
```

Or chained:

```css
.danger-button {
  composes: base from './base.module.css';
  composes: interactive from './base.module.css';
  background: var(--color-danger);
}
```

## `:global` - escape the scope

Rare. Used when a class must remain unscoped because it's set by an external library, a parent app, or the browser:

```css
/* Wrap a selector */
:global(.tippy-tooltip) {
  font-family: var(--font-sans);
}

/* Wrap a section */
:global {
  .tippy-tooltip { font-family: var(--font-sans); }
  .tippy-arrow { fill: var(--color-surface); }
}
```

Default to scoped. Only reach for `:global` for proven third-party hooks.

## `:local` - re-enter scope

Inside a `:global` block, switch back with `:local`:

```css
:global {
  .third-party-grid :local(.card) {
    border-color: var(--color-accent);
  }
}
```

Usually unnecessary - prefer keeping the scope boundary clear by not nesting `:global` and `:local`.

## Custom properties cross all scopes

CSS Modules do **not** scope custom properties. They cascade globally, as they should:

```css
/* tokens.css - imported once at app root, NOT a module */
:root {
  --color-accent: oklch(60% 0.18 250);
  --space-md: 1rem;
}
```

```css
/* button.module.css */
.button {
  background: var(--color-accent);   /* References global token */
  padding: var(--space-md);
}
```

Declaring `:root { --color-accent: ... }` inside `.module.css` works (the selector `:root` isn't a class so it isn't scoped). But conventionally, tokens live in a single non-module stylesheet.

## Selectors inside modules

Element and attribute selectors are **not** scoped (only classes and IDs are). That means:

```css
/* card.module.css */
.card h2 {              /* h2 is unscoped - matches any h2 inside .card_scoped */
  font-size: var(--font-size-h2);
}

.card [data-state="open"] {  /* attribute is unscoped */
  background: var(--color-accent-tint);
}
```

This is the right behaviour - you usually want descendant element selectors to match the actual DOM elements, not be rewritten.

If you genuinely want to scope by element, use a class:

```css
.title {
  font-size: var(--font-size-h2);
}
```

## Animations are scoped

`@keyframes` names are scoped per module:

```css
@keyframes pulse {
  from { scale: 1; }
  to { scale: 1.05; }
}

.button:hover {
  animation: pulse 200ms ease both;
}
```

The compiled `@keyframes` name is something like `pulse_a1b2c3`, so two modules with `@keyframes pulse` don't collide.

To use a global keyframes name:

```css
.button:hover {
  animation: global(spin) 1s linear infinite;
}
```

## Files that aren't `.module.css`

In a project with CSS Modules, plain `.css` imports remain global:

```ts
import './tokens.css';      // global - tokens, resets, base layer
import styles from './button.module.css';   // scoped
```

Convention:

- `tokens.css`, `reset.css`, `base.css` are plain `.css` - they declare globals.
- All component styles are `.module.css`.

## When NOT to use CSS Modules

- **Global utilities** (`.visually-hidden`, `.text-balance`) - put them in a plain `.css` file in a `utilities` `@layer`.
- **Page-level styles** that genuinely target the whole document - plain `.css`.
- **Third-party component overrides** (e.g. styling a `react-select` instance) - plain `.css`, since the library's own classes aren't scoped to your module.

Modules are for components. Tokens and globals stay plain.

## Composition patterns

### Variants via composes

```css
.button { composes: base from './base.module.css'; }
.button.primary { background: var(--color-accent); }
.button.compact { padding: var(--space-xs) var(--space-sm); }
```

Apply variants via additional class names:

```tsx
<button className={`${styles.button} ${styles.primary} ${styles.compact}`}>
```

For larger variant counts, use a helper (`clsx`, `classnames`) or a CVA-style approach.

### Slot patterns

```css
.card { /* outer wrapper */ }
.media { /* image / icon slot */ }
.content { /* text slot */ }
.actions { /* button row */ }
```

The component shape is implicit in the class names; consumers don't need to know structural details.
