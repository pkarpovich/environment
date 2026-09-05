<script>
  import { topRowOutputs, baseDrift, optionOnly, unreachable } from './keymap.js'

  let { lang } = $props()

  const lowerRow = $derived(topRowOutputs(1, lang))
  const raiseRow = $derived(topRowOutputs(2, lang))
  const drift = $derived(baseDrift(lang))
  const viaOption = $derived(optionOnly(lang))
  const missing = $derived(unreachable(lang))
</script>

<section class="notes">
  <h2>What matters here</h2>

  <p>
    The large glyph on a key is <b>what actually gets typed</b> with your macOS "Universal" layout.
    The small one below is what the keycap says and what QMK calls that key. Where there is no small
    one, the two agree.
  </p>

  <p>
    <b>Digits and symbols are swapped.</b> Universal puts symbols on the unshifted row and digits
    behind Shift. The stock firmware does not know that, so the top row of <b>Lower</b> types
    <code>{lowerRow}</code> while the top row of <b>Raise</b> types <code>{raiseRow}</code>.
  </p>

  {#if drift.length}
    <p>On the base layer these disagree:</p>
    <div class="drift">
      {#each drift as row (row.us)}
        <span class="from">keycap {row.us}</span>
        <span class="to">{row.out}</span>
        <span class="why">{row.shift === row.out ? 'same with Shift' : `with Shift - ${row.shift}`}</span>
      {/each}
    </div>
  {/if}

  {#if viaOption.length}
    <p><b>Option only.</b> Without it these characters are not on the keyboard at all:</p>
    <div class="drift">
      {#each viaOption as row (row.ch)}
        <span class="to">{row.ch}</span>
        <span class="from">{row.hint}</span>
        <span class="why"></span>
      {/each}
    </div>
  {/if}

  {#if missing.length}
    <p><b>Not reachable by any combination:</b> <code>{missing.join('  ')}</code></p>
  {/if}
</section>

<style>
  .notes {
    display: flex;
    flex-direction: column;
    gap: var(--space-sm);
    padding: var(--space-md);
    border: 1px solid var(--rule);
    border-inline-start: 3px solid var(--live);
    border-radius: var(--radius-md);
    background: var(--paper-raised);
    font-size: 0.88rem;
    color: var(--ink-soft);
    text-wrap: pretty;
  }

  h2 {
    font-size: 0.82rem;
    text-transform: uppercase;
    letter-spacing: 0.2em;
    color: var(--ink);
  }

  b { color: var(--ink); font-weight: 600; }

  .drift {
    display: grid;
    grid-template-columns: auto auto 1fr;
    gap: 0.15em var(--space-sm);
    align-items: baseline;
    font-family: var(--mono);
    font-size: 0.85rem;
    font-variant-ligatures: none;
    font-feature-settings: "liga" 0, "calt" 0;
  }

  .from { color: var(--ink-faint); }
  .to { color: var(--live); font-weight: 600; }
  .why { font-family: var(--sans); }
</style>
