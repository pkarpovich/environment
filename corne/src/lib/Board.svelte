<script>
  import { LAYERS, LAYER_META, parseToken, outputOf } from './keymap.js'
  import Key from './Key.svelte'

  let { layer, lang, mods, pressed, minor = false, bare = false } = $props()

  const meta = $derived(LAYER_META[layer])
  const tokens = $derived(LAYERS[layer])

  function liveState(token, index) {
    const key = parseToken(token, index)
    if (!key.code) return undefined
    const hit = pressed.find((p) => p.code === key.code)
    if (!hit) return undefined
    return hit.char && outputOf(key, lang, mods) === hit.char ? 'primary' : 'on'
  }
</script>

<section class="block" class:block--minor={minor} class:block--bare={bare}>
  {#if !bare}
    <div class="head">
      <h2>{meta.title}</h2>
      <p>{meta.note}</p>
    </div>
  {/if}
  <div class="board">
    {#each tokens as token, index (index)}
      <Key {token} {index} {lang} {mods} live={liveState(token, index)} />
    {/each}
  </div>
</section>

<style>
  .block { container-type: inline-size; }

  .head {
    display: flex;
    align-items: baseline;
    gap: var(--space-md);
    flex-wrap: wrap;
    margin-block-end: var(--space-sm);
  }

  h2 {
    font-size: 0.82rem;
    text-transform: uppercase;
    letter-spacing: 0.2em;
    color: var(--ink-soft);
  }

  p {
    font-size: 0.86rem;
    color: var(--ink-soft);
    text-wrap: pretty;
  }

  .board {
    --u: calc(100cqi / 15.2);
    position: relative;
    inline-size: calc(var(--u) * 15);
    block-size: calc(var(--u) * 5.25);
    margin-inline: auto;
  }

  .block--minor .board { --u: calc(100cqi / 19); }

  .block--bare {
    container-type: size;
    min-block-size: 0;
    display: grid;
    place-content: center;
  }

  .block--bare .board {
    --u: min(calc(100cqi / 15.4), calc(100cqb / 5.5));
    margin-inline: 0;
  }
</style>
