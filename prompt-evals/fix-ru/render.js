const fs = require('fs');
const os = require('os');
const path = require('path');

const LIVE = path.join(__dirname, '..', '..', 'dotfiles', 'Library', 'Application Support', 'Tuna', 'Prompts', 'fix-ru.md');
const BASELINE = path.join(__dirname, 'versions', 'baseline.md');
const EDITH = path.join(os.homedir(), '.config', 'edith', 'fix-ru.txt');

function render(file, vars, placeholder = '{{input}}') {
  const body = fs
    .readFileSync(file, 'utf8')
    .replace(/^(#.*\r?\n)+\s*/, '')
    .replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n/, '')
    .trim();
  const at = body.indexOf(placeholder);
  if (at <= 0) throw new Error(`${file}: expected text before ${placeholder}`);
  const prefix = { type: 'text', text: body.slice(0, at), cache_control: { type: 'ephemeral' } };
  const rest = { type: 'text', text: vars.input + body.slice(at + placeholder.length) };
  return JSON.stringify([{ role: 'user', content: [prefix, rest] }]);
}

module.exports = {
  current: ({ vars }) => render(LIVE, vars),
  baseline: ({ vars }) => render(BASELINE, vars),
  edith: ({ vars }) => render(EDITH, vars, '{{selection}}'),
  edithV7s: ({ vars }) => render(path.join(__dirname, 'versions', 'edith-v7s.md'), vars, '{{selection}}'),
  edithV8: ({ vars }) => render(path.join(__dirname, 'versions', 'edith-v8.md'), vars, '{{selection}}'),
  edithV9: ({ vars }) => render(path.join(__dirname, 'versions', 'edith-v9.md'), vars, '{{selection}}'),
};
