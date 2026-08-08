export const COORDS = [
  [0, 0.3], [1, 0.3], [2, 0.1], [3, 0], [4, 0.1], [5, 0.2], [6, 0.7], [8, 0.7], [9, 0.2], [10, 0.1], [11, 0], [12, 0.1], [13, 0.3], [14, 0.3],
  [0, 1.3], [1, 1.3], [2, 1.1], [3, 1], [4, 1.1], [5, 1.2], [6, 1.7], [8, 1.7], [9, 1.2], [10, 1.1], [11, 1], [12, 1.1], [13, 1.3], [14, 1.3],
  [0, 2.3], [1, 2.3], [2, 2.1], [3, 2], [4, 2.1], [5, 2.2], [9, 2.2], [10, 2.1], [11, 2], [12, 2.1], [13, 2.3], [14, 2.3],
  [3.5, 3.75, 1, 0], [4.5, 3.85, 1, 15], [5.77, 3.68, 1.5, 25],
  [8.23, 3.68, 1.5, -25], [9.5, 3.85, 1, -15], [10.5, 3.75, 1, 0],
]

export const HOME_INDEXES = [18, 23]

const CAP_BY_FINGER = {
  pinky2: 'white',
  pinky: 'blue',
  ring: 'red',
  middle: 'green',
  index: 'grey',
  index2: 'black',
  thumb: 'dark',
}

const CAP_OVERRIDES = {
  0: 'cyan',
  6: 'grey',
  7: 'grey',
  20: 'grey',
  21: 'grey',
  13: 'yellow',
  14: 'green',
  27: 'black',
  28: 'green',
  39: 'purple',
  40: 'steel',
  41: 'orange',
  42: 'black',
  43: 'black',
  44: 'orange',
  45: 'wine',
}

const FINGER_BY_COL = {
  0: 'pinky2', 1: 'pinky', 2: 'ring', 3: 'middle', 4: 'index', 5: 'index2', 6: 'index2',
  8: 'index2', 9: 'index2', 10: 'index', 11: 'middle', 12: 'ring', 13: 'pinky', 14: 'pinky2',
}

export const FINGER_NAMES = {
  pinky2: 'pinky, outer',
  pinky: 'pinky',
  ring: 'ring',
  middle: 'middle',
  index: 'index',
  index2: 'index, inner',
  thumb: 'thumb',
}

export const LAYERS = [
  [
    'TAB', 'q', 'w', 'e', 'r', 't', 'LCTL', '[', 'y', 'u', 'i', 'o', 'p', 'BSPC',
    'HYPER', 'a', 's', 'd', 'f', 'g', 'LALT', ']', 'h', 'j', 'k', 'l', ';', "'",
    'LSFT', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 'ESC',
    'LGUI', 'MO1', 'SPC', 'ENT', 'MO2', 'RGUI',
  ],
  [
    'TAB', '1', '2', '3', '4', '5', 'LCTL', 'RCTL', '6', '7', '8', '9', '0', 'BSPC',
    'HYPER', 'NONE', 'NONE', 'NONE', 'NONE', 'NONE', 'LALT', 'RALT', 'LEFT', 'DOWN', 'UP', 'RIGHT', 'NONE', 'NONE',
    'LSFT', 'NONE', 'NONE', 'NONE', 'NONE', 'NONE', 'NONE', 'NONE', 'NONE', 'NONE', 'NONE', 'NONE',
    'LGUI', 'TRNS', 'SPC', 'ENT', 'MO3', 'RGUI',
  ],
  [
    'TAB', 'S:1', 'S:2', 'S:3', 'S:4', 'S:5', 'LCTL', 'RCTL', 'S:6', 'S:7', 'S:8', 'S:9', 'S:0', 'BSPC',
    'HYPER', 'NONE', 'NONE', 'NONE', 'NONE', 'NONE', 'LALT', 'RALT', '-', '=', '[', ']', '\\', '`',
    'LSFT', 'NONE', 'NONE', 'NONE', 'NONE', 'NONE', 'S:-', 'S:=', 'S:[', 'S:]', 'S:\\', 'S:`',
    'LGUI', 'MO3', 'SPC', 'ENT', 'TRNS', 'RGUI',
  ],
  [
    'BOOT', 'NONE', 'NONE', 'NONE', 'NONE', 'NONE', 'LCTL', 'RCTL', 'NONE', 'NONE', 'NONE', 'NONE', 'NONE', 'NONE',
    'RGB_TOG', 'RGB_HUI', 'RGB_SAI', 'RGB_VAI', 'NONE', 'NONE', 'LALT', 'RALT', 'NONE', 'NONE', 'NONE', 'NONE', 'NONE', 'NONE',
    'RGB_MOD', 'RGB_HUD', 'RGB_SAD', 'RGB_VAD', 'NONE', 'NONE', 'NONE', 'NONE', 'NONE', 'NONE', 'NONE', 'NONE',
    'LGUI', 'TRNS', 'SPC', 'ENT', 'TRNS', 'RGUI',
  ],
]

