const fs = require('fs');
const path = 'C:/Users/xiaomi/XiaomiMiMoProjects/electron-arm64-port/output/Xiaomi MiMo ARM64/resources/app.asar';
const text = fs.readFileSync(path).toString('latin1');

const idx = text.indexOf('function Age(e){');
console.log('Age @', idx);
console.log(text.slice(idx, idx + 1500).replace(/[^\x09\x0A\x0D\x20-\x7E]/g, '.'));

// who calls Age(
console.log('\n\n======== callers of Age( ========');
let from = 0, n = 0;
while (n < 12) {
  const i = text.indexOf('Age(', from);
  if (i < 0) break;
  // skip definition
  if (i !== idx) {
    const ctx = text.slice(Math.max(0, i - 120), i + 80).replace(/[^\x20-\x7E]/g, '.');
    console.log('\n---- call @ %d ----', i);
    console.log(ctx);
    n++;
  }
  from = i + 4;
}

// also search $a( since it's sibling near Age
console.log('\n\n======== $a definition/calls ========');
const i2 = text.indexOf('function $a(e)');
if (i2 >= 0) console.log(text.slice(i2, i2 + 400).replace(/[^\x20-\x7E]/g, '.'));
