# Typography

## Base font-size: do not override it

**Never** set a fixed pixel font-size on `html` or `body`. Doing so overrides the user's browser default (a setting often used by people with low vision to scale text up). Per Adrian Roselli's guidance: respect user agency over design control.

```css
/* Wrong - hard-codes 16px and ignores user prefs */
html { font-size: 16px; }
body { font-size: 16px; }

/* Wrong - the "62.5% trick" forces users to set their browser default to 160% just to see the page at their preferred size */
html { font-size: 62.5%; }

/* Right - either set nothing on html/body, or use 100% if a build tool insists */
html { font-size: 100%; }
```

Then use **`rem`** (or `em` for component-relative sizing) for every other font-size in the codebase. `1rem` resolves to whatever the user picked. A user with a 24px browser default reads the site at 24px-base; a user with 16px gets 16px. The site scales for both, automatically.

### Why not `px` for font-size

`px` is wrong for font-size specifically. It's fine for:

- borders, radii, shadow spread (these are visual decoration, not text)
- absolute icon dimensions (`width: 24px` on an SVG icon - text-around it still scales)
- viewport-relative fixed positioning offsets that aren't tied to text size

It is wrong for: any font-size declaration, line-height (use unitless), letter-spacing on body text (use `em`).

### iOS Safari rotation fix

Mobile Safari inflates text on landscape rotation by default. Disable it:

```css
html {
  -webkit-text-size-adjust: 100%;
  text-size-adjust: 100%;
}
```

`100%` (not `none`) is preferred - it disables the auto-inflation while still letting users explicitly zoom.

## Fluid type scale

Font sizes for **headings and display** use `clamp()` to grow smoothly with viewport (or container). Body font-size stays a plain `1rem` so user prefs flow through unmodified.

```css
:root {
  /* Body stays 1rem - respects user default verbatim */
  --font-size-body: 1rem;
  --font-size-sm:   0.875rem;
  --font-size-xs:   0.75rem;

  /* Headings & display scale fluidly */
  --font-size-md:   clamp(1.125rem, 1rem + 0.4vw, 1.375rem);
  --font-size-lg:   clamp(1.375rem, 1rem + 1.2vw, 1.75rem);
  --font-size-xl:   clamp(1.75rem, 1rem + 2.4vw, 2.5rem);
  --font-size-2xl:  clamp(2.25rem, 1rem + 4vw, 3.5rem);
  --font-size-3xl:  clamp(3rem,    1rem + 6vw, 5rem);
}

body  { font-size: var(--font-size-body); }
small { font-size: var(--font-size-sm); }
h3    { font-size: var(--font-size-lg); }
h2    { font-size: var(--font-size-xl); }
h1    { font-size: var(--font-size-2xl); }
```

Note the **`+ 1rem`** floor in the preferred value. This is critical: if the preferred is `0` + `Nvw` and the viewport collapses, the value collapses too, and the font becomes unreadable. Anchoring with `+ 1rem` (or any rem floor) means the value still respects user zoom even when the fluid component is small.

### The clamp() formula (Utopia / Pedro Rodriguez)

To derive `clamp(MIN, PREFERRED, MAX)` for a fluid value that goes from `MIN` (in rem) at `MIN_VW` (viewport in rem, divide px by 16) to `MAX` (in rem) at `MAX_VW`:

```
slope          = (MAX - MIN) / (MAX_VW - MIN_VW)
yIntersection  = -1 * MIN_VW * slope + MIN

font-size: clamp(MIN, {yIntersection}rem + {slope * 100}vw, MAX);
```

Worked example: scale from `1.25rem` at 320px (20rem) to `2rem` at 1440px (90rem):

- slope = (2 - 1.25) / (90 - 20) = 0.0107
- yIntersection = -20 * 0.0107 + 1.25 = 1.036rem

```css
font-size: clamp(1.25rem, 1.036rem + 1.07vw, 2rem);
```

