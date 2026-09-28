const fs = require('fs');
const t = fs.readFileSync(
  'C:/Users/xiaomi/XiaomiMiMoProjects/electron-arm64-port/scripts/bench-output/index-C2vAeNdg.js',
  'utf8'
);
const i = t.indexOf('function _r(');
console.log('def _r', i);
if (i >= 0) console.log(t.slice(i, i + 200).replace(/\n/g, ' '));
const j = t.indexOf('function wre(');
console.log('def wre', j);
if (j >= 0) console.log(t.slice(j, j + 250).replace(/\n/g, ' '));
console.log('_r(" count', (t.match(/_r\("/g) || []).length);
console.log('Fb(" count', (t.match(/Fb\("/g) || []).length);
// zustand persist?
console.log('persist( count', (t.match(/persist\(/g) || []).length);
console.log('localStorage.getItem count', (t.match(/localStorage\.getItem/g) || []).length);
