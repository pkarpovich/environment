<script lang="ts">
  import { fade } from 'svelte/transition'
  import type { Shortcut } from '../types'
  import ShortcutItem from './ShortcutItem.svelte'
  import { SHORTCUTS_DATA, normalizeActionKey } from '../data/shortcuts'

  interface Props {
    currentApp?: string
    selectedShortcut?: Shortcut | null
    filterKeyId?: string | null
    onAppChange: (appId: string) => void
    onShortcutHover: (shortcut: Shortcut) => void
    onShortcutLeave: (shortcut: Shortcut) => void
    onShortcutClick: (shortcut: Shortcut) => void
  }

  let {
    currentApp = 'wezterm',
    selectedShortcut = null,
    filterKeyId = null,
    onAppChange,
    onShortcutHover,
    onShortcutLeave,
    onShortcutClick
  }: Props = $props()

  let searchQuery = $state('')
  let isRecording = $state(false)
  let recordedKeys = $state<string[]>([])

  function getKeyFromCode(code: string): string | null {
    if (code.startsWith('Key')) return code.slice(3)
    if (code.startsWith('Digit')) return code.slice(5)
    const mapping: Record<string, string> = {
      'Backquote': '`', 'Minus': '-', 'Equal': '=',
      'BracketLeft': '[', 'BracketRight': ']', 'Backslash': '\\',
      'Semicolon': ';', 'Quote': "'", 'Comma': ',', 'Period': '.', 'Slash': '/',
      'Space': 'SPACE', 'Enter': 'ENTER', 'Backspace': 'BACKSPACE', 'Tab': 'TAB',
      'ArrowUp': '↑', 'ArrowDown': '↓', 'ArrowLeft': '←', 'ArrowRight': '→'
    }
    return mapping[code] || null
  }

  function handleKeyDown(e: KeyboardEvent) {
    if (!isRecording) return

    e.preventDefault()
    e.stopPropagation()

    const keys: string[] = []

    if (e.metaKey) keys.push('CMD')
    if (e.altKey) keys.push('ALT')
    if (e.shiftKey) keys.push('SHIFT')
    if (e.ctrlKey) keys.push('CTRL')

    const ignoredCodes = ['MetaLeft', 'MetaRight', 'AltLeft', 'AltRight', 'ShiftLeft', 'ShiftRight', 'ControlLeft', 'ControlRight']
    if (!ignoredCodes.includes(e.code)) {
      const key = getKeyFromCode(e.code)
      if (key) {
        keys.push(key)
        recordedKeys = keys
        isRecording = false
      }
    } else {
      recordedKeys = keys
    }
  }

  function handleKeyUp(e: KeyboardEvent) {
    if (!isRecording) return
    if (recordedKeys.length > 0 && !e.metaKey && !e.altKey && !e.shiftKey && !e.ctrlKey) {
      isRecording = false
    }
  }

  function startRecording() {
    isRecording = true
    recordedKeys = []
  }

  function clearRecording() {
    recordedKeys = []
    isRecording = false
  }

  function shortcutMatchesRecorded(shortcut: Shortcut, recorded: string[]): boolean {
    if (recorded.length === 0) return true

    const hasCmd = recorded.includes('CMD')
    const hasAlt = recorded.includes('ALT')
    const hasShift = recorded.includes('SHIFT')
    const hasCtrl = recorded.includes('CTRL')

    const shortcutHasCmd = shortcut.keys.includes('CMD')
    const shortcutHasAlt = shortcut.keys.includes('ALT')
    const shortcutHasShift = shortcut.keys.includes('SHIFT')
    const shortcutHasCtrl = shortcut.keys.includes('CTRL')

    if (hasCmd !== shortcutHasCmd) return false
    if (hasAlt !== shortcutHasAlt) return false
    if (hasShift !== shortcutHasShift) return false
    if (hasCtrl !== shortcutHasCtrl) return false

    const actionKey = recorded.find(k => !['CMD', 'ALT', 'SHIFT', 'CTRL'].includes(k))
    if (actionKey) {
      return shortcut.actionKeys.some(k => k.toUpperCase() === actionKey)
    }

    return true
  }

  $effect(() => {
    if (isRecording) {
      window.addEventListener('keydown', handleKeyDown)
      window.addEventListener('keyup', handleKeyUp)
    }
    return () => {
      window.removeEventListener('keydown', handleKeyDown)
      window.removeEventListener('keyup', handleKeyUp)
    }
  })

  const apps = Object.entries(SHORTCUTS_DATA)

  const allAppsData = $derived(() => {
    const groups: { name: string; shortcuts: Shortcut[] }[] = []
    Object.entries(SHORTCUTS_DATA).forEach(([appId, app]) => {
      app.groups.forEach(group => {
        groups.push({
          name: `${app.name} — ${group.name}`,
          shortcuts: group.shortcuts
        })
      })
    })
    return { name: 'All', groups }
  })

  const currentAppData = $derived(
    currentApp === 'all' ? allAppsData() : SHORTCUTS_DATA[currentApp]
  )

  function shortcutUsesKey(shortcut: Shortcut, keyId: string): boolean {
    if (shortcut.keys.includes('ALT') && (keyId === 'alt-l' || keyId === 'alt-r')) return true
    if (shortcut.keys.includes('R-OPT') && keyId === 'alt-r') return true
    if (shortcut.keys.includes('SHIFT') && (keyId === 'shift-l' || keyId === 'shift-r')) return true
    if (shortcut.keys.includes('CMD') && (keyId === 'cmd-l' || keyId === 'cmd-r')) return true
    if (shortcut.keys.includes('HYPER') && keyId === 'caps') return true
    if (shortcut.leader && keyId === 'l') return true
    return shortcut.actionKeys.some(key => normalizeActionKey(key) === keyId)
  }

  function matchesSearch(shortcut: Shortcut, query: string): boolean {
    if (!query) return true
    const lowerQuery = query.toLowerCase()
    return shortcut.action.toLowerCase().includes(lowerQuery) ||
           shortcut.keys.some(k => k.toLowerCase().includes(lowerQuery))
  }

  const filteredGroups = $derived(() => {
    return currentAppData.groups
      .map(group => ({
        ...group,
        shortcuts: group.shortcuts.filter(s => {
          const matchesKey = !filterKeyId || shortcutUsesKey(s, filterKeyId)
          const matchesQuery = matchesSearch(s, searchQuery)
          const matchesRecorded = shortcutMatchesRecorded(s, recordedKeys)
          return matchesKey && matchesQuery && matchesRecorded
        })
      }))
      .filter(group => group.shortcuts.length > 0)
  })
