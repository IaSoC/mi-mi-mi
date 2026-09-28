#!/usr/bin/env node
// Patch an OFFICIAL MiMo app.asar for the ARM64 runtime.
//
// The port needs exactly one equal-length byte edit in out/main/index.mjs:
// the platform whitelist must admit win32-arm64. Everything else in the
// official asar is already architecture-independent.
//
// Usage:
//   node patch-asar.js <path/to/app.asar>           # patch in place
//   node patch-asar.js <path/to/app.asar> --check   # report only, no write
//
// Exit codes: 0 patched/already patched, 2 pattern not found (version drift),
//             3 usage error.

'use strict';
const fs = require('fs');
const crypto = require('crypto');

const OFFICIAL = Buffer.from(
  'return r==="darwin-arm64"||r==="win32-x64"||r==="linux-x64"?r:null',
  'ascii'
);
const PATCHED = Buffer.from(
  'return r==="win32-arm64"||r==="win32-x64"||r==="linux-x64"?r: null',
  'ascii'
);

if (OFFICIAL.length !== PATCHED.length) {
  console.error('FATAL: patch is not length-preserving');
  process.exit(3);
}

function count(buf, needle) {
  let c = 0, i = 0;
  while ((i = buf.indexOf(needle, i)) !== -1) { c++; i += needle.length; }
  return c;
}

function sha256(buf) {
  return crypto.createHash('sha256').update(buf).digest('hex');
}

const argv = process.argv.slice(2);
const check = argv.includes('--check');
const file = argv.find(a => !a.startsWith('--'));
if (!file) {
  console.error('usage: node patch-asar.js <path/to/app.asar> [--check]');
  process.exit(3);
}

const buf = fs.readFileSync(file);
const nOfficial = count(buf, OFFICIAL);
const nPatched = count(buf, PATCHED);

console.log('file   :', file);
console.log('size   :', buf.length);
console.log('sha256 :', sha256(buf));
console.log('official-pattern:', nOfficial, ' patched-pattern:', nPatched);

if (nOfficial === 1 && nPatched === 0) {
  if (check) {
    console.log('RESULT : OK, patchable (not applied, --check)');
    process.exit(0);
  }
  const idx = buf.indexOf(OFFICIAL);
  PATCHED.copy(buf, idx);
  fs.writeFileSync(file, buf);
  console.log('applied at byte offset', idx);
  console.log('sha256 after:', sha256(buf));
  console.log('RESULT : OK, patched');
  process.exit(0);
}

if (nOfficial === 0 && nPatched === 1) {
  console.log('RESULT : OK, already patched');
  process.exit(0);
}

console.error('RESULT : FAIL — expected exactly one platform-whitelist match.');
console.error('  This asar is neither stock nor known-patched; the payload');
console.error('  version has changed and the pattern no longer applies.');
console.error('  Refusing to guess. Do NOT launch with a half-patched asar.');
process.exit(2);
