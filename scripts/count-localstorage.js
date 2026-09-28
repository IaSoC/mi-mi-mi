const fs = require('fs');
const text = fs.readFileSync(
  'C:/Users/xiaomi/XiaomiMiMoProjects/electron-arm64-port/scripts/bench-output/index-C2vAeNdg.js',
  'utf8'
);

// Extract the settings store initializer
const i = text.indexOf('Age();const Mt=Et(');
const slice = text.slice(i, i + 1800);
console.log('==== store init ====');
console.log(slice);

// Count Ca(/gu(/Bb( inside this init block (until setStr)
const end = slice.indexOf('setStr');
const init = slice.slice(0, end > 0 ? end : slice.length);
const ca = (init.match(/Ca\(/g) || []).length;
const gu = (init.match(/gu\(/g) || []).length;
const bb = (init.match(/Bb\(/g) || []).length;
console.log('\n==== init block counts ====');
console.log('Ca  (enum getItem)', ca);
console.log('gu  (bool  getItem)', gu);
console.log('Bb  (raw   getItem)', bb);
console.log('Age (removeItem)   8 (fixed)');
console.log('TOTAL sync ops at module init =', ca + gu + bb + 8);

// Other module-level Ca/gu/Bb near language init
const lang = text.indexOf('Ca("language",Dm,"system")');
console.log('\n==== extra language Ca ====');
console.log(slice.length, 'lang idx', lang);
console.log(text.slice(lang - 60, lang + 80).replace(/\n/g, '\\n'));

// Bb and gu definitions
for (const name of ['function gu(', 'function Bb(']) {
  const j = text.indexOf(name);
  console.log('\n====', name, '====');
  console.log(text.slice(j, j + 160).replace(/\n/g, '\\n'));
}

// Count ALL wrapper invocations that look like runtime getters (Ca(" / gu(" / Bb(")
function namedCalls(fn) {
  const re = new RegExp(fn + '\\("', 'g');
  return (text.match(re) || []).length;
}
console.log('\n==== static call sites with string keys ====');
console.log('Ca(" ', namedCalls('Ca'));
console.log('gu(" ', namedCalls('gu'));
console.log('Bb(" ', namedCalls('Bb'));

// Direct localStorage in whole file besides wrappers
console.log('\n==== direct localStorage outside wrappers (raw counts) ====');
console.log('localStorage.getItem   ', (text.match(/localStorage\.getItem/g) || []).length);
console.log('localStorage.setItem   ', (text.match(/localStorage\.setItem/g) || []).length);
console.log('localStorage.removeItem', (text.match(/localStorage\.removeItem/g) || []).length);
