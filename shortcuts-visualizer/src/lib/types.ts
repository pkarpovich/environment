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

export type HighlightType =
  | 'highlight-alt'
  | 'highlight-shift'
  | 'highlight-cmd'
  | 'highlight-action'
  | 'highlight-leader'
  | 'highlight-heat-1'
  | 'highlight-heat-2'
  | 'highlight-heat-3'
  | 'highlight-heat-4'
  | 'highlight-heat-5'

export interface HighlightedKey {
  id: string
  type: HighlightType
}
