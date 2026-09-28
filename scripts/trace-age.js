const fs = require('fs');
const path = 'C:/Users/xiaomi/XiaomiMiMoProjects/electron-arm64-port/scripts/bench-output/index-C2vAeNdg.js';
const text = fs.readFileSync(path, 'utf8');
const lines = text.split('\n');

// Show line 184 fully around Age
const line = lines[183];
console.log('line 184 length', line.length);
const col = 1392;
console.log('--- Age def ---');
console.log(line.slice(col, col + 350));

// Find rc prefix
const rcIdx = text.indexOf('const rc=');
console.log('\n--- rc ---');
if (rcIdx >= 0) console.log(text.slice(rcIdx, rcIdx + 80));
else {
  const r2 = text.search(/\brc\s*=\s*["'`]/);
  console.log('rc=', text.slice(Math.max(0, r2 - 20), r2 + 60));
}

// Find Age() call sites (not definition)
console.log('\n--- Age() call sites ---');
let from = 0, n = 0;
while (n < 25) {
  const i = text.indexOf('Age(', from);
  if (i < 0) break;
  const before = text.slice(Math.max(0, i - 10), i);
  const after = text.slice(i + 4, i + 20);
  // skip function Age( definition
  if (!/function\s*$/.test(before)) {
    const ln = text.slice(0, i).split('\n').length;
    const ctx = text.slice(Math.max(0, i - 70), i + 40).replace(/\n/g, '\\n');
    console.log(`[${n}] line~${ln} ...${ctx}...`);
    n++;
  }
  from = i + 4;
}

// Also search localStorage removeItem nearby callers via `Age()`
console.log('\n--- exact Age() with parens ---');
from = 0; n = 0;
while (n < 20) {
  const i = text.indexOf('Age()', from);
  if (i < 0) break;
  const ln = text.slice(0, i).split('\n').length;
  const ctx = text.slice(Math.max(0, i - 90), i + 15).replace(/\n/g, '\\n');
  console.log(`[${n}] line~${ln} ${ctx}`);
  n++;
  from = i + 5;
}

// How much localStorage is used in this file
const rem = (text.match(/localStorage\.removeItem/g) || []).length;
const get = (text.match(/localStorage\.getItem/g) || []).length;
const set = (text.match(/localStorage\.setItem/g) || []).length;
console.log(`\nlocalStorage: removeItem=${rem} getItem=${get} setItem=${set}`);
