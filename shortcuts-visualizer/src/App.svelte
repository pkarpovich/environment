<script lang="ts">
  import type { Shortcut, HighlightedKey } from './lib/types'
  import Sidebar from './lib/components/Sidebar.svelte'
  import Keyboard from './lib/components/Keyboard.svelte'
  import { normalizeActionKey, SHORTCUTS_DATA } from './lib/data/shortcuts'

  let currentApp = $state('wezterm')
  let selectedShortcut = $state<Shortcut | null>(null)
  let hoveredShortcut = $state<Shortcut | null>(null)

  const activeShortcut = $derived(hoveredShortcut || selectedShortcut)
  const showLeaderMode = $derived(activeShortcut?.leader === true)

  const allUsedKeys = $derived((): HighlightedKey[] => {
    const appData = SHORTCUTS_DATA[currentApp]
    if (!appData) return []

    const keyFrequency = new Map<string, number>()

    const incrementKey = (key: string) => {
      keyFrequency.set(key, (keyFrequency.get(key) || 0) + 1)
    }

    appData.groups.forEach(group => {
      group.shortcuts.forEach(shortcut => {
        if (shortcut.keys.includes('ALT')) {
          incrementKey('alt-l')
          incrementKey('alt-r')
        }
        if (shortcut.keys.includes('SHIFT')) {
          incrementKey('shift-l')
          incrementKey('shift-r')
        }
        if (shortcut.leader) {
          incrementKey('l')
        }
        shortcut.actionKeys.forEach(key => {
          incrementKey(normalizeActionKey(key))
        })
      })
    })

    const maxFreq = Math.max(...keyFrequency.values())

    const getHeatLevel = (freq: number): HighlightedKey['type'] => {
      const ratio = freq / maxFreq
      if (ratio > 0.8) return 'highlight-heat-5'
      if (ratio > 0.6) return 'highlight-heat-4'
      if (ratio > 0.4) return 'highlight-heat-3'
      if (ratio > 0.2) return 'highlight-heat-2'
      return 'highlight-heat-1'
    }

    return Array.from(keyFrequency.entries()).map(([id, freq]) => ({
      id,
      type: getHeatLevel(freq)
    }))
  })

  const highlightedKeys = $derived((): HighlightedKey[] => {
    if (!activeShortcut) return allUsedKeys()

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
      {#key activeShortcut}
        <div class="current-shortcut-content">
          {#if activeShortcut}
            <div class="current-shortcut-text">{activeShortcut.keys.join(' + ')}</div>
            <div class="current-shortcut-action">{activeShortcut.action}</div>
          {:else}
            <div class="current-shortcut-text placeholder">Hover over a shortcut</div>
          {/if}
        </div>
      {/key}
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
    height: 80px;
    display: flex;
    flex-direction: column;
    justify-content: center;
    position: relative;
  }

  .current-shortcut-label {
    font-size: 11px;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 1px;
    margin-bottom: 8px;
  }

  .current-shortcut-content {
    animation: fadeSlideIn 0.2s ease-out;
  }

  @keyframes fadeSlideIn {
    from {
      opacity: 0;
      transform: translateY(-4px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  .current-shortcut-text {
    font-family: 'JetBrains Mono', monospace;
    font-size: 18px;
    color: var(--accent-cyan);
    font-weight: 600;
  }

  .current-shortcut-text.placeholder {
    color: var(--text-muted);
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
    background: linear-gradient(135deg, rgba(206, 93, 151, 0.5), rgba(206, 93, 151, 0.25));
    border: 1px solid var(--accent-magenta);
  }

  .legend-color.mod-shift {
    background: linear-gradient(135deg, rgba(58, 169, 159, 0.5), rgba(58, 169, 159, 0.25));
    border: 1px solid var(--accent-cyan);
  }

  .legend-color.mod-action {
    background: linear-gradient(135deg, rgba(218, 112, 44, 0.5), rgba(218, 112, 44, 0.25));
    border: 1px solid var(--accent-orange);
  }

  .legend-color.mod-leader {
    background: linear-gradient(135deg, rgba(135, 154, 57, 0.5), rgba(135, 154, 57, 0.25));
    border: 1px solid var(--accent-green);
  }
</style>
