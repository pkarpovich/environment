<script>
  let { name, label } = $props()

  const GHOST = 'M14 54 A36 36 0 0 1 86 54 L86 82 Q76.5 94 67 82 Q57.5 94 48 82 Q38.5 94 29 82 Q19.5 94 14 82 Z'
  const PACMAN = 'M82.9 31 A38 38 0 1 0 82.9 69 L50 50 Z'
</script>

<svg class="icon" viewBox="0 0 100 100" role="img" aria-label={label}>
  {#if name === 'ghost'}
    <path d={GHOST} fill="none" stroke="currentColor" stroke-width="6" stroke-linejoin="round" />
    <ellipse cx="37" cy="49" rx="7" ry="8" fill="currentColor" />
    <ellipse cx="63" cy="49" rx="7" ry="8" fill="currentColor" />
  {:else if name === 'pacman'}
    <path d={PACMAN} fill="none" stroke="currentColor" stroke-width="6" stroke-linejoin="round" />
    <circle cx="56" cy="27" r="4.5" fill="currentColor" />
  {/if}
</svg>

<style>
  .icon {
    inline-size: calc(var(--u) * 0.44);
    block-size: calc(var(--u) * 0.44);
    display: block;
    margin-inline: auto;
    color: var(--cap-ink);
    overflow: visible;
  }
</style>
