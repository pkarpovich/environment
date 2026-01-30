<script lang="ts">
  import type { KeyInput, HighlightedKey } from '../types'

  interface Props {
    keyData: KeyInput
    highlightedKeys?: HighlightedKey[]
  }

  let { keyData, highlightedKeys = [] }: Props = $props()

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
  class={['key', widthClass, isModifier && 'modifier', highlightClass()]}
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
    background: linear-gradient(135deg, rgba(206, 93, 151, 0.3), rgba(206, 93, 151, 0.15));
    border-color: var(--accent-magenta);
    color: var(--accent-magenta);
    box-shadow:
      0 2px 0 var(--bg-primary),
      0 0 20px var(--glow-magenta);
  }

  .highlight-shift {
    background: linear-gradient(135deg, rgba(58, 169, 159, 0.3), rgba(58, 169, 159, 0.15));
    border-color: var(--accent-cyan);
    color: var(--accent-cyan);
    box-shadow:
      0 2px 0 var(--bg-primary),
      0 0 20px var(--glow-cyan);
  }

  .highlight-cmd {
    background: linear-gradient(135deg, rgba(67, 133, 190, 0.3), rgba(67, 133, 190, 0.15));
    border-color: var(--accent-blue);
    color: var(--accent-blue);
    box-shadow:
      0 2px 0 var(--bg-primary),
      0 0 20px rgba(67, 133, 190, 0.3);
  }

  .highlight-action {
    background: linear-gradient(135deg, rgba(218, 112, 44, 0.35), rgba(218, 112, 44, 0.15));
    border-color: var(--accent-orange);
    color: var(--accent-orange);
    box-shadow:
      0 2px 0 var(--bg-primary),
      0 0 20px rgba(218, 112, 44, 0.3);
  }

  .highlight-leader {
    background: linear-gradient(135deg, rgba(135, 154, 57, 0.35), rgba(135, 154, 57, 0.15));
    border-color: var(--accent-green);
    color: var(--accent-green);
    box-shadow:
      0 2px 0 var(--bg-primary),
      0 0 20px rgba(135, 154, 57, 0.3);
  }

  .highlight-heat-1 {
    background: linear-gradient(135deg, rgba(58, 169, 159, 0.08), rgba(58, 169, 159, 0.03));
    border-color: rgba(58, 169, 159, 0.2);
    color: rgba(206, 205, 195, 0.6);
    box-shadow: 0 2px 0 var(--bg-primary);
  }

  .highlight-heat-2 {
    background: linear-gradient(135deg, rgba(58, 169, 159, 0.15), rgba(58, 169, 159, 0.06));
    border-color: rgba(58, 169, 159, 0.35);
    color: rgba(206, 205, 195, 0.75);
    box-shadow:
      0 2px 0 var(--bg-primary),
      0 0 8px rgba(58, 169, 159, 0.1);
  }

  .highlight-heat-3 {
    background: linear-gradient(135deg, rgba(58, 169, 159, 0.22), rgba(58, 169, 159, 0.1));
    border-color: rgba(58, 169, 159, 0.5);
    color: var(--text-primary);
    box-shadow:
      0 2px 0 var(--bg-primary),
      0 0 12px rgba(58, 169, 159, 0.15);
  }

  .highlight-heat-4 {
    background: linear-gradient(135deg, rgba(58, 169, 159, 0.3), rgba(58, 169, 159, 0.15));
    border-color: rgba(58, 169, 159, 0.65);
    color: var(--accent-cyan);
    box-shadow:
      0 2px 0 var(--bg-primary),
      0 0 16px rgba(58, 169, 159, 0.2);
  }

  .highlight-heat-5 {
    background: linear-gradient(135deg, rgba(58, 169, 159, 0.4), rgba(58, 169, 159, 0.2));
    border-color: var(--accent-cyan);
    color: var(--accent-cyan);
    box-shadow:
      0 2px 0 var(--bg-primary),
      0 0 20px rgba(58, 169, 159, 0.3);
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