export const LAYER_META = [
  { title: 'Base', note: 'Home row: pinkies on a and ;, index fingers on f and j - those carry the bumps.' },
  { title: 'Lower', note: 'Held with the left thumb on the second key.' },
  { title: 'Raise', note: 'Held with the right thumb on the second key.' },
  { title: 'Adjust', note: 'Lower + Raise together. Backlight and BOOT for flashing.' },
]

const ICONS = { TAB: 'ghost', BSPC: 'pacman', ESC: 'ghost', LGUI: 'ghost', RGUI: 'ghost' }

const WORDS = {
  TAB: ['tab', 'Tab'], BSPC: ['bksp', 'Backspace'], HYPER: ['Hyper', 'CapsLock'],
  LSFT: ['Shift', 'ShiftLeft'], ESC: ['esc', 'Escape'], LGUI: ['cmd', 'MetaLeft'],
  SPC: ['Space', 'Space'], ENT: ['Enter', 'Enter'], RGUI: ['cmd', 'MetaRight'],
  LCTL: ['LCtrl', 'ControlLeft'], RCTL: ['RCtrl', 'ControlRight'],
  LALT: ['LAlt', 'AltLeft'], RALT: ['RAlt', 'AltRight'],
  MO1: ['Lower', null], MO2: ['Raise', null], MO3: ['Adjust', null], BOOT: ['BOOT', null],
  RGB_TOG: ['rgb', null], RGB_MOD: ['mode', null],
  RGB_HUI: ['hue +', null], RGB_HUD: ['hue -', null],
  RGB_SAI: ['sat +', null], RGB_SAD: ['sat -', null],
  RGB_VAI: ['lighter', null], RGB_VAD: ['darker', null],
}

const ARROWS = {
  LEFT: ['←', 'ArrowLeft'], DOWN: ['↓', 'ArrowDown'], UP: ['↑', 'ArrowUp'], RIGHT: ['→', 'ArrowRight'],
}

const LETTERS = 'abcdefghijklmnopqrstuvwxyz'.split('')

const DOMCODE = {
  '1': 'Digit1', '2': 'Digit2', '3': 'Digit3', '4': 'Digit4', '5': 'Digit5',
  '6': 'Digit6', '7': 'Digit7', '8': 'Digit8', '9': 'Digit9', '0': 'Digit0',
  '-': 'Minus', '=': 'Equal', '[': 'BracketLeft', ']': 'BracketRight', '\\': 'Backslash',
  ';': 'Semicolon', "'": 'Quote', ',': 'Comma', '.': 'Period', '/': 'Slash', '`': 'Backquote',
}
LETTERS.forEach((c) => { DOMCODE[c] = 'Key' + c.toUpperCase() })

const US = {
  '1': ['1', '!'], '2': ['2', '@'], '3': ['3', '#'], '4': ['4', '$'], '5': ['5', '%'],
  '6': ['6', '^'], '7': ['7', '&'], '8': ['8', '*'], '9': ['9', '('], '0': ['0', ')'],
  '-': ['-', '_'], '=': ['=', '+'], '[': ['[', '{'], ']': [']', '}'], '\\': ['\\', '|'],
  ';': [';', ':'], "'": ["'", '"'], ',': [',', '<'], '.': ['.', '>'], '/': ['/', '?'], '`': ['`', '~'],
}
LETTERS.forEach((c) => { US[c] = [c, c.toUpperCase()] })

