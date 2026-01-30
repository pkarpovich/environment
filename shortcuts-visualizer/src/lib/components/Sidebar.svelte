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
    if (shortcut.keys.includes('SHIFT') && (keyId === 'shift-l' || keyId === 'shift-r')) return true
    if (shortcut.keys.includes('CMD') && (keyId === 'cmd-l' || keyId === 'cmd-r')) return true
    if (shortcut.leader && keyId === 'l') return true
    return shortcut.actionKeys.some(key => normalizeActionKey(key) === keyId)
  }

  const filteredGroups = $derived(() => {
    if (!filterKeyId) return currentAppData.groups

    return currentAppData.groups
      .map(group => ({
        ...group,
        shortcuts: group.shortcuts.filter(s => shortcutUsesKey(s, filterKeyId))
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
