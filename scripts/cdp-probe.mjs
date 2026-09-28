#!/usr/bin/env node
// CDP probe for MiMo startup milestones (TL / T0 / T1).
//
// Usage:
//   node cdp-probe.mjs --port 9333 --timeout 60000
//
// Output (stdout, one JSON per line):
//   {"event":"connected","ts":<ms>}
//   {"event":"startup-loader","ts":<ms>,"detail":"..."}
//   {"event":"main-ui","ts":<ms>,"detail":"..."}
//   {"event":"list-ready","ts":<ms>,"detail":"..."}
//   {"event":"probe-debug","ts":<ms>,"detail":"..."}   // when T0/T1 not yet
//   {"event":"done","loaderMs":...,"mainUiMs":...,"listMs":...,"mainToListMs":...}
//   {"event":"timeout"|"error","message":"..."}
//
// Detection (Runtime.evaluate in the page):
//   TL startup-loader : .startup-loader / .startup-loader__logo visible
//   T0 main-ui        : slogan text visible (he/yi qi tan suo wu xian ke neng)
//   T1 list-ready     : sub-conversation rows (indented under project titles)
//                       >=3, count stable across 2 polls. Project titles alone
//                       do NOT count.
//   Extra functional checkpoints (for one-shot startup evidence):
//     sidebar-chrome  : 项目 + 最近 headers visible
//     interactive     : 新建任务 / primary input visible
//     perf            : first-paint, FCP, DCL, load, responseEnd (page clock)

const args = process.argv.slice(2);
function arg(name, def) {
  const i = args.indexOf(`--${name}`);
  return i >= 0 && args[i + 1] ? args[i + 1] : def;
}

const PORT = Number(arg('port', '9333'));
const TIMEOUT = Number(arg('timeout', '60000'));
const POLL_MS = 150;

