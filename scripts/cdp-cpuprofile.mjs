#!/usr/bin/env node
// CDP Profiler capture for startup (renderer JS).
// Electron V8 rejects --cpu-prof; use DevTools Protocol Profiler instead.
//
// Usage:
//   node cdp-cpuprofile.mjs --port 9333 --out /path/startup.cpuprofile --timeout 60000
//
// Logs every step to <out>.log so silent failures are visible.

import fs from 'node:fs';
import path from 'node:path';
const args = process.argv.slice(2);
function arg(name, def) {
  const i = args.indexOf(`--${name}`);
  return i >= 0 && args[i + 1] ? args[i + 1] : def;
}

const PORT = Number(arg('port', '9333'));
const OUT = arg('out', 'startup.cpuprofile');
const TIMEOUT = Number(arg('timeout', '60000'));
const SAMPLE_US = Number(arg('sample-us', '100'));
const LOG = OUT + '.log';

function log(obj) {
  const line = JSON.stringify(obj);
  try { fs.appendFileSync(LOG, line + '\n'); } catch (_) {}
  process.stdout.write(line + '\n');
}

function logErr(msg) {
  log({ event: 'error', message: String(msg) });
}

process.on('uncaughtException', (e) => logErr('uncaught ' + e));
process.on('unhandledRejection', (e) => logErr('unhandled ' + e));

async function getWsUrl() {
  const res = await fetch(`http://127.0.0.1:${PORT}/json`);
  const list = await res.json();
  log({ event: 'targets', ts: 0, count: list.length, types: list.map((t) => t.type) });
  const page = list.find((t) => t.type === 'page' && t.webSocketDebuggerUrl)
    || list.find((t) => t.webSocketDebuggerUrl);
  if (!page) throw new Error('no CDP page target');
  return page.webSocketDebuggerUrl;
}

function cdp(ws, id, method, params = {}) {
  return new Promise((resolve, reject) => {
    let settled = false;
    const timer = setTimeout(() => {
      if (settled) return;
      settled = true;
      ws.removeEventListener('message', onMsg);
      reject(new Error(`cdp ${method} timeout`));
    }, 20000);
    const onMsg = (event) => {
      const raw = (event && event.data != null) ? event.data : event;
      try {
        const text = typeof raw === 'string' ? raw : Buffer.from(raw).toString('utf8');
        const msg = JSON.parse(text);
        if (msg.id === id) {
          if (settled) return;
          settled = true;
          clearTimeout(timer);
          ws.removeEventListener('message', onMsg);
          if (msg.error) reject(new Error(method + ': ' + msg.error.message));
          else resolve(msg.result);
        }
      } catch (_) {}
    };
    ws.addEventListener('message', onMsg);
    try {
      ws.send(JSON.stringify({ id, method, params }));
    } catch (e) {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      ws.removeEventListener('message', onMsg);
      reject(e);
    }
  });
}

const READY = [
  '(function () {',
  '  try {',
  '  function visible(el) {',
  '    if (!el) return false;',
  '    var r = el.getBoundingClientRect();',
  '    if (r.width < 2 || r.height < 2) return false;',
  '    var s = getComputedStyle(el);',
  '    return s.visibility !== "hidden" && s.display !== "none" && s.opacity !== "0";',
  '  }',
  '  var body = document.body;',
  '  var bodyText = body ? (body.innerText || "") : "";',
  '  var t0 = bodyText.indexOf("一起探索无限可能") >= 0 || bodyText.indexOf("无限可能") >= 0;',
  '  var nodes = document.querySelectorAll("div,span,li,a,p,button");',
  '  var rows = 0;',
  '  for (var i = 0; i < nodes.length; i++) {',
  '    var el = nodes[i];',
  '    if (el.children.length > 0) continue;',
  '    var t = (el.textContent || "").trim();',
  '    if (!t || t.length > 80) continue;',
  '    var r = el.getBoundingClientRect();',
  '    if (r.left > 460 || r.top < 30) continue;',
  '    if (!visible(el)) continue;',
  '    rows++;',
  '  }',
  '  return { t0: t0, rows: rows, hasRecent: bodyText.indexOf("最近") >= 0 };',
  '  } catch (e) { return { t0: false, rows: 0, hasRecent: false, err: String(e) }; }',
  '})()'
].join('\n');

