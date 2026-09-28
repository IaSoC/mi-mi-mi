const fs = require('fs');
const text = fs.readFileSync(
  'C:/Users/xiaomi/XiaomiMiMoProjects/electron-arm64-port/scripts/bench-output/index-C2vAeNdg.js',
  'utf8'
);

// find all function C( or ,C= or ;C=
for (const needle of ['function C(', 'function C (', ',C=function', ';C=function', ' C=function']) {
  let from = 0, n = 0;
  while (n < 8) {
    const i = text.indexOf(needle, from);
    if (i < 0) break;
    const before = text.slice(Math.max(0, i - 30), i);
    if (!/function\s*$/.test(before)) {
      console.log('\n====', needle, '@', i, '====');
      console.log(text.slice(i, i + 280).replace(/\n/g, '\\n'));
      n++;
    }
    from = i + needle.length;
  }
}

// search C that calls getBoundingClientRect
let from = 0;
console.log('\n==== getBoundingClientRect callers ====');
while (true) {
  const i = text.indexOf('getBoundingClientRect', from);
  if (i < 0) break;
  console.log(text.slice(Math.max(0, i - 180), i + 40).replace(/\n/g, '\\n'));
  console.log('---');
  from = i + 20;
}

// init3 defs in asar already known - get more context from app.asar via node
const asar = fs.readFileSync(
  'C:/Users/xiaomi/XiaomiMiMoProjects/electron-arm64-port/output/Xiaomi MiMo ARM64/resources/app.asar'
);
const asarText = asar.toString('latin1');
for (const needle of ['function init3(inst, def)', 'async function init3(options2)']) {
  const i = asarText.indexOf(needle);
  console.log('\n==== asar', needle, '@', i, '====');
  if (i >= 0) console.log(asarText.slice(i, i + 500).replace(/[^\x20-\x7E]/g, '.'));
}
