(() => {
  const stage = document.getElementById("stage");
  const slides = Array.from(document.querySelectorAll(".slide"));
  const progressBar = document.getElementById("progress-bar");

  const BASE_W = 1600;
  const BASE_H = 1000;
  let index = 0;

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
    // innerWidth/Height match the layout viewport that #stage-wrap (fixed inset:0)
    // uses as its containing block — keep scale and left/top in that same space.
    // Explicitly place the *scaled* box; grid-centering the 1600×1000 layout box
    // against a smaller viewport (200% DPI / Edge zoom) makes the visual drift.
    const vw = window.innerWidth;
    const vh = window.innerHeight;
    const scale = Math.min(vw / BASE_W, vh / BASE_H);
    stage.style.transform = `scale(${scale})`;
    stage.style.left = `${Math.round((vw - BASE_W * scale) / 2)}px`;
    stage.style.top = `${Math.round((vh - BASE_H * scale) / 2)}px`;
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
    progressBar.style.width = `${((index + 1) / slides.length) * 100}%`;
    if (pushHash) {
      const hash = `#p${index + 1}`;
      if (location.hash !== hash) history.replaceState(null, "", hash);
    }
  }

  function parseHash() {
    const m = /#p(\d+)/.exec(location.hash || "");
    if (!m) return 0;
    const n = Number(m[1]) - 1;
    return Number.isFinite(n) ? n : 0;
  }

  window.addEventListener("keydown", (e) => {
    if (e.target && /input|textarea/i.test(e.target.tagName)) return;
    switch (e.key) {
      case "ArrowRight":
      case "ArrowDown":
      case "PageDown":
      case " ":
      case "Enter":
      case "n":
      case "N":
        e.preventDefault();
        show(index + 1);
        break;
      case "ArrowLeft":
      case "ArrowUp":
      case "PageUp":
      case "p":
      case "P":
      case "Backspace":
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
      case "f":
      case "F":
        e.preventDefault();
        if (document.fullscreenElement) document.exitFullscreen();
        else document.documentElement.requestFullscreen?.();
        break;
      default:
        break;
    }
  });

  window.addEventListener("resize", fitStage);
  window.addEventListener("hashchange", () => show(parseHash(), { pushHash: false }));

  fitStage();
  slides.forEach(prepStagger);
  show(parseHash());

  // expose for recording scripts
  window.__deck = {
    show,
    get index() { return index; },
    get total() { return slides.length; },
  };
})();
