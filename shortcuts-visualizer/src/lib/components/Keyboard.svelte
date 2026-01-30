<script lang="ts">
  import type { HighlightedKey } from '../types'
  import Key from './Key.svelte'
  import { KEYBOARD_LAYOUT, ARROWS } from '../data/shortcuts'

  interface Props {
    highlightedKeys?: HighlightedKey[]
    showLeaderMode?: boolean
  }

  let { highlightedKeys = [], showLeaderMode = false }: Props = $props()
</script>

<div class="keyboard-container">
  <div class={['mode-indicator', showLeaderMode && 'visible']}>
    Leader Mode
  </div>
  <div class="keyboard">
    {#each KEYBOARD_LAYOUT as row}
      <div class="keyboard-row">
        {#each row as keyData}
          <Key {keyData} {highlightedKeys} />
        {/each}
      </div>
    {/each}
    <div class="keyboard-row arrows">
      {#each ARROWS as keyData}
        <Key {keyData} {highlightedKeys} />
      {/each}
    </div>
  </div>
</div>

<style>
  .keyboard-container {
    position: relative;
  }

  .keyboard {
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding: 40px;
    background: var(--bg-secondary);
    border-radius: 24px;
    border: 1px solid var(--border-color);
    box-shadow:
      0 4px 24px rgba(0, 0, 0, 0.4),
      inset 0 1px 0 rgba(255, 255, 255, 0.03);
  }

  .keyboard-row {
    display: flex;
    gap: 10px;
    justify-content: center;
  }

  .keyboard-row.arrows {
    margin-top: 10px;
    margin-left: auto;
  }

  .mode-indicator {
    position: absolute;
    top: -12px;
    right: 20px;
    background: var(--bg-tertiary);
    padding: 6px 14px;
    border-radius: 20px;
    font-size: 11px;
    font-weight: 600;
    color: var(--accent-green);
    border: 1px solid var(--accent-green);
    text-transform: uppercase;
    letter-spacing: 1px;
    opacity: 0;
    transition: opacity 0.3s ease;
  }

  .mode-indicator.visible {
    opacity: 1;
  }
</style>
