<script>
  import Board from './lib/Board.svelte'
  import Notes from './lib/Notes.svelte'
  import {
    FINGER_NAMES, LAYER_META, fingerAt, handAt, usLabelForCode, findIndexByCode, layerForCode,
  } from './lib/keymap.js'
  import { connectKeytap } from './lib/keytap.js'

  const NO_SCROLL = new Set(['Space', 'Tab', 'ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Backspace', 'Enter'])

  const NAMED = new Set([
    'Shift', 'Control', 'Alt', 'Meta', 'Enter', 'Tab', 'Backspace', 'Escape', 'CapsLock',
    'ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Dead', 'Unidentified', 'Process',
    'ContextMenu', 'Home', 'End', 'PageUp', 'PageDown', 'Delete', 'Insert',
  ])

  const SHIFT_CODES = new Set(['ShiftLeft', 'ShiftRight'])
  const ALT_CODES = new Set(['AltLeft', 'AltRight'])
  const FINGER_ORDER = ['pinky2', 'pinky', 'ring', 'middle', 'index', 'index2', 'thumb']

  const printable = (key) => !NAMED.has(key) && !/^F\d+$/.test(key) && key.length <= 4

  let mode = $state(localStorage.getItem('corne-mode') === 'live' ? 'live' : 'sheet')
  let lang = $state('en')
  let shift = $state(false)
  let alt = $state(false)
  let pressed = $state([])
  let last = $state(null)
  let activeLayer = $state(0)
  let tap = $state('off')

  const mods = $derived({ shift, alt })

  $effect(() => {
    localStorage.setItem('corne-mode', mode)
    document.body.classList.toggle('is-live', mode === 'live')
  })

  $effect(() => connectKeytap({
    onPress: press,
    onRelease: release,
    onStatus: (status) => {
      if (status !== tap) clear()
      tap = status
    },
  }))

  const readout = $derived.by(() => {
    if (!last) return null
    const index = findIndexByCode(last.code)
    if (index === -1) return { unknown: last.code }
    return {
      hand: handAt(index),
      finger: FINGER_NAMES[fingerAt(index)],
      us: usLabelForCode(last.code),
      out: last.char,
    }
  })

  function followOsLanguage(char) {
    if (!char) return
    const wanted = /[Ѐ-ӿ]/.test(char) ? 'ru' : /[a-zA-Z]/.test(char) ? 'en' : null
    if (wanted && wanted !== lang) lang = wanted
  }

  function press(code, char, shiftFlag, altFlag) {
    shift = shiftFlag ?? (SHIFT_CODES.has(code) ? true : shift)
    alt = altFlag ?? (ALT_CODES.has(code) ? true : alt)
    followOsLanguage(char)

    const layer = layerForCode(code, shift)
    if (layer !== null) activeLayer = layer

    if (!pressed.some((p) => p.code === code)) pressed = [...pressed, { code, char }]
    last = { code, char }
  }

  function release(code, shiftFlag, altFlag) {
    shift = shiftFlag ?? (SHIFT_CODES.has(code) ? false : shift)
    alt = altFlag ?? (ALT_CODES.has(code) ? false : alt)
    pressed = pressed.filter((p) => p.code !== code)
  }

  function clear() {
    pressed = []
    shift = false
    alt = false
  }

  function handleKeydown(event) {
    if (event.metaKey || event.ctrlKey) return
    if (NO_SCROLL.has(event.code)) event.preventDefault()
    if (tap === 'on') return

    press(event.code, printable(event.key) ? event.key : null, event.shiftKey, event.altKey)
  }

  function handleKeyup(event) {
    if (tap === 'on') return
    release(event.code, event.shiftKey, event.altKey)
  }

  function reset() {
    if (tap === 'on') return
    clear()
  }
</script>

<svelte:window onkeydown={handleKeydown} onkeyup={handleKeyup} onblur={reset} />

