# Container queries

## Anatomy

Two parts:

1. A **containment context** declared on an ancestor via `container-type`.
2. A `@container` rule that queries it.

```css
.layout {
  container-type: inline-size;
  container-name: layout;
}

.card {
  display: grid;
  grid-template-columns: 1fr;
}

@container layout (inline-size > 30rem) {
  .card { grid-template-columns: 1fr 1fr; }
}
```

Naming is optional but recommended when multiple nested containers exist - it prevents the closest container from accidentally matching.

## `container-type` values

| Value | Effect |
|---|---|
| `inline-size` | Establishes a size containment context for inline-axis queries. The default choice. |
| `size` | Establishes containment for both inline and block axes. Required to query `block-size`. The element must have an explicit `block-size`, or it collapses to zero. |
| `normal` | No size containment. Required to be `normal` to enable `@container style(...)` queries on this element. |

```css
/* Most common: query the container's width */
.list { container-type: inline-size; }

/* Query both axes - the container must have an explicit block-size */
.tile {
  container-type: size;
  block-size: 20rem;
}

/* Style query container - no size containment needed */
.theme-host {
  container-name: theme;
  /* No container-type required for style queries on this name */
}
```

## Size queries

Query syntax matches media queries:

```css
@container (inline-size > 30rem) { /* ... */ }
@container (inline-size >= 30rem) and (inline-size < 60rem) { /* ... */ }
@container (block-size > 20rem) { /* requires container-type: size */ }
@container (aspect-ratio > 1) { /* ... */ }
@container (orientation: landscape) { /* ... */ }
```

Use range syntax (`>`, `<`, `>=`, `<=`), not `min-`/`max-` prefixes.

## Style queries

Query the computed value of a custom property on the container:

```css
@container style(--theme: dark) {
  .card { background: var(--color-surface-dark); }
}

@container style(--density: compact) {
  .card { padding: var(--space-xs); }
}
```

Style queries do not require `container-type` to be set - any element can be queried by its custom property values.

## Container query units

Sized relative to the **nearest containment context** of the queried element:

| Unit | Equivalent |
|---|---|
| `cqi` | 1% of the container's inline-size |
| `cqb` | 1% of the container's block-size |
| `cqw` | 1% of the container's width (writing-mode dependent equivalent of cqi for horizontal-tb) |
| `cqh` | 1% of the container's height |
| `cqmin` | the smaller of cqi and cqb |
| `cqmax` | the larger of cqi and cqb |

Use `cqi`/`cqb` (writing-mode aware) over `cqw`/`cqh` (axis-locked).

```css
.card {
  padding: clamp(1rem, 4cqi, 2rem);
  font-size: clamp(1rem, 3cqi, 1.25rem);
  gap: 2cqi;
}
```

Container query units fall back to viewport units (`vi`/`vb`) when there is no containing context.

## Gotchas

**An element cannot query its own container.** The query applies to descendants of the containment context, not the context itself. Wrap the component you want to style with a parent that owns the `container-type`.

```css
/* Wrong - .card cannot query itself */
.card {
  container-type: inline-size;
}
@container (inline-size > 30rem) {
  .card { /* This never matches */ }
}

/* Right - parent owns the container */
.card-host { container-type: inline-size; }
@container (inline-size > 30rem) {
  .card { /* OK */ }
}
```

**`container-type: inline-size` triggers layout containment.** Children with `position: absolute` are positioned relative to the container as if it were `position: relative`, and the element can no longer be sized by its content in the block direction. Usually fine, occasionally surprising.

**Container query units inside a nested container** resolve to the **nearest** container, not the outermost. If you need cross-container sizing, name the container explicitly and query it by name.

## Patterns

### Stacked-to-row card

```css
.card-host { container-type: inline-size; }

.card {
  display: grid;
  grid-template-columns: 1fr;
  gap: var(--space-sm);

  @container (inline-size > 24rem) {
    grid-template-columns: 8rem 1fr;
  }
}
```

### Density modes via style query

```css
.theme-host { --density: comfortable; }
.theme-host.compact { --density: compact; }

.row {
  padding-block: var(--space-md);

  @container style(--density: compact) {
    padding-block: var(--space-xs);
  }
}
```

### Component-internal type scale

```css
.article-host { container-type: inline-size; }

.article h1 { font-size: clamp(1.75rem, 6cqi, 3rem); }
.article h2 { font-size: clamp(1.25rem, 4cqi, 2rem); }
.article p { font-size: clamp(0.95rem, 2cqi, 1.125rem); }
```

The same article scales its own type when placed in a sidebar vs the main column.
