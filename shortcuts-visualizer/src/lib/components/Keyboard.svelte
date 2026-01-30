<script lang="ts">
  import type { HighlightedKey } from '../types'
  import Key from './Key.svelte'
  import { ARROWS, getKeyboardLayout, getShiftLayout, getAltLayout, type KeyboardLang } from '../data/shortcuts'

  interface Props {
    highlightedKeys?: HighlightedKey[]
    heatmapKeys?: HighlightedKey[]
    modifierHighlights?: HighlightedKey[]
    showLeaderMode?: boolean
    hoveredKeyId?: string | null
    showHeatmap?: boolean
    onKeyHover?: (keyId: string) => void
    onKeyLeave?: () => void
    onToggleHeatmap?: () => void
  }

  let { highlightedKeys = [], heatmapKeys = [], modifierHighlights = [], showLeaderMode = false, hoveredKeyId = null, showHeatmap = false, onKeyHover, onKeyLeave, onToggleHeatmap }: Props = $props()

  const effectiveHighlights = $derived(
    highlightedKeys.length > 0 ? highlightedKeys :
    modifierHighlights.length > 0 ? modifierHighlights :
    showHeatmap ? heatmapKeys :
    []
  )

  let lang = $state<KeyboardLang>('en')
  let shiftHeld = $state(false)
  let altHeld = $state(false)

  const layout = $derived(
    altHeld ? getAltLayout(lang) :
    shiftHeld ? getShiftLayout(lang) :
    getKeyboardLayout(lang)
  )

  function toggleLang() {
    lang = lang === 'en' ? 'ru' : 'en'
  }

  function handleKeyDown(e: KeyboardEvent) {
    if (e.key === 'Shift') shiftHeld = true
    if (e.key === 'Alt') altHeld = true
  }

  function handleKeyUp(e: KeyboardEvent) {
    if (e.key === 'Shift') shiftHeld = false
    if (e.key === 'Alt') altHeld = false
  }

  $effect(() => {
    window.addEventListener('keydown', handleKeyDown)
    window.addEventListener('keyup', handleKeyUp)
    return () => {
      window.removeEventListener('keydown', handleKeyDown)
      window.removeEventListener('keyup', handleKeyUp)
    }
  })
</script>

<div class="keyboard-container">
  <div class={['mode-indicator', showLeaderMode && 'visible']}>
    Leader Mode
  </div>
  <div class={['mode-indicator shift-indicator', shiftHeld && 'visible']}>
    Shift Layer
  </div>
  <div class={['mode-indicator alt-indicator', altHeld && 'visible']}>
    Alt Layer
  </div>
  <div class="toolbar">
    <button class="toolbar-btn" onclick={toggleLang} title="Switch keyboard layout">
      {lang.toUpperCase()}
    </button>
    <button
      class={['toolbar-btn', showHeatmap && 'active']}
      onclick={onToggleHeatmap}
      title="Toggle heatmap"
    >
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2z" />
        <path d="M12 6v6l4 2" />
      </svg>
    </button>
  </div>
  <div class="keyboard">
    {#each layout as row}
      <div class="keyboard-row">
        {#each row as keyData}
          <Key {keyData} highlightedKeys={effectiveHighlights} {hoveredKeyId} {onKeyHover} {onKeyLeave} />
        {/each}
      </div>
    {/each}
    <div class="keyboard-row arrows">
      {#each ARROWS as keyData}
        <Key {keyData} highlightedKeys={effectiveHighlights} {hoveredKeyId} {onKeyHover} {onKeyLeave} />
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

  .shift-indicator {
    right: auto;
    left: 140px;
    color: var(--accent-cyan);
    border-color: var(--accent-cyan);
  }

  .alt-indicator {
    right: auto;
    left: 140px;
    color: var(--accent-magenta);
    border-color: var(--accent-magenta);
  }

  .toolbar {
    position: absolute;
    top: -12px;
    left: 20px;
    display: flex;
    gap: 8px;
  }

  .toolbar-btn {
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
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 4px;
  }

  .toolbar-btn:hover {
    border-color: var(--accent-cyan);
    color: var(--accent-cyan);
  }

  .toolbar-btn.active {
    background: linear-gradient(135deg, rgba(58, 169, 159, 0.2), rgba(58, 169, 159, 0.1));
    border-color: var(--accent-cyan);
    color: var(--accent-cyan);
  }
</style>