</script>

<aside class="sidebar">
  <div class="sidebar-header">
    <div class="sidebar-title">Applications</div>
    <div class="app-tabs">
      <button
        class={['app-tab', currentApp === 'all' && 'active']}
        onclick={() => onAppChange('all')}
      >
        All
      </button>
      {#each apps as [id, app]}
        <button
          class={['app-tab', id === currentApp && 'active']}
          onclick={() => onAppChange(id)}
        >
          {app.name}
        </button>
      {/each}
    </div>
    <div class="search-row">
      <div class="search-container">
        <input
          type="text"
          class="search-input"
          placeholder={isRecording ? 'Press keys...' : 'Search shortcuts...'}
          bind:value={searchQuery}
          disabled={isRecording}
        />
        {#if searchQuery}
          <button class="search-clear" onclick={() => searchQuery = ''}>×</button>
        {/if}
      </div>
      <button
        class={['record-btn', isRecording && 'recording']}
        onclick={startRecording}
        title="Record shortcut"
      >
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <rect x="2" y="4" width="20" height="16" rx="2" />
          <line x1="6" y1="8" x2="6" y2="8" stroke-linecap="round" />
          <line x1="10" y1="8" x2="10" y2="8" stroke-linecap="round" />
          <line x1="14" y1="8" x2="14" y2="8" stroke-linecap="round" />
          <line x1="18" y1="8" x2="18" y2="8" stroke-linecap="round" />
          <line x1="8" y1="12" x2="16" y2="12" stroke-linecap="round" />
          <line x1="6" y1="16" x2="6" y2="16" stroke-linecap="round" />
          <line x1="18" y1="16" x2="18" y2="16" stroke-linecap="round" />
        </svg>
      </button>
    </div>
    {#if recordedKeys.length > 0}
      <div class="recorded-keys">
        {recordedKeys.join(' + ')}
        <button class="recorded-clear" onclick={clearRecording}>×</button>
      </div>
    {/if}
    {#if filterKeyId}
      <div class="filter-indicator">
        Filtering by <kbd>{filterKeyId.toUpperCase()}</kbd>
      </div>
    {/if}
  </div>

  {#each filteredGroups() as group (group.name)}
    <div class="shortcut-group" transition:fade={{ duration: 150 }}>
      <div class="group-title">{group.name}</div>
      {#each group.shortcuts as shortcut (shortcut.action)}
        <div transition:fade={{ duration: 100 }}>
          <ShortcutItem
            {shortcut}
            isActive={selectedShortcut === shortcut}
            onhover={() => onShortcutHover(shortcut)}
            onleave={() => onShortcutLeave(shortcut)}
            onclick={() => onShortcutClick(shortcut)}
          />
        </div>
      {/each}
    </div>
  {/each}
</aside>

<style>
  .sidebar {
    width: 22%;
    min-width: 280px;
    max-width: 360px;
    height: 100vh;
    background: var(--bg-secondary);
    border-right: 1px solid var(--border-color);
    padding: 24px;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .sidebar-header {
    position: sticky;
    top: -24px;
    margin: -24px -24px 16px -24px;
    padding: 24px 24px 16px 24px;
    background: var(--bg-secondary);
    z-index: 10;
  }

  .sidebar-title {
    font-size: 14px;
    font-weight: 600;
    color: var(--text-secondary);
    text-transform: uppercase;
    letter-spacing: 1.5px;
    margin-bottom: 8px;
  }

  .app-tabs {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }

  .app-tab {
    padding: 8px 16px;
    background: var(--bg-tertiary);
    border: 1px solid var(--border-color);
    border-radius: 6px;
    color: var(--text-secondary);
    font-size: 13px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s ease;
    font-family: 'JetBrains Mono', monospace;
  }

  .app-tab:hover {
    border-color: var(--accent-cyan);
    color: var(--text-primary);
  }

  .app-tab.active {
    background: linear-gradient(135deg, rgba(58, 169, 159, 0.15), rgba(206, 93, 151, 0.1));
    border-color: var(--accent-cyan);
    color: var(--accent-cyan);
  }

  .search-row {
    display: flex;
    gap: 8px;
    margin-top: 12px;
  }

  .search-container {
    position: relative;
    flex: 1;
  }

  .search-input {
    width: 100%;
    padding: 10px 32px 10px 12px;
    background: var(--bg-tertiary);
    border: 1px solid var(--border-color);
    border-radius: 6px;
    color: var(--text-primary);
    font-size: 13px;
    font-family: 'JetBrains Mono', monospace;
    transition: all 0.2s ease;
  }

  .search-input::placeholder {
    color: var(--text-muted);
  }

  .search-input:focus {
    outline: none;
    border-color: var(--accent-cyan);
    box-shadow: 0 0 0 2px rgba(58, 169, 159, 0.1);
  }

  .search-input:disabled {
    background: linear-gradient(135deg, rgba(206, 93, 151, 0.1), rgba(206, 93, 151, 0.05));
    border-color: var(--accent-magenta);
    color: var(--accent-magenta);
  }

  .search-input:disabled::placeholder {
    color: var(--accent-magenta);
  }

  .search-clear {
    position: absolute;
    right: 8px;
    top: 50%;
    transform: translateY(-50%);
    background: none;
    border: none;
    color: var(--text-muted);
    font-size: 18px;
    cursor: pointer;
    padding: 4px 8px;
    line-height: 1;
    transition: color 0.2s ease;
  }

  .search-clear:hover {
    color: var(--text-primary);
  }

  .record-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 38px;
    height: 38px;
    background: var(--bg-tertiary);
    border: 1px solid var(--border-color);
    border-radius: 6px;
    color: var(--text-secondary);
    cursor: pointer;
    transition: all 0.2s ease;
    flex-shrink: 0;
  }

  .record-btn:hover {
    border-color: var(--accent-magenta);
    color: var(--accent-magenta);
  }

  .record-btn.recording {
    background: linear-gradient(135deg, rgba(206, 93, 151, 0.2), rgba(206, 93, 151, 0.1));
    border-color: var(--accent-magenta);
    color: var(--accent-magenta);
    animation: pulse 1s ease-in-out infinite;
  }

  @keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.7; }
  }

  .recorded-keys {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    margin-top: 8px;
    padding: 6px 10px;
    background: linear-gradient(135deg, rgba(206, 93, 151, 0.15), rgba(206, 93, 151, 0.05));
    border: 1px solid var(--accent-magenta);
    border-radius: 6px;
    font-size: 12px;
    font-family: 'JetBrains Mono', monospace;
    color: var(--accent-magenta);
    width: fit-content;
  }

  .recorded-clear {
    background: none;
    border: none;
    color: var(--accent-magenta);
    font-size: 14px;
    cursor: pointer;
    padding: 0 2px;
    line-height: 1;
    opacity: 0.7;
    transition: opacity 0.2s ease;
  }

  .recorded-clear:hover {
    opacity: 1;
  }

  .filter-indicator {
    margin-top: 12px;
    padding: 8px 12px;
    background: linear-gradient(135deg, rgba(58, 169, 159, 0.1), rgba(58, 169, 159, 0.05));
    border: 1px solid var(--accent-cyan);
    border-radius: 6px;
    font-size: 12px;
    color: var(--text-secondary);
  }

  .filter-indicator kbd {
    background: var(--bg-key);
    padding: 2px 6px;
    border-radius: 4px;
    border: 1px solid var(--border-color);
    font-family: 'JetBrains Mono', monospace;
    font-size: 11px;
    color: var(--accent-cyan);
  }

  .shortcut-group {
    margin-bottom: 20px;
  }

  .group-title {
    font-size: 11px;
    font-weight: 600;
    color: var(--accent-cyan);
    text-transform: uppercase;
    letter-spacing: 1.2px;
    margin-bottom: 10px;
    padding-bottom: 6px;
    border-bottom: 1px solid var(--border-color);
  }
</style>
