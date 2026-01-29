<script lang="ts">
  import type { KeyInput, HighlightedKey } from '../types'

  let { keyData, highlightedKeys = [] }: { keyData: KeyInput; highlightedKeys: HighlightedKey[] } = $props()

  const isObject = $derived(typeof keyData === 'object')
  const label = $derived(isObject ? (keyData as Exclude<KeyInput, string>).key : keyData)
  const keyId = $derived(isObject ? ((keyData as Exclude<KeyInput, string>).id || (keyData as Exclude<KeyInput, string>).key.toLowerCase()) : (keyData as string).toLowerCase())
  const isModifier = $derived(isObject && (keyData as Exclude<KeyInput, string>).modifier)
  const widthClass = $derived(isObject && (keyData as Exclude<KeyInput, string>).width ? `w-${(keyData as Exclude<KeyInput, string>).width}` : '')

  const highlightClass = $derived(() => {
    const match = highlightedKeys.find(h => h.id === keyId)
    return match ? match.type : ''
  })
</script>

<div
  class="key {widthClass} {isModifier ? 'modifier' : ''} {highlightClass()}"
  data-key={keyId}
>
  {label}
</div>

<style>
  .key {
    min-width: 80px;
    height: 80px;
    background: var(--bg-key);
    border: 1px solid var(--border-color);
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-family: 'JetBrains Mono', monospace;
    font-size: 16px;
    font-weight: 500;
    color: var(--text-secondary);
    cursor: pointer;
    transition: all 0.15s ease;
    text-transform: uppercase;
    box-shadow:
      0 4px 0 var(--bg-primary),
      inset 0 1px 0 rgba(255, 255, 255, 0.05);
  }

  .key:hover {
    background: var(--bg-key-hover);
    transform: translateY(-1px);
  }

  .modifier {
    background: linear-gradient(180deg, var(--bg-tertiary), var(--bg-key));
  }

  .highlight-alt {
    background: linear-gradient(135deg, rgba(198, 120, 221, 0.3), rgba(198, 120, 221, 0.15));
    border-color: var(--accent-magenta);
    color: var(--accent-magenta);
    box-shadow:
      0 2px 0 var(--bg-primary),
      0 0 20px var(--glow-magenta);
  }

  .highlight-shift {
    background: linear-gradient(135deg, rgba(57, 197, 207, 0.3), rgba(57, 197, 207, 0.15));
    border-color: var(--accent-cyan);
    color: var(--accent-cyan);
    box-shadow:
      0 2px 0 var(--bg-primary),
      0 0 20px var(--glow-cyan);
  }

  .highlight-action {
    background: linear-gradient(135deg, rgba(229, 192, 123, 0.35), rgba(229, 192, 123, 0.15));
    border-color: var(--accent-orange);
    color: var(--accent-orange);
    box-shadow:
      0 2px 0 var(--bg-primary),
      0 0 20px rgba(229, 192, 123, 0.3);
  }

  .highlight-leader {
    background: linear-gradient(135deg, rgba(152, 195, 121, 0.35), rgba(152, 195, 121, 0.15));
    border-color: var(--accent-green);
    color: var(--accent-green);
    box-shadow:
      0 2px 0 var(--bg-primary),
      0 0 20px rgba(152, 195, 121, 0.3);
  }

  .w-tab { min-width: 120px; }
  .w-caps { min-width: 140px; }
  .w-shift-l { min-width: 180px; }
  .w-shift-r { min-width: 220px; }
  .w-ctrl { min-width: 100px; }
  .w-alt { min-width: 90px; }
  .w-cmd { min-width: 100px; }
  .w-space { min-width: 500px; }
  .w-enter { min-width: 160px; }
  .w-backspace { min-width: 140px; }
  .w-backslash { min-width: 120px; }
</style>
