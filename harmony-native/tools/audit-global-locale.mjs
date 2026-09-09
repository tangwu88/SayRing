import { readFileSync } from 'node:fs';
import { registerHooks } from 'node:module';
registerHooks({resolve(specifier,context,next){return next(specifier.startsWith('.') && context.parentURL?.endsWith('.ts') && !/\.[a-z]+$/.test(specifier)?specifier+'.ts':specifier,context);}});
const { appText, translationKeys, APP_LOCALES } = await import('../entry/src/main/ets/model/GlobalLocale.ts');
const { ENGLISH_FALLBACKS } = await import('../entry/src/main/ets/model/GlobalEnglishFallbacks.ts');
const source=readFileSync(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
const literals=[...new Set([...source.matchAll(/'((?:[^'\\]|\\.)*)'/g)].map(match=>match[1]).filter(value=>/[\u4e00-\u9fff]/.test(value)))];
const covered=literals.filter(value=>!/[\u4e00-\u9fff]/.test(appText(value,'en')));
const missing=literals.filter(value=>/[\u4e00-\u9fff]/.test(appText(value,'en')));
const missingEveryLocale=Object.fromEntries(APP_LOCALES.map(locale=>[locale,literals.filter(value=>appText(value,locale)===value).length]));
process.stdout.write(JSON.stringify({semanticRows:translationKeys().length,languages:APP_LOCALES,
  chineseSingleQuoteLiterals:literals.length,englishCoveredLiterals:covered.length,
  remainingEnglishLiterals:missing.length,englishFallbackLiteralCount:literals.filter(value=>!!ENGLISH_FALLBACKS[value]).length,missing,notes:[
  'This inventory is not a visual or mother-tongue acceptance test.',
  'Dynamic template literals, native callbacks and server content require separate review.',
  '311 generic UI rows are machine-assisted drafts with reviewed English and corrected key ambiguities.'
]},null,2));
