const fs = require('fs');
const path = require('path');

const LIVE = path.join(__dirname, '..', '..', 'dotfiles', 'tuna-prompts', 'fix-ru.md');
const BASELINE = path.join(__dirname, 'versions', 'baseline.md');

function render(file, vars) {
  const body = fs
    .readFileSync(file, 'utf8')
    .replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n/, '')
    .trim();
  return body.replace('{{input}}', () => vars.input);
}

module.exports = {
  current: ({ vars }) => render(LIVE, vars),
  baseline: ({ vars }) => render(BASELINE, vars),
};
