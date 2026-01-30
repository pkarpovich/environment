<script lang="ts">
  import type { Shortcut } from '../types'
  import ShortcutItem from './ShortcutItem.svelte'
  import { SHORTCUTS_DATA } from '../data/shortcuts'

  interface Props {
    currentApp?: string
    selectedShortcut?: Shortcut | null
    onAppChange: (appId: string) => void
    onShortcutHover: (shortcut: Shortcut) => void
    onShortcutLeave: (shortcut: Shortcut) => void
    onShortcutClick: (shortcut: Shortcut) => void
  }

  let {
    currentApp = 'wezterm',
    selectedShortcut = null,
    onAppChange,
    onShortcutHover,
    onShortcutLeave,
    onShortcutClick
  }: Props = $props()

  const apps = Object.entries(SHORTCUTS_DATA)
  const currentAppData = $derived(SHORTCUTS_DATA[currentApp])
</script>

<aside class="sidebar">
  <div class="sidebar-header">
    <div class="sidebar-title">Applications</div>
    <div class="app-tabs">
      {#each apps as [id, app]}
        <button
          class={['app-tab', id === currentApp && 'active']}
          onclick={() => onAppChange(id)}
        >
          {app.name}
        </button>
      {/each}
    </div>
  </div>

  {#each currentAppData.groups as group}
    <div class="shortcut-group">
      <div class="group-title">{group.name}</div>
      {#each group.shortcuts as shortcut}
        <ShortcutItem
          {shortcut}
          isActive={selectedShortcut === shortcut}
          onhover={() => onShortcutHover(shortcut)}
          onleave={() => onShortcutLeave(shortcut)}
          onclick={() => onShortcutClick(shortcut)}
        />
      {/each}
    </div>
  {/each}
</aside>

<style>
  .sidebar {
    width: 22%;
    min-width: 280px;
    max-width: 360px;
    background: var(--bg-secondary);
    border-right: 1px solid var(--border-color);
    padding: 24px;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .sidebar-header {
    margin-bottom: 16px;
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
