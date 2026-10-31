const shared = require('../fix-ru/asserts.js');

const ok = { pass: true, score: 1, reason: 'ok' };
const no = (reason) => ({ pass: false, score: 0, reason });

function straightQuotes(output) {
  const n = (output.match(/[“”‘’]/g) || []).length;
  return n ? no(`output contains curly quotes (${n}x)`) : ok;
}

function textOnly(output, context) {
  const text = output.trim();
  const input = context.vars.input.trim();
  if (text.includes('```')) return no('output contains a code fence');
  if (text.split('\n').length > input.split('\n').length) return no('output has more lines than the input');
  const quoted = /^"[\s\S]*"$/.test(text) || /^'[\s\S]*'$/.test(text);
  if (quoted && !/^["']/.test(input)) return no('output is wrapped in quotes');
  return ok;
}

module.exports = {
  plainHyphen: shared.plainHyphen,
  noTrailingPeriod: shared.noTrailingPeriod,
  firstCharCase: shared.firstCharCase,
  unchangedWhenValid: shared.unchangedWhenValid,
  straightQuotes,
  textOnly,
};
