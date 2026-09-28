const fs = require('fs');

const asarPath = 'C:/Users/xiaomi/XiaomiMiMoProjects/electron-arm64-port/output/Xiaomi MiMo ARM64/resources/app.asar';
const want = process.argv[2] || 'index-C2vAeNdg.js';
const out = process.argv[3] || 'C:/Users/xiaomi/XiaomiMiMoProjects/electron-arm64-port/scripts/bench-output/index-C2vAeNdg.js';

const fd = fs.openSync(asarPath, 'r');

// Electron asar:
//   [0..7]   pickle(headerSize)  -> readUInt32LE(4) = headerSize
//   [8 .. 8+headerSize)  pickle(string JSON)
const sizeBuf = Buffer.alloc(8);
fs.readSync(fd, sizeBuf, 0, 8, 0);
const headerSize = sizeBuf.readUInt32LE(4);
console.log('headerSize', headerSize);

const headerBuf = Buffer.alloc(headerSize);
fs.readSync(fd, headerBuf, 0, headerSize, 8);

// string pickle: [0..3] payload size, [4..7] string length, [8..] utf8
const strLen = headerBuf.readUInt32LE(4);
const json = headerBuf.slice(8, 8 + strLen).toString('utf8');
console.log('json length', json.length, 'starts', json.slice(0, 40));
const header = JSON.parse(json);

function findNode(node, wantName, prefix = '') {
  if (!node || !node.files) return null;
  for (const [name, child] of Object.entries(node.files)) {
    const p = prefix ? prefix + '/' + name : name;
    if (name === wantName && child.files === undefined) return { node: child, path: p };
    if (child.files) {
      const r = findNode(child, wantName, p);
      if (r) return r;
    }
  }
  return null;
}

const hit = findNode(header, want);
if (!hit) {
  console.log('NOT FOUND', want);
  process.exit(1);
}
const offset = Number(hit.node.offset);
const size = Number(hit.node.size);
console.log('found', hit.path, 'offset', offset, 'size', size);

// data starts at 8 + headerSize
const dataStart = 8 + headerSize;
const data = Buffer.alloc(size);
fs.readSync(fd, data, 0, size, dataStart + offset);
fs.closeSync(fd);
fs.writeFileSync(out, data);
console.log('wrote', out, data.length);

const text = data.toString('utf8');
const lines = text.split('\n');
console.log('total lines', lines.length);

function showLineCol(ln, col) {
  const line = lines[ln - 1] || '';
  console.log('\n--- line ' + ln + ' length=' + line.length + ' around col ' + col + ' ---');
  const s = Math.max(0, col - 180);
  const e = Math.min(line.length, col + 500);
  console.log(line.slice(s, e));
}

showLineCol(183, 1404);

// find all function Age
let idx = 0, n = 0;
while (n < 8) {
  const i = text.indexOf('function Age', idx);
  if (i < 0) break;
  const before = text.slice(0, i);
  const ln = before.split('\n').length;
  const col = i - (before.lastIndexOf('\n') + 1);
  console.log('\nfunction Age @ line ' + ln + ' col ' + col);
  console.log(text.slice(i, i + 280).replace(/\n/g, '\\n'));
  idx = i + 12;
  n++;
}
