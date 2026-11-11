(function () {
  "use strict";

  const C = window.SM_CONFIG;
  const SM = (window.SM = window.SM || {});
  const NS = "http://www.w3.org/2000/svg";

  SM.lakh = (rupees) => "₹" + (rupees / 100000).toFixed(1) + " L";
  SM.reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  const VIEW = { w: 1200, h: 860 };
  const WALL = { x: 30, y: 30, w: 1140, h: 800 };
  const AVENUE = { x: 570, w: 60 };
  const CROSS = { y: 340, h: 40 };
  const BOTTOM = { y: 740, h: 40 };
  const DEPTH = 60;
  const ROAD_X = [111, 264, 417, 750, 903, 1056];
  const SEGMENTS = [
    { top: 560, bottom: 740 },
    { top: 380, bottom: 560 }
  ];
  const PARKS = [
    { x: 450, y: 380, w: 120, h: 180 },
    { x: 630, y: 380, w: 120, h: 180 }
  ];
  const FRONTAGE = { 150: 22.5, 200: 30, 267: 40, 300: 45, 400: 60 };
  const DIMENSIONS = { 150: "22.5 × 60 ft", 200: "30 × 60 ft", 267: "40 × 60 ft", 300: "45 × 60 ft", 400: "60 × 60 ft" };

  const COLUMNS = [
    { x: 51, facing: "East" },
    { x: 144, facing: "West" },
    { x: 204, facing: "East" },
    { x: 297, facing: "West" },
    { x: 357, facing: "East" },
    { x: 450, facing: "West", park: true },
    { x: 510, facing: "East", park: true, avenue: true },
    { x: 630, facing: "West", park: true, avenue: true },
    { x: 690, facing: "East", park: true },
    { x: 783, facing: "West" },
    { x: 843, facing: "East" },
    { x: 936, facing: "West" },
    { x: 996, facing: "East" },
    { x: 1089, facing: "West" }
  ];

  const PATTERNS = [
    { sizes: [150, 150, 150, 150, 150, 150, 150, 150], weight: 1 },
    { sizes: [200, 200, 200, 200, 200, 200], weight: 2 },
    { sizes: [300, 300, 300, 300], weight: 2 },
    { sizes: [400, 400, 400], weight: 1 },
    { sizes: [267, 267, 267, 400], weight: 2 },
    { sizes: [200, 200, 267, 267, 267], weight: 2 },
    { sizes: [150, 150, 150, 150, 200, 200, 200], weight: 2 },
    { sizes: [200, 200, 200, 300, 300], weight: 2 }
  ];

  function mulberry32(seed) {
    let a = seed;
    return function () {
      a |= 0;
      a = (a + 0x6d2b79f5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function pickPattern(rand) {
    const total = PATTERNS.reduce((sum, p) => sum + p.weight, 0);
    let roll = rand() * total;
    for (const p of PATTERNS) {
      roll -= p.weight;
      if (roll < 0) return p.sizes;
    }
    return PATTERNS[0].sizes;
  }

  function buildPlots() {
    const rand = mulberry32(51520);
    const plots = [];
    COLUMNS.forEach((col) => {
      SEGMENTS.forEach((seg, si) => {
        if (col.park && si === 1) return;
        const pattern = pickPattern(rand);
        const sizes = rand() < 0.5 ? pattern.slice() : pattern.slice().reverse();
        let y = seg.bottom;
        sizes.forEach((size, i) => {
          const h = FRONTAGE[size];
          y -= h;
          plots.push({
            size,
            x: col.x,
            y,
            w: DEPTH,
            h,
            facing: col.facing,
            avenue: !!col.avenue,
            corner: (si === 0 && i === 0) || (si === 1 && i === sizes.length - 1)
          });
        });
      });
    });
    plots.forEach((p, i) => {
      p.id = i + 1;
      p.number = String(i + 1).padStart(3, "0");
      p.price = p.size * C.pricePerSqYd;
      p.dimensions = DIMENSIONS[p.size];
      p.cx = p.x + p.w / 2;
      p.cy = p.y + p.h / 2;
      let roll = rand();
      if (p.avenue || p.corner) roll *= 0.8;
      p.status = roll < 0.34 ? "sold" : roll < 0.68 ? "booked" : "available";
    });
    return plots;
  }

  const plots = buildPlots();
  const stats = plots.reduce(
    (acc, p) => {
      acc[p.status] += 1;
      return acc;
    },
    { total: plots.length, available: 0, booked: 0, sold: 0 }
  );
  stats.bookedPct = Math.round(((stats.booked + stats.sold) / stats.total) * 100);
  stats.phase2 = Math.max(C.totalPlots - stats.total, 0);

  const STATUS_LABEL = { available: "Available", booked: "Booked", sold: "Sold" };

  SM.plan = {
    plots,
    stats,
    statusLabel: STATUS_LABEL,
    count(filterFn) {
      return plots.filter(filterFn).length;
    },
    describe(p) {
      return `Plot ${p.number} · ${p.size} sq. yd · ${p.facing} facing · ${SM.lakh(p.price)} · ${STATUS_LABEL[p.status]}`;
    }
  };

  function node(name, attrs, parent) {
    const n = document.createElementNS(NS, name);
    if (attrs) for (const k in attrs) n.setAttribute(k, attrs[k]);
    if (parent) parent.appendChild(n);
    return n;
  }

  function text(parent, x, y, value, cls, extra) {
    const t = node("text", Object.assign({ x, y, class: cls }, extra || {}), parent);
    t.textContent = value;
    return t;
  }

  function stone(parent, x, y, cls) {
    return node("path", { d: `M${x - 5},${y + 6} L${x - 5},${y - 2} L${x},${y - 7} L${x + 5},${y - 2} L${x + 5},${y + 6} Z`, class: cls || "pl-stone" }, parent);
  }

  function renderSvg() {
    const svg = node("svg", {
      viewBox: `0 0 ${VIEW.w} ${VIEW.h}`,
      class: "plan-svg",
      role: "group",
      "aria-labelledby": "plan-svg-title",
      "aria-describedby": "plan-help"
    });
    const title = node("title", { id: "plan-svg-title" }, svg);
    title.textContent = `${C.brand} master plan. Phase 1 has ${stats.total} plots, ${stats.available} available.`;

    const defs = node("defs", null, svg);
    const hatch = node("pattern", { id: "pl-hatch", width: 9, height: 9, patternUnits: "userSpaceOnUse", patternTransform: "rotate(45)" }, defs);
    node("line", { x1: 0, y1: 0, x2: 0, y2: 9, class: "pl-hatch-line" }, hatch);

    const base = node("g", { "aria-hidden": "true" }, svg);
    const wall = node("rect", { x: WALL.x, y: WALL.y, width: WALL.w, height: WALL.h, rx: 4, class: "pl-wall" }, base);

    const phase2 = node("g", { class: "pl-phase2" }, base);
    node("rect", { x: 40, y: 40, width: 1120, height: 300, class: "pl-phase2-area" }, phase2);
    node("rect", { x: AVENUE.x, y: 40, width: AVENUE.w, height: 300, class: "pl-future-road" }, phase2);
    ROAD_X.forEach((x) => node("rect", { x, y: 40, width: 33, height: 300, class: "pl-future-road" }, phase2));
    node("rect", { x: 300, y: 150, width: 600, height: 82, rx: 3, class: "pl-phase2-tag" }, phase2);
    text(phase2, 600, 186, "PHASE 2", "pl-phase2-title", { "text-anchor": "middle" });
    text(phase2, 600, 212, `LAUNCHING SOON · ${stats.phase2} PLOTS`, "pl-label pl-label--strong", { "text-anchor": "middle" });

    const roads = node("g", { class: "pl-roads" }, base);
    const roadEls = [];
    roadEls.push(node("rect", { x: 40, y: BOTTOM.y, width: 1120, height: BOTTOM.h, class: "pl-road", "data-axis": "x" }, roads));
    roadEls.push(node("rect", { x: 40, y: CROSS.y, width: 1120, height: CROSS.h, class: "pl-road", "data-axis": "x" }, roads));
    ROAD_X.forEach((x) => roadEls.push(node("rect", { x, y: 380, width: 33, height: 360, class: "pl-road", "data-axis": "y" }, roads)));
    roadEls.push(node("rect", { x: AVENUE.x, y: 340, width: AVENUE.w, height: 490, class: "pl-road pl-road--avenue", "data-axis": "y" }, roads));
    const centre = node("line", { x1: 600, y1: 828, x2: 600, y2: 344, class: "pl-centre-line" }, roads);

    const parks = node("g", { class: "pl-parks" }, base);
    PARKS.forEach((pk, i) => {
      const g = node("g", { class: "pl-park" }, parks);
      node("rect", { x: pk.x + 2, y: pk.y + 2, width: pk.w - 4, height: pk.h - 4, rx: 3, class: "pl-park-lawn" }, g);
      node("rect", { x: pk.x + 14, y: pk.y + 16, width: pk.w - 28, height: pk.h - 32, rx: 26, class: "pl-park-track" }, g);
      const trees = i === 0 ? [[476, 410], [540, 404], [470, 530], [546, 520]] : [[656, 404], [724, 412], [650, 522], [728, 532]];
      trees.forEach(([tx, ty]) => node("circle", { cx: tx, cy: ty, r: 6.5, class: "pl-tree" }, g));
      if (i === 1) {
        node("rect", { x: 676, y: 446, width: 30, height: 30, rx: 3, class: "pl-play" }, g);
      }
    });
    text(parks, 510, 466, "CENTRAL", "pl-label pl-label--park", { "text-anchor": "middle" });
    text(parks, 510, 479, "PARK", "pl-label pl-label--park", { "text-anchor": "middle" });
    text(parks, 691, 494, "PLAY AREA", "pl-label pl-label--park", { "text-anchor": "middle" });

    const labels = node("g", { class: "pl-labels" }, base);
    text(labels, 0, 0, `${C.mainAvenueFt}′ MAIN AVENUE`, "pl-label pl-label--road", { transform: "translate(604 700) rotate(-90)" });
    text(labels, 250, 763, "40′ ROAD", "pl-label pl-label--road");
    text(labels, 880, 363, "40′ ROAD", "pl-label pl-label--road");
    text(labels, 0, 0, "33′ ROAD", "pl-label pl-label--road", { transform: "translate(131 700) rotate(-90)" });

    const gate = node("g", { class: "pl-gate" }, base);
    node("rect", { x: 556, y: 812, width: 12, height: 30, rx: 1, class: "pl-gate-pillar" }, gate);
    node("rect", { x: 632, y: 812, width: 12, height: 30, rx: 1, class: "pl-gate-pillar" }, gate);
    node("line", { x1: 568, y1: 818, x2: 632, y2: 818, class: "pl-gate-beam" }, gate);
    text(gate, 600, 856, "ENTRANCE", "pl-label pl-label--strong", { "text-anchor": "middle" });

    const survey = node("g", { class: "pl-survey" }, base);
    [[WALL.x, WALL.y], [WALL.x + WALL.w, WALL.y], [WALL.x, WALL.y + WALL.h], [WALL.x + WALL.w, WALL.y + WALL.h], [600, WALL.y]].forEach(([x, y]) => stone(survey, x, y));
    text(survey, 30, 18, `${C.coordinates.lat.toFixed(2)}° N · ${C.coordinates.lng.toFixed(2)}° E`, "pl-label");
    text(survey, 1170, 18, `${C.acres} ACRES · ${C.totalPlots} PLOTS`, "pl-label", { "text-anchor": "end" });
    const north = node("g", { transform: "translate(1128 70)" }, survey);
    node("circle", { cx: 0, cy: 0, r: 16, class: "pl-compass" }, north);
    node("path", { d: "M0,-12 L5,6 L0,2 L-5,6 Z", class: "pl-compass-needle" }, north);
    text(north, 0, -20, "N", "pl-label pl-label--strong", { "text-anchor": "middle" });
    const scale = node("g", { transform: "translate(60 806)" }, survey);
    node("line", { x1: 0, y1: 0, x2: 100, y2: 0, class: "pl-scale" }, scale);
    [0, 50, 100].forEach((x) => node("line", { x1: x, y1: -4, x2: x, y2: 4, class: "pl-scale" }, scale));
    text(scale, 0, 16, "0", "pl-label", { "text-anchor": "middle" });
    text(scale, 100, 16, "100 FT", "pl-label", { "text-anchor": "middle" });

    const plotGroup = node("g", { class: "pl-plots", role: "group", "aria-label": `Phase 1 plots, ${stats.total} in total` }, svg);
    plots.forEach((p) => {
      const g = node("g", {
        class: `plot is-${p.status}`,
        role: "button",
        tabindex: "-1",
        "data-id": p.id,
        "aria-label": `Plot ${p.number}, ${p.size} square yards, ${p.facing} facing, ${SM.lakh(p.price).replace(" L", " lakh")}, ${STATUS_LABEL[p.status]}${p.corner ? ", corner plot" : ""}`
      }, plotGroup);
      node("rect", { x: p.x + 1.4, y: p.y + 1.4, width: p.w - 2.8, height: p.h - 2.8, rx: 1.5 }, g);
      text(g, p.cx, p.cy + 3.2, p.number, "plot-num", { "text-anchor": "middle", "aria-hidden": "true" });
      p.el = g;
    });

    return { svg, wall, roadEls, centre, parks, labels, gate, phase2, survey, plotGroup };
  }

  function mount() {
    const root = document.querySelector("[data-plan]");
    if (!root) return;
    const stage = root.querySelector(".plan__stage");
    const scroller = root.querySelector(".plan__scroller");
    const card = root.querySelector(".plot-card");
    const backdrop = root.querySelector(".plot-sheet-backdrop");
    const parts = renderSvg();
    scroller.appendChild(parts.svg);

    const sheetMode = window.matchMedia("(max-width: 767px), (hover: none)");
    const fields = {
      title: card.querySelector("[data-card-title]"),
      meta: card.querySelector("[data-card-meta]"),
      status: card.querySelector("[data-card-status]"),
      dims: card.querySelector("[data-card-dims]"),
      corner: card.querySelector("[data-card-corner]"),
      action: card.querySelector("[data-card-enquire]"),
      close: card.querySelector("[data-card-close]")
    };

    let filterFn = () => true;
    let current = plots.find((p) => p.status === "available") || plots[0];
    let shown = null;
    let pinned = false;
    let hideTimer = 0;
    current.el.setAttribute("tabindex", "0");

    function visiblePlots() {
      return plots.filter(filterFn);
    }

    function setCurrent(p, focus) {
      if (current && current !== p) current.el.setAttribute("tabindex", "-1");
      current = p;
      p.el.setAttribute("tabindex", "0");
      if (focus) {
        p.el.focus({ preventScroll: true });
        revealInScroller(p);
      }
    }

    function revealInScroller(p) {
      const s = scroller.getBoundingClientRect();
      const r = p.el.getBoundingClientRect();
      if (r.left < s.left + 16) scroller.scrollLeft -= s.left + 16 - r.left;
      else if (r.right > s.right - 16) scroller.scrollLeft += r.right - (s.right - 16);
    }

    function fill(p) {
      fields.title.textContent = `Plot ${p.number}`;
      fields.meta.textContent = `${p.size} sq. yd · ${p.facing} facing · ${SM.lakh(p.price)}`;
      fields.status.textContent = STATUS_LABEL[p.status];
      fields.status.className = `pill pill--${p.status}`;
      fields.dims.textContent = p.dimensions;
      fields.corner.hidden = !p.corner;
      fields.action.textContent = p.status === "available" ? "Enquire about this plot" : "Enquire about similar plots";
      card.setAttribute("aria-label", SM.plan.describe(p));
    }

    function position(p) {
      if (sheetMode.matches) {
        card.style.transform = "";
        return;
      }
      const wrap = stage.getBoundingClientRect();
      const r = p.el.getBoundingClientRect();
      const cw = card.offsetWidth;
      const ch = card.offsetHeight;
      let left = r.right - wrap.left + 14;
      if (left + cw > wrap.width - 8) left = r.left - wrap.left - cw - 14;
      left = Math.max(8, left);
      let top = r.top - wrap.top + r.height / 2 - ch / 2;
      top = Math.min(Math.max(8, top), wrap.height - ch - 8);
      card.style.transform = `translate(${Math.round(left)}px, ${Math.round(top)}px)`;
    }

    function show(p, opts) {
      clearTimeout(hideTimer);
      const o = opts || {};
      if (shown) shown.el.classList.remove("is-active");
      shown = p;
      pinned = !!o.pin;
      p.el.classList.add("is-active");
      fill(p);
      card.hidden = false;
      card.classList.toggle("is-pinned", pinned);
      position(p);
      requestAnimationFrame(() => card.classList.add("is-open"));
      if (sheetMode.matches && pinned) {
        backdrop.hidden = false;
        requestAnimationFrame(() => backdrop.classList.add("is-open"));
        document.documentElement.classList.add("sheet-open");
        if (SM.lenis) SM.lenis.stop();
      }
      if (o.focusCard) setTimeout(() => fields.action.focus(), 30);
    }

    function hide(returnFocus) {
      clearTimeout(hideTimer);
      if (!shown) return;
      const was = shown;
      shown.el.classList.remove("is-active");
      shown = null;
      pinned = false;
      card.classList.remove("is-open", "is-pinned");
      backdrop.classList.remove("is-open");
      document.documentElement.classList.remove("sheet-open");
      if (SM.lenis) SM.lenis.start();
      setTimeout(() => {
        if (!shown) {
          card.hidden = true;
          backdrop.hidden = true;
        }
      }, 220);
      if (returnFocus) {
        setCurrent(was, false);
        was.el.focus({ preventScroll: true });
      }
    }

    function scheduleHide() {
      if (pinned) return;
      clearTimeout(hideTimer);
      hideTimer = setTimeout(() => hide(false), 220);
    }

    function plotFrom(target) {
      const g = target.closest && target.closest(".plot");
      return g ? plots[Number(g.getAttribute("data-id")) - 1] : null;
    }

    parts.plotGroup.addEventListener("pointerover", (e) => {
      if (e.pointerType !== "mouse" || sheetMode.matches || pinned) return;
      const p = plotFrom(e.target);
      if (p && p !== shown) show(p);
      else if (p) clearTimeout(hideTimer);
    });
    parts.plotGroup.addEventListener("pointerout", (e) => {
      if (e.pointerType !== "mouse" || sheetMode.matches) return;
      const to = e.relatedTarget && plotFrom(e.relatedTarget);
      if (!to) scheduleHide();
    });
    card.addEventListener("pointerenter", () => clearTimeout(hideTimer));
    card.addEventListener("pointerleave", (e) => {
      if (e.pointerType === "mouse") scheduleHide();
    });

    parts.plotGroup.addEventListener("click", (e) => {
      const p = plotFrom(e.target);
      if (!p) return;
      setCurrent(p, false);
      show(p, { pin: true });
    });

    parts.plotGroup.addEventListener("focusin", (e) => {
      const p = plotFrom(e.target);
      if (!p) return;
      if (p !== current) setCurrent(p, false);
      if (!sheetMode.matches && (!pinned || shown !== p)) show(p);
    });

    root.addEventListener("focusout", (e) => {
      if (sheetMode.matches && pinned) return;
      if (e.relatedTarget && root.contains(e.relatedTarget)) return;
      hide(false);
    });

    const KEYS = { ArrowRight: [1, 0], ArrowLeft: [-1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] };

    function nearest(from, dir) {
      let best = null;
      let bestScore = Infinity;
      visiblePlots().forEach((p) => {
        if (p === from) return;
        const dx = p.cx - from.cx;
        const dy = p.cy - from.cy;
        const primary = dir[0] ? dx * dir[0] : dy * dir[1];
        if (primary <= 1) return;
        const perp = dir[0] ? Math.abs(dy) : Math.abs(dx);
        const score = primary + perp * 2.2;
        if (score < bestScore) {
          bestScore = score;
          best = p;
        }
      });
      return best;
    }

    parts.plotGroup.addEventListener("keydown", (e) => {
      const p = plotFrom(e.target);
      if (!p) return;
      const dir = KEYS[e.key];
      if (dir) {
        e.preventDefault();
        const next = nearest(p, dir);
        if (next) setCurrent(next, true);
        return;
      }
      if (e.key === "Home" || e.key === "End") {
        e.preventDefault();
        const list = visiblePlots();
        if (list.length) setCurrent(e.key === "Home" ? list[0] : list[list.length - 1], true);
        return;
      }
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        show(p, { pin: true, focusCard: true });
        return;
      }
      if (e.key === "Escape") hide(false);
    });

    card.addEventListener("keydown", (e) => {
      if (e.key === "Escape") {
        e.preventDefault();
        hide(true);
      }
    });
    fields.close.addEventListener("click", () => hide(true));
    backdrop.addEventListener("click", () => hide(false));
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && shown && pinned && sheetMode.matches) hide(true);
    });
    document.addEventListener("pointerdown", (e) => {
      if (!shown || !pinned || sheetMode.matches) return;
      if (card.contains(e.target) || plotFrom(e.target)) return;
      hide(false);
    });

    fields.action.addEventListener("click", () => {
      const p = shown;
      if (!p) return;
      hide(false);
      document.dispatchEvent(new CustomEvent("sm:enquire", { detail: p }));
    });

    const FILTERS = {
      all: () => true,
      available: (p) => p.status === "available",
      east: (p) => p.facing === "East",
      large: (p) => p.size >= 200
    };
    const chips = root.querySelectorAll("[data-filter]");
    const countOut = root.querySelector("[data-plan-count]");

    function applyFilter(key) {
      filterFn = FILTERS[key] || FILTERS.all;
      chips.forEach((c) => c.setAttribute("aria-pressed", String(c.getAttribute("data-filter") === key)));
      let matching = 0;
      plots.forEach((p) => {
        const match = filterFn(p);
        if (match) matching += 1;
        p.el.classList.toggle("is-dim", !match);
      });
      if (countOut) countOut.textContent = key === "all" ? `${stats.total} plots in Phase 1` : `${matching} of ${stats.total} plots match`;
      if (!filterFn(current)) {
        const first = visiblePlots()[0];
        if (first) setCurrent(first, false);
      }
      if (shown && !filterFn(shown)) hide(false);
    }
    chips.forEach((c) => c.addEventListener("click", () => applyFilter(c.getAttribute("data-filter"))));
    applyFilter("all");

    root.querySelectorAll("[data-legend]").forEach((elm) => {
      elm.textContent = String(stats[elm.getAttribute("data-legend")]);
    });

    window.addEventListener("resize", () => {
      if (shown) position(shown);
    });

    if (sheetMode.matches) {
      requestAnimationFrame(() => {
        scroller.scrollLeft = (scroller.scrollWidth - scroller.clientWidth) / 2;
      });
    }

    animate(parts);
  }

  function animate(parts) {
    const gsap = window.gsap;
    if (!gsap || SM.reduceMotion || !window.ScrollTrigger) return;
    gsap.registerPlugin(window.ScrollTrigger);
    const gate = { x: 600, y: 830 };
    const ordered = plots.slice().sort((a, b) => Math.hypot(a.cx - gate.x, a.cy - gate.y) - Math.hypot(b.cx - gate.x, b.cy - gate.y));
    const batches = [];
    for (let i = 0; i < ordered.length; i += 12) batches.push(ordered.slice(i, i + 12).map((p) => p.el));

    const xRoads = parts.roadEls.filter((r) => r.getAttribute("data-axis") === "x");
    const yRoads = parts.roadEls.filter((r) => r.getAttribute("data-axis") === "y");
    gsap.set(xRoads, { scaleX: 0, transformOrigin: "50% 50%" });
    gsap.set(yRoads, { scaleY: 0, transformOrigin: "50% 100%" });
    gsap.set([parts.wall, parts.centre, parts.labels, parts.phase2, parts.survey, parts.gate], { opacity: 0 });
    gsap.set(parts.parks, { opacity: 0 });
    gsap.set(plots.map((p) => p.el), { opacity: 0, scale: 0.4, transformOrigin: "50% 50%" });

    const tl = gsap.timeline({
      defaults: { ease: "expo.out" },
      scrollTrigger: { trigger: parts.svg, start: "top 78%", once: true }
    });
    tl.to(parts.wall, { opacity: 1, duration: 0.6 })
      .to(parts.gate, { opacity: 1, duration: 0.5 }, 0.1)
      .to(yRoads[yRoads.length - 1], { scaleY: 1, duration: 1.1, ease: "power3.inOut" }, 0.1)
      .to(xRoads, { scaleX: 1, duration: 1, ease: "power3.inOut" }, 0.45)
      .to(yRoads.slice(0, -1), { scaleY: 1, duration: 0.9, stagger: 0.05, ease: "power3.inOut" }, 0.7)
      .to([parts.centre, parts.labels, parts.survey], { opacity: 1, duration: 0.6 }, 1.1)
      .to(parts.parks, { opacity: 1, duration: 0.7 }, 1.1)
      .to(parts.phase2, { opacity: 1, duration: 0.8 }, 1.3);
    batches.forEach((batch, i) => {
      tl.to(batch, { opacity: 1, scale: 1, duration: 0.5, stagger: 0.012, ease: "back.out(1.6)" }, 1.15 + i * 0.07);
    });
  }

  SM.plan.mount = mount;
})();
