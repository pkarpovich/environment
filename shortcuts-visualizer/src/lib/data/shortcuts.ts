import type { ShortcutsData, KeyInput } from '../types'

export const SHORTCUTS_DATA: ShortcutsData = {
  obsidian: {
    name: "Obsidian",
    groups: [
      {
        name: "Navigation",
        shortcuts: [
          { keys: ["CMD", "E"], action: "Quick Switcher", actionKeys: ["E"] },
          { keys: ["CMD", "SHIFT", "E"], action: "Previous file", actionKeys: ["E"] }
        ]
      },
      {
        name: "Templates",
        shortcuts: [
          { keys: ["CMD", "T"], action: "Templater", actionKeys: ["T"] },
          { keys: ["CMD", "SHIFT", "T"], action: "QuickAdd menu", actionKeys: ["T"] }
        ]
      },
      {
        name: "Panels",
        shortcuts: [
          { keys: ["CMD", "\\"], action: "Left sidebar", actionKeys: ["\\"] },
          { keys: ["CMD", "SHIFT", "\\"], action: "Right sidebar", actionKeys: ["\\"] }
        ]
      },
      {
        name: "Mode",
        shortcuts: [
          { keys: ["CMD", "R"], action: "Toggle Read/Edit view", actionKeys: ["R"] }
        ]
      },
      {
        name: "Periods",
        shortcuts: [
          { keys: ["CMD", "D"], action: "Current week", actionKeys: ["D"] },
          { keys: ["CMD", "SHIFT", "D"], action: "Previous week", actionKeys: ["D"] }
        ]
      }
    ]
  },
  wezterm: {
    name: "WezTerm",
    groups: [
      {
        name: "Tabs",
        shortcuts: [
          { keys: ["ALT", "SHIFT", "1-9,0"], action: "Switch to tab", actionKeys: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"] },
          { keys: ["ALT", "SHIFT", "["], action: "Previous tab", actionKeys: ["["] },
          { keys: ["ALT", "SHIFT", "]"], action: "Next tab", actionKeys: ["]"] },
          { keys: ["ALT", "SHIFT", "T"], action: "New tab", actionKeys: ["T"] },
          { keys: ["ALT", "SHIFT", "W"], action: "Close tab", actionKeys: ["W"] }
        ]
      },
      {
        name: "Panes",
        shortcuts: [
          { keys: ["ALT", "SHIFT", "\\"], action: "Split horizontal", actionKeys: ["\\"] },
          { keys: ["ALT", "SHIFT", "_"], action: "Split vertical", actionKeys: ["-"] },
          { keys: ["ALT", "SHIFT", "←→↑↓"], action: "Navigate panes", actionKeys: ["←", "→", "↑", "↓"] }
        ]
      },
      {
        name: "Copy Mode",
        shortcuts: [
          { keys: ["ALT", "SHIFT", "V"], action: "Enter Copy Mode", actionKeys: ["V"] }
        ]
      },
      {
        name: "Leader Mode (ALT+SHIFT+L)",
        shortcuts: [
          { keys: ["LEADER", "S"], action: "Workspace switcher", actionKeys: ["S"], leader: true },
          { keys: ["LEADER", "U"], action: "Update plugins", actionKeys: ["U"], leader: true },
          { keys: ["LEADER", "C"], action: "Close pane", actionKeys: ["C"], leader: true },
          { keys: ["LEADER", "Z"], action: "Toggle zoom", actionKeys: ["Z"], leader: true },
          { keys: ["LEADER", "="], action: "Equalize panes", actionKeys: ["="], leader: true },
          { keys: ["LEADER", "F"], action: "Search scrollback", actionKeys: ["F"], leader: true },
          { keys: ["LEADER", "T"], action: "Pane to new tab", actionKeys: ["T"], leader: true },
          { keys: ["LEADER", "W"], action: "Pane to new window", actionKeys: ["W"], leader: true },
          { keys: ["LEADER", "A"], action: "Gather windows", actionKeys: ["A"], leader: true },
          { keys: ["LEADER", "N"], action: "Narrow prompt", actionKeys: ["N"], leader: true }
        ]
      }
    ]
  }
}

export const KEYBOARD_LAYOUT: KeyInput[][] = [
  ['`', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', { key: '⌫', width: 'backspace' }],
  [{ key: '⇥', width: 'tab' }, 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '[', ']', { key: '\\', width: 'backslash' }],
  [{ key: '⇪', width: 'caps' }, 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ';', "'", { key: '↵', width: 'enter' }],
  [{ key: '⇧', width: 'shift-l', id: 'shift-l', modifier: true }, 'Z', 'X', 'C', 'V', 'B', 'N', 'M', ',', '.', '/', { key: '⇧', width: 'shift-r', id: 'shift-r', modifier: true }],
  [
    { key: 'ctrl', width: 'ctrl', modifier: true },
    { key: '⌥', width: 'alt', id: 'alt-l', modifier: true },
    { key: '⌘', width: 'cmd', id: 'cmd-l', modifier: true },
    { key: '', width: 'space' },
    { key: '⌘', width: 'cmd', id: 'cmd-r', modifier: true },
    { key: '⌥', width: 'alt', id: 'alt-r', modifier: true },
    { key: 'ctrl', width: 'ctrl', modifier: true }
  ]
]

export const ARROWS: KeyInput[] = [
  { key: '←', id: 'arrow-left' },
  { key: '↓', id: 'arrow-down' },
  { key: '↑', id: 'arrow-up' },
  { key: '→', id: 'arrow-right' }
]

export function getKeyId(keyData: KeyInput): string {
  if (typeof keyData === 'string') {
    return keyData.toLowerCase()
  }
  return keyData.id || keyData.key.toLowerCase()
}

export function normalizeActionKey(key: string): string {
  const mapping: Record<string, string> = {
    '←': 'arrow-left',
    '→': 'arrow-right',
    '↑': 'arrow-up',
    '↓': 'arrow-down',
    '_': '-'
  }
  return mapping[key] || key.toLowerCase()
}
