<script lang="ts">
  import type { Shortcut, HighlightedKey } from './lib/types'
  import Sidebar from './lib/components/Sidebar.svelte'
  import Keyboard from './lib/components/Keyboard.svelte'
  import { normalizeActionKey } from './lib/data/shortcuts'

  let currentApp = $state('wezterm')
  let selectedShortcut = $state<Shortcut | null>(null)
  let hoveredShortcut = $state<Shortcut | null>(null)

  const activeShortcut = $derived(hoveredShortcut || selectedShortcut)
  const showLeaderMode = $derived(activeShortcut?.leader === true)

  const highlightedKeys = $derived((): HighlightedKey[] => {
    if (!activeShortcut) return []

    const keys: HighlightedKey[] = []
    const isLeader = activeShortcut.leader === true

    if (activeShortcut.keys.includes('ALT')) {
      keys.push({ id: 'alt-l', type: 'highlight-alt' })
      keys.push({ id: 'alt-r', type: 'highlight-alt' })
    }

    if (activeShortcut.keys.includes('SHIFT')) {
      keys.push({ id: 'shift-l', type: 'highlight-shift' })
      keys.push({ id: 'shift-r', type: 'highlight-shift' })
    }

    if (isLeader) {
      keys.push({ id: 'l', type: 'highlight-leader' })
    }

    activeShortcut.actionKeys.forEach(key => {
      const keyId = normalizeActionKey(key)
      keys.push({ id: keyId, type: isLeader ? 'highlight-leader' : 'highlight-action' })
    })

    return keys
  })

  function handleAppChange(appId: string) {
    currentApp = appId
    selectedShortcut = null
    hoveredShortcut = null
  }

  function handleShortcutHover(shortcut: Shortcut) {
    hoveredShortcut = shortcut
  }

  function handleShortcutLeave() {
    hoveredShortcut = null
  }

  function handleShortcutClick(shortcut: Shortcut) {
    if (selectedShortcut === shortcut) {
      selectedShortcut = null
    } else {
      selectedShortcut = shortcut
    }
  }
</script>

<div class="container">
  <Sidebar
    {currentApp}
    {selectedShortcut}
    onAppChange={handleAppChange}
    onShortcutHover={handleShortcutHover}
    onShortcutLeave={handleShortcutLeave}
    onShortcutClick={handleShortcutClick}
  />

  <main class="main-content">
    <div class="current-shortcut">
      <div class="current-shortcut-label">Selected Shortcut</div>
      {#if activeShortcut}
        <div class="current-shortcut-text">{activeShortcut.keys.join(' + ')}</div>
        <div class="current-shortcut-action">{activeShortcut.action}</div>
      {:else}
        <div class="current-shortcut-text">Hover over a shortcut</div>
        <div class="current-shortcut-action"></div>
      {/if}
    </div>

    <Keyboard highlightedKeys={highlightedKeys()} {showLeaderMode} />

    <div class="legend">
      <div class="legend-item">
        <div class="legend-color mod-alt"></div>
        <span>ALT</span>
      </div>
      <div class="legend-item">
        <div class="legend-color mod-shift"></div>
        <span>SHIFT</span>
      </div>
      <div class="legend-item">
        <div class="legend-color mod-action"></div>
        <span>Action Key</span>
      </div>
      <div class="legend-item">
        <div class="legend-color mod-leader"></div>
        <span>Leader Combo</span>
      </div>
    </div>
  </main>
</div>

<style>
  .container {
    display: flex;
    min-height: 100vh;
    position: relative;
    z-index: 1;
  }

  .main-content {
    flex: 1;
    padding: 40px;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 32px;
  }

  .current-shortcut {
    text-align: center;
    min-height: 60px;
  }

  .current-shortcut-label {
    font-size: 11px;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 1px;
    margin-bottom: 8px;
  }

  .current-shortcut-text {
    font-family: 'JetBrains Mono', monospace;
    font-size: 18px;
    color: var(--accent-cyan);
    font-weight: 600;
  }

  .current-shortcut-action {
    font-size: 14px;
    color: var(--text-secondary);
    margin-top: 4px;
  }

  .legend {
    display: flex;
    gap: 24px;
    justify-content: center;
    flex-wrap: wrap;
  }

  .legend-item {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 12px;
    color: var(--text-secondary);
  }

  .legend-color {
    width: 16px;
    height: 16px;
    border-radius: 4px;
  }

  .legend-color.mod-alt {
    background: linear-gradient(135deg, rgba(198, 120, 221, 0.5), rgba(198, 120, 221, 0.25));
    border: 1px solid var(--accent-magenta);
  }

  .legend-color.mod-shift {
    background: linear-gradient(135deg, rgba(57, 197, 207, 0.5), rgba(57, 197, 207, 0.25));
    border: 1px solid var(--accent-cyan);
  }

  .legend-color.mod-action {
    background: linear-gradient(135deg, rgba(229, 192, 123, 0.5), rgba(229, 192, 123, 0.25));
    border: 1px solid var(--accent-orange);
  }

  .legend-color.mod-leader {
    background: linear-gradient(135deg, rgba(152, 195, 121, 0.5), rgba(152, 195, 121, 0.25));
    border: 1px solid var(--accent-green);
  }
</style>
