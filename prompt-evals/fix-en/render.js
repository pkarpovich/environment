const fs = require('fs');
const os = require('os');
const path = require('path');

const EDITH = path.join(os.homedir(), '.config', 'edith', 'fix-en.txt');
const PLACEHOLDER = '{{selection}}';

function render(file, vars) {
  const body = fs
    .readFileSync(file, 'utf8')
    .replace(/^(#.*\r?\n)+\s*/, '')
    .replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n/, '')
    .trim();
  const at = body.indexOf(PLACEHOLDER);
  if (at <= 0) throw new Error(`${file}: expected text before ${PLACEHOLDER}`);
  const prefix = { type: 'text', text: body.slice(0, at), cache_control: { type: 'ephemeral' } };
  const rest = { type: 'text', text: vars.input + body.slice(at + PLACEHOLDER.length) };
  return JSON.stringify([{ role: 'user', content: [prefix, rest] }]);
}

const version = (name) => ({ vars }) => render(path.join(__dirname, 'versions', `edith-${name}.md`), vars);

module.exports = {
  edith: ({ vars }) => render(EDITH, vars),
  v0: version('v0'),
  v1: version('v1'),
  v2: version('v2'),
};
