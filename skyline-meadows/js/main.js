(function () {
  "use strict";

  const C = window.SM_CONFIG;
  const SM = (window.SM = window.SM || {});
  const root = document.documentElement;
  const gsap = window.gsap;
  const ST = window.ScrollTrigger;
  const hasGsap = !!(gsap && ST);
  const reduce = !!SM.reduceMotion;
  const motion = hasGsap && !reduce;
  const fine = window.matchMedia("(hover: hover) and (pointer: fine)").matches;
  const EASE = "expo.out";
  const NS = "http://www.w3.org/2000/svg";

  if (hasGsap) {
    gsap.registerPlugin(ST);
    if (window.SplitText) gsap.registerPlugin(window.SplitText);
  }
  root.classList.toggle("has-motion", motion);

  const inr = new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 });
  const lakhWords = (rupees) => {
    const l = rupees / 100000;
    return "₹" + (Number.isInteger(l) ? l : l.toFixed(1)) + " lakh";
  };
  const joinList = (items) => (items.length < 2 ? items.join("") : items.slice(0, -1).join(", ") + " and " + items[items.length - 1]);
  const coords = `${C.coordinates.lat.toFixed(2)}° N · ${C.coordinates.lng.toFixed(2)}° E`;
  const waHref = (text) => `https://wa.me/${C.whatsappNumber}?text=${encodeURIComponent(text)}`;
  const svgEl = (name, attrs, parent) => {
    const n = document.createElementNS(NS, name);
    if (attrs) for (const k in attrs) n.setAttribute(k, attrs[k]);
    if (parent) parent.appendChild(n);
    return n;
  };

  function bindConfig() {
    const stats = SM.plan ? SM.plan.stats : null;
    const sizes = C.plotSizes.slice().sort((a, b) => a - b);
    const secretariat = C.locations.find((l) => /secretariat/i.test(l.name));
    const map = {
      brand: C.brand,
      developer: C.developer,
      priceFrom: lakhWords(sizes[0] * C.pricePerSqYd),
      sizeRange: `${sizes[0]}–${sizes[sizes.length - 1]}`,
      rate: inr.format(C.pricePerSqYd),
      acres: C.acres,
      totalPlots: C.totalPlots,
      mainAvenueFt: C.mainAvenueFt,
      amenitiesCount: C.amenitiesCount,
      rera: C.reraNumber,
      address: C.address,
      callDisplay: C.callDisplay,
      email: C.email,
      pickupFrom: C.pickupFrom,
      booking: lakhWords(C.bookingAmount),
      slots: joinList(C.visitSlots),
      coords,
      secretariatMin: secretariat ? secretariat.minutes : "",
      bookedPct: stats ? stats.bookedPct : "",
      available: stats ? stats.available : "",
      phase1Plots: stats ? stats.total : ""
    };
    document.querySelectorAll("[data-bind]").forEach((el) => {
      const v = map[el.getAttribute("data-bind")];
      if (v !== undefined && v !== "") el.textContent = String(v);
    });
    const hello = `Hi ${C.brand} team, I'd like to know more about the plots.`;
    document.querySelectorAll("[data-wa]").forEach((a) => {
      a.href = waHref(hello);
    });
    document.querySelectorAll("[data-call]").forEach((a) => {
      a.href = `tel:${C.callNumber}`;
    });
    document.querySelectorAll("[data-email]").forEach((a) => {
      a.href = `mailto:${C.email}`;
    });
    document.querySelectorAll("[data-agency]").forEach((a) => {
      a.href = C.agency.url;
      a.textContent = C.agency.name;
    });
  }

  function buildJsonLd() {
    const faq = Array.from(document.querySelectorAll(".faq__item")).map((d) => ({
      "@type": "Question",
      name: d.querySelector("summary span").textContent.trim(),
      acceptedAnswer: { "@type": "Answer", text: d.querySelector(".faq__body").textContent.trim() }
    }));
    const data = [
      {
        "@context": "https://schema.org",
        "@type": "RealEstateAgent",
        name: `${C.brand} by ${C.developer}`,
        url: C.siteUrl,
        image: new URL("assets/img/hero-aerial.jpg", C.siteUrl).href,
        telephone: C.callNumber,
        email: C.email,
        priceRange: `${lakhWords(Math.min(...C.plotSizes) * C.pricePerSqYd)} – ${lakhWords(Math.max(...C.plotSizes) * C.pricePerSqYd)}`,
        address: { "@type": "PostalAddress", streetAddress: C.address, addressRegion: "Andhra Pradesh", addressCountry: "IN" },
        geo: { "@type": "GeoCoordinates", latitude: C.coordinates.lat, longitude: C.coordinates.lng },
        areaServed: "Amaravati capital region"
      },
      { "@context": "https://schema.org", "@type": "FAQPage", mainEntity: faq }
    ];
    const s = document.createElement("script");
    s.type = "application/ld+json";
    s.textContent = JSON.stringify(data);
    document.head.appendChild(s);
  }

  function renderLocation() {
    const list = document.querySelector("[data-drive-list]");
    if (list) {
      list.textContent = "";
      C.locations.forEach((loc) => {
        const li = document.createElement("li");
        [["drive-list__name", loc.name], ["drive-list__detail", loc.detail], ["drive-list__min", `${loc.minutes} min`]].forEach(([cls, txt]) => {
          const s = document.createElement("span");
          s.className = cls;
          s.textContent = txt;
          li.appendChild(s);
        });
        list.appendChild(li);
      });
    }

    const canvas = document.querySelector("[data-map-canvas]");
    if (!canvas) return;
    const SIZE = 640;
    const CX = 320;
    const CY = 330;
    const K = 5.6;
    const svg = svgEl("svg", { viewBox: `0 0 ${SIZE} ${SIZE}`, class: "map__svg", "aria-hidden": "true" });
    const grid = svgEl("g", { class: "map-grid" }, svg);
    for (let i = 40; i < SIZE; i += 40) {
      svgEl("line", { x1: i, y1: 0, x2: i, y2: SIZE }, grid);
      svgEl("line", { x1: 0, y1: i, x2: SIZE, y2: i }, grid);
    }
    svgEl("line", { x1: CX, y1: 10, x2: CX, y2: SIZE - 10, class: "map-axis" }, svg);
    svgEl("line", { x1: 10, y1: CY, x2: SIZE - 10, y2: CY, class: "map-axis" }, svg);
    const river = svgEl("g", { class: "map-river" }, svg);
    const riverD = "M -10 150 C 100 160, 200 205, 310 200 S 430 262, 462 342 S 530 414, 650 432";
    svgEl("path", { d: riverD, class: "map-river__band" }, river);
    svgEl("path", { d: riverD, id: "map-river-line", class: "map-river__line" }, river);
    const rText = svgEl("text", { class: "map-river__label", dy: "-12" }, river);
    const tp = svgEl("textPath", { href: "#map-river-line", startOffset: "6%" }, rText);
    tp.textContent = "KRISHNA RIVER";

    const rings = svgEl("g", { class: "map-rings" }, svg);
    [15, 30, 45].forEach((m) => {
      svgEl("circle", { cx: CX, cy: CY, r: m * K, class: "map-ring" }, rings);
      const t = svgEl("text", { x: CX + 6, y: CY - m * K - 6, class: "map-ring__label" }, rings);
      t.textContent = `${m} MIN`;
    });

    const spokes = svgEl("g", { class: "map-spokes" }, svg);
    const pins = svgEl("g", { class: "map-pins" }, svg);
    const labels = [];
    const pinEls = [];
    C.locations.forEach((loc) => {
      const r = loc.minutes * K;
      const rad = (loc.bearing * Math.PI) / 180;
      const x = CX + r * Math.sin(rad);
      const y = CY - r * Math.cos(rad);
      svgEl("line", { x1: CX, y1: CY, x2: x, y2: y, class: "map-spoke" }, spokes);
      const g = svgEl("g", { class: "map-pin", transform: `translate(${x.toFixed(1)} ${y.toFixed(1)})` }, pins);
      const inner = svgEl("g", null, g);
      svgEl("circle", { r: 11, class: "map-pin__halo" }, inner);
      svgEl("circle", { r: 4.5, class: "map-pin__dot" }, inner);
      pinEls.push(inner);
      const side = x + 150 > SIZE ? "top" : x >= CX - 10 ? "right" : "left";
      const label = document.createElement("div");
      label.className = `map__label map__label--${side}`;
      label.style.left = `${(x / SIZE) * 100}%`;
      label.style.top = `${(y / SIZE) * 100}%`;
      const name = document.createElement("span");
      name.className = "map__name";
      name.textContent = loc.name;
      const min = document.createElement("span");
      min.className = "map__min";
      min.textContent = `${loc.minutes} min`;
      label.append(name, min);
      labels.push(label);
    });

    const site = svgEl("g", { class: "map-site", transform: `translate(${CX} ${CY})` }, svg);
    const siteInner = svgEl("g", null, site);
    svgEl("circle", { r: 22, class: "map-site__pulse" }, siteInner);
    svgEl("path", { d: "M-9 12 L-9 -3 L0 -13 L9 -3 L9 12 Z", class: "map-site__stone" }, siteInner);
    const north = svgEl("g", { class: "map-north", transform: "translate(596 44)" }, svg);
    svgEl("circle", { r: 16, class: "map-north__ring" }, north);
    svgEl("path", { d: "M0 -11 L5 6 L0 2 L-5 6 Z", class: "map-north__needle" }, north);
    const nT = svgEl("text", { y: -22, "text-anchor": "middle", class: "map-ring__label" }, north);
    nT.textContent = "N";

    canvas.appendChild(svg);
    const siteLabel = document.createElement("div");
    siteLabel.className = "map__label map__label--site";
    siteLabel.style.left = `${(CX / SIZE) * 100}%`;
    siteLabel.style.top = `${(CY / SIZE) * 100}%`;
    const sn = document.createElement("span");
    sn.className = "map__name";
    sn.textContent = C.brand;
    const sc = document.createElement("span");
    sc.className = "map__min";
    sc.textContent = "You are here";
    siteLabel.append(sn, sc);
    canvas.appendChild(siteLabel);
    labels.forEach((l) => canvas.appendChild(l));

    if (!motion) return;
    const tl = gsap.timeline({ scrollTrigger: { trigger: canvas, start: "top 75%", once: true }, defaults: { ease: EASE } });
    tl.from(rings.querySelectorAll(".map-ring"), { scale: 0, svgOrigin: `${CX} ${CY}`, duration: 1.4, stagger: 0.12 })
      .from(rings.querySelectorAll(".map-ring__label"), { opacity: 0, duration: 0.6, stagger: 0.1 }, 0.5)
      .from(river, { opacity: 0, duration: 1.2 }, 0.1)
      .from(siteInner, { scale: 0, transformOrigin: "50% 50%", duration: 0.8, ease: "back.out(2)" }, 0.2)
      .from(siteLabel, { opacity: 0, y: 10, duration: 0.6 }, 0.4)
      .from(spokes.children, { opacity: 0, duration: 0.6, stagger: 0.08 }, 0.6)
      .from(pinEls, { scale: 0, transformOrigin: "50% 50%", duration: 0.7, stagger: 0.09, ease: "back.out(2.2)" }, 0.7)
      .from(labels, { opacity: 0, y: 12, duration: 0.6, stagger: 0.09 }, 0.8);
  }

  function renderPricing() {
    const wrap = document.querySelector("[data-price-cards]");
    if (!wrap) return;
    const plots = SM.plan ? SM.plan.plots : [];
    const taken = (size) => plots.filter((p) => p.size === size && p.status !== "available").length;
    const popular = C.plotSizes.reduce((best, s) => (taken(s) > taken(best) ? s : best), C.plotSizes[0]);
    wrap.textContent = "";
    C.plotSizes.forEach((size) => {
      const ofSize = plots.filter((p) => p.size === size);
      const open = ofSize.filter((p) => p.status === "available").length;
      const frontage = Math.round(((size * 9) / 60) * 2) / 2;
      const card = document.createElement("article");
      card.className = "price-card" + (size === popular ? " price-card--popular" : "");
      card.innerHTML = `
        ${size === popular ? '<p class="price-card__tag">Most chosen</p>' : ""}
        <p class="price-card__size"><span class="price-card__num">${size}</span> sq. yd</p>
        <p class="price-card__dims">${frontage} × 60 ft</p>
        <p class="price-card__price">${SM.lakh(size * C.pricePerSqYd)}</p>
        <p class="price-card__avail">${ofSize.length ? (open ? `${open} of ${ofSize.length} open in Phase 1` : "Phase 1 sold out") : "Ask for availability"}</p>
        <button class="btn btn--line btn--block" type="button" data-size="${size}"><span>Check eligibility</span></button>`;
      wrap.appendChild(card);
    });
    wrap.addEventListener("click", (e) => {
      const b = e.target.closest("[data-size]");
      if (b) document.dispatchEvent(new CustomEvent("sm:size", { detail: Number(b.getAttribute("data-size")) }));
    });
  }

  function setupEmi() {
    const box = document.querySelector("[data-emi]");
    if (!box) return;
    const E = C.emi;
    const sizeSel = box.querySelector("[data-emi-size]");
    const down = box.querySelector("[data-emi-down]");
    const rate = box.querySelector("[data-emi-rate]");
    const tenure = box.querySelector("[data-emi-tenure]");
    const out = (k) => box.querySelector(`[data-emi-out="${k}"]`);
    const row = (k) => box.querySelector(`[data-emi-row="${k}"]`);
    const value = box.querySelector("[data-emi-value]");
    C.plotSizes.forEach((s) => sizeSel.add(new Option(`${s} sq. yd · ${SM.lakh(s * C.pricePerSqYd)}`, String(s))));
    sizeSel.value = String(C.plotSizes.includes(200) ? 200 : C.plotSizes[0]);
    Object.assign(down, { min: E.downMin, max: E.downMax, value: E.downDefault });
    Object.assign(rate, { min: E.rateMin, max: E.rateMax, value: E.rateDefault });
    Object.assign(tenure, { min: E.tenureMin, max: E.tenureMax, value: E.tenureDefault });

    const fill = (input) => {
      const p = ((Number(input.value) - Number(input.min)) / (Number(input.max) - Number(input.min))) * 100;
      input.style.setProperty("--fill", `${p}%`);
    };

    function calc() {
      const price = Number(sizeSel.value) * C.pricePerSqYd;
      const downAmt = Math.round((price * Number(down.value)) / 100);
      const loan = price - downAmt;
      const r = Number(rate.value) / 1200;
      const n = Number(tenure.value) * 12;
      const emi = loan > 0 ? (loan * r * Math.pow(1 + r, n)) / (Math.pow(1 + r, n) - 1) : 0;
      const interest = Math.max(0, emi * n - loan);
      out("down").textContent = `${down.value}%`;
      out("rate").textContent = `${Number(rate.value).toFixed(1)}%`;
      out("tenure").textContent = `${tenure.value} years`;
      down.setAttribute("aria-valuetext", `${down.value}% down payment`);
      rate.setAttribute("aria-valuetext", `${Number(rate.value).toFixed(1)}% interest`);
      tenure.setAttribute("aria-valuetext", `${tenure.value} years`);
      row("price").textContent = inr.format(price);
      row("down").textContent = inr.format(downAmt);
      row("loan").textContent = inr.format(loan);
      row("interest").textContent = inr.format(Math.round(interest));
      value.textContent = loan > 0 ? `${inr.format(Math.round(emi))}/mo` : "No loan needed";
      [down, rate, tenure].forEach(fill);
    }
    [sizeSel, down, rate, tenure].forEach((i) => i.addEventListener("input", calc));
    sizeSel.addEventListener("change", calc);
    calc();
  }

  function setupLenis() {
    if (reduce || !window.Lenis) return;
    const lenis = new window.Lenis({
      duration: 1.1,
      easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
      smoothWheel: true,
      anchors: false
    });
    SM.lenis = lenis;
    if (hasGsap) {
      lenis.on("scroll", ST.update);
      gsap.ticker.add((time) => lenis.raf(time * 1000));
      gsap.ticker.lagSmoothing(0);
    } else {
      const raf = (t) => {
        lenis.raf(t);
        requestAnimationFrame(raf);
      };
      requestAnimationFrame(raf);
    }
  }

  SM.scrollTo = function (target, done) {
    const finish = () => done && done();
    if (SM.lenis) {
      SM.lenis.scrollTo(target, { offset: 0, duration: 1.2, onComplete: finish });
      return;
    }
    const top = target.getBoundingClientRect().top + window.scrollY;
    window.scrollTo({ top, behavior: reduce ? "auto" : "smooth" });
    setTimeout(finish, reduce ? 0 : 700);
  };

  function setupAnchors() {
    document.addEventListener("click", (e) => {
      const a = e.target.closest && e.target.closest('a[href^="#"]');
      if (!a) return;
      const id = a.getAttribute("href").slice(1);
      const target = id ? document.getElementById(id) : null;
      if (!target) return;
      e.preventDefault();
      SM.scrollTo(target, () => {
        if (id === "eligibility") document.dispatchEvent(new CustomEvent("sm:focus-form"));
        else if (target.hasAttribute("tabindex")) target.focus({ preventScroll: true });
      });
    });
  }

  function setupHeader() {
    const header = document.querySelector("[data-header]");
    if (!header) return;
    let last = window.scrollY;
    let ticking = false;
    const update = () => {
      const y = window.scrollY;
      header.classList.toggle("is-scrolled", y > 24);
      if (!root.classList.contains("menu-open") && y > 200 && y > last + 4) header.classList.add("is-hidden");
      else if (y < last - 4 || y <= 200) header.classList.remove("is-hidden");
      last = y;
      ticking = false;
    };
    window.addEventListener(
      "scroll",
      () => {
        if (!ticking) {
          ticking = true;
          requestAnimationFrame(update);
        }
      },
      { passive: true }
    );
    header.addEventListener("focusin", () => header.classList.remove("is-hidden"));
    update();
  }

  function setupMenu() {
    const menu = document.getElementById("menu");
    const openBtn = document.querySelector("[data-menu-open]");
    if (!menu || !openBtn) return;
    const closeBtn = menu.querySelector("[data-menu-close]");
    let lastFocus = null;

    function open() {
      lastFocus = document.activeElement;
      menu.hidden = false;
      root.classList.add("menu-open");
      openBtn.setAttribute("aria-expanded", "true");
      if (SM.lenis) SM.lenis.stop();
      if (motion) {
        gsap.fromTo(menu, { opacity: 0 }, { opacity: 1, duration: 0.35, ease: "power2.out" });
        gsap.fromTo(menu.querySelectorAll(".menu__list li, .menu__foot"), { y: 30, opacity: 0 }, { y: 0, opacity: 1, duration: 0.8, stagger: 0.05, ease: EASE, delay: 0.05 });
      }
      closeBtn.focus();
    }

    function close(returnFocus) {
      root.classList.remove("menu-open");
      openBtn.setAttribute("aria-expanded", "false");
      if (SM.lenis) SM.lenis.start();
      const done = () => {
        menu.hidden = true;
      };
      if (motion) gsap.to(menu, { opacity: 0, duration: 0.25, ease: "power2.in", onComplete: done });
      else done();
      if (returnFocus !== false && lastFocus) lastFocus.focus();
    }

    openBtn.addEventListener("click", open);
    closeBtn.addEventListener("click", () => close());
    menu.addEventListener("keydown", (e) => {
      if (e.key === "Escape") {
        e.preventDefault();
        close();
        return;
      }
      if (e.key !== "Tab") return;
      const items = Array.from(menu.querySelectorAll("a, button"));
      const first = items[0];
      const lastItem = items[items.length - 1];
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        lastItem.focus();
      } else if (!e.shiftKey && document.activeElement === lastItem) {
        e.preventDefault();
        first.focus();
      }
    });
    menu.querySelectorAll('a[href^="#"]').forEach((a) => a.addEventListener("click", () => close(false)));
    window.matchMedia("(min-width: 1024px)").addEventListener("change", (e) => {
      if (e.matches && !menu.hidden) close(false);
    });
  }

  function setupMobileBar() {
    const bar = document.querySelector("[data-mobile-bar]");
    const hero = document.querySelector(".hero");
    const form = document.getElementById("eligibility");
    if (!bar || !hero || !form || !("IntersectionObserver" in window)) return;
    let pastHero = false;
    let formOn = false;
    const apply = () => {
      const show = pastHero && !formOn;
      bar.classList.toggle("is-visible", show);
      bar.inert = !show;
    };
    new IntersectionObserver(
      ([entry]) => {
        pastHero = !entry.isIntersecting;
        apply();
      },
      { rootMargin: "0px 0px -50% 0px" }
    ).observe(hero);
    new IntersectionObserver(
      ([entry]) => {
        formOn = entry.isIntersecting;
        apply();
      },
      { rootMargin: "0px 0px -10% 0px" }
    ).observe(form);
  }

  function setupFaq() {
    const items = document.querySelectorAll(".faq__item");
    let refreshTimer = 0;
    const refresh = () => {
      if (!ST) return;
      clearTimeout(refreshTimer);
      refreshTimer = setTimeout(() => ST.refresh(), 120);
    };
    items.forEach((d) => {
      const summary = d.querySelector("summary");
      const body = d.querySelector(".faq__body");
      summary.addEventListener("click", (e) => {
        if (!motion) {
          refresh();
          return;
        }
        e.preventDefault();
        if (d.open) {
          gsap.to(body, {
            opacity: 0,
            y: -8,
            duration: 0.22,
            ease: "power2.in",
            onComplete() {
              d.open = false;
              gsap.set(body, { clearProps: "opacity,transform" });
              refresh();
            }
          });
        } else {
          d.open = true;
          gsap.fromTo(body, { opacity: 0, y: -12 }, { opacity: 1, y: 0, duration: 0.6, ease: EASE, clearProps: "opacity,transform" });
          refresh();
        }
      });
    });
  }

  function runPreloader() {
    const pre = document.querySelector(".preloader");
    if (!pre) return 0;
    if (!root.classList.contains("is-preloading") || !motion) {
      root.classList.remove("is-preloading");
      pre.remove();
      return 0;
    }
    try {
      sessionStorage.setItem("sm-intro", "1");
    } catch (e) {}
    if (SM.lenis) SM.lenis.stop();
    const lines = pre.querySelectorAll(".pre-line");
    const stones = pre.querySelectorAll(".pre-stone");
    const num = pre.querySelector(".pre-num");
    const lat = pre.querySelector("[data-pre-lat]");
    const lng = pre.querySelector("[data-pre-lng]");
    const c = { lat: 0, lng: 0 };
    const draw = { duration: 0.26, ease: "power2.inOut" };
    const tl = gsap.timeline({
      onComplete() {
        root.classList.remove("is-preloading");
        pre.remove();
        if (SM.lenis) SM.lenis.start();
        ST.refresh();
      }
    });
    tl.fromTo(lines[0], { scaleX: 0, opacity: 1 }, Object.assign({ scaleX: 1, transformOrigin: "0% 50%" }, draw), 0)
      .fromTo(lines[1], { scaleY: 0, opacity: 1 }, Object.assign({ scaleY: 1, transformOrigin: "50% 0%" }, draw), 0.24)
      .fromTo(lines[2], { scaleX: 0, opacity: 1 }, Object.assign({ scaleX: 1, transformOrigin: "100% 50%" }, draw), 0.48)
      .fromTo(lines[3], { scaleY: 0, opacity: 1 }, Object.assign({ scaleY: 1, transformOrigin: "50% 100%" }, draw), 0.72)
      .fromTo(stones, { scale: 0, opacity: 0 }, { scale: 1, opacity: 1, transformOrigin: "50% 100%", duration: 0.35, stagger: 0.5, ease: "back.out(2)" }, 0.15)
      .fromTo(num, { opacity: 0 }, { opacity: 1, duration: 0.3 }, 0.45)
      .to(c, {
        lat: C.coordinates.lat,
        lng: C.coordinates.lng,
        duration: 1,
        ease: "power2.out",
        onUpdate() {
          lat.textContent = c.lat.toFixed(2);
          lng.textContent = c.lng.toFixed(2);
        }
      }, 0)
      .to(pre, { yPercent: -100, duration: 0.5, ease: "expo.inOut" }, 1.08);
    return 1.12;
  }

  function setupHero(delay) {
    const hero = document.querySelector(".hero");
    if (!hero) return;
    const title = hero.querySelector(".hero__title");
    const media = hero.querySelector("[data-hero-media]");
    const img = media.querySelector("img");
    const stats = SM.plan ? SM.plan.stats : null;
    const bar = hero.querySelector("[data-booked-bar]");
    const pct = stats ? stats.bookedPct / 100 : 0.7;

    if (!motion) {
      root.classList.add("hero-ready");
      if (bar) bar.style.transform = `scaleX(${pct})`;
      return;
    }

    gsap.fromTo(img, { scale: 1.1 }, { scale: 1, duration: 2.6, ease: EASE, delay });
    gsap.to(media, { yPercent: 14, ease: "none", scrollTrigger: { trigger: hero, start: "top top", end: "bottom top", scrub: true } });

    const parts = hero.querySelectorAll(".hero__overline, .hero__telugu, .hero__lead > *, .hero__stats li, .phase-card");
    gsap.from(parts, { y: 30, opacity: 0, duration: 1, stagger: 0.06, ease: EASE, delay: delay + 0.35, clearProps: "transform,opacity" });

    hero.querySelectorAll("[data-count]").forEach((el) => {
      const end = parseInt(el.textContent, 10);
      if (!Number.isFinite(end)) return;
      const o = { v: 0 };
      el.textContent = "0";
      gsap.to(o, {
        v: end,
        duration: 1.6,
        ease: "power3.out",
        delay: delay + 0.5,
        onUpdate() {
          el.textContent = String(Math.round(o.v));
        }
      });
    });
    if (bar) gsap.fromTo(bar, { scaleX: 0 }, { scaleX: pct, duration: 1.6, ease: EASE, delay: delay + 0.7 });

    if (window.SplitText) {
      let first = true;
      window.SplitText.create(title, {
        type: "lines",
        mask: "lines",
        linesClass: "line",
        autoSplit: true,
        onSplit(self) {
          root.classList.add("hero-ready");
          const tween = gsap.from(self.lines, { yPercent: 118, duration: 1.25, stagger: 0.1, ease: EASE, delay: first ? delay + 0.1 : 0 });
          first = false;
          return tween;
        }
      });
    } else {
      root.classList.add("hero-ready");
      gsap.from(title, { y: 30, opacity: 0, duration: 1, ease: EASE, delay });
    }
  }

  function setupReveals() {
    gsap.utils.toArray("[data-reveal]").forEach((el) => {
      gsap.from(el, {
        y: 30,
        opacity: 0,
        duration: 0.7,
        ease: EASE,
        clearProps: "transform,opacity",
        scrollTrigger: { trigger: el, start: "top 88%", once: true }
      });
    });
    gsap.utils.toArray("[data-stagger]").forEach((group) => {
      gsap.from(group.children, {
        y: 30,
        opacity: 0,
        duration: 0.7,
        stagger: 0.06,
        ease: EASE,
        clearProps: "transform,opacity",
        scrollTrigger: { trigger: group, start: "top 85%", once: true }
      });
    });
  }

  function setupProcess() {
    const section = document.querySelector("[data-process]");
    if (!section) return;
    const pin = section.querySelector("[data-process-pin]");
    const track = section.querySelector("[data-process-track]");
    const bar = section.querySelector("[data-process-bar]");
    const mm = gsap.matchMedia();
    mm.add("(min-width: 1024px)", () => {
      section.classList.add("has-hscroll");
      const distance = () => Math.max(0, track.scrollWidth - document.documentElement.clientWidth);
      const tl = gsap.timeline({
        scrollTrigger: {
          trigger: pin,
          start: "top top",
          end: () => "+=" + distance(),
          pin: true,
          scrub: 0.8,
          invalidateOnRefresh: true,
          anticipatePin: 1
        }
      });
      tl.to(track, { x: () => -distance(), ease: "none" }, 0).fromTo(bar, { scaleX: 0 }, { scaleX: 1, ease: "none" }, 0);
      return () => section.classList.remove("has-hscroll");
    });
  }

  function setupStory() {
    const media = document.querySelector("[data-story-media]");
    if (!media) return;
    const trigger = { trigger: media.parentElement, start: "top 70%", once: true };
    gsap.fromTo(media, { clipPath: "inset(0% 100% 0% 0%)" }, { clipPath: "inset(0% 0% 0% 0%)", duration: 1.5, ease: "expo.inOut", scrollTrigger: trigger });
    gsap.fromTo(media.querySelector("img"), { scale: 1.2 }, { scale: 1, duration: 2, ease: EASE, scrollTrigger: Object.assign({}, trigger) });
  }

  function setupCursor() {
    if (!fine || !hasGsap) return;
    const cursor = document.querySelector(".cursor");
    if (!cursor) return;
    root.classList.add("has-cursor");
    const speed = reduce ? 0.01 : 0.35;
    const xTo = gsap.quickTo(cursor, "x", { duration: speed, ease: "power3" });
    const yTo = gsap.quickTo(cursor, "y", { duration: speed, ease: "power3" });
    let shown = false;
    window.addEventListener(
      "pointermove",
      (e) => {
        if (e.pointerType !== "mouse") return;
        if (!shown) {
          gsap.set(cursor, { x: e.clientX, y: e.clientY });
          cursor.classList.add("is-visible");
          shown = true;
        }
        xTo(e.clientX);
        yTo(e.clientY);
      },
      { passive: true }
    );
    document.documentElement.addEventListener("mouseleave", () => {
      cursor.classList.remove("is-visible");
      shown = false;
    });
    document.addEventListener("pointerover", (e) => {
      const t = e.target.closest && e.target.closest("a, button, summary, label, select, input, .plot");
      cursor.classList.toggle("is-hover", !!t);
      cursor.classList.toggle("is-view", !!(t && t.classList.contains("plot")));
    });
  }

  function setupMagnetic() {
    if (!fine) return;
    document.querySelectorAll("[data-magnetic]").forEach((el) => {
      const xTo = gsap.quickTo(el, "x", { duration: 0.6, ease: "power3" });
      const yTo = gsap.quickTo(el, "y", { duration: 0.6, ease: "power3" });
      el.addEventListener("pointermove", (e) => {
        if (e.pointerType !== "mouse") return;
        const r = el.getBoundingClientRect();
        xTo((e.clientX - (r.left + r.width / 2)) * 0.22);
        yTo((e.clientY - (r.top + r.height / 2)) * 0.32);
      });
      el.addEventListener("pointerleave", () => {
        xTo(0);
        yTo(0);
      });
    });
  }

  bindConfig();
  buildJsonLd();
  setupLenis();
  if (SM.plan && SM.plan.mount) SM.plan.mount();
  renderLocation();
  renderPricing();
  setupEmi();
  setupHeader();
  setupMenu();
  setupAnchors();
  setupMobileBar();
  setupFaq();
  setupCursor();
  const delay = runPreloader();
  setupHero(delay);
  if (motion) {
    setupReveals();
    setupProcess();
    setupStory();
    setupMagnetic();
    if (document.fonts && document.fonts.ready) document.fonts.ready.then(() => ST.refresh());
    window.addEventListener("load", () => ST.refresh());
  }
})();