const SHARED = {
  '1': ['!', '1'], '2': ['@', '2'], '3': ['#', '3'], '4': ['$', '4'], '5': ['%', '5'],
  '6': ['^', '6'], '7': ['?', '7'], '8': ['*', '8'], '9': ['(', '9'], '0': [')', '0'],
  '-': ['-', '_'], '=': ['=', '+'], '\\': ['/', '|'], '`': ["'", '"'],
  ',': [',', ';'], '.': ['.', ':'],
}

const EN = { ...SHARED, ';': ['=>', '=>'], "'": ['~', '≈'], '/': ['&', '&'], '[': ['[', '{'], ']': [']', '}'] }
LETTERS.forEach((c) => { EN[c] = [c, c.toUpperCase()] })

const RU_LETTERS = {
  q: 'й', w: 'ц', e: 'у', r: 'к', t: 'е', y: 'н', u: 'г', i: 'ш', o: 'щ', p: 'з',
  a: 'ф', s: 'ы', d: 'в', f: 'а', g: 'п', h: 'р', j: 'о', k: 'л', l: 'д',
  z: 'я', x: 'ч', c: 'с', v: 'м', b: 'и', n: 'т', m: 'ь',
}

const RU = { ...SHARED, ';': ['ж', 'Ж'], "'": ['э', 'Э'], '/': ['ю', 'Ю'], '[': ['х', 'Х'], ']': ['б', 'Б'] }
Object.entries(RU_LETTERS).forEach(([k, v]) => { RU[k] = [v, v.toUpperCase()] })

const TABLES = { en: EN, ru: RU }

const OPTION = {
  q: ['ψ', 'Ψ'], w: ['ω', 'Ω'], e: ['€', '€'], r: ['®', '®'], t: ['ё', 'Ë'],
  y: ['¥', '¥'], u: ['λ', 'Λ'], i: ['щ', 'Щ'], o: ['', ''], p: ['π', 'Π'],
  a: ['α', 'Α'], s: ['§', 'Σ'], d: ['°', 'Δ'], f: ['£', '£'], g: ['γ', 'Γ'],
  h: ['₽', '₽'], j: ['ø', 'Ø'], k: ['=>', '->'], l: ['«', '←'], ';': ['»', '→'],
  "'": ['~', '≈'], z: ['μ', 'Μ'], x: ['×', '×'], c: ['©', '¢'], v: ['√', '√'],
  b: ['β', 'Β'], n: ['η', 'Η'], m: ['ъ', 'Ъ'], ',': ['<', '≤'], '.': ['>', '≥'],
  '/': ['&', '…'],
  '1': ['¹', '¡'], '2': ['²', '½'], '3': ['³', '⅓'], '4': ['⁴', '¼'], '5': ['‰', '‰'],
  '6': ['ˆ', 'ˆ'], '7': ['¿', '⁈'], '8': ['∞', '∞'], '9': ['‘', '“'], '0': ['’', '”'],
  '-': ['–', '—'], '=': ['≠', '±'], '[': ['[', '{'], ']': [']', '}'],
  '\\': ['\\', '¦'], '`': ['`', '•'],
}

export const NO_MODS = { shift: false, alt: false }

export function parseToken(token, index) {
  if (token === 'NONE') return { kind: 'dead' }
  if (token === 'TRNS') return { ...parseToken(LAYERS[0][index], index), pass: true }
  if (ARROWS[token]) return { kind: 'glyph', glyph: ARROWS[token][0], code: ARROWS[token][1] }
  if (WORDS[token]) {
    const [glyph, code] = WORDS[token]
    return { kind: 'word', glyph, code, layerKey: token.startsWith('MO'), icon: ICONS[token] }
  }
  const shifted = token.startsWith('S:')
  const us = shifted ? token.slice(2) : token
  return { kind: 'char', us, shifted, code: DOMCODE[us] }
}