For full scales, use [utopia.fyi](https://utopia.fyi/type/calculator) - paste your min/max viewport and font-size, copy the rules.

### Modular scale ratios

Pair fluid scaling with a **modular ratio** so the steps relate harmonically. Common ratios:

| Name | Ratio |
|---|---|
| Minor second | 1.067 |
| Major second | 1.125 |
| Minor third | 1.2 |
| Major third | 1.25 |
| Perfect fourth | 1.333 |
| Perfect fifth | 1.5 |
| Golden ratio | 1.618 |

A 1.333 (perfect fourth) ratio from a 1rem base produces: 1, 1.333, 1.777, 2.369, 3.157, 4.209. Use these as your `MAX` values at the large viewport; pick smaller `MIN` values for the small viewport (typically 70-80% of MAX for body-adjacent steps, 50-60% for display steps).

For component-internal fluid type (sizes the article based on its container, not the viewport), use `cqi` instead of `vw`. See `container-queries.md`.

## Line height

Always unit-less. The line-height ratio multiplies the element's font-size, so the result scales correctly when font-size changes via responsive scale.

```css
:root {
  --line-height-tight: 1.15;
  --line-height-snug: 1.3;
  --line-height-normal: 1.5;
  --line-height-relaxed: 1.7;
}

body { line-height: var(--line-height-normal); }
h1, h2, h3, h4 { line-height: var(--line-height-tight); }
.lead { line-height: var(--line-height-relaxed); }
```

`line-height: 24px` is wrong - it doesn't scale with font-size.

## `text-wrap`

```css
h1, h2, h3 { text-wrap: balance; }   /* Distribute words evenly across lines */
p          { text-wrap: pretty; }    /* Avoid orphan words on the last line */
.code      { text-wrap: nowrap; }    /* For inline code spans, etc. */
```

`balance` is for short multi-line text (headings, callouts). It's expensive - browsers limit it to ~6 lines.

`pretty` is for long-form prose. Cheaper than balance, focuses on the last few lines.

## `text-box` - trim leading and trailing visual space

Text in HTML has implicit space above and below glyphs (the half-leading). For tight visual alignment (heading flush against a border, button label flush against its padding), use `text-box`:

```css
h1 {
  text-box: trim-both cap alphabetic;
}
```

Shorthand: `text-box: <text-box-trim> <text-box-edge>`.

`text-box-trim`:

- `none` - no trimming (default)
- `trim-start` - trim above the text only
- `trim-end` - trim below the text only
- `trim-both` - trim both

`text-box-edge`:

- `auto` - browser default
- `text` - the text content edge (ascender / descender)
- `cap` - capital letter height (top trim)
- `ex` - x-height (top trim)
- `alphabetic` - the baseline (bottom trim)
- `ideographic` - ideographic baseline
- `ideographic-ink` - ideographic ink edge

Common pairings:

```css
/* Headings: trim to cap height top, baseline bottom */
h1, h2, h3 { text-box: trim-both cap alphabetic; }

/* Button labels: trim to x-height for snug vertical centering */
.button { text-box: trim-both ex alphabetic; }
```

## Font loading

Use `font-display: swap` so text is visible immediately during font load:

```css
@font-face {
  font-family: 'Inter';
  src: url('inter.woff2') format('woff2');
  font-weight: 100 900;
  font-display: swap;
  font-style: normal;
}
```

For critical fonts (display headings) use `font-display: optional` to suppress the swap flash, accepting a fallback if the font is too slow.

For variable fonts, declare the full weight range in one `@font-face`:

```css
@font-face {
  font-family: 'Inter';
  src: url('inter-var.woff2') format('woff2-variations');
  font-weight: 100 900;       /* Variable axis */
  font-stretch: 75% 125%;
  font-display: swap;
}

.thin   { font-weight: 200; }
.bold   { font-weight: 700; }
.black  { font-weight: 900; }
```

## System font stack as default

```css
:root {
  --font-sans: ui-sans-serif, system-ui, -apple-system, 'Segoe UI', sans-serif;
  --font-mono: ui-monospace, 'Menlo', 'Consolas', monospace;
  --font-serif: ui-serif, 'New York', 'Charter', serif;
}

body { font-family: var(--font-sans); }
code, pre, kbd, samp { font-family: var(--font-mono); }
```

`ui-sans-serif` / `ui-monospace` / `ui-serif` are the standard "use the OS UI font" keywords. They render the same font macOS / iOS use for system UI.

## Vertical rhythm

Use unitless line-heights plus a spacing scale tied to the font scale:

```css
:root {
  --space-text-xs: 0.5em;
  --space-text-sm: 0.75em;
  --space-text-md: 1em;
  --space-text-lg: 1.5em;
}

h1 { margin-block-end: var(--space-text-md); }
h2 { margin-block: var(--space-text-lg) var(--space-text-sm); }
p  { margin-block-end: var(--space-text-md); }
```

`em` units relate to the element's own font-size, so a larger heading gets proportionally larger margin.

## Measure (line length)

Optimal line length for body text is 45-75 characters. Limit it with `ch` unit:

```css
.prose {
  max-inline-size: 70ch;
}
```

`ch` = the width of "0" in the current font. Approximate but reliable.

## Letter and word spacing

Avoid manual letter-spacing on body text. Use it sparingly on display headings or all-caps labels:

```css
.label-uppercase {
  text-transform: uppercase;
  letter-spacing: 0.05em;
  font-size: var(--font-size-xs);
}
```

`letter-spacing` should use `em` so it scales with font-size.

## Hyphenation

For long-form prose in languages that benefit:

```css
.prose {
  hyphens: auto;
  -webkit-hyphens: auto;
}
```

Browsers need the document language set (`<html lang="...">`) for hyphenation to work correctly.
