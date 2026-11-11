(() => {
  window.CB_READY = true;
  const C = window.CB_CONFIG || {};
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));
  const root = document.documentElement;
  const page = document.body.dataset.page;
  const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const fine = matchMedia("(hover: hover) and (pointer: fine)").matches;
  const desktop = () => innerWidth >= 1024;
  const G = window.gsap;
  const ST = window.ScrollTrigger;
  const motion = !!(G && ST) && !reduce;
  if (G && ST) G.registerPlugin(ST);
  if (G && window.Flip) G.registerPlugin(window.Flip);
  root.classList.add(motion ? "js-motion" : "no-motion");
  const EASE = "expo.out";
  const inr = n => Number(n).toLocaleString("en-IN");
  const waNumber = C.whatsapp || "916301521358";
  const waLink = msg => `https://wa.me/${waNumber}?text=${encodeURIComponent(msg)}`;
  const DEFAULT_WA = `Hi ${C.companyName || "Coastal Builders"}, I'd like a free site visit and estimate.`;
  const ICON = {
    arrow: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14m-6-6 6 6-6 6" fill="none" stroke="currentColor" stroke-width="2"/></svg>',
    star: '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="m12 2.8 2.8 5.8 6.3.9-4.6 4.4 1.1 6.3L12 17.2l-5.6 3 1.1-6.3L2.9 9.5l6.3-.9z"/></svg>'
  };
  const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

  let projectsPromise;
  const getProjects = () => projectsPromise || (projectsPromise = fetch("data/projects.json").then(r => { if (!r.ok) throw new Error("projects"); return r.json(); }));

  function bindConfig() {
    $$("[data-cfg]").forEach(el => {
      const v = C[el.dataset.cfg];
      if (v !== undefined && v !== "") el.textContent = typeof v === "number" && v >= 10000 ? inr(v) : v;
    });
    $$("[data-cfg-tel]").forEach(el => C.phone && (el.href = `tel:${C.phone}`));
    $$("[data-cfg-wa]").forEach(el => (el.href = waLink(el.dataset.waMsg || DEFAULT_WA)));
    $$("[data-cfg-mail]").forEach(el => C.email && (el.href = `mailto:${C.email}`));
    $$("[data-cfg-maps]").forEach(el => C.mapsLink && (el.href = C.mapsLink));
    $$("[data-cfg-social]").forEach(el => { const u = C.social && C.social[el.dataset.cfgSocial]; if (u) el.href = u; });
    $$("[data-cfg-count]").forEach(el => { const v = C[el.dataset.cfgCount]; if (v !== undefined) el.textContent = v; });
    $$("[data-year]").forEach(el => (el.textContent = new Date().getFullYear()));
    const frames = $$("[data-cfg-embed]");
    if (frames.length) {
      const io = new IntersectionObserver(es => es.forEach(e => {
        if (!e.isIntersecting) return;
        e.target.src = C.mapsEmbed || e.target.dataset.src;
        io.unobserve(e.target);
      }), { rootMargin: "400px" });
      frames.forEach(f => io.observe(f));
    }
  }

  let lenis;
  function smooth() {
    if (!motion || !window.Lenis) return;
    lenis = new Lenis({ lerp: 0.11, smoothWheel: true, wheelMultiplier: 0.95 });
    window.CB_LENIS = lenis;
    lenis.on("scroll", ST.update);
    G.ticker.add(t => lenis.raf(t * 1000));
    G.ticker.lagSmoothing(0);
    $$('a[href^="#"]').forEach(a => a.addEventListener("click", e => {
      const id = a.getAttribute("href");
      if (id.length < 2) return;
      const t = document.querySelector(id);
      if (!t) return;
      e.preventDefault();
      lenis.scrollTo(t, { offset: -20, duration: 1.4 });
    }));
  }

  function headerAndBars() {
    const head = $("[data-head]");
    const bar = $(".progress span");
    const mbar = $(".mbar");
    const wa = $(".wa-float");
    let last = scrollY, ticking = false, nudged = false;
    const update = () => {
      const y = scrollY;
      const max = document.documentElement.scrollHeight - innerHeight;
      head.classList.toggle("is-scrolled", y > 30);
      if (!head.classList.contains("is-open") && !$(".has-mega.is-open")) {
        if (y > last + 4 && y > 260) head.classList.add("is-hidden");
        else if (y < last - 4 || y < 260) head.classList.remove("is-hidden");
      }
      if (bar) bar.style.transform = `scaleX(${max > 0 ? Math.min(1, y / max) : 0})`;
      if (mbar) mbar.classList.toggle("is-on", y > 320);
      if (wa && !nudged && y > 900) {
        nudged = true;
        wa.classList.add("is-nudge");
        setTimeout(() => wa.classList.remove("is-nudge"), 3200);
      }
      last = y;
      ticking = false;
    };
    addEventListener("scroll", () => { if (!ticking) { ticking = true; requestAnimationFrame(update); } }, { passive: true });
    update();
  }

  function megaMenu() {
    const li = $(".has-mega");
    if (!li) return;
    const trigger = $(".nav__svc", li);
    const img = $("[data-mega-preview]", li);
    let t;
    const open = () => { clearTimeout(t); li.classList.add("is-open"); trigger.setAttribute("aria-expanded", "true"); };
    const close = () => { t = setTimeout(() => { li.classList.remove("is-open"); trigger.setAttribute("aria-expanded", "false"); }, 160); };
    li.addEventListener("mouseenter", open);
    li.addEventListener("mouseleave", close);
    li.addEventListener("focusin", open);
    li.addEventListener("focusout", e => { if (!li.contains(e.relatedTarget)) close(); });
    li.addEventListener("keydown", e => { if (e.key === "Escape") { li.classList.remove("is-open"); trigger.setAttribute("aria-expanded", "false"); trigger.focus(); } });
    $$("[data-mega-img]", li).forEach(a => {
      const pre = new Image();
      const swap = () => {
        const src = a.dataset.megaImg;
        if (img.getAttribute("src") === src) return;
        pre.src = src;
        img.classList.add("is-swapping");
        setTimeout(() => { img.src = src; img.classList.remove("is-swapping"); }, 180);
      };
      a.addEventListener("mouseenter", swap);
      a.addEventListener("focus", swap);
    });
  }

  function mobileMenu() {
    const btn = $(".burger");
    const nav = $("#mnav");
    const head = $("[data-head]");
    if (!btn || !nav) return;
    const set = open => {
      btn.setAttribute("aria-expanded", String(open));
      btn.setAttribute("aria-label", open ? "Close menu" : "Open menu");
      head.classList.toggle("is-open", open);
      document.body.style.overflow = open ? "hidden" : "";
      if (open) {
        nav.hidden = false;
        lenis && lenis.stop();
        if (motion) {
          G.fromTo(nav, { clipPath: "inset(0 0 100% 0)" }, { clipPath: "inset(0 0 0% 0)", duration: 0.7, ease: "expo.inOut" });
          G.fromTo($$(".mnav__list a, .mnav__foot > *", nav), { y: 40, opacity: 0 }, { y: 0, opacity: 1, duration: 0.8, stagger: 0.05, ease: EASE, delay: 0.25 });
        }
        setTimeout(() => $("a", nav).focus(), 50);
      } else {
        lenis && lenis.start();
        if (motion) G.to(nav, { clipPath: "inset(0 0 100% 0)", duration: 0.5, ease: "expo.inOut", onComplete: () => (nav.hidden = true) });
        else nav.hidden = true;
      }
    };
    btn.addEventListener("click", () => set(btn.getAttribute("aria-expanded") !== "true"));
    document.addEventListener("keydown", e => { if (e.key === "Escape" && !nav.hidden) { set(false); btn.focus(); } });
    $$("a", nav).forEach(a => a.addEventListener("click", () => set(false)));
  }

  function splitHeading(el, delay = 0, immediate = false) {
    if (!motion || !window.SplitType) { el.style.visibility = "visible"; return null; }
    const split = new SplitType(el, { types: "lines,words", lineClass: "split-line" });
    G.set(el, { visibility: "visible" });
    const tween = G.from(split.words, {
      yPercent: 115, rotate: 4, duration: 1.15, ease: EASE, stagger: 0.035, delay,
      paused: !immediate,
      onComplete: () => split.revert()
    });
    if (!immediate) ST.create({ trigger: el, start: "top 88%", once: true, onEnter: () => tween.play() });
    return tween;
  }

  function reveals(scope = document) {
    const els = $$("[data-reveal]", scope).filter(el => !el.dataset.revealed);
    els.forEach(el => (el.dataset.revealed = "1"));
    if (!motion) { els.forEach(el => { el.style.opacity = 1; el.style.transform = "none"; }); return; }
    ST.batch(els, {
      start: "top 90%",
      once: true,
      onEnter: b => G.to(b, { opacity: 1, y: 0, duration: 1, ease: EASE, stagger: 0.08, overwrite: true })
    });
  }

  function counters() {
    $$("[data-count]").forEach(el => {
      const target = parseFloat(el.textContent.replace(/[^\d.]/g, "")) || 0;
      if (!motion) { el.textContent = inr(target); return; }
      const o = { v: 0 };
      el.textContent = "0";
      ST.create({
        trigger: el, start: "top 90%", once: true,
        onEnter: () => G.to(o, { v: target, duration: 2, ease: "power4.out", onUpdate: () => (el.textContent = inr(Math.round(o.v))) })
      });
    });
  }

  function parallax() {
    if (!motion) return;
    $$("[data-parallax]").forEach(img => G.to(img, { yPercent: 10, ease: "none", scrollTrigger: { trigger: img.closest("section"), start: "top top", end: "bottom top", scrub: true } }));
    $$("[data-parallax-in]").forEach(img => G.fromTo(img, { yPercent: -8 }, { yPercent: 4, ease: "none", scrollTrigger: { trigger: img.parentElement, start: "top bottom", end: "bottom top", scrub: true } }));
  }

  function magnetic() {
    if (!fine || !motion) return;
    $$("[data-magnetic]").forEach(el => {
      const xTo = G.quickTo(el, "x", { duration: 0.6, ease: "power3" });
      const yTo = G.quickTo(el, "y", { duration: 0.6, ease: "power3" });
      el.addEventListener("mousemove", e => {
        const r = el.getBoundingClientRect();
        xTo((e.clientX - r.left - r.width / 2) * 0.28);
        yTo((e.clientY - r.top - r.height / 2) * 0.4);
      });
      el.addEventListener("mouseleave", () => { xTo(0); yTo(0); });
    });
  }

  function cursor() {
    const c = $(".cursor");
    if (!c || !fine || reduce) return;
    root.classList.add("has-cursor");
    const label = $(".cursor__label", c);
    let x = innerWidth / 2, y = innerHeight / 2, cx = x, cy = y;
    addEventListener("mousemove", e => { x = e.clientX; y = e.clientY; c.classList.remove("is-hidden"); }, { passive: true });
    document.addEventListener("mouseleave", () => c.classList.add("is-hidden"));
    const loop = () => {
      cx += (x - cx) * 0.2;
      cy += (y - cy) * 0.2;
      c.style.transform = `translate3d(${cx}px, ${cy}px, 0)`;
      requestAnimationFrame(loop);
    };
    loop();
    document.addEventListener("mouseover", e => {
      const lab = e.target.closest("[data-cursor]");
      const link = e.target.closest("a, button, summary, label, select, input");
      c.classList.toggle("is-label", !!lab);
      c.classList.toggle("is-link", !lab && !!link);
      if (lab) label.textContent = lab.dataset.cursor;
    });
  }

  function tilt() {
    if (!fine || reduce || !window.VanillaTilt) return;
    VanillaTilt.init($$("[data-tilt-card]"), { max: 6, speed: 900, perspective: 1400, scale: 1.015, glare: true, "max-glare": 0.18, reset: true });
  }

  function initCompare(el) {
    if (el.dataset.ready) return;
    el.dataset.ready = "1";
    const range = $(".compare__range", el);
    const set = v => { v = Math.max(0, Math.min(100, v)); el.style.setProperty("--pos", v + "%"); range.value = v; };
    let drag = false;
    const fromEvent = e => { const r = el.getBoundingClientRect(); set(((e.clientX - r.left) / r.width) * 100); };
    el.addEventListener("pointerdown", e => {
      if (e.pointerType === "mouse" && e.button !== 0) return;
      drag = true;
      el.classList.add("is-dragging");
      el.setPointerCapture(e.pointerId);
      fromEvent(e);
    });
    el.addEventListener("pointermove", e => { if (drag) fromEvent(e); });
    const end = () => { drag = false; el.classList.remove("is-dragging"); };
    el.addEventListener("pointerup", end);
    el.addEventListener("pointercancel", end);
    range.addEventListener("input", () => set(+range.value));
    el.addEventListener("keydown", e => {
      if (e.target !== range) return;
      if (e.key === "Home") { e.preventDefault(); set(0); }
      if (e.key === "End") { e.preventDefault(); set(100); }
    });
    set(50);
    if (motion) {
      ST.create({ trigger: el, start: "top 75%", once: true, onEnter: () => {
        const o = { v: 50 };
        G.timeline().to(o, { v: 22, duration: 0.9, ease: "power3.inOut", onUpdate: () => set(o.v) }).to(o, { v: 50, duration: 1.1, ease: "power3.inOut", onUpdate: () => set(o.v) });
      } });
    }
  }

  function compareMarkup(before, after, label) {
    return `<div class="compare" data-compare data-cursor="Drag">
<img class="compare__after" src="${esc(after)}" alt="After: ${esc(label)}" loading="lazy" width="1680" height="944">
<div class="compare__before"><img src="${esc(before)}" alt="Before: ${esc(label)}" loading="lazy" width="1680" height="944"></div>
<span class="compare__tag compare__tag--b mono">Before</span><span class="compare__tag compare__tag--a mono">After</span>
<span class="compare__line" aria-hidden="true"><span class="compare__knob"><svg viewBox="0 0 24 24"><path d="m9 6-6 6 6 6m6-12 6 6-6 6" fill="none" stroke="currentColor" stroke-width="2"/></svg></span></span>
<input class="compare__range" type="range" min="0" max="100" value="50" aria-label="Before and after comparison: ${esc(label)}. Use arrow keys to move.">
</div>`;
  }

  function tabs() {
    const list = $(".ba__tabs");
    if (!list) return;
    const tabsEls = $$('[role="tab"]', list);
    const select = (t, focus) => {
      tabsEls.forEach(x => {
        const on = x === t;
        x.setAttribute("aria-selected", String(on));
        x.tabIndex = on ? 0 : -1;
        const p = document.getElementById(x.getAttribute("aria-controls"));
        p.hidden = !on;
        if (on && motion) G.fromTo(p, { opacity: 0, y: 16 }, { opacity: 1, y: 0, duration: 0.7, ease: EASE });
      });
      if (focus) t.focus();
    };
    tabsEls.forEach((t, i) => {
      t.addEventListener("click", () => select(t));
      t.addEventListener("keydown", e => {
        const k = e.key;
        let n = null;
        if (k === "ArrowRight") n = tabsEls[(i + 1) % tabsEls.length];
        if (k === "ArrowLeft") n = tabsEls[(i - 1 + tabsEls.length) % tabsEls.length];
        if (k === "Home") n = tabsEls[0];
        if (k === "End") n = tabsEls[tabsEls.length - 1];
        if (n) { e.preventDefault(); select(n, true); }
      });
    });
  }

  function faq() {
    $$(".faq__item").forEach(d => {
      const a = $(".faq__a", d);
      $("summary", d).addEventListener("click", e => {
        if (!motion) return;
        e.preventDefault();
        if (d.open) {
          G.to(a, { height: 0, opacity: 0, duration: 0.45, ease: "power3.inOut", onComplete: () => { d.open = false; G.set(a, { clearProps: "all" }); ST.refresh(); } });
        } else {
          d.open = true;
          G.from(a, { height: 0, opacity: 0, duration: 0.6, ease: EASE, onComplete: () => ST.refresh() });
        }
      });
    });
  }

  function validate(form) {
    let ok = true;
    $$("[required]", form).forEach(f => {
      let good = f.value.trim() !== "";
      if (good && f.type === "tel") good = f.value.replace(/\D/g, "").replace(/^91(?=\d{10}$)/, "").length === 10;
      f.closest(".field")?.classList.toggle("is-invalid", !good);
      f.setAttribute("aria-invalid", String(!good));
      if (!good && ok) { ok = false; f.focus(); }
    });
    return ok;
  }

  function openWa(msg) {
    const url = waLink(msg);
    try { window.open(url, "_blank", "noopener"); } catch (e) {}
    return url;
  }

  function simpleForms() {
    $$("[data-mini-form], [data-contact-form]").forEach(form => {
      const msg = $(".form-msg", form);
      form.addEventListener("submit", e => {
        e.preventDefault();
        if (!validate(form)) { msg.textContent = "Please fill in the highlighted fields."; msg.classList.add("is-error"); return; }
        msg.classList.remove("is-error");
        const d = Object.fromEntries(new FormData(form));
        const text = form.hasAttribute("data-contact-form")
          ? `Hi ${C.companyName || "Coastal Builders"},\n\nName: ${d.name}\nPhone: ${d.phone}\n\n${d.message}`
          : `Hi ${C.companyName || "Coastal Builders"}, I'd like a free site visit and estimate.\n\nName: ${d.name}\nPhone: ${d.phone}\nProject: ${d.type}\nArea: ${d.area}`;
        const url = openWa(text);
        msg.innerHTML = `Details ready. <a href="${esc(url)}" target="_blank" rel="noopener">Send them on WhatsApp</a> if it did not open. Expect a call within 2 hours.`;
        form.reset();
      });
      $$("input, select, textarea", form).forEach(f => f.addEventListener("input", () => f.closest(".field")?.classList.remove("is-invalid")));
    });
  }

  function timelineLine() {
    const line = $("[data-tl-line]");
    if (!line) return;
    if (!motion) { line.style.transform = "scaleY(1)"; return; }
    G.to(line, { scaleY: 1, ease: "none", scrollTrigger: { trigger: ".tl", start: "top 70%", end: "bottom 60%", scrub: 0.6 } });
  }

  function heroVideo() {
    const v = $("[data-hero-video]");
    if (!v || reduce) return;
    const vids = C.videos || {};
    const src = innerWidth < 768 ? (vids.heroDroneMobile || vids.heroDrone) : vids.heroDrone;
    if (!src || (navigator.connection && navigator.connection.saveData)) return;
    v.src = src;
    v.addEventListener("playing", () => v.classList.add("is-ready"), { once: true });
    v.play().catch(() => {});
  }

  function preloaderAndHero() {
    const pre = $(".preloader");
    const title = $('[data-split="hero"]');
    const intro = () => {
      if (!title) return;
      if (!motion) { title.style.visibility = "visible"; return; }
      splitHeading(title, 0, true);
      G.from(".hero__eyebrow, .hero__sub, .hero__row .btn, .trust li, .scroll-hint", { y: 30, opacity: 0, duration: 1.1, ease: EASE, stagger: 0.07, delay: 0.35 });
      G.from(".hero__img", { scale: 1.3, duration: 2.2, ease: "expo.out" });
    };
    if (!pre) { intro(); return; }
    if (!motion) { pre.remove(); intro(); return; }
    const start = performance.now();
    let done = false;
    const finish = () => {
      if (done) return;
      done = true;
      const wait = Math.max(0, 1050 - (performance.now() - start));
      setTimeout(() => {
        G.to(pre, { yPercent: -100, duration: 0.9, ease: "expo.inOut", onComplete: () => { pre.remove(); root.classList.add("is-loaded"); } });
        setTimeout(intro, 250);
      }, wait);
    };
    if (document.readyState === "complete") finish();
    else addEventListener("load", finish, { once: true });
    setTimeout(finish, 1400);
  }

  function featuredCard(p) {
    return `<a class="fcard" href="project.html?id=${encodeURIComponent(p.id)}" data-cursor="View">
<div class="fcard__img"><img src="${esc(p.cover)}" alt="${esc(p.title)}, ${esc(p.categoryLabel)} project by Coastal Builders in ${esc(p.location)}, Visakhapatnam" loading="lazy" width="1680" height="944"><span class="fcard__tag mono">${esc(p.categoryLabel)}</span></div>
<div class="fcard__meta"><h3>${esc(p.title)}</h3><p class="fcard__out">${esc(p.location)}</p>
<p class="fcard__facts mono"><span>${inr(p.size)} sq ft</span><span>${esc(p.duration)}</span><span>${esc(p.budget)}</span><span>${p.year}</span></p></div>
</a>`;
  }

  function projectCard(p, h = "h3") {
    return `<a class="pcard" href="project.html?id=${encodeURIComponent(p.id)}" data-cat="${esc(p.category)}" data-cursor="View" data-reveal>
<div class="pcard__img"><img src="${esc(p.thumb || p.cover)}" alt="${esc(p.title)} in ${esc(p.location)}, Vizag" loading="lazy" width="900" height="600"><span class="pcard__cat mono">${esc(p.categoryLabel)}</span></div>
<div class="pcard__body"><${h}>${esc(p.title)}</${h}><p class="pcard__facts mono"><span>${esc(p.location)}</span><span>${inr(p.size)} sq ft</span><span>${esc(p.duration)}</span><span>${p.year}</span></p></div>
</a>`;
  }

  function featured() {
    const sec = $("[data-featured]");
    if (!sec) return;
    const track = $("[data-featured-track]", sec);
    getProjects().then(list => {
      const items = list.filter(p => p.featured).slice(0, 4);
      track.innerHTML = items.map(featuredCard).join("") + `<a class="fcard fcard--end" href="projects.html" data-cursor="View"><p>See all<span>${list.length} projects</span></p></a>`;
      if (motion && desktop()) {
        sec.classList.add("is-pinned");
        const dist = () => Math.max(0, track.scrollWidth - innerWidth + parseFloat(getComputedStyle(track).paddingLeft));
        G.to(track, {
          x: () => -dist(), ease: "none",
          scrollTrigger: { trigger: sec, start: "top top", end: () => "+=" + dist(), pin: true, scrub: 0.8, invalidateOnRefresh: true, anticipatePin: 1 }
        });
        G.from($$(".fcard", track), { opacity: 0, x: 120, duration: 1.2, ease: EASE, stagger: 0.1, scrollTrigger: { trigger: sec, start: "top 70%", once: true } });
        ST.sort();
        ST.refresh();
      }
    }).catch(() => { track.innerHTML = '<p class="loading mono">Projects could not load. Open the site through a web server (see README).</p>'; });
  }

  function build3d() {
    const sec = $("[data-build]");
    if (!sec) return;
    const steps = $$(".build__step", sec);
    const meter = $("[data-build-meter]", sec);
    const num = $("[data-build-num]", sec);
    const label = $("[data-build-label]", sec);
    const labels = ["BLUEPRINT", "RCC FRAME", "WALLS & ROOF", "HANDOVER"];
    const webgl = (() => { try { const c = document.createElement("canvas"); return !!(c.getContext("webgl2") || c.getContext("webgl")); } catch (e) { return false; } })();
    const vids = C.videos || {};
    if (!(motion && desktop() && webgl)) {
      if (vids.buildTransform) {
        const wrap = $("[data-build-video]", sec);
        const v = $("video", wrap);
        wrap.hidden = false;
        $(".build__cards", sec).hidden = true;
        const io = new IntersectionObserver(es => es.forEach(e => {
          if (e.isIntersecting) { if (!v.src) v.src = vids.buildTransform; if (!reduce) v.play().catch(() => {}); } else v.pause();
        }));
        io.observe(v);
      }
      return;
    }
    sec.classList.add("is-3d");
    let scene = null, loading = false, progress = 0, current = -1, visible = false;
    const setStage = p => {
      const i = Math.min(3, Math.floor(p * 4 + 0.0001));
      if (meter) meter.style.transform = `scaleX(${p})`;
      if (i === current) return;
      current = i;
      steps.forEach((s, k) => s.classList.toggle("is-active", k === i));
      if (num) num.textContent = "0" + (i + 1);
      if (label) label.textContent = labels[i];
    };
    setStage(0);
    ST.create({
      trigger: sec, start: "top top", end: "+=320%", pin: ".build__pin", scrub: true, anticipatePin: 1,
      onUpdate: self => { progress = self.progress; setStage(progress); scene && scene.setProgress(progress); }
    });
    const canvasHost = $("[data-build-canvas]", sec);
    const load = () => {
      if (scene || loading) return;
      loading = true;
      import(new URL("js/house3d.js", document.baseURI).href).then(mod => {
        loading = false;
        if (!visible) return;
        scene = mod.createHouse(canvasHost);
        scene.setProgress(progress);
        scene.start();
      }).catch(() => {
        loading = false;
        sec.classList.remove("is-3d");
      });
    };
    new IntersectionObserver(es => es.forEach(e => {
      visible = e.isIntersecting;
      if (visible) { if (scene) scene.start(); else load(); }
      else if (scene) { scene.dispose(); scene = null; }
    }), { rootMargin: "60% 0px" }).observe(sec);
  }

  function projectsPage() {
    const grid = $("[data-gallery]");
    if (!grid) return;
    const buttons = $$("[data-filter]");
    const status = $("[data-filter-status]");
    getProjects().then(list => {
      grid.innerHTML = list.map(p => projectCard(p, "h2")).join("");
      const cards = $$(".pcard", grid);
      buttons.forEach(b => {
        const k = b.dataset.filter;
        const n = k === "all" ? list.length : list.filter(p => p.category === k).length;
        const c = $("[data-filter-count]", b);
        if (c) c.textContent = n;
      });
      const apply = (k, animate) => {
        buttons.forEach(b => b.setAttribute("aria-pressed", String(b.dataset.filter === k)));
        const state = animate && motion && window.Flip ? Flip.getState(cards) : null;
        let shown = 0;
        cards.forEach(c => { const on = k === "all" || c.dataset.cat === k; c.classList.toggle("is-out", !on); if (on) shown++; c.style.opacity = 1; c.style.transform = "none"; });
        if (state) {
          Flip.from(state, {
            duration: 0.8, ease: "power3.inOut", scale: true, absolute: true, nested: true,
            onEnter: els => G.fromTo(els, { opacity: 0, scale: 0.92 }, { opacity: 1, scale: 1, duration: 0.6, ease: EASE }),
            onLeave: els => G.to(els, { opacity: 0, scale: 0.92, duration: 0.4 }),
            onComplete: () => ST.refresh()
          });
        }
        if (status) status.textContent = `Showing ${shown} ${shown === 1 ? "project" : "projects"}`;
        if (animate) history.replaceState(null, "", k === "all" ? location.pathname : "#" + k);
      };
      buttons.forEach(b => b.addEventListener("click", () => apply(b.dataset.filter, true)));
      const initial = location.hash.slice(1);
      apply(buttons.some(b => b.dataset.filter === initial) ? initial : "all", false);
      reveals(grid);
    }).catch(() => { grid.innerHTML = '<p class="loading mono">Projects could not load. Open the site through a web server (see README).</p>'; });
  }

  function relatedProjects() {
    const host = $("[data-related]");
    if (!host) return;
    const cat = host.dataset.related;
    getProjects().then(list => {
      const same = list.filter(p => p.category === cat);
      const rest = list.filter(p => p.category !== cat);
      host.innerHTML = same.concat(rest).slice(0, 3).map(p => projectCard(p)).join("");
      reveals(host);
    }).catch(() => (host.innerHTML = '<p class="related__empty">See all our work on the <a href="projects.html">projects page</a>.</p>'));
  }

  function projectDetail() {
    const art = $("[data-project]");
    if (!art) return;
    const id = new URLSearchParams(location.search).get("id");
    getProjects().then(list => {
      const idx = Math.max(0, list.findIndex(p => p.id === id));
      if (id && list.findIndex(p => p.id === id) < 0) { location.replace("projects.html"); return; }
      const p = list[idx];
      const data = Object.assign({}, p, p.story, { sizeLabel: `${inr(p.size)} sq ft`, baLabel: p.beforeAfter ? p.beforeAfter.label : "" });
      $$("[data-p]", art).forEach(el => {
        const k = el.dataset.p;
        if (k === "cover") { el.src = p.cover; el.alt = `${p.title} by Coastal Builders in ${p.location}, Visakhapatnam`; return; }
        if (data[k] !== undefined) el.textContent = data[k];
      });
      document.title = `${p.title}, ${p.location} | ${p.categoryLabel} in Vizag | Coastal Builders`;
      const desc = `${p.summary} ${inr(p.size)} sq ft in ${p.location}, Visakhapatnam, completed in ${p.duration}.`;
      $('meta[name="description"]').setAttribute("content", desc);
      const ld = document.createElement("script");
      ld.type = "application/ld+json";
      ld.textContent = JSON.stringify({ "@context": "https://schema.org", "@type": "CreativeWork", name: p.title, about: p.categoryLabel, description: desc, image: p.cover, dateCreated: String(p.year), locationCreated: { "@type": "Place", name: `${p.location}, Visakhapatnam` }, creator: { "@type": "GeneralContractor", name: C.companyName || "Coastal Builders" } });
      document.head.appendChild(ld);
      if (p.review) {
        $("[data-p-review]", art).innerHTML = `<figure class="review review--compact"><div class="review__top"><span class="stars" aria-label="5 out of 5 stars">${ICON.star.repeat(5)}</span><span class="tag">Sample review</span></div><blockquote><p>&ldquo;${esc(p.review.text)}&rdquo;</p></blockquote><figcaption><span class="avatar mono" aria-hidden="true">${esc(p.review.who.replace(/\./g, ""))}</span><span><b>${esc(p.review.who)}</b><small>${esc(p.review.job)}</small></span></figcaption></figure>`;
      }
      if (p.beforeAfter) {
        const sec = $("[data-p-ba]", art);
        sec.hidden = false;
        $("[data-p-compare]", sec).innerHTML = compareMarkup(p.beforeAfter.before, p.beforeAfter.after, p.beforeAfter.label);
        initCompare($("[data-compare]", sec));
      }
      const gal = $("[data-p-gallery]", art);
      gal.innerHTML = p.gallery.map((g, i) => `<button type="button" data-cursor="View" data-index="${i}" aria-label="Open image ${i + 1} of ${p.gallery.length}"><img src="${esc(g)}" alt="${esc(p.title)}, photo ${i + 1}" loading="lazy" width="1680" height="944"></button>`).join("");
      lightbox(p.gallery, p.title);
      const next = list[(idx + 1) % list.length];
      const nl = $("[data-p-next]", art);
      nl.href = `project.html?id=${encodeURIComponent(next.id)}`;
      $("[data-p-next-title]", art).textContent = next.title;
      if (motion) {
        G.from(".phero h1, .phero .lead, .phero .eyebrow", { y: 40, opacity: 0, duration: 1.1, ease: EASE, stagger: 0.08 });
        G.from(".facts__bar > div", { y: 20, opacity: 0, duration: 0.9, ease: EASE, stagger: 0.06, delay: 0.3 });
      }
      ST && ST.refresh();
    }).catch(() => { $("h1", art).textContent = "Project could not load"; });
  }

  function lightbox(images, title) {
    const box = $("[data-lightbox]");
    if (!box) return;
    const img = $("[data-lightbox-img]", box);
    const count = $("[data-lightbox-count]", box);
    let i = 0, lastFocus;
    const show = n => {
      i = (n + images.length) % images.length;
      img.src = images[i];
      img.alt = `${title}, photo ${i + 1}`;
      count.textContent = `${i + 1} / ${images.length}`;
    };
    const open = n => {
      lastFocus = document.activeElement;
      show(n);
      box.hidden = false;
      lenis && lenis.stop();
      document.body.style.overflow = "hidden";
      motion && G.fromTo(img, { opacity: 0, scale: 0.96 }, { opacity: 1, scale: 1, duration: 0.6, ease: EASE });
      $(".lightbox__close", box).focus();
    };
    const close = () => { box.hidden = true; lenis && lenis.start(); document.body.style.overflow = ""; lastFocus && lastFocus.focus(); };
    $$("[data-p-gallery] button").forEach(b => b.addEventListener("click", () => open(+b.dataset.index)));
    $(".lightbox__close", box).addEventListener("click", close);
    $(".lightbox__prev", box).addEventListener("click", () => show(i - 1));
    $(".lightbox__next", box).addEventListener("click", () => show(i + 1));
    box.addEventListener("click", e => { if (e.target === box) close(); });
    document.addEventListener("keydown", e => {
      if (box.hidden) return;
      if (e.key === "Escape") close();
      if (e.key === "ArrowRight") show(i + 1);
      if (e.key === "ArrowLeft") show(i - 1);
      if (e.key === "Tab") {
        const f = $$("button", box);
        if (e.shiftKey && document.activeElement === f[0]) { e.preventDefault(); f[f.length - 1].focus(); }
        else if (!e.shiftKey && document.activeElement === f[f.length - 1]) { e.preventDefault(); f[0].focus(); }
      }
    });
  }

  function wizard() {
    const form = $("[data-wizard]");
    if (!form) return;
    const steps = $$(".wizard__step", form);
    const bar = $("[data-wizard-bar]", form);
    const num = $("[data-wizard-num]", form);
    const back = $("[data-wizard-back]", form);
    const next = $("[data-wizard-next]", form);
    const submit = $("[data-wizard-submit]", form);
    const msg = $("[data-wizard-msg]", form);
    const success = $("[data-success]");
    const range = $("#q-size", form);
    const out = $("[data-size-out]", form);
    const exact = $("[data-size-num]", form);
    let unit = "sq ft", cur = 0;
    const units = { "sq ft": { min: 200, max: 20000, step: 50 }, "sq yards": { min: 25, max: 2500, step: 5 } };
    const paint = () => {
      const pct = ((range.value - range.min) / (range.max - range.min)) * 100;
      range.style.setProperty("--fill", pct + "%");
      out.textContent = `${inr(range.value)} ${unit}`;
      exact.value = range.value;
    };
    range.addEventListener("input", paint);
    exact.addEventListener("input", () => {
      const v = Math.max(+range.min, Math.min(+range.max, +exact.value || 0));
      range.value = v;
      const pct = ((v - range.min) / (range.max - range.min)) * 100;
      range.style.setProperty("--fill", pct + "%");
      out.textContent = `${inr(exact.value || 0)} ${unit}`;
    });
    $$("[data-unit]", form).forEach(b => b.addEventListener("click", () => {
      if (b.dataset.unit === unit) return;
      const v = +exact.value || +range.value;
      unit = b.dataset.unit;
      $$("[data-unit]", form).forEach(x => x.setAttribute("aria-pressed", String(x === b)));
      const u = units[unit];
      Object.assign(range, { min: u.min, max: u.max, step: u.step });
      $("[data-size-min]", form).textContent = inr(u.min);
      $("[data-size-max]", form).textContent = inr(u.max);
      range.value = Math.round(unit === "sq yards" ? v / 9 : v * 9);
      paint();
    }));
    paint();
    const date = $("#q-date", form);
    const tomorrow = new Date(Date.now() + 864e5);
    date.min = tomorrow.toISOString().slice(0, 10);
    const params = new URLSearchParams(location.search);
    const typeMap = { "New Homes": "New house", "New house": "New house", Renovation: "Renovation", Interiors: "Interiors", Commercial: "Commercial", Waterproofing: "Waterproofing" };
    const pt = params.get("type");
    if (pt && typeMap[pt]) { const r = $(`input[name="type"][value="${typeMap[pt]}"]`, form); if (r) r.checked = true; }
    const pa = params.get("area");
    if (pa) { const r = $$('input[name="area"]', form).find(x => x.value === pa); if (r) r.checked = true; }
    const stepValid = i => {
      const s = steps[i];
      const radios = $$('input[type="radio"]', s);
      if (radios.length) return radios.some(r => r.checked) || (msg.textContent = "Please choose an option to continue.", false);
      if (i === 1) return +exact.value > 0 || (msg.textContent = "Please enter a size.", false);
      if (i === 5) {
        const ok = validate(s);
        if (!ok) msg.textContent = "Please enter your name, a 10-digit mobile number and a date.";
        return ok;
      }
      return true;
    };
    const go = i => {
      msg.textContent = "";
      const prev = steps[cur];
      cur = i;
      steps.forEach((s, k) => { s.hidden = k !== i; s.classList.toggle("is-active", k === i); });
      bar.style.transform = `scaleX(${(i + 1) / steps.length})`;
      num.textContent = i + 1;
      back.disabled = i === 0;
      next.hidden = i === steps.length - 1;
      submit.hidden = i !== steps.length - 1;
      if (motion && prev !== steps[i]) G.fromTo(steps[i], { opacity: 0, x: 40 }, { opacity: 1, x: 0, duration: 0.6, ease: EASE });
      const first = $("input:checked", steps[i]) || $("input, button", steps[i]);
      first && first.focus({ preventScroll: true });
    };
    next.addEventListener("click", () => { if (stepValid(cur)) go(cur + 1); });
    back.addEventListener("click", () => cur > 0 && go(cur - 1));
    $$('input[type="radio"]', form).forEach(r => r.addEventListener("change", () => {
      msg.textContent = "";
      if (r.closest(".wizard__step") === steps[cur] && cur < steps.length - 1) setTimeout(() => go(cur + 1), 320);
    }));
    form.addEventListener("keydown", e => {
      if (e.key === "Enter" && e.target.tagName === "INPUT" && cur < steps.length - 1) { e.preventDefault(); if (stepValid(cur)) go(cur + 1); }
    });
    $$("input", form).forEach(f => f.addEventListener("input", () => f.closest(".field")?.classList.remove("is-invalid")));
    form.addEventListener("submit", e => {
      e.preventDefault();
      for (let i = 0; i < steps.length; i++) if (!stepValid(i)) { go(i); stepValid(i); return; }
      const d = new FormData(form);
      const when = new Date(d.get("date") + "T00:00:00").toLocaleDateString("en-IN", { weekday: "short", day: "numeric", month: "short", year: "numeric" });
      const text = [
        `Hi ${C.companyName || "Coastal Builders"}, I'd like a free site visit and estimate.`,
        "",
        `*Project:* ${d.get("type")}`,
        `*Size:* ${inr(exact.value)} ${unit}`,
        `*Area:* ${d.get("area")}, Visakhapatnam`,
        `*Budget:* ${d.get("budget")}`,
        `*Start:* ${d.get("when")}`,
        "",
        `*Name:* ${d.get("name")}`,
        `*Phone:* ${d.get("phone")}`,
        `*Preferred site visit:* ${when}`
      ].join("\n");
      const url = openWa(text);
      $("[data-success-wa]").href = url;
      form.hidden = true;
      const sub = $(".quote__main > .muted");
      if (sub) sub.hidden = true;
      $(".quote__title").textContent = "Thank you, " + String(d.get("name")).split(" ")[0] + ".";
      success.hidden = false;
      success.focus();
      scrollTo({ top: 0, behavior: reduce ? "auto" : "smooth" });
    });
    go(0);
  }

  function optionalVideos() {
    const v = C.videos || {};
    $$("[data-optional-video]").forEach(box => {
      const src = box.dataset.optionalVideo.includes("site-walk") ? v.siteWalk : "";
      if (!src) return;
      const img = $("img", box);
      const vid = document.createElement("video");
      Object.assign(vid, { muted: true, loop: true, playsInline: true, preload: "none", poster: img.src });
      vid.setAttribute("aria-label", img.alt);
      box.replaceChild(vid, img);
      new IntersectionObserver(es => es.forEach(e => {
        if (e.isIntersecting) { if (!vid.src) vid.src = src; if (!reduce) vid.play().catch(() => {}); } else vid.pause();
      })).observe(vid);
    });
  }

  function pageIntro() {
    if (page === "home") return;
    $$("[data-split]").forEach(el => {
      const inHero = el.closest(".phero, .quote, .contact");
      if (!motion) { el.style.visibility = "visible"; return; }
      splitHeading(el, inHero ? 0.15 : 0, !!inHero);
    });
    if (motion) G.from(".phero .lead, .phero .eyebrow, .phero .crumbs, .phero .btn-row, .phero__price", { y: 24, opacity: 0, duration: 1.1, ease: EASE, stagger: 0.06, delay: 0.2 });
  }

  function homeSplits() {
    if (page !== "home") return;
    $$("[data-split]:not([data-split='hero'])").forEach(el => splitHeading(el));
  }

  bindConfig();
  smooth();
  headerAndBars();
  megaMenu();
  mobileMenu();
  preloaderAndHero();
  heroVideo();
  pageIntro();
  homeSplits();
  build3d();
  featured();
  reveals();
  counters();
  parallax();
  timelineLine();
  tabs();
  $$("[data-compare]").forEach(initCompare);
  faq();
  simpleForms();
  projectsPage();
  relatedProjects();
  projectDetail();
  wizard();
  optionalVideos();
  tilt();
  magnetic();
  cursor();
  if (!motion) $$("[data-split]").forEach(el => (el.style.visibility = "visible"));
  addEventListener("load", () => ST && ST.refresh());
})();
