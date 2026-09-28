(() => {
  const stage = document.getElementById("stage");
  const slides = Array.from(document.querySelectorAll(".slide"));
  const progressBar = document.getElementById("progress-bar");
  const subtitleEl = document.getElementById("subtitle");
  const pageInd = document.getElementById("page-ind");
  const btnPrev = document.getElementById("btn-prev");
  const btnNext = document.getElementById("btn-next");
  const btnPlay = document.getElementById("btn-play");

  const BASE_W = 1600;
  const BASE_H = 1000;
  let index = 0;
  let auto = false;
  let timer = null;


  function prepStagger(slide) {
    const nodes = slide.querySelectorAll(".reveal, .block, .wf-row, .wf-total, .track-line");
    nodes.forEach((el, i) => {
      // --i feeds child calc() staggers. The inline delay outranks every
      // stylesheet stagger rule (.dN classes, one-shot shorthands, block
      // calc()s), so playback always follows document order; an explicit
      // animation-delay in the HTML is kept as an escape hatch.
      el.style.setProperty("--i", String(i));
      if (!el.style.animationDelay) {
        el.style.animationDelay = `${i * 0.24}s`;
      }
    });
  }

  function fitStage() {
    const pad = 24;
    const vw = window.innerWidth - pad;
    const vh = window.innerHeight - pad;
    const scale = Math.min(vw / BASE_W, vh / BASE_H);
    stage.style.transform = `scale(${scale})`;
  }

  function durationOf(i) {
    const n = Number(slides[i]?.dataset.dur || 8);
    return Math.max(2, n) * 1000;
  }

  function show(i, { pushHash = true } = {}) {
    index = Math.max(0, Math.min(slides.length - 1, i));
    slides.forEach((s, n) => {
      const on = n === index;
      if (on) {
        prepStagger(s);
        // drop playing first so keyframes can replay after reflow
        s.classList.remove("playing");
        void s.offsetWidth;
        s.classList.add("active", "playing");
      } else {
        s.classList.remove("active", "playing");
      }
    });
    const sub = slides[index].dataset.sub || "";
    subtitleEl.textContent = sub;
    pageInd.textContent = `${index + 1} / ${slides.length}`;
    progressBar.style.width = `${((index + 1) / slides.length) * 100}%`;
    if (pushHash) {
      const hash = `#p${index + 1}`;
      if (location.hash !== hash) history.replaceState(null, "", hash);
    }
    if (auto) restartTimer();
  }

  function restartTimer() {
    clearTimeout(timer);
    const dur = durationOf(index);
    timer = setTimeout(() => {
      if (index >= slides.length - 1) {
        setAuto(false);
        return;
      }
      show(index + 1);
    }, dur);
  }

  function setAuto(on) {
    auto = on;
    btnPlay.textContent = on ? "❚❚" : "▶";
    btnPlay.title = on ? "Pause (A)" : "Auto play (A)";
    if (on) restartTimer();
    else clearTimeout(timer);
  }

  function parseHash() {
    const m = /#p(\d+)/.exec(location.hash || "");
    if (!m) return 0;
    const n = Number(m[1]) - 1;
    return Number.isFinite(n) ? n : 0;
  }

  btnPrev.addEventListener("click", () => show(index - 1));
  btnNext.addEventListener("click", () => show(index + 1));
  btnPlay.addEventListener("click", () => setAuto(!auto));

  window.addEventListener("keydown", (e) => {
    if (e.target && /input|textarea/i.test(e.target.tagName)) return;
    switch (e.key) {
      case "ArrowRight":
      case "PageDown":
      case " ":
        e.preventDefault();
        show(index + 1);
        break;
      case "ArrowLeft":
      case "PageUp":
        e.preventDefault();
        show(index - 1);
        break;
      case "Home":
        e.preventDefault();
        show(0);
        break;
      case "End":
        e.preventDefault();
        show(slides.length - 1);
        break;
      case "a":
      case "A":
        setAuto(!auto);
        break;
      case "p":
      case "P":
        setAuto(false);
        break;
      default:
        break;
    }
  });

  window.addEventListener("resize", fitStage);
  window.addEventListener("hashchange", () => show(parseHash(), { pushHash: false }));

  const params = new URLSearchParams(location.search);
  fitStage();
  slides.forEach(prepStagger);
  show(parseHash());
  if (params.get("auto") === "1") setAuto(true);

  // expose for recording scripts
  window.__deck = {
    show,
    setAuto,
    get index() { return index; },
    get total() { return slides.length; },
    durationOf,
  };
})();
