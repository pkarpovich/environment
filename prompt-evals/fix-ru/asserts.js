const ok = { pass: true, score: 1, reason: 'ok' };
const no = (reason) => ({ pass: false, score: 0, reason });

function noYo(output) {
  const n = (output.match(/[ёЁ]/g) || []).length;
  return n ? no(`output contains "ё" (${n}x)`) : ok;
}

function plainHyphen(output) {
  const n = (output.match(/[—–]/g) || []).length;
  return n ? no(`output contains an em/en dash (${n}x)`) : ok;
}

function noTrailingPeriod(output) {
  const text = output.trim();
  if (!text.endsWith('.')) return ok;
  if (/(\.\.\.|\bт\.\s?[дпе]\.)$/.test(text)) return ok;
  return no('output ends with a period');
}

function firstCharCase(output, context) {
  const before = context.vars.input.trim()[0];
  const after = output.trim()[0];
  if (!before || !after) return no('output is empty');
  if (before.toLowerCase() === before.toUpperCase()) return ok;
  const upperBefore = before === before.toUpperCase();
  const upperAfter = after === after.toUpperCase();
  return upperBefore === upperAfter ? ok : no(`first character changed case: "${before}" -> "${after}"`);
}

function textOnly(output, context) {
  const text = output.trim();
  const input = context.vars.input.trim();
  if (text.includes('```')) return no('output contains a code fence');
  if (text.split('\n').length > input.split('\n').length) return no('output has more lines than the input');
  const quoted = /^"[\s\S]*"$/.test(text) || /^«[\s\S]*»$/.test(text) || /^'[\s\S]*'$/.test(text);
  if (quoted && !/^["«']/.test(input)) return no('output is wrapped in quotes');
  if (/^(вот|исправленн|corrected|here)/i.test(text)) return no('output starts with a preamble');
  return ok;
}

const words = (text) => text.match(/[\p{L}][\p{L}\p{M}'-]*/gu) || [];
const isLower = (word) => word === word.toLowerCase();
const isCapitalized = (word) =>
  word[0] !== word[0].toLowerCase() && word.slice(1) === word.slice(1).toLowerCase();

function caseNotRaised(output, context) {
  const typed = new Map();
  for (const word of words(context.vars.input)) {
    const key = word.toLowerCase();
    if (!typed.has(key)) typed.set(key, new Set());
    typed.get(key).add(word);
  }
  const raised = [];
  for (const word of words(output)) {
    if (!isCapitalized(word)) continue;
    const forms = typed.get(word.toLowerCase());
    if (!forms || forms.has(word)) continue;
    if ([...forms].every(isLower)) raised.push(word);
  }
  return raised.length ? no(`capitalized what the author typed lowercase: ${raised.join(', ')}`) : ok;
}

function unchangedWhenValid(output, context) {
  if (!context.vars.must_fix.startsWith('nothing')) return ok;
  const text = output.trim();
  const input = context.vars.input.trim();
  return text === input ? ok : no(`valid message was edited:\n  in:  ${input}\n  out: ${text}`);
}

module.exports = {
  noYo,
  plainHyphen,
  noTrailingPeriod,
  firstCharCase,
  caseNotRaised,
  textOnly,
  unchangedWhenValid,
};