// Keep this expression self-contained (no backticks inside).
const PAGE_PROBE = [
  '(function () {',
  '  try {',
  '  function visible(el) {',
  '    if (!el) return false;',
  '    var r = el.getBoundingClientRect();',
  '    if (r.width < 2 || r.height < 2) return false;',
  '    var s = getComputedStyle(el);',
  '    return s.visibility !== "hidden" && s.display !== "none" && s.opacity !== "0";',
  '  }',
  '  function depthOf(el) {',
  '    var d = 0, n = el;',
  '    while (n && n !== document.body) { d++; n = n.parentElement; }',
  '    return d;',
  '  }',
  '',
  '  var body = document.body;',
  '  var bodyText = body ? (body.innerText || body.textContent || "") : "";',
  '',
  '  // --- TL startup-loader ---',
  '  var loaderEl = document.querySelector(".startup-loader");',
  '  if (!loaderEl) loaderEl = document.querySelector(".startup-loader__logo, .startup-loader__base");',
  '  var loader = false;',
  '  var loaderDetail = "absent";',
  '  if (loaderEl) {',
  '    var lr = loaderEl.getBoundingClientRect();',
  '    var ls = getComputedStyle(loaderEl);',
  '    loader = (lr.width > 4 && lr.height > 4 && ls.visibility !== "hidden" && ls.display !== "none" && ls.opacity !== "0");',
  '    loaderDetail = loader ? ("present " + Math.round(lr.width) + "x" + Math.round(lr.height)) : "in-dom-not-visible";',
  '  }',
  '',
  '  // --- T0 slogan ---',
  '  var sloganNeedles = ["一起探索无限可能", "探索无限可能", "无限可能"];',
  '  var t0 = false;',
  '  var t0Why = "no";',
  '  for (var si = 0; si < sloganNeedles.length; si++) {',
  '    if (bodyText.indexOf(sloganNeedles[si]) >= 0) { t0 = true; t0Why = "innerText:" + sloganNeedles[si]; break; }',
  '  }',
  '  if (!t0) {',
  '    var all = document.querySelectorAll("div,span,h1,h2,h3,p");',
  '    for (var ai = 0; ai < all.length; ai++) {',
  '      var el = all[ai];',
  '      var t = (el.textContent || "").trim();',
  '      if (!t || t.length > 40) continue;',
  '      for (var aj = 0; aj < sloganNeedles.length; aj++) {',
  '        if (t.indexOf(sloganNeedles[aj]) >= 0 && visible(el)) {',
  '          t0 = true; t0Why = "node:" + sloganNeedles[aj]; break;',
  '        }',
  '      }',
  '      if (t0) break;',
  '    }',
  '  }',
  '',
  '  // --- sidebar rows between 项目 and 最近 ---',
  '  // Headers may wrap icons, so do NOT require leaf-only nodes.',
  '  function findHeader(label) {',
  '    // Avoid querySelectorAll("*") — too slow under x64 emulation and hits CDP timeout.',
  '    var els = document.querySelectorAll("div,span,li,a,p,button,td,h1,h2,h3,h4");',
  '    var best = null;',
  '    for (var i = 0; i < els.length; i++) {',
  '      var el = els[i];',
  '      if (el.children.length > 2) continue;',
  '      var t = (el.textContent || "").replace(/\\s+/g, "").trim();',
  '      if (t !== label) continue;',
  '      if (!visible(el)) continue;',
  '      var r = el.getBoundingClientRect();',
  '      if (r.left > 460) continue;',
  '      if (!best || r.width * r.height < best.w * best.h) {',
  '        best = { el: el, y: r.top, x: r.left, w: r.width, h: r.height };',
  '      }',
  '    }',
  '    return best;',
  '  }',
  '',
  '  var projH = findHeader("项目");',
  '  var recentH = findHeader("最近");',
  '  var hasRecent = !!recentH || bodyText.indexOf("最近") >= 0;',
  '',
  '  var items = [];',
  '  var nodes = document.querySelectorAll("div,span,li,a,p,button,td,h1,h2,h3,h4");',
  '  for (var ni = 0; ni < nodes.length; ni++) {',
  '    var el = nodes[ni];',
  '    // ONLY true leaves. Parent textContent concatenates children and would',
  '    // double-count the same visible row.',
  '    if (el.children.length > 0) continue;',
  '    var t = (el.textContent || "").trim();',
  '    if (!t || t.length > 80) continue;',
  '    var r = el.getBoundingClientRect();',
  '    if (r.left > 460 || r.top < 30 || r.bottom > window.innerHeight - 20) continue;',
  '    if (!visible(el)) continue;',
  '    items.push({ t: t, y: r.top, x: r.left, h: r.height, d: depthOf(el) });',
  '  }',
  '  items.sort(function (a, b) { return a.y - b.y || a.x - b.x; });',
  '  // Collapse same visual line (icon+label or split text runs)',
  '  var deduped = [];',
  '  var lastY = -999;',
  '  for (var di = 0; di < items.length; di++) {',
  '    var cur = items[di];',
  '    if (cur.y - lastY < 6 && deduped.length > 0) {',
  '      var prev = deduped[deduped.length - 1];',
  '      if (cur.t.length > prev.t.length) {',
  '        prev.t = cur.t;',
  '        if (cur.x < prev.x) prev.x = cur.x;',
  '      }',
  '      continue;',
  '    }',
  '    deduped.push({ t: cur.t, y: cur.y, x: cur.x, h: cur.h, d: cur.d });',
  '    lastY = cur.y;',
  '  }',
  '  items = deduped;',
  '',
  '  var chrome = {',
  '    "项目": 1, "最近": 1, "暂无任务": 1, "暂无项目": 1, "暂无对话": 1,',
  '    "新建任务": 1, "插件": 1, "产物中心": 1, "自动化": 1, "搜索": 1,',
  '    "展开显示": 1, "显示更多": 1, "收起": 1, "置顶": 1, "更多": 1,',
  '    "Xiaomi MiMo": 1, "正在恢复": 1, "正在恢复历史对话…": 1,',
  '    "历史对话": 1, "导入的会话": 1',
  '  };',
  '',
  '  var projY = projH ? projH.y : null;',
  '  var recentY = recentH ? recentH.y : null;',
  '  var rows = 0;',
  '  var subRows = 0;',
  '  var topRows = 0;',
  '  var rowTexts = [];',
  '  var subTexts = [];',
  '  var projIdx = -1;',
  '  var recentIdx = -1;',
  '',
  '  // locate headings in the item list by y proximity / text',
  '  for (var i = 0; i < items.length; i++) {',
  '    var raw = items[i].t.replace(/\\s+/g, "");',
  '    if (projIdx < 0 && raw === "项目") projIdx = i;',
  '    if (raw === "最近") recentIdx = i;',
  '  }',
  '',
  '  if (projIdx >= 0 || projY != null) {',
  '    var startY = projY != null ? projY : (projIdx >= 0 && items[projIdx] ? items[projIdx].y : 0);',
  '    var endY = recentY != null ? recentY : (recentIdx >= 0 && items[recentIdx] ? items[recentIdx].y : 1e9);',
  '    var minX = 1e9;',
  '    var j;',
  '    for (j = 0; j < items.length; j++) {',
  '      var it = items[j];',
  '      if (it.y <= startY + 2) continue;',
  '      if (it.y >= endY - 2) continue;',
  '      var key = it.t.replace(/\\s+/g, "");',
  '      if (chrome[key]) continue;',
  '      if (key.length < 2) continue;',
  '      if (it.x < minX) minX = it.x;',
  '    }',
  '    if (minX > 1e8) minX = 0;',
  '',
  '    // Classify project titles vs sub-conversations.',
  '    // Indent alone is unreliable (flat left edge), so also use DOM depth:',
  '    // a sub-row is nested deeper than the shallowest row in this band.',
  '    var depths = [];',
  '    for (j = 0; j < items.length; j++) {',
  '      var it3 = items[j];',
  '      if (it3.y <= startY + 2) continue;',
  '      if (it3.y >= endY - 2) continue;',
  '      var k3 = it3.t.replace(/\\s+/g, "");',
  '      if (chrome[k3]) continue;',
  '      depths.push(it3.d || 0);',
  '    }',
  '    var minD = depths.length ? Math.min.apply(null, depths) : 0;',
  '    var SUB_INDENT = 8;',
  '    var dSub = 2;',
  '    for (j = 0; j < items.length; j++) {',
  '      var it2 = items[j];',
  '      if (it2.y <= startY + 2) continue;',
  '      if (it2.y >= endY - 2) continue;',
  '      var key2 = it2.t.replace(/\\s+/g, "");',
  '      if (chrome[key2]) continue;',
  '      if (key2.length < 2) continue;',
  '      if (/^[\\s\\d\\W]+$/.test(key2) && key2.length < 4) continue;',
  '      rows++;',
  '      if (rowTexts.length < 12) rowTexts.push(it2.t);',
  '      var byIndent = (it2.x >= minX + SUB_INDENT);',
  '      var byDepth = ((it2.d || 0) >= minD + dSub);',
  '      var isSub = byDepth || byIndent;',
  '      if (isSub) {',
  '        subRows++;',
  '        if (subTexts.length < 12) subTexts.push(it2.t);',
  '      } else {',
  '        topRows++;',
  '      }',
  '    }',
  '    // If indent/depth collapsed (all same x), split by text length:',
  '    // short names = project folders, longer lines = conversation titles.',
  '    if (subRows === 0 && rows >= 3) {',
  '      var shortN = 0;',
  '      var longN = 0;',
  '      for (j = 0; j < rowTexts.length; j++) {',
  '        var rt = rowTexts[j].replace(/\\s+/g, "");',
  '        if (rt.length <= 12) shortN++; else longN++;',
  '      }',
  '      if (longN >= 2) {',
  '        topRows = shortN;',
  '        subRows = longN;',
  '        subTexts = [];',
  '        for (j = 0; j < rowTexts.length; j++) {',
  '          if (rowTexts[j].replace(/\\s+/g, "").length > 12) subTexts.push(rowTexts[j]);',
  '        }',
  '      } else {',
  '        topRows = rows;',
  '        subRows = 0;',
  '      }',
  '    }',
  '  }',
  '',
  '  var t1 = t0 && hasRecent && (projIdx >= 0 || projY != null) && subRows >= 3;',
  '',
  '  // --- interactive control ---',
  '  var interactive = false;',
  '  var interactiveWhy = "no";',
  '  var iBtns = document.querySelectorAll("button, input, textarea, [role=button], [role=textbox]");',
  '  for (var ib = 0; ib < iBtns.length; ib++) {',
  '    var bel = iBtns[ib];',
  '    if (!visible(bel)) continue;',
  '    var br = bel.getBoundingClientRect();',
  '    if (br.width < 8 || br.height < 8) continue;',
  '    var bt = (bel.textContent || bel.getAttribute("aria-label") || bel.getAttribute("placeholder") || "").trim();',
  '    if (bt.indexOf("新建") >= 0 || bt.indexOf("任务") >= 0 || bel.tagName === "INPUT" || bel.tagName === "TEXTAREA") {',
  '      interactive = true;',
  '      interactiveWhy = (bel.tagName || "el") + ":" + (bt || "control").slice(0, 24);',
  '      break;',
  '    }',
  '  }',
  '  if (!interactive) {',
  '    if (bodyText.indexOf("新建任务") >= 0 || bodyText.indexOf("新建对话") >= 0) {',
  '      interactive = true;',
  '      interactiveWhy = "text:新建";',
  '    }',
  '  }',
  '',
  '  // --- performance timings (page clock, not host) ---',
  '  var perf = { fp: null, fcp: null, dcl: null, load: null, responseEnd: null };',
  '  try {',
  '    var paints = performance.getEntriesByType("paint");',
  '    for (var pi = 0; pi < paints.length; pi++) {',
  '      if (paints[pi].name === "first-paint") perf.fp = Math.round(paints[pi].startTime);',
  '      if (paints[pi].name === "first-contentful-paint") perf.fcp = Math.round(paints[pi].startTime);',
  '    }',
  '    var navs = performance.getEntriesByType("navigation");',
  '    if (navs && navs[0]) {',
  '      var n0 = navs[0];',
  '      if (n0.domContentLoadedEventEnd) perf.dcl = Math.round(n0.domContentLoadedEventEnd);',
  '      if (n0.loadEventEnd) perf.load = Math.round(n0.loadEventEnd);',
  '      if (n0.responseEnd) perf.responseEnd = Math.round(n0.responseEnd);',
  '    }',
  '  } catch (pe) {}',
  '',
  '  return {',
  '    loader: loader,',
  '    loaderDetail: loaderDetail,',
  '    t0: t0,',
  '    t0Why: t0Why,',
  '    t1: t1,',
  '    rows: rows,',
  '    subRows: subRows,',
  '    topRows: topRows,',
  '    subTexts: subTexts,',
  '    projIdx: projIdx,',
  '    recentIdx: recentIdx,',
  '    projY: projY,',
  '    recentY: recentY,',
  '    hasRecent: hasRecent,',
  '    itemCount: items.length,',
  '    rowTexts: rowTexts,',
  '    sample: items.map(function (x) { return x.t; }).slice(0, 30),',
  '    interactive: interactive,',
  '    interactiveWhy: interactiveWhy,',
  '    sidebarChrome: !!(projH && recentH),',
  '    perf: perf,',
  '  };',
  '  } catch (e) {',
  '    return { loader: false, t0: false, t1: false, rows: 0, subRows: 0, topRows: 0,',
  '      hasRecent: false, itemCount: 0, rowTexts: [], subTexts: [], sample: [],',
  '      interactive: false, interactiveWhy: "err", sidebarChrome: false,',
  '      perf: { fp: null, fcp: null, dcl: null, load: null, responseEnd: null },',
  '      t0Why: "probe-exception", err: String(e && e.message ? e.message : e) };',
  '  }',
  '})()'
].join('\n');

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

