#!/usr/bin/env node
// Fine-grained CDP probe: Network + Resource + LongTasks.
// Goal: identify whether ONE single call is stuck during startup.
//
// Usage:
//   node cdp-deep-probe.mjs --port 9333 --timeout 90000
//
// Output (stdout, one JSON per line):
//   {"event":"connected","ts":ms}
//   {"event":"net","hostMs":ms,"endMs":ms,"durationMs":ms,"url":"...","method":"GET","status":200}
//   {"event":"net-fail","hostMs":ms,"durationMs":ms,"url":"...","errorText":"..."}
//   {"event":"resource","pageStartMs":ms,"durationMs":ms,"size":n,"type":"...","name":"..."}
//   {"event":"longtask","pageStartMs":ms,"durationMs":ms}
//   {"event":"done","netCount":n,"topN":[...]}

const args = process.argv.slice(2);
function arg(name, def) {
  const i = args.indexOf(`--${name}`);
  return i >= 0 && args[i + 1] ? args[i + 1] : def;
}

const PORT = Number(arg('port', '9333'));
const TIMEOUT = Number(arg('timeout', '90000'));
const TOP_N = 12;

function log(obj) {
  process.stdout.write(JSON.stringify(obj) + '\n');
}

async function getWsUrl() {
  const res = await fetch(`http://127.0.0.1:${PORT}/json`);
  const list = await res.json();
  const page = list.find((t) => t.type === 'page' && t.webSocketDebuggerUrl)
    || list.find((t) => t.webSocketDebuggerUrl);
  if (!page) throw new Error('no CDP page target');
  return page.webSocketDebuggerUrl;
}

