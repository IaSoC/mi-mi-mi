const fs = require("fs");
const path = require("path");

const asarPath =
  process.argv[2] ||
  "C:/Users/xiaomi/AppData/Local/Programs/Xiaomi MiMo/resources/app.asar";
const outDir =
  process.argv[3] ||
  "C:/Users/xiaomi/XiaomiMiMoProjects/electron-arm64-port/docs/compose/deck/assets";
const wants = ["logo.png", "icon.png", "icon-win.png", "icon-win.ico", "ai-watermark.svg"];

const fd = fs.openSync(asarPath, "r");
const sizeBuf = Buffer.alloc(8);
fs.readSync(fd, sizeBuf, 0, 8, 0);
const headerSize = sizeBuf.readUInt32LE(4);
const headerBuf = Buffer.alloc(headerSize);
fs.readSync(fd, headerBuf, 0, headerSize, 8);
const strLen = headerBuf.readUInt32LE(4);
const json = headerBuf.slice(8, 8 + strLen).toString("utf8");
const header = JSON.parse(json);
const dataStart = 8 + headerSize;

function findAll(node, wantName, prefix = "", acc = []) {
  if (!node || !node.files) return acc;
  for (const [name, child] of Object.entries(node.files)) {
    const p = prefix ? prefix + "/" + name : name;
    if (name === wantName && child.files === undefined) acc.push({ node: child, path: p });
    if (child.files) findAll(child, wantName, p, acc);
  }
  return acc;
}

fs.mkdirSync(outDir, { recursive: true });
for (const want of wants) {
  const hits = findAll(header, want);
  if (!hits.length) {
    console.log("NOT FOUND", want);
    continue;
  }
  hits.forEach((hit, i) => {
    const offset = Number(hit.node.offset);
    const size = Number(hit.node.size);
    const data = Buffer.alloc(size);
    fs.readSync(fd, data, 0, size, dataStart + offset);
    const safe = i ? `-${i}` : "";
    const ext = path.extname(want);
    const base = path.basename(want, ext);
    const out = path.join(outDir, `mimo-${base}${safe}${ext}`);
    fs.writeFileSync(out, data);
    console.log("wrote", out, data.length, "from", hit.path);
  });
}
fs.closeSync(fd);
console.log("done");
