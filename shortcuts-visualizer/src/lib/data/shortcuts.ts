import type { ShortcutsData, KeyInput } from '../types'

export const SHORTCUTS_DATA: ShortcutsData = {
  karabiner: {
    name: "Karabiner",
    groups: [
      {
        name: "Right Option + Key (Apps)",
        shortcuts: [
          { keys: ["R-OPT", "T"], action: "WezTerm", actionKeys: ["T"] },
          { keys: ["R-OPT", "G"], action: "GoLand", actionKeys: ["G"] },
          { keys: ["R-OPT", "W"], action: "WebStorm", actionKeys: ["W"] },
          { keys: ["R-OPT", "B"], action: "Dia", actionKeys: ["B"] },
          { keys: ["R-OPT", "Z"], action: "Zed", actionKeys: ["Z"] },
          { keys: ["R-OPT", "L"], action: "Logseq", actionKeys: ["L"] },
          { keys: ["R-OPT", "M"], action: "Telegram", actionKeys: ["M"] },
          { keys: ["R-OPT", "H"], action: "Bruno", actionKeys: ["H"] },
          { keys: ["R-OPT", "N"], action: "Obsidian", actionKeys: ["N"] },
          { keys: ["R-OPT", "F"], action: "Finder", actionKeys: ["F"] },
          { keys: ["R-OPT", "C"], action: "Claude", actionKeys: ["C"] },
          { keys: ["R-OPT", "4"], action: "Sublime Merge", actionKeys: ["4"] }
        ]
      },
      {
        name: "Right Option + Key (Media)",
        shortcuts: [
          { keys: ["R-OPT", "S"], action: "Play/Pause", actionKeys: ["S"] },
          { keys: ["R-OPT", "D"], action: "Fast Forward", actionKeys: ["D"] },
          { keys: ["R-OPT", "A"], action: "Rewind", actionKeys: ["A"] }
        ]
      },
      {
        name: "Hyper (Caps) → O (Search)",
        shortcuts: [
          { keys: ["HYPER", "O", "G"], action: "GitHub Search", actionKeys: ["O", "G"] },
          { keys: ["HYPER", "O", "A"], action: "Arc History", actionKeys: ["O", "A"] },
          { keys: ["HYPER", "O", "K"], action: "Arc Search", actionKeys: ["O", "K"] }
        ]
      },
      {
        name: "Hyper (Caps) → W (Window)",
        shortcuts: [
          { keys: ["HYPER", "W", "←→↑↓"], action: "Move Window", actionKeys: ["W", "←", "→", "↑", "↓"] },
          { keys: ["HYPER", "W", "↵"], action: "Maximize", actionKeys: ["W"] },
          { keys: ["HYPER", "W", "C"], action: "Center", actionKeys: ["W", "C"] },
          { keys: ["HYPER", "W", "H"], action: "Hide Window", actionKeys: ["W", "H"] },
          { keys: ["HYPER", "W", "I/O"], action: "Top Half/Bottom", actionKeys: ["W", "I", "O"] },
          { keys: ["HYPER", "W", "J/K/L"], action: "Thirds", actionKeys: ["W", "J", "K", "L"] },
          { keys: ["HYPER", "W", "[/]"], action: "Prev/Next Display", actionKeys: ["W", "[", "]"] },
          { keys: ["HYPER", "W", "R"], action: "Restore", actionKeys: ["W", "R"] }
        ]
      },
      {
        name: "Hyper (Caps) Shortcuts",
        shortcuts: [
          { keys: ["HYPER", "C"], action: "Clipboard History", actionKeys: ["C"] },
          { keys: ["HYPER", "G"], action: "Raycast AI Chat", actionKeys: ["G"] }
        ]
      },
      {
        name: "Hyper (Caps) → S (Shortcuts)",
        shortcuts: [
          { keys: ["HYPER", "S", "A"], action: "Shortcut A", actionKeys: ["S", "A"] },
          { keys: ["HYPER", "S", "T"], action: "Shortcut T", actionKeys: ["S", "T"] },
          { keys: ["HYPER", "S", "M"], action: "Shortcut M", actionKeys: ["S", "M"] }
        ]
      },
      {
        name: "Hyper (Caps) → A (Actions)",
        shortcuts: [
          { keys: ["HYPER", "A", "E"], action: "Action 1", actionKeys: ["A", "E"] },
          { keys: ["HYPER", "A", "R"], action: "Action 2", actionKeys: ["A", "R"] },
          { keys: ["HYPER", "A", "N"], action: "Action 3", actionKeys: ["A", "N"] }
        ]
      },
      {
        name: "Hyper (Caps) → M (Memory Cells)",
        shortcuts: [
          { keys: ["HYPER", "M", "1"], action: "Tap: Get / Hold: Save Cell 1", actionKeys: ["M", "1"] },
          { keys: ["HYPER", "M", "2"], action: "Tap: Get / Hold: Save Cell 2", actionKeys: ["M", "2"] },
          { keys: ["HYPER", "M", "3"], action: "Tap: Get / Hold: Save Cell 3", actionKeys: ["M", "3"] },
          { keys: ["HYPER", "M", "P"], action: "Tap: Get / Hold: Save Password", actionKeys: ["M", "P"] }
        ]
      }
    ]
  },
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
  [{ key: '⇪', width: 'caps', id: 'caps' }, 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ';', "'", { key: '↵', width: 'enter' }],
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

export const KEYBOARD_LAYOUT_RU: KeyInput[][] = [
  [{ key: 'ё', id: '`' }, { key: '1', id: '1' }, { key: '2', id: '2' }, { key: '3', id: '3' }, { key: '4', id: '4' }, { key: '5', id: '5' }, { key: '6', id: '6' }, { key: '7', id: '7' }, { key: '8', id: '8' }, { key: '9', id: '9' }, { key: '0', id: '0' }, { key: '-', id: '-' }, { key: '=', id: '=' }, { key: '⌫', width: 'backspace' }],
  [{ key: '⇥', width: 'tab' }, { key: 'Й', id: 'q' }, { key: 'Ц', id: 'w' }, { key: 'У', id: 'e' }, { key: 'К', id: 'r' }, { key: 'Е', id: 't' }, { key: 'Н', id: 'y' }, { key: 'Г', id: 'u' }, { key: 'Ш', id: 'i' }, { key: 'Щ', id: 'o' }, { key: 'З', id: 'p' }, { key: 'Х', id: '[' }, { key: 'Ъ', id: ']' }, { key: '\\', width: 'backslash' }],
  [{ key: '⇪', width: 'caps', id: 'caps' }, { key: 'Ф', id: 'a' }, { key: 'Ы', id: 's' }, { key: 'В', id: 'd' }, { key: 'А', id: 'f' }, { key: 'П', id: 'g' }, { key: 'Р', id: 'h' }, { key: 'О', id: 'j' }, { key: 'Л', id: 'k' }, { key: 'Д', id: 'l' }, { key: 'Ж', id: ';' }, { key: 'Э', id: "'" }, { key: '↵', width: 'enter' }],
  [{ key: '⇧', width: 'shift-l', id: 'shift-l', modifier: true }, { key: 'Я', id: 'z' }, { key: 'Ч', id: 'x' }, { key: 'С', id: 'c' }, { key: 'М', id: 'v' }, { key: 'И', id: 'b' }, { key: 'Т', id: 'n' }, { key: 'Ь', id: 'm' }, { key: 'Б', id: ',' }, { key: 'Ю', id: '.' }, { key: '.', id: '/' }, { key: '⇧', width: 'shift-r', id: 'shift-r', modifier: true }],
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

export type KeyboardLang = 'en' | 'ru'

export function getKeyboardLayout(lang: KeyboardLang): KeyInput[][] {
  return lang === 'ru' ? KEYBOARD_LAYOUT_RU : KEYBOARD_LAYOUT
}

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