<header class="masthead">
  <div class="id">
    <h1>Corne v4.1</h1>
    {#if mode === 'sheet'}<p class="spec">46 keys · split 3×6+3 ex2 · stock QMK</p>{/if}
  </div>

  <div class="controls">
    <fieldset class="segmented">
      <legend>Mode</legend>
      <label>
        <input type="radio" name="mode" value="sheet" bind:group={mode} />
        <span>sheet</span>
      </label>
      <label>
        <input type="radio" name="mode" value="live" bind:group={mode} />
        <span>live</span>
      </label>
    </fieldset>

    <fieldset class="segmented">
      <legend>Layout</legend>
      <label>
        <input type="radio" name="lang" value="en" bind:group={lang} />
        <span>EN</span>
      </label>
      <label>
        <input type="radio" name="lang" value="ru" bind:group={lang} />
        <span>RU</span>
      </label>
    </fieldset>

    <p class="tap" data-state={tap}>
      <i></i>
      {#if tap === 'on'}
        catching keys in the background
      {:else}
        focused window only - run <code>mise run tap</code>
      {/if}
    </p>
  </div>
</header>

{#if mode === 'live'}
  <section class="live">
    <div class="bar">
      <span class="chip chip--layer" title="Layer is inferred from the last key pressed: the firmware never tells the host about Lower and Raise">
        ≈ {LAYER_META[activeLayer].title}
      </span>
      <span class="chip" class:chip--on={shift}>Shift</span>
      <span class="chip" class:chip--on={alt}>Option</span>
      <span class="bar-hint">layer inferred from the last key, Shift and Option are live</span>

      {#if readout && !readout.unknown}
        <span class="bar-readout">
          <span class="tag">{readout.hand} · {readout.finger}</span>
          {#if readout.us}<b>{readout.us}</b>{/if}
          {#if readout.out}<span class="arrow">→</span><span class="out">{readout.out}</span>{/if}
        </span>
      {/if}
    </div>

    <Board layer={activeLayer} {lang} {mods} {pressed} bare />
  </section>
{:else}
  <div class="readout" aria-live="polite">
    {#if !readout}
      <span class="idle">press any key</span>
    {:else if readout.unknown}
      <span class="idle">{readout.unknown} - no such key on the Corne</span>
    {:else}
      <span class="tag">{readout.hand} · {readout.finger}</span>
      {#if readout.us}<b>{readout.us}</b>{/if}
      {#if readout.out}<span class="arrow">→</span><span class="out">{readout.out}</span>{/if}
    {/if}
  </div>

  <main>
    <Board layer={0} {lang} {mods} {pressed} />

    <div class="pair">
      <Board layer={1} {lang} {mods} {pressed} />
      <Board layer={2} {lang} {mods} {pressed} />
    </div>

    <Board layer={3} {lang} {mods} {pressed} minor />

    <section class="legend">
      <h2>Fingers</h2>
      <ul>
        {#each FINGER_ORDER as finger (finger)}
          <li><i data-finger={finger}></i>{FINGER_NAMES[finger]}</li>
        {/each}
      </ul>
    </section>

    <Notes {lang} />
  </main>
{/if}

<style>
  .masthead {
    display: flex;
    flex-wrap: wrap;
    align-items: end;
    justify-content: space-between;
    gap: var(--space-md) var(--space-xl);
    max-inline-size: 96rem;
    margin-inline: auto;
    padding-block-end: var(--space-sm);
    border-block-end: 1px solid var(--rule);
  }

  h1 {
    font-size: clamp(1.4rem, 0.9rem + 1.6vw, 2rem);
    letter-spacing: -0.02em;
    text-box: trim-both cap alphabetic;
  }

  .spec {
    font-family: var(--mono);
    font-size: 0.76rem;
    letter-spacing: 0.06em;
    color: var(--ink-faint);
    margin-block-start: 0.5em;
  }

  .controls {
    display: flex;
    align-items: center;
    gap: var(--space-md);
    flex-wrap: wrap;
  }

  .segmented {
    display: flex;
    align-items: center;
    gap: var(--space-xs);
  }

  .segmented legend {
    float: inline-start;
    font-family: var(--mono);
    font-size: 0.68rem;
    text-transform: uppercase;
    letter-spacing: 0.14em;
    color: var(--ink-faint);
    margin-inline-end: var(--space-xs);
    padding-block-start: 0.35em;
  }

  .segmented label { cursor: pointer; }

  .segmented input {
    position: absolute;
    opacity: 0;
    pointer-events: none;
  }

  .segmented span {
    display: block;
    font-family: var(--mono);
    font-size: 0.8rem;
    letter-spacing: 0.08em;
    padding: 0.28em 0.85em;
    border: 1px solid var(--rule);
    border-radius: var(--radius-sm);
    background: var(--paper-raised);
    color: var(--ink-soft);
    transition: background var(--tick), color var(--tick), border-color var(--tick);
  }

  .segmented input:checked + span {
    background: var(--ink);
    border-color: var(--ink);
    color: var(--paper);
  }

  .segmented input:focus-visible + span {
    outline: 2px solid var(--live);
    outline-offset: 2px;
  }

  .tap {
    display: flex;
    align-items: center;
    gap: 0.45em;
    font-size: 0.78rem;
    color: var(--ink-soft);
  }

  .tap i {
    inline-size: 0.55em;
    block-size: 0.55em;
    border-radius: 50%;
    background: var(--ink-faint);
  }

  .tap[data-state="on"] i {
    background: oklch(68% 0.17 156);
    box-shadow: 0 0 0 3px oklch(68% 0.17 156 / 0.22);
  }

  .readout {
    max-inline-size: 96rem;
    margin-inline: auto;
    margin-block: var(--space-md) var(--space-lg);
    padding: var(--space-xs) var(--space-sm);
    border: 1px solid var(--rule);
    border-radius: var(--radius-md);
    background: var(--paper-raised);
    font-family: var(--mono);
    font-size: 0.9rem;
    font-variant-ligatures: none;
    font-feature-settings: "liga" 0, "calt" 0;
    display: flex;
    align-items: center;
    gap: 0.6em;
    min-block-size: 2.9em;
    flex-wrap: wrap;
  }

  .idle { color: var(--ink-faint); }

  .readout b, .bar b {
    font-weight: 600;
    font-size: 1.15em;
  }

  .tag {
    font-size: 0.72rem;
    text-transform: uppercase;
    letter-spacing: 0.12em;
    color: var(--ink-faint);
  }

  .arrow { color: var(--ink-faint); }

  .out {
    color: var(--live);
    font-weight: 600;
    font-size: 1.15em;
  }

  main {
    display: flex;
    flex-direction: column;
    gap: var(--space-xl);
    max-inline-size: 96rem;
    margin-inline: auto;
  }

  .pair {
    display: grid;
    grid-template-columns: 1fr;
    gap: var(--space-xl);
  }

  @media (width > 92rem) {
    .pair { grid-template-columns: 1fr 1fr; }
  }

  .live {
    display: grid;
    grid-template-rows: auto minmax(0, 1fr);
    gap: var(--space-sm);
    block-size: calc(100dvh - 7.5rem);
    max-inline-size: 96rem;
    margin-inline: auto;
    padding-block-start: var(--space-sm);
  }

  .bar {
    display: flex;
    align-items: center;
    gap: var(--space-xs);
    flex-wrap: wrap;
    font-family: var(--mono);
    font-size: 0.9rem;
    font-variant-ligatures: none;
    font-feature-settings: "liga" 0, "calt" 0;
  }

  .chip {
    font-size: 0.72rem;
    text-transform: uppercase;
    letter-spacing: 0.12em;
    padding: 0.3em 0.7em;
    border: 1px solid var(--rule);
    border-radius: var(--radius-sm);
    background: var(--paper-raised);
    color: var(--ink-faint);
    transition: background var(--tick), color var(--tick), border-color var(--tick);
  }

  .chip--layer {
    background: var(--ink);
    border-color: var(--ink);
    color: var(--paper);
  }

  .chip--on {
    background: var(--live);
    border-color: var(--live);
    color: var(--paper);
  }

  .bar-hint {
    font-family: var(--sans);
    font-size: 0.76rem;
    color: var(--ink-faint);
  }

  .bar-readout {
    display: flex;
    align-items: center;
    gap: 0.5em;
    margin-inline-start: auto;
  }

  .legend h2 {
    font-size: 0.82rem;
    text-transform: uppercase;
    letter-spacing: 0.2em;
    color: var(--ink-soft);
    margin-block-end: var(--space-sm);
  }

  .legend ul {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-xs) var(--space-lg);
    font-size: 0.84rem;
    color: var(--ink-soft);
  }

  .legend li {
    display: flex;
    align-items: center;
    gap: 0.5em;
  }

  .legend i {
    inline-size: 1.1em;
    block-size: 1.1em;
    border-radius: var(--radius-sm);
    background: var(--cap, var(--cap-none));
    box-shadow: inset 0 -2px 0 oklch(from var(--cap, var(--cap-none)) calc(l - 0.09) calc(c + 0.02) h);
  }

  .legend i[data-finger="pinky2"] { --cap: var(--cap-white); }
  .legend i[data-finger="pinky"]  { --cap: var(--cap-blue); }
  .legend i[data-finger="ring"]   { --cap: var(--cap-red); }
  .legend i[data-finger="middle"] { --cap: var(--cap-green); }
  .legend i[data-finger="index"]  { --cap: var(--cap-grey); }
  .legend i[data-finger="thumb"]  { --cap: var(--cap-dark); }

  .legend i[data-finger="index2"] {
    --cap: var(--cap-black);
    background:
      repeating-linear-gradient(135deg, oklch(100% 0 0 / 0.14) 0 2px, transparent 2px 5px),
      var(--cap-black);
  }
</style>
