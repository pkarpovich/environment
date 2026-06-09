# Forms and overlays

## `field-sizing: content` - inputs that grow with content

```css
input, textarea, select { field-sizing: content; }
```

Now an `<input>` widens as the user types; a `<textarea>` grows in height. No JS, no auto-resize library.

Combine with min/max bounds to constrain growth:

```css
textarea {
  field-sizing: content;
  min-block-size: 4lh;
  max-block-size: 20lh;
  min-inline-size: 20ch;
}
```

`lh` = current line-height. `ch` = current 0-width. Both are perfect for sizing form fields.

For inputs that should NOT grow (filling a fixed grid cell), use `field-sizing: fixed` (the default).

## Form validity styles

Use `:user-invalid` / `:user-valid` instead of `:invalid` / `:valid`. The user-* versions only match after the user has interacted with the field, so empty required fields don't look broken on page load.

```css
input {
  border: 1px solid var(--color-border);

  &:user-invalid { border-color: var(--color-danger); }
  &:user-valid   { border-color: var(--color-success); }
}

input:user-invalid + .error-message { display: block; }
.error-message { display: none; }
```

## Native styled inputs

Style ranges, color pickers, file inputs with the standard pseudo-elements:

```css
input[type="range"]::-webkit-slider-thumb { /* WebKit thumb */ }
input[type="range"]::-moz-range-thumb { /* Firefox thumb */ }
input[type="file"]::file-selector-button { /* Cross-browser */ }
```

The `::file-selector-button` pseudo is standard and supported. Style file inputs without wrapping them.

```css
input[type="file"]::file-selector-button {
  padding: var(--space-xs) var(--space-md);
  border-radius: var(--radius-md);
  border: 0;
  background: var(--color-accent);
  color: var(--color-on-accent);
  cursor: pointer;
}
```

## Popover API

The `popover` attribute creates an element rendered in the top layer with browser-managed:

- Light-dismiss (click outside or Escape closes it)
- Focus management
- Z-index (top layer always wins, no `z-index` games)

```html
<button popovertarget="menu">Open menu</button>
<div id="menu" popover>
  <a href="/profile">Profile</a>
  <a href="/settings">Settings</a>
  <a href="/logout">Log out</a>
</div>
```

```css
[popover] {
  margin: 0;
  padding: var(--space-sm);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  background: var(--color-surface);

  &::backdrop {
    background: oklch(0% 0 0 / 0.4);
  }
}
```

### Popover types

| Value | Behaviour |
|---|---|
| `popover` (or `popover="auto"`) | Light-dismiss. Only one auto popover open at a time (others close on opening a new one). |
| `popover="manual"` | No light-dismiss. Show/hide explicitly via JS or another button. Used for toasts, persistent panels. |
| `popover="hint"` | Like auto but lighter dismiss semantics, for tooltips. |

### Triggers and actions

```html
<button popovertarget="menu" popovertargetaction="show">Show</button>
<button popovertarget="menu" popovertargetaction="hide">Hide</button>
<button popovertarget="menu" popovertargetaction="toggle">Toggle</button>
```

Default action is `toggle`.

### State

`:popover-open` matches an open popover:

```css
[popover] {
  opacity: 0;
  translate: 0 0.5rem;
  transition:
    opacity 200ms ease,
    translate 200ms ease,
    display 200ms ease allow-discrete,
    overlay 200ms ease allow-discrete;

  &:popover-open {
    opacity: 1;
    translate: 0 0;
  }

  @starting-style {
    &:popover-open {
      opacity: 0;
      translate: 0 0.5rem;
    }
  }
}
```

`@starting-style` is needed because the element is `display: none` when closed; the entry animation starts from there.

## Anchor positioning

Pair anchor positioning with the Popover API for dropdowns, tooltips, menus.

### Basic syntax

```css
.action-button {
  anchor-name: --action;
}

.popover-menu {
  position: fixed;
  position-anchor: --action;
  position-area: block-end;          /* below the anchor */
  margin-block-start: 0.5rem;
}
```

`anchor-name` declares the anchor. `position-anchor` connects a positioned element to it. `position-area` is the high-level shortcut for "where relative to the anchor".

### `position-area` values

Two-axis grid: `block-start | block-end | inline-start | inline-end | center | start | end | self-start | self-end`. Pairs combine the axes:

```css
.tooltip { position-area: block-end center; }      /* below, centered */
.menu    { position-area: block-end inline-start; } /* below, left-aligned */
.badge   { position-area: block-start inline-end; } /* above, right-aligned */
.spanned { position-area: block-end span-inline; }  /* below, spans inline axis */
```

Span values (`span-block`, `span-inline`, `span-all`) let the popover stretch beyond a single grid cell.

### `anchor()` function (manual positioning)

For control beyond `position-area`:

```css
.tooltip {
  position: fixed;
  position-anchor: --action;
  inset-block-start: calc(anchor(block-end) + 0.5rem);
  inset-inline-start: anchor(center);
  translate: -50% 0;
}
```

`anchor(<side>)` returns the anchor's position on that side. Sides: `top`, `bottom`, `left`, `right`, `start`, `end`, `block-start`, `block-end`, `inline-start`, `inline-end`, `center`.

### `position-try-fallbacks`

If the default position would overflow the viewport, try alternatives:

```css
.popover-menu {
  position: fixed;
  position-anchor: --action;
  position-area: block-end;
  position-try-fallbacks: block-start, inline-end, inline-start, flip-block;
}
```

Each fallback is either a `position-area` value, a `flip-*` keyword (`flip-block`, `flip-inline`, `flip-start`), or a custom `@position-try` rule.

```css
@position-try --above-right {
  position-area: block-start inline-end;
  margin-block-end: 0.5rem;
}

.menu { position-try-fallbacks: --above-right, block-start; }
```

### `anchor-size()` - inherit anchor dimensions

```css
.dropdown {
  position-anchor: --combobox;
  inline-size: anchor-size(width);
  /* Dropdown matches the combobox width exactly */
}
```

`anchor-size(<dimension>)`: `width`, `height`, `inline`, `block`, `self-inline`, `self-block`.

### Full anchored popover pattern

```html
<button popovertarget="menu" id="trigger">Open</button>
<div id="menu" popover>...</div>
```

```css
#trigger { anchor-name: --trigger; }

#menu {
  position-anchor: --trigger;
  position-area: block-end inline-start;
  position-try-fallbacks:
    block-end inline-end,
    block-start inline-start,
    block-start inline-end;
  margin: 0.5rem 0;
  inline-size: max-content;
  max-inline-size: anchor-size(width);
}
```

## Dialog vs popover

| Use case | Element |
|---|---|
| Tooltip, dropdown menu, autocomplete | `[popover]` with anchor positioning |
| Toast notification | `[popover="manual"]` |
| Modal dialog (blocks interaction with the page) | `<dialog>` with `.showModal()` |
| Non-modal dialog (sidebar panel, drawer) | `<dialog>` with `.show()` or `[popover="manual"]` |

`<dialog>` has its own pseudo (`::backdrop`) and gets focus management for free.
