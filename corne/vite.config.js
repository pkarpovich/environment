import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'

export default defineConfig({
  plugins: [svelte()],
  base: './',
  server: {
    host: true,
    port: 50500,
    strictPort: true,
    allowedHosts: ['corne.localhost'],
  },
})