function cdpEvaluate(ws, id, expression) {
  return new Promise((resolve, reject) => {
    let settled = false;
    const timer = setTimeout(() => {
      if (settled) return;
      settled = true;
      ws.removeEventListener('message', onMsg);
      reject(new Error('cdp evaluate timeout'));
    }, 8000);

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
          else if (msg.result && msg.result.exceptionDetails) {
            const d = msg.result.exceptionDetails;
            reject(new Error(d.exception && d.exception.description ? d.exception.description : (d.text || 'page exception')));
          } else {
            resolve(msg.result);
          }
        }
      } catch (_) {}
    };
    ws.addEventListener('message', onMsg);
    try {
      ws.send(JSON.stringify({
        id,
        method: 'Runtime.evaluate',
        params: { expression, returnByValue: true, awaitPromise: true }
      }));
    } catch (e) {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      ws.removeEventListener('message', onMsg);
      reject(e);
    }
  });
}

async function main() {
  try {
    const proto = WebSocket && WebSocket.prototype;
    const caps = proto ? ['addEventListener', 'removeEventListener', 'send', 'close', 'once', 'on']
      .map((k) => k + '=' + (typeof proto[k])).join(' ') : 'no-proto';
    log({ event: 'ws-caps', ts: 0, detail: caps });
  } catch (_) {}
  const t0host = Date.now();
  const deadline = t0host + TIMEOUT;

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
  log({ event: 'connected', ts: Date.now() - t0host, ws: wsUrl });

  let id = 1;
  let loaderMs = null;
  let mainUiMs = null;
  let listMs = null;
  let sidebarMs = null;
  let interactiveMs = null;
  let perf = { fp: null, fcp: null, dcl: null, load: null, responseEnd: null };
  let perfEmitted = { fp: false, fcp: false, dcl: false, load: false, responseEnd: false };
  let lastRows = -1;
  let stableRows = 0;
  let polls = 0;
  let lastDebug = 0;

  while (Date.now() < deadline) {
    let result = null;
    try {
      const raw = await cdpEvaluate(ws, id++, PAGE_PROBE);
      if (raw && raw.result && raw.result.value != null) {
        result = raw.result.value;
      }
    } catch (e) {
      const nowErr = Date.now() - t0host;
      if (nowErr - lastDebug >= 1500) {
        lastDebug = nowErr;
        log({ event: 'probe-debug', ts: nowErr, detail: 'evaluate-error ' + String(e && e.message ? e.message : e) });
      }
    }

    const now = Date.now() - t0host;
    polls++;

    if (result) {
      if (result.perf) {
        for (const k of ['fp', 'fcp', 'dcl', 'load', 'responseEnd']) {
          if (result.perf[k] != null && perf[k] == null) {
            perf[k] = result.perf[k];
          }
          if (perf[k] != null && !perfEmitted[k]) {
            perfEmitted[k] = true;
            log({ event: 'perf', ts: now, detail: `${k}=${perf[k]}` });
          }
        }
      }

      if (loaderMs == null && result.loader) {
        loaderMs = now;
        log({ event: 'startup-loader', ts: now, detail: result.loaderDetail });
      }

      if (sidebarMs == null && result.sidebarChrome) {
        sidebarMs = now;
        log({ event: 'sidebar-chrome', ts: now, detail: '项目+最近 visible' });
      }

      if (interactiveMs == null && result.interactive) {
        interactiveMs = now;
        log({ event: 'interactive', ts: now, detail: result.interactiveWhy || 'control' });
      }

      if (mainUiMs == null && result.t0) {
        mainUiMs = now;
        log({ event: 'main-ui', ts: now, detail: `slogan ${result.t0Why}` });
      }

      if (listMs == null) {
        const canJudge = result.hasRecent && (result.projIdx >= 0 || result.projY != null);
        const sub = result.subRows || 0;
        if (canJudge && sub >= 3) {
          if (sub === lastRows) stableRows++;
          else { stableRows = 1; lastRows = sub; }
          if (stableRows >= 2) {
            listMs = now;
            log({
              event: 'list-ready',
              ts: now,
              detail: `subRows=${sub} topRows=${result.topRows} texts=${JSON.stringify(result.subTexts)}`
            });
          }
        } else {
          lastRows = sub;
          stableRows = 0;
        }
      }

      // periodic debug while T0 or T1 missing
      if ((mainUiMs == null || listMs == null) && now - lastDebug >= 1500) {
        lastDebug = now;
        log({
          event: 'probe-debug',
          ts: now,
          detail: JSON.stringify({
            t0: result.t0,
            t0Why: result.t0Why,
            loader: result.loader,
            rows: result.rows,
            subRows: result.subRows,
            topRows: result.topRows,
            subTexts: result.subTexts,
            projIdx: result.projIdx,
            recentIdx: result.recentIdx,
            projY: result.projY,
            recentY: result.recentY,
            hasRecent: result.hasRecent,
            itemCount: result.itemCount,
            sample: result.sample
          })
        });
      }
    }

    if (mainUiMs != null && listMs != null) {
      // brief grace so perf load / interactive can still land in done
      if (interactiveMs != null && (perf.load != null || now > (listMs + 800))) break;
      if (interactiveMs == null && now > (listMs + 800)) break;
    }

    await new Promise((r) => setTimeout(r, POLL_MS));
  }

  log({
    event: 'done',
    loaderMs,
    mainUiMs,
    listMs,
    sidebarMs,
    interactiveMs,
    mainToListMs: mainUiMs != null && listMs != null ? listMs - mainUiMs : null,
    perf,
    polls
  });
  try { ws.close(); } catch {}
  process.exit(mainUiMs != null && listMs != null ? 0 : 3);
}

main().catch((e) => {
  log({ event: 'error', message: String(e && e.message ? e.message : e) });
  process.exit(1);
});
