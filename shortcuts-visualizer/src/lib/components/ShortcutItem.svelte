<script lang="ts">
  import type { Shortcut } from '../types'

  interface Props {
    shortcut: Shortcut
    isActive?: boolean
    onhover: () => void
    onleave: () => void
    onclick: () => void
  }

  let { shortcut, isActive = false, onhover, onleave, onclick }: Props = $props()

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault()
      onclick()
    }
  }
</script>

<button
  type="button"
  class={['shortcut-item', isActive && 'active']}
  onmouseenter={onhover}
  onmouseleave={onleave}
  onclick={onclick}
  onkeydown={handleKeydown}
>
  <div class="shortcut-keys">
    {#each shortcut.keys as key}
      <kbd>{key}</kbd>
    {/each}
  </div>
  <div class="shortcut-action">{shortcut.action}</div>
</button>

<style>
  .shortcut-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 10px 12px;
    background: var(--bg-tertiary);
    border-radius: 6px;
    margin-bottom: 6px;
    cursor: pointer;
    transition: all 0.15s ease;
    border: 1px solid transparent;
    width: 100%;
    font-family: inherit;
    font-size: inherit;
    text-align: left;
    transform: translateX(0);
  }

  .shortcut-item:hover {
    background: var(--bg-key-hover);
    border-color: var(--border-color);
    transform: translateX(4px);
  }

  .shortcut-item:focus {
    outline: 2px solid var(--accent-cyan);
    outline-offset: 2px;
  }

  .shortcut-item:active {
    transform: translateX(2px) scale(0.98);
  }

  .shortcut-item.active {
    background: linear-gradient(135deg, rgba(57, 197, 207, 0.12), rgba(198, 120, 221, 0.08));
    border-color: var(--accent-cyan);
    transform: translateX(4px);
  }

  .shortcut-keys {
    font-family: 'JetBrains Mono', monospace;
    font-size: 12px;
    font-weight: 500;
    color: var(--accent-orange);
    display: flex;
    gap: 4px;
    flex-wrap: wrap;
  }

  .shortcut-keys kbd {
    background: var(--bg-key);
    padding: 3px 6px;
    border-radius: 4px;
    border: 1px solid var(--border-color);
    font-size: 11px;
    font-family: inherit;
  }

  .shortcut-action {
    font-size: 12px;
    color: var(--text-secondary);
    text-align: right;
    max-width: 140px;
  }
</style>