export function outputOf(key, lang, mods = NO_MODS) {
  if (key.kind !== 'char') return null
  const pair = (mods.alt ? OPTION : TABLES[lang])[key.us]
  if (!pair) return key.us
  return pair[key.shifted || mods.shift ? 1 : 0] || null
}

export function layerForCode(code, shiftHeld = false) {
  const found = []
  for (let index = 0; index < LAYERS.length; index++) {
    for (let slot = 0; slot < LAYERS[index].length; slot++) {
      const key = parseToken(LAYERS[index][slot], slot)
      if (key.code !== code) continue
      found.push({ index, shifted: Boolean(key.shifted) })
      break
    }
  }
  if (found.length === 1) return found[0].index

  const matching = found.filter((entry) => entry.shifted === shiftHeld)
  return matching.length === 1 ? matching[0].index : null
}

export function legendOf(key, shiftHeld = false) {
  if (key.kind !== 'char') return null
  return US[key.us][key.shifted || shiftHeld ? 1 : 0]
}

export function fingerAt(index) {
  const [x, y] = COORDS[index]
  return y > 3 ? 'thumb' : FINGER_BY_COL[x]
}

export function capAt(index) {
  return CAP_OVERRIDES[index] ?? CAP_BY_FINGER[fingerAt(index)]
}

export function handAt(index) {
  return COORDS[index][0] <= 6 ? 'left' : 'right'
}

export function usLabelForCode(code) {
  return Object.entries(DOMCODE).find(([, value]) => value === code)?.[0] ?? null
}

export function findIndexByCode(code) {
  for (const layer of LAYERS) {
    const i = layer.findIndex((token, index) => parseToken(token, index).code === code)
    if (i !== -1) return i
  }
  return -1
}

const DIGIT_ROW = [1, 2, 3, 4, 5, 8, 9, 10, 11, 12]

export function topRowOutputs(layerIndex, lang) {
  return DIGIT_ROW
    .map((slot) => {
      const key = parseToken(LAYERS[layerIndex][slot], slot)
      return key.kind === 'char' ? outputOf(key, lang) : ''
    })
    .join(' ')
}

export function baseDrift(lang) {
  return LAYERS[0]
    .map((token, i) => parseToken(token, i))
    .filter((key) => key.kind === 'char' && !/^[a-z]$/.test(key.us))
    .map((key) => ({
      us: key.us,
      out: outputOf(key, lang),
      shift: outputOf(key, lang, SHIFTED),
      drifted: outputOf(key, lang) !== legendOf(key) || outputOf(key, lang, SHIFTED) !== legendOf(key, true),
    }))
    .filter((row) => row.drifted)
}

const WANTED = ['\\', '`', '<', '>', ':', ';', '"', "'", '|', '~', '&', '/', '?', '_', '#', '$']

const SHIFTED = { shift: true, alt: false }
const ALT = { shift: false, alt: true }
const ALT_SHIFTED = { shift: true, alt: true }

function reachable(lang, mods) {
  const found = new Map()
  for (const layer of LAYERS) {
    for (let slot = 0; slot < layer.length; slot++) {
      const key = parseToken(layer[slot], slot)
      if (key.kind !== 'char') continue
      const out = outputOf(key, lang, mods)
      if (out && !found.has(out)) found.set(out, key.us)
    }
  }
  return found
}

export function optionOnly(lang) {
  const plain = new Set([...reachable(lang, NO_MODS).keys(), ...reachable(lang, SHIFTED).keys()])
  const alt = reachable(lang, ALT)
  const altShifted = reachable(lang, ALT_SHIFTED)

  const rows = []
  for (const ch of WANTED) {
    if (plain.has(ch)) continue
    if (alt.has(ch)) rows.push({ ch, hint: `Option + ${alt.get(ch)}` })
    else if (altShifted.has(ch)) rows.push({ ch, hint: `Option + Shift + ${altShifted.get(ch)}` })
  }
  return rows
}

export function unreachable(lang) {
  const all = new Set()
  for (const mods of [NO_MODS, SHIFTED, ALT, ALT_SHIFTED]) {
    for (const out of reachable(lang, mods).keys()) all.add(out)
  }
  return WANTED.filter((ch) => !all.has(ch))
}
