# Animations

## View Transitions API

The View Transitions API animates between two DOM states (or between two documents) by snapshotting before, snapshotting after, and cross-fading in the browser's top layer. The CSS controls the animation; no JS for the actual animation.

### Same-document (SPA)

Wrap a DOM mutation in `document.startViewTransition()`:

```js
function navigate(newView) {
  if (!document.startViewTransition) {
    mutateDom(newView);
    return;
  }
  document.startViewTransition(() => mutateDom(newView));
}
```

Tag the elements that should animate as a single morph:

```css
.hero-image { view-transition-name: hero; }
.hero-title { view-transition-name: hero-title; }
```

Each `view-transition-name` must be unique on the page at any given moment. Two elements with the same name simultaneously will break the transition.

Customise the animation:

```css
::view-transition-old(hero) {
  animation: 250ms ease-out both fade-and-shrink;
}
::view-transition-new(hero) {
  animation: 350ms ease-out both fade-and-grow;
}

@keyframes fade-and-shrink { to { opacity: 0; scale: 0.95; } }
@keyframes fade-and-grow   { from { opacity: 0; scale: 1.05; } }
```

The default animation (without keyframes) is a cross-fade.

### Cross-document (MPA)

Opt the document into transitions across same-origin navigations:

```css
@view-transition { navigation: auto; }
```

Then tag elements on both the source and destination pages with matching `view-transition-name`. The browser handles snapshotting at navigation time.

```css
/* index.html */
@view-transition { navigation: auto; }
.thumbnail[data-id="abc"] { view-transition-name: card-abc; }

/* detail.html */
@view-transition { navigation: auto; }
.hero { view-transition-name: card-abc; }
```

### Pseudo-element tree

For each named element, the browser creates:

- `::view-transition-group(name)` - container that handles position/size morph
- `::view-transition-image-pair(name)` - wrapper for the old/new snapshots
- `::view-transition-old(name)` - outgoing snapshot (a replaced element)
- `::view-transition-new(name)` - incoming snapshot

Target these to customise.

There's also a root pair (`::view-transition-old(root)` / `::view-transition-new(root)`) for elements that don't have a name.

### `view-transition-class` and types

Group named elements:

```css
.card { view-transition-class: card; }
::view-transition-group(.card) {
  animation-duration: 400ms;
}
```

Distinguish transition types (e.g. forward vs back):

```js
document.startViewTransition({
  update: mutate,
  types: ['back']
});
```

```css
:active-view-transition-type(back) {
  &::view-transition-old(*) { animation-name: slide-out-right; }
  &::view-transition-new(*) { animation-name: slide-in-left; }
}
```

## Scroll-driven animations

`animation-timeline` rebinds an `@keyframes` animation to scroll progress instead of time.

### `scroll()` timeline

Animation progress = scroll progress of an ancestor scroll container.

```css
.progress-bar {
  animation: grow linear;
  animation-timeline: scroll(root block);
}

@keyframes grow { from { scale: 0 1; } to { scale: 1 1; } }
```

`scroll(<scroller>, <axis>)`:

- `<scroller>`: `nearest` (default), `root` (the document scroller), `self` (this element if it's a scroller).
- `<axis>`: `block` (default), `inline`, `y`, `x`.

### `view()` timeline

Animation progress = the element's own position in the scroll viewport.

```css
.fade-in {
  animation: fade-in linear both;
  animation-timeline: view();
  animation-range: entry 0% entry 100%;
}

@keyframes fade-in { from { opacity: 0; translate: 0 2rem; } to { opacity: 1; } }
```

`view(<axis> <inset>)`. Inset is optional, shrinks the viewport region used for progress.

### `animation-range`

Controls which portion of the timeline maps to 0%-100% animation progress:

```css
.parallax {
  animation: drift linear;
  animation-timeline: view();
  animation-range: cover 0% cover 100%;
}
```

Phase keywords:

- `cover` - entire time the element is in the viewport (from first appearing to fully leaving)
- `entry` - element entering the viewport (0% just appearing, 100% fully visible)
- `exit` - element leaving the viewport (0% starts leaving, 100% fully gone)
- `entry-crossing` / `exit-crossing` - crosses the leading/trailing edge of the viewport

### Named timelines

For animation timelines shared across elements:

```css
.scroller {
  scroll-timeline-name: --feed;
  scroll-timeline-axis: block;
}

.item {
  animation: highlight linear;
  animation-timeline: --feed;
  animation-range: entry 0% entry 80%;
}
```

## `interpolate-size` - animate to `auto`

Animations to/from `auto`, `min-content`, `max-content`, `fit-content` are disabled by default. Opt in:

```css
:root { interpolate-size: allow-keywords; }
```

Now this works:

```css
details::details-content {
  block-size: 0;
  overflow: hidden;
  transition: block-size 200ms ease, content-visibility 200ms ease allow-discrete;
}

details[open]::details-content {
  block-size: auto;
}
```

The `allow-discrete` keyword in `transition` lets discrete properties (display, content-visibility) animate alongside.

## Transitions

Always animate specific properties, never `transition: all`:

```css
.button {
  transition:
    background-color 150ms ease,
    color 150ms ease,
    scale 150ms ease;
}

.button:hover { scale: 1.02; }
```

`transition: all` causes unintended animations when neighbouring properties change (e.g. layout shifts on hover trigger expensive re-animation).

### `transition-behavior`

For discrete properties (display, content-visibility, popover state):

```css
[popover] {
  transition:
    opacity 200ms ease,
    translate 200ms ease,
    display 200ms ease allow-discrete,
    overlay 200ms ease allow-discrete;
  opacity: 0;
  translate: 0 1rem;

  &:popover-open {
    opacity: 1;
    translate: 0 0;
  }

  /* Starting state for the entry animation - required for discrete properties */
  @starting-style {
    &:popover-open { opacity: 0; translate: 0 1rem; }
  }
}
```

`@starting-style` defines the "before" state for entry animations on elements newly added to the document or transitioning from `display: none`.

## Respect `prefers-reduced-motion`

Always defer to user preference:

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

This is the one acceptable use of `!important` in modern CSS.
