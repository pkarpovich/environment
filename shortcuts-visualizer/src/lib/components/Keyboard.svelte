<script lang="ts">
  import type { HighlightedKey } from '../types'
  import Key from './Key.svelte'
  import { ARROWS, getKeyboardLayout, type KeyboardLang } from '../data/shortcuts'

  interface Props {
    highlightedKeys?: HighlightedKey[]
    showLeaderMode?: boolean
    hoveredKeyId?: string | null
    onKeyHover?: (keyId: string) => void
    onKeyLeave?: () => void
  }

  let { highlightedKeys = [], showLeaderMode = false, hoveredKeyId = null, onKeyHover, onKeyLeave }: Props = $props()

  let lang = $state<KeyboardLang>('en')
  const layout = $derived(getKeyboardLayout(lang))

  function toggleLang() {
    lang = lang === 'en' ? 'ru' : 'en'
  }
</script>

<div class="keyboard-container">
  <div class={['mode-indicator', showLeaderMode && 'visible']}>
    Leader Mode
  </div>
  <button class="lang-toggle" onclick={toggleLang} title="Switch keyboard layout">
    {lang.toUpperCase()}
  </button>
  <div class="keyboard">
    {#each layout as row}
      <div class="keyboard-row">
        {#each row as keyData}
          <Key {keyData} {highlightedKeys} {hoveredKeyId} {onKeyHover} {onKeyLeave} />
        {/each}
      </div>
    {/each}
    <div class="keyboard-row arrows">
      {#each ARROWS as keyData}
        <Key {keyData} {highlightedKeys} {hoveredKeyId} {onKeyHover} {onKeyLeave} />
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

  .lang-toggle {
    position: absolute;
    top: -12px;
    left: 20px;
    background: var(--bg-tertiary);
    padding: 6px 12px;
    border-radius: 20px;
    font-size: 11px;
    font-weight: 600;
    color: var(--text-secondary);
    border: 1px solid var(--border-color);
    text-transform: uppercase;
    letter-spacing: 1px;
    cursor: pointer;
    transition: all 0.2s ease;
    font-family: 'JetBrains Mono', monospace;
  }

  .lang-toggle:hover {
    border-color: var(--accent-cyan);
    color: var(--accent-cyan);
  }
</style>