function cdpSend(ws, id, method, params = {}) {
  return new Promise((resolve, reject) => {
    let settled = false;
    const timer = setTimeout(() => {
      if (settled) return;
      settled = true;
      ws.removeEventListener('message', onMsg);
      reject(new Error(`cdp ${method} timeout`));
    }, 12000);

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
          if (msg.error) reject(new Error(msg.error.message));
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

const PAGE_SNAP = [
  '(function () {',
  '  try {',
  '    var res = performance.getEntriesByType("resource") || [];',
  '    var out = [];',
  '    for (var i = 0; i < res.length; i++) {',
  '      var r = res[i];',
  '      out.push({',
  '        n: (r.name || "").slice(0, 160),',
  '        t: r.initiatorType || "",',
  '        s: Math.round(r.startTime),',
  '        d: Math.round(r.duration),',
  '        z: r.transferSize || r.encodedBodySize || 0',
  '      });',
  '    }',
  '    return out;',
  '  } catch (e) { return []; }',
  '})()'
].join('\n');

const PAGE_LT = [
  '(function () {',
  '  try {',
  '    var lt = performance.getEntriesByType("longtask") || [];',
  '    var out = [];',
  '    for (var i = 0; i < lt.length; i++) {',
  '      out.push({ s: Math.round(lt[i].startTime), d: Math.round(lt[i].duration) });',
  '    }',
  '    return out;',
  '  } catch (e) { return []; }',
  '})()'
].join('\n');

async function main() {
  const t0host = Date.now();
  const deadline = t0host + TIMEOUT;
  const hostNow = () => Date.now() - t0host;

  let wsUrl = null;
  while (Date.now() < deadline) {
    try {
      wsUrl = await getWsUrl();
      break;
    } catch {
      await new Promise((r) => setTimeout(r, 150));
    }
  }
  if (!wsUrl) {
    log({ event: 'error', message: `CDP not up on port ${PORT}` });
    process.exit(2);
  }

  const ws = new WebSocket(wsUrl);
  await new Promise((resolve, reject) => {
    const onOpen = () => {
      ws.removeEventListener('error', onError);
      resolve();
    };
    const onError = (err) => {
      ws.removeEventListener('open', onOpen);
      reject(err && err.message ? err : new Error('websocket error'));
    };
    ws.addEventListener('open', onOpen);
    ws.addEventListener('error', onError);
  });

  log({ event: 'connected', ts: hostNow(), ws: wsUrl });

  const pending = new Map();
  const finished = [];
  let msgId = 5000;

  ws.addEventListener('message', (event) => {
    const raw = (event && event.data != null) ? event.data : event;
    try {
      const text = typeof raw === 'string' ? raw : Buffer.from(raw).toString('utf8');
      const msg = JSON.parse(text);
      if (!msg.method) return;
      const p = msg.params || {};
      const ts = hostNow();

      if (msg.method === 'Network.requestWillBeSent') {
        pending.set(p.requestId, {
          url: (p.request && p.request.url) || '',
          method: (p.request && p.request.method) || '',
          startTime: ts,
          status: null,
          timing: null
        });
      } else if (msg.method === 'Network.responseReceived') {
        const rec = pending.get(p.requestId);
        if (rec) {
          rec.status = p.response && p.response.status;
          rec.mimeType = p.response && p.response.mimeType;
          rec.timing = p.response && p.response.timing;
          rec.protocol = p.response && p.response.protocol;
        }
      } else if (msg.method === 'Network.loadingFinished') {
        const rec = pending.get(p.requestId);
        if (rec) {
          const durationMs = ts - rec.startTime;
          const item = {
            event: 'net',
            hostMs: rec.startTime,
            endMs: ts,
            durationMs,
            url: rec.url.slice(0, 220),
            method: rec.method,
            status: rec.status,
            mimeType: rec.mimeType,
            encodedDataLength: p.encodedDataLength,
            timing: rec.timing
          };
          finished.push(item);
          log(item);
          pending.delete(p.requestId);
        }
      } else if (msg.method === 'Network.loadingFailed') {
        const rec = pending.get(p.requestId);
        if (rec) {
          log({
            event: 'net-fail',
            hostMs: rec.startTime,
            durationMs: ts - rec.startTime,
            url: rec.url.slice(0, 220),
            errorText: p.errorText || ''
          });
          pending.delete(p.requestId);
        }
      }
    } catch (_) {}
  });

  try {
    await cdpSend(ws, msgId++, 'Network.enable', {
      maxTotalBufferSize: 20 * 1024 * 1024
    });
    log({ event: 'net-enabled', ts: hostNow() });
  } catch (e) {
    log({ event: 'error', message: 'Network.enable failed: ' + e.message });
  }

  const seenRes = new Set();
  const seenLt = new Set();
  let lastSnap = 0;

  while (Date.now() < deadline) {
    const now = hostNow();

    if (now - lastSnap >= 300) {
      lastSnap = now;
      try {
        const raw = await cdpSend(ws, msgId++, 'Runtime.evaluate', {
          expression: PAGE_SNAP,
          returnByValue: true
        });
        const list = (raw && raw.result && raw.result.value) || [];
        for (const r of list) {
          const key = r.n + '|' + r.s;
          if (seenRes.has(key)) continue;
          if (r.d >= 80 || r.z >= 300000) {
            seenRes.add(key);
            log({
              event: 'resource',
              pageStartMs: r.s,
              durationMs: r.d,
              size: r.z,
              type: r.t,
              name: r.n
            });
          }
        }
      } catch (_) {}

      try {
        const raw2 = await cdpSend(ws, msgId++, 'Runtime.evaluate', {
          expression: PAGE_LT,
          returnByValue: true
        });
        const lts = (raw2 && raw2.result && raw2.result.value) || [];
        for (const lt of lts) {
          const key = lt.s + 'x' + lt.d;
          if (seenLt.has(key)) continue;
          seenLt.add(key);
          log({ event: 'longtask', pageStartMs: lt.s, durationMs: lt.d });
        }
      } catch (_) {}
    }

    // Exit when we have substantial data and nothing in-flight for 2s after 20s
    if (now > 20000 && finished.length >= 5 && pending.size === 0 && now > lastSnap + 2000) {
      // continue a little to catch late engine calls
      if (now > 35000) break;
    }

    await new Promise((r) => setTimeout(r, 100));
  }

  // Final resource top
  try {
    const raw = await cdpSend(ws, msgId++, 'Runtime.evaluate', {
      expression: PAGE_SNAP,
      returnByValue: true
    });
    const list = (raw && raw.result && raw.result.value) || [];
    const sorted = list.slice().sort((a, b) => b.d - a.d).slice(0, TOP_N);
    for (const r of sorted) {
      log({
        event: 'resource-top',
        pageStartMs: r.s,
        durationMs: r.d,
        size: r.z,
        type: r.t,
        name: r.n
      });
    }
  } catch (_) {}

  const topNet = finished.slice().sort((a, b) => b.durationMs - a.durationMs).slice(0, TOP_N);
  log({
    event: 'done',
    netCount: finished.length,
    pendingLeft: pending.size,
    topN: topNet.map((x) => ({
      url: x.url,
      method: x.method,
      status: x.status,
      durationMs: x.durationMs,
      hostMs: x.hostMs,
      timing: x.timing
    }))
  });

  try { ws.close(); } catch {}
  process.exit(0);
}

main().catch((e) => {
  log({ event: 'error', message: String(e && e.message ? e.message : e) });
  process.exit(1);
});
