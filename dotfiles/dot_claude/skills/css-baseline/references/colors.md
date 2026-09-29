# Colors

## OKLCH is the default

`oklch()` (perceptually uniform LCH in the OKLab color space) is the default color function. Use it everywhere except for legacy interop.

Syntax: `oklch(L C H / A)` where:

- **L** (lightness): `0%` to `100%`. Perceptually linear - 50% looks half as bright as 100% to the human eye.
- **C** (chroma): `0` to ~`0.4`. Saturation. `0` is grayscale. Past ~`0.4` the color falls outside the sRGB gamut and is clipped.
- **H** (hue): `0deg` to `360deg`. 0/360 = red, 90 = green-ish, 180 = cyan, 270 = blue.
- **A** (alpha): `0` to `1` or `0%` to `100%`, after the slash.

```css
:root {
  --color-accent: oklch(60% 0.18 250);    /* blue */
  --color-success: oklch(70% 0.18 145);   /* green */
  --color-danger: oklch(60% 0.22 25);     /* red */
  --color-text: oklch(20% 0.02 250);
  --color-surface: oklch(98% 0.01 250);
  --color-overlay: oklch(0% 0 0 / 0.5);   /* 50% black */
}
```

## Why OKLCH over hex/rgb/hsl

Three reasons:

1. **Perceptually uniform**: equal numerical changes in L look equal to the eye. In HSL, `hsl(60deg 100% 50%)` (yellow) and `hsl(240deg 100% 50%)` (blue) have the same L but look wildly different in brightness.
2. **Gradient interpolation works correctly**: a gradient from `oklch(60% 0.18 0)` (red) to `oklch(60% 0.18 240)` (blue) stays equally bright through the middle. The same gradient in `rgb()` goes muddy gray.
3. **Wide-gamut friendly**: OKLCH can express colors beyond sRGB (P3, Rec2020) on modern displays. Chroma values above ~0.25 fall outside sRGB and are mapped into P3 on supporting hardware.

```css
/* This stays vibrant across the spectrum */
.rainbow-bar {
  background: linear-gradient(in oklch to right,
    oklch(70% 0.2 0), oklch(70% 0.2 60),
    oklch(70% 0.2 120), oklch(70% 0.2 180),
    oklch(70% 0.2 240), oklch(70% 0.2 300));
}
```

## Relative color syntax

Derive a color from another by transforming its L/C/H/A components:

```css
:root {
  --color-accent: oklch(60% 0.18 250);
  --color-accent-hover: oklch(from var(--color-accent) calc(l - 0.08) c h);
  --color-accent-pressed: oklch(from var(--color-accent) calc(l - 0.16) c h);
  --color-accent-muted: oklch(from var(--color-accent) l calc(c * 0.3) h);
  --color-accent-tint: oklch(from var(--color-accent) calc(l + 0.3) calc(c * 0.5) h);
}
```

Inside `oklch(from ...)`, the keywords `l`, `c`, `h`, `alpha` refer to the source color's components. Use `calc()` to derive.

## color-mix()

Interpolate between two colors:

```css
:root {
  --color-accent: oklch(60% 0.18 250);
  --color-accent-hover: color-mix(in oklch, var(--color-accent), black 12%);
  --color-accent-muted: color-mix(in oklch, var(--color-accent) 30%, transparent);
  --color-on-accent-faded: color-mix(in oklch, var(--color-on-accent), var(--color-accent) 30%);
}
```

`color-mix(in oklch, A, B P%)` returns A mixed with `P%` of B. `color-mix(in oklch, A P%, B Q%)` weights both sides explicitly.

Always specify the interpolation color space (`in oklch`, `in oklab`, `in srgb`). OKLCH is the default for visual work.

## light-dark() and color-scheme

For two-tone theming (light vs dark), use the `light-dark()` color function combined with `color-scheme`:

```css
:root {
  color-scheme: light dark;
  --color-bg: light-dark(oklch(98% 0.01 250), oklch(15% 0.02 250));
  --color-text: light-dark(oklch(20% 0.02 250), oklch(95% 0.02 250));
  --color-border: light-dark(oklch(85% 0.02 250), oklch(35% 0.02 250));
  --color-accent: light-dark(oklch(55% 0.18 250), oklch(70% 0.16 250));
}

body {
  background: var(--color-bg);
  color: var(--color-text);
}
```

`color-scheme: light dark` does two things:

1. Tells the browser to render form controls, scrollbars, and other UA elements in either light or dark depending on user preference.
2. Activates `light-dark()` to resolve to the matching value.

Force a theme by setting `color-scheme: light` or `color-scheme: dark` on a subtree:

```css
.invert-theme { color-scheme: dark; }
.invert-theme.in-light-context { color-scheme: light; }
```

## Common patterns

### Generating a hover/active palette from one accent

```css
:root {
  --color-accent: oklch(60% 0.18 250);
  --color-accent-hover: oklch(from var(--color-accent) calc(l - 0.08) c h);
  --color-accent-active: oklch(from var(--color-accent) calc(l - 0.16) c h);
  --color-on-accent: oklch(98% 0.01 250);
}
```

### Transparent overlays from a token

```css
:root {
  --color-accent: oklch(60% 0.18 250);
  --color-accent-20: color-mix(in oklch, var(--color-accent) 20%, transparent);
  --color-accent-50: color-mix(in oklch, var(--color-accent) 50%, transparent);
}

.glow { background: var(--color-accent-20); }
```

### Text-over-image legibility

```css
.headline {
  background: color-mix(in oklch, black 50%, transparent);
  color: oklch(98% 0 0);
}
```

### Status colors with consistent lightness

```css
:root {
  --status-l: 60%;
  --status-c: 0.18;
  --color-info: oklch(var(--status-l) var(--status-c) 240);
  --color-success: oklch(var(--status-l) var(--status-c) 145);
  --color-warning: oklch(var(--status-l) var(--status-c) 80);
  --color-danger: oklch(var(--status-l) var(--status-c) 25);
}
```

All four statuses have identical perceived brightness, so they read as a family.

## Color contrast

Use `color-contrast()` is **not yet supported** in production browsers as of 2026-05. Until it ships, compute contrast pairs manually and store both in tokens:

```css
:root {
  --color-accent: oklch(60% 0.18 250);
  --color-on-accent: oklch(98% 0.01 250);   /* near-white text on accent */
}
```

For automatic contrast on light/dark themes, use `light-dark()`.
