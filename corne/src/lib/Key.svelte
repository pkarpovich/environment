<script>
  import { COORDS, HOME_INDEXES, fingerAt, capAt, parseToken, outputOf, legendOf } from './keymap.js'
  import Icon from './Icon.svelte'

  let { token, index, lang, mods, live } = $props()

  const key = $derived(parseToken(token, index))
  const coord = $derived(COORDS[index])
  const finger = $derived(fingerAt(index))
  const cap = $derived(capAt(index))
  const home = $derived(HOME_INDEXES.includes(index))

  const out = $derived(outputOf(key, lang, mods))
  const legend = $derived(legendOf(key, mods.shift))
  const sub = $derived(out !== null && out !== legend ? legend : null)
</script>

{#if key.kind === 'dead'}
  <div class="key key--dead" style="--kx: {coord[0]}; --ky: {coord[1]}"></div>
{:else}
  <div
    class="key"
    class:key--pass={key.pass}
    class:key--mod={key.kind === 'word' && !key.icon}
    class:key--layerkey={key.layerKey}
    class:key--home={home}
    data-finger={finger}
    data-cap={cap}
    data-live={live}
    style="--kx: {coord[0]}; --ky: {coord[1]}; --kh: {coord[2] ?? 1}; --kr: {coord[3] ?? 0}deg"
  >
    {#if key.kind === 'char'}
      <span class="glyph">{out ?? '·'}</span>
      {#if sub}<span class="sub">{sub}</span>{/if}
    {:else if key.icon}
      <Icon name={key.icon} label={key.glyph} />
      <span class="sub">{key.glyph}</span>
    {:else}
      <span class="glyph" class:glyph--word={key.kind === 'word'}>{key.glyph}</span>
    {/if}
  </div>
{/if}

<style>
  .key {
    --cap: var(--cap-none);
    --cap-ink: var(--key-ink);
    --cap-sub: var(--key-sub);
    --hatch: oklch(0% 0 0 / 0.11);
    --kh: 1;
    --kr: 0deg;
    --lift: 0px;

    position: absolute;
    inset-block-start: 0;
    inset-inline-start: 0;
    inline-size: calc(var(--u) * 0.9);
    block-size: calc(var(--u) * (var(--kh) - 0.1));
    translate: calc(var(--kx) * var(--u)) calc(var(--ky) * var(--u) - var(--lift));
    rotate: var(--kr);

    display: grid;
    place-content: center;
    gap: 0.1em;
    text-align: center;

    border-radius: calc(var(--u) * 0.12);
    background: var(--cap);
    box-shadow:
      inset 0 calc(var(--u) * -0.055) 0 oklch(from var(--cap) calc(l - 0.09) calc(c + 0.02) h),
      0 1px 2px var(--key-shadow);
    transition: --lift var(--tick) ease-out, box-shadow var(--tick) ease-out;
  }

  .key[data-cap="white"] { --cap: var(--cap-white); }
  .key[data-cap="dark"] { --cap: var(--cap-dark); }

  .key[data-cap="blue"] {
    --cap: var(--cap-blue);
    --cap-sub: var(--sub-on-blue);
  }

  .key[data-cap="red"] {
    --cap: var(--cap-red);
    --cap-ink: oklch(99% 0 0);
    --cap-sub: var(--sub-on-red);
  }

  .key[data-cap="green"] {
    --cap: var(--cap-green);
    --cap-sub: var(--sub-on-green);
  }

  .key[data-cap="grey"] {
    --cap: var(--cap-grey);
    --cap-sub: var(--sub-on-grey);
  }

  .key[data-cap="cyan"] {
    --cap: var(--cap-cyan);
    --cap-sub: var(--sub-on-cyan);
  }

  .key[data-cap="yellow"] {
    --cap: var(--cap-yellow);
    --cap-sub: var(--sub-on-yellow);
  }

  .key[data-cap="purple"] {
    --cap: var(--cap-purple);
    --cap-sub: var(--sub-on-purple);
  }

  .key[data-cap="steel"] {
    --cap: var(--cap-steel);
    --cap-sub: var(--sub-on-steel);
  }

  .key[data-cap="orange"] {
    --cap: var(--cap-orange);
    --cap-sub: var(--sub-on-orange);
  }

  .key[data-cap="wine"] {
    --cap: var(--cap-wine);
    --cap-ink: oklch(99% 0 0);
    --cap-sub: var(--sub-on-wine);
  }

  .key[data-cap="black"] {
    --cap: var(--cap-black);
    --cap-ink: oklch(97% 0 0);
    --cap-sub: var(--sub-on-black);
    --hatch: oklch(100% 0 0 / 0.12);
  }

  .key[data-finger="index2"]::before {
    content: "";
    position: absolute;
    inset: 0;
    border-radius: inherit;
    background: repeating-linear-gradient(135deg, var(--hatch) 0 2px, transparent 2px 5px);
    pointer-events: none;
  }

  .glyph, .sub {
    font-variant-ligatures: none;
    font-feature-settings: "liga" 0, "calt" 0, "dlig" 0;
    font-family: var(--mono);
    line-height: 1;
    white-space: nowrap;
  }

  .glyph {
    font-size: calc(var(--u) * 0.33);
    color: var(--cap-ink);
  }

  .glyph--word {
    font-size: calc(var(--u) * 0.17);
    letter-spacing: 0.06em;
    text-transform: uppercase;
  }

  .sub {
    font-size: calc(var(--u) * 0.135);
    letter-spacing: 0.04em;
    color: var(--cap-sub);
  }

  .key--dead {
    background: none;
    border: 1px dashed var(--rule);
    box-shadow: none;
  }

  .key--pass { opacity: 0.42; }

  .key--mod .glyph { color: color-mix(in oklch, var(--cap-ink) 74%, transparent); }

  .key--home::after {
    content: "";
    position: absolute;
    inset-block-end: calc(var(--u) * 0.12);
    inset-inline: 34%;
    block-size: calc(var(--u) * 0.045);
    border-radius: 99px;
    background: oklch(from var(--cap) calc(l - 0.28) calc(c + 0.05) h);
  }

  .key--layerkey {
    outline: calc(var(--u) * 0.035) solid var(--key-mark);
    outline-offset: calc(var(--u) * -0.035);
  }

  .key[data-live] {
    --lift: calc(var(--u) * 0.07);
    z-index: 2;
    box-shadow:
      0 0 0 calc(var(--u) * 0.055) var(--live),
      inset 0 calc(var(--u) * -0.055) 0 oklch(from var(--cap) calc(l - 0.09) calc(c + 0.02) h),
      0 calc(var(--u) * 0.09) calc(var(--u) * 0.16) oklch(from var(--live) l c h / 0.32);
  }

  .key[data-live="primary"] { --cap: oklch(from var(--live) 93% 0.09 h); }

  @media (prefers-reduced-motion: reduce) {
    .key { transition: none; }
  }
</style>
