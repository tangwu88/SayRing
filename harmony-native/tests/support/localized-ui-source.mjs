import { readFileSync } from 'node:fs';

// Layout contracts inspect the original expression shape. Localization behavior
// has its own catalog/placeholder tests; stripping this wrapper does not skip
// layout assertions or alter any source on disk.
export function readUiSource(file) {
  let source = readFileSync(file, 'utf8');
  let start = source.indexOf('this.tr(');
  while (start >= 0) {
    let index = start + 8, depth = 1, quote = '';
    for (; index < source.length; index++) {
      const char = source[index];
      if (quote) {
        if (char === '\\') { index++; continue; }
        if (char === quote) quote = '';
      } else if (char === "'" || char === '"' || char === '`') quote = char;
      else if (char === '(') depth++;
      else if (char === ')' && --depth === 0) break;
    }
    if (depth !== 0) throw Error('Unbalanced localization wrapper');
    source = source.slice(0, start) + source.slice(start + 8, index) + source.slice(index + 1);
    start = source.indexOf('this.tr(', start);
  }
  return source;
}
