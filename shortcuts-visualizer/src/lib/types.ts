export interface Shortcut {
  keys: string[]
  action: string
  actionKeys: string[]
  leader?: boolean
}

export interface ShortcutGroup {
  name: string
  shortcuts: Shortcut[]
}

export interface AppConfig {
  name: string
  groups: ShortcutGroup[]
}

export type ShortcutsData = Record<string, AppConfig>

export interface KeyData {
  key: string
  width?: string
  id?: string
  modifier?: boolean
}

export type KeyInput = string | KeyData

export interface HighlightedKey {
  id: string
  type: 'highlight-alt' | 'highlight-shift' | 'highlight-action' | 'highlight-leader' | 'highlight-overview'
}