async function main() {
  try { fs.mkdirSync(path.dirname(OUT), { recursive: true }); } catch (_) {}
  fs.writeFileSync(LOG, '');
  const t0 = Date.now();
  const deadline = t0 + TIMEOUT;
  log({ event: 'start', out: OUT, port: PORT, timeout: TIMEOUT });

  let wsUrl = null;
  while (Date.now() < deadline) {
    try {
      wsUrl = await getWsUrl();
      break;
    } catch (e) {
      await new Promise((r) => setTimeout(r, 200));
    }
  }
  if (!wsUrl) {
    logErr('CDP not up on ' + PORT);
    process.exit(2);
  }

  const ws = new WebSocket(wsUrl);
  await new Promise((resolve, reject) => {
    const onOpen = () => { ws.removeEventListener('error', onError); resolve(); };
    const onError = (err) => { ws.removeEventListener('open', onOpen); reject(err); };
    ws.addEventListener('open', onOpen);
    ws.addEventListener('error', onError);
  });

  const hostNow = () => Date.now() - t0;
  log({ event: 'connected', ts: hostNow(), ws: wsUrl });

  let id = 1;

  // Capability probe
  try {
    await cdp(ws, id++, 'Profiler.enable');
    log({ event: 'Profiler.enable ok', ts: hostNow() });
  } catch (e) {
    logErr('Profiler.enable failed: ' + e.message);
    process.exit(4);
  }

  try {
    await cdp(ws, id++, 'Profiler.setSamplingInterval', { interval: SAMPLE_US });
    log({ event: 'sampling', ts: hostNow(), sampleUs: SAMPLE_US });
  } catch (e) {
    logErr('setSamplingInterval failed (continue): ' + e.message);
  }

  try {
    await cdp(ws, id++, 'Profiler.start');
    log({ event: 'profiler-started', ts: hostNow() });
  } catch (e) {
    logErr('Profiler.start failed: ' + e.message);
    process.exit(5);
  }

  let readyTs = null;
  let lastRows = -1;
  let stable = 0;
  let polls = 0;

  while (Date.now() < deadline) {
    polls++;
    try {
      const raw = await cdp(ws, id++, 'Runtime.evaluate', {
        expression: READY,
        returnByValue: true
      });
      const v = raw && raw.result && raw.result.value;
      const now = hostNow();
      if (v && polls % 10 === 1) {
        log({ event: 'poll', ts: now, t0: v.t0, rows: v.rows, hasRecent: v.hasRecent });
      }
      if (v) {
        if (v.t0 && v.hasRecent && v.rows >= 3) {
          if (v.rows === lastRows) stable++;
          else { stable = 1; lastRows = v.rows; }
          if (stable >= 2) {
            readyTs = now;
            log({ event: 'list-ready', ts: now, rows: v.rows, polls });
            break;
          }
        } else {
          lastRows = v.rows;
          stable = 0;
        }
      }
    } catch (e) {
      if (polls % 10 === 1) logErr('poll error: ' + e.message);
    }
    await new Promise((r) => setTimeout(r, 150));
  }

  log({ event: 'stopping', ts: hostNow(), readyTs, polls });

  let profile = null;
  try {
    const res = await cdp(ws, id++, 'Profiler.stop');
    log({ event: 'stop-raw', ts: hostNow(), keys: res ? Object.keys(res) : null });
    // DevTools: { profile: Profile }
    if (res && res.profile) profile = res.profile;
    else if (res && res.result && res.result.profile) profile = res.result.profile;
    else if (res && res.nodes) profile = res; // already the profile
  } catch (e) {
    logErr('Profiler.stop failed: ' + e.message);
  }

  if (profile && Array.isArray(profile.nodes)) {
    const json = JSON.stringify(profile);
    fs.writeFileSync(OUT, json);
    const st = fs.statSync(OUT);
    log({
      event: 'saved',
      ts: hostNow(),
      out: OUT,
      bytes: st.size,
      nodes: profile.nodes.length,
      samples: (profile.samples || []).length
    });
  } else {
    logErr('no usable profile object; keys=' + (profile ? Object.keys(profile) : 'null'));
    // dump whatever we got for debug
    try {
      fs.writeFileSync(OUT + '.raw.json', JSON.stringify(profile || {}));
    } catch (_) {}
    process.exit(3);
  }

  try { ws.close(); } catch {}
  process.exit(0);
}

main().catch((e) => {
  logErr(e && e.stack ? e.stack : e);
  process.exit(1);
});
