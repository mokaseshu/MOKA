(function () {
  const S = window.SITE;
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));
  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const fine = window.matchMedia("(hover: hover) and (pointer: fine)").matches;
  const rupee = n => "₹" + Number(n).toLocaleString("en-IN");
  const esc = s => String(s).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const initials = n => n.replace(/^(Mr|Mrs|Ms|Dr)\.\s*/, "").split(/[\s.]+/).filter(Boolean).map(w => w[0]).join("").slice(0, 2).toUpperCase();
  const waLink = msg => "https://wa.me/" + S.whatsapp + "?text=" + encodeURIComponent(msg);
  const store = {
    get(k) { try { return localStorage.getItem(k); } catch (e) { return null; } },
    set(k, v) { try { localStorage.setItem(k, v); } catch (e) {} }
  };

  function bindConfig() {
    $$("[data-cfg]").forEach(el => { const v = S[el.dataset.cfg]; if (v != null) el.textContent = v; });
    $$("[data-tel]").forEach(el => { el.href = "tel:+" + S.phoneRaw; });
    $$("[data-mail]").forEach(el => { el.href = "mailto:" + S.email; });
    $$("[data-map]").forEach(el => { el.href = S.mapsUrl; });
    $$("[data-wa]").forEach(el => {
      el.href = waLink(el.dataset.wa || ("Hello " + S.name + ", I would like to know more about admissions for " + S.academicYear + "."));
      el.target = "_blank";
      el.rel = "noopener";
    });
    $$("[data-year]").forEach(el => { el.textContent = new Date().getFullYear(); });
    $$("[data-early]").forEach(el => { el.textContent = S.earlyOffer.text; });
  }

  function countdown() {
    const box = $("#cd");
    if (!box) return;
    const end = new Date(S.admissionLastDate).getTime();
    const label = $("#cd-date");
    if (label) label.textContent = new Date(end).toLocaleDateString("en-IN", { day: "numeric", month: "short", year: "numeric" });
    const tick = () => {
      let d = end - Date.now();
      if (d <= 0) { box.innerHTML = "<span>Admissions closed · enquire for next batch</span>"; return; }
      const days = Math.floor(d / 864e5); d -= days * 864e5;
      const h = Math.floor(d / 36e5); d -= h * 36e5;
      const m = Math.floor(d / 6e4); d -= m * 6e4;
      const s = Math.floor(d / 1e3);
      box.innerHTML = `<span>${days}d</span><span>${String(h).padStart(2, "0")}h</span><span>${String(m).padStart(2, "0")}m</span><span>${String(s).padStart(2, "0")}s</span>`;
    };
    tick();
    setInterval(tick, 1000);
  }

  function lang() {
    const btns = $$(".lang button");
    const nodes = $$("[data-te]");
    nodes.forEach(n => { n.dataset.en = n.innerHTML; });
    const apply = l => {
      document.documentElement.lang = l === "te" ? "te" : "en";
      document.body.classList.toggle("te", l === "te");
      nodes.forEach(n => { n.innerHTML = l === "te" ? n.dataset.te : n.dataset.en; });
      btns.forEach(b => b.setAttribute("aria-pressed", String(b.dataset.lang === l)));
      store.set("ssl-lang", l);
    };
    btns.forEach(b => b.addEventListener("click", () => { apply(b.dataset.lang); if (window.ScrollTrigger) ScrollTrigger.refresh(); }));
    const saved = store.get("ssl-lang");
    if (saved === "te") apply("te");
  }

  function header() {
    const h = $(".hdr");
    if (!h) return;
    let last = 0;
    const onScroll = () => {
      const y = window.scrollY;
      h.classList.toggle("scrolled", y > 20);
      h.classList.toggle("hide", y > 260 && y > last && !document.body.classList.contains("menu-open"));
      last = y;
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    onScroll();
    const btn = $(".menu-btn");
    if (btn) btn.addEventListener("click", () => {
      const open = document.body.classList.toggle("menu-open");
      btn.setAttribute("aria-expanded", String(open));
      const d = $(".drawer");
      if (d) d.setAttribute("aria-hidden", String(!open));
    });
    document.addEventListener("keydown", e => {
      if (e.key === "Escape" && document.body.classList.contains("menu-open")) btn.click();
    });
  }

  function renderStats() {
    const el = $("#stats");
    if (!el) return;
    el.innerHTML = S.stats.map(s => `<div class="stat rv"><div class="stat-n" data-count="${s.value}" data-suffix="${s.suffix}">${s.value.toLocaleString("en-IN")}${s.suffix}</div><div class="stat-l">${esc(s.label)}</div></div>`).join("");
  }

  function batchPanel(b) {
    const fee = S.fees.find(f => f.course.startsWith(b.title.split(" (")[0])) || S.fees.find(f => b.id === "9-10" ? f.course === "Class 9" : false);
    return `<div class="panel-card"><span class="tag green">${esc(b.board)}</span><h3 class="h-md" style="margin:14px 0 10px">${esc(b.title)}</h3><p class="muted">${esc(b.note)}</p><h4 style="font-family:var(--body);font-size:.8rem;letter-spacing:.12em;text-transform:uppercase;color:var(--muted);margin:22px 0 10px">Subjects</h4><div class="chips">${b.subjects.map(s => `<span class="chip">${esc(s)}</span>`).join("")}</div></div>
    <div class="panel-card green"><span class="tag">Batch details</span><dl class="kv">${b.timings.map((t, i) => `<div><dt>${i === 0 ? "Batch A" : "Batch B"}</dt><dd>${esc(t)}</dd></div>`).join("")}<div><dt>Days</dt><dd>${esc(b.days)}</dd></div><div><dt>Batch size</dt><dd>Max ${b.size} students</dd></div>${fee ? `<div><dt>Fee from</dt><dd>${rupee(fee.monthly)} / month</dd></div>` : ""}</dl><div style="display:flex;gap:10px;flex-wrap:wrap;margin-top:24px"><a class="btn sun sm" href="admissions.html#${b.id}">Enquire for this batch</a><a class="btn ghost sm" style="color:var(--on-green);border-color:rgba(246,251,243,.5)" href="courses.html#${b.id}">Full details</a></div></div>`;
  }

  function renderBatchTabs() {
    const tabs = $("#batch-tabs");
    const panel = $("#batch-panel");
    if (!tabs || !panel) return;
    tabs.innerHTML = S.batches.map((b, i) => `<button class="tab" role="tab" id="tab-${b.id}" aria-controls="batch-panel" aria-selected="${i === 0}" tabindex="${i === 0 ? 0 : -1}" data-i="${i}"><span data-te="${esc(b.te)}">${esc(b.title)}</span></button>`).join("");
    const show = i => {
      $$(".tab", tabs).forEach((t, j) => { t.setAttribute("aria-selected", String(i === j)); t.tabIndex = i === j ? 0 : -1; });
      panel.setAttribute("aria-labelledby", "tab-" + S.batches[i].id);
      panel.innerHTML = batchPanel(S.batches[i]);
      if (window.gsap && !reduce) gsap.from(panel.children, { y: 18, opacity: 0, duration: .5, stagger: .08, ease: "power3.out" });
    };
    tabs.addEventListener("click", e => { const t = e.target.closest(".tab"); if (t) show(+t.dataset.i); });
    tabs.addEventListener("keydown", e => {
      if (!["ArrowRight", "ArrowLeft"].includes(e.key)) return;
      const cur = $$(".tab", tabs).findIndex(t => t.getAttribute("aria-selected") === "true");
      const n = (cur + (e.key === "ArrowRight" ? 1 : -1) + S.batches.length) % S.batches.length;
      show(n);
      $$(".tab", tabs)[n].focus();
    });
    show(0);
  }

  function renderCourses() {
    const el = $("#courses");
    if (!el) return;
    el.innerHTML = S.batches.map(b => {
      const dots = Array.from({ length: b.size }, () => "<i></i>").join("");
      return `<article class="course rv" id="${b.id}"><div style="display:grid;gap:14px;align-content:start"><span class="tag green">${esc(b.board)}</span><h2 data-te="${esc(b.te)}">${esc(b.title)}</h2><p class="muted">${esc(b.note)}</p><a class="btn sm" href="admissions.html#${b.id}">Enquire now</a></div><div><h3>Subjects</h3><div class="chips">${b.subjects.map(s => `<span class="chip">${esc(s)}</span>`).join("")}</div><div class="seat"><div class="seat-dots" aria-hidden="true">${dots}</div><span><b>Max ${b.size}</b> per batch</span></div></div><div><h3>Timings · ${esc(b.days)}</h3><div class="slots">${b.timings.map((t, i) => `<div class="slot"><span>Batch ${i ? "B" : "A"}</span><span>${esc(t)}</span></div>`).join("")}</div></div></article>`;
    }).join("");
  }

  function feeRows(mode) {
    return S.fees.map(f => {
      const val = mode === "yearly" ? f.yearly : f.monthly;
      const save = f.monthly * 12 - f.yearly;
      return `<div class="fee-row"><div><h3>${esc(f.course)}</h3><p class="muted">${mode === "yearly" ? `<span class="save">You save ${rupee(save)} vs monthly</span>` : `Or ${rupee(f.yearly)} per year`}</p></div><div class="price">${rupee(val)}<small>${mode === "yearly" ? "per year · 10 months" : "per month"}</small></div></div>`;
    }).join("");
  }

  function renderFees() {
    $$("[data-fees]").forEach(box => {
      const limit = +box.dataset.fees || S.fees.length;
      const list = box.querySelector(".fee-list");
      const btns = $$(".toggle button", box);
      const draw = mode => {
        const all = feeRows(mode).split('<div class="fee-row">').filter(Boolean).slice(0, limit).map(r => '<div class="fee-row">' + r).join("");
        list.innerHTML = all;
        btns.forEach(b => b.setAttribute("aria-pressed", String(b.dataset.mode === mode)));
      };
      btns.forEach(b => b.addEventListener("click", () => draw(b.dataset.mode)));
      draw("monthly");
    });
    const inc = $("#fee-includes");
    if (inc) inc.innerHTML = S.feeIncludes.map(i => `<li>${esc(i)}</li>`).join("");
    const sib = $$("[data-sibling]");
    sib.forEach(e => { e.textContent = S.siblingDiscount + "%"; });
  }

  function feeCalc() {
    const f = $("#calc");
    if (!f) return;
    const course = $("#calc-course"), plan = $("#calc-plan"), sib = $("#calc-sib"), early = $("#calc-early"), out = $("#calc-out"), note = $("#calc-note");
    course.innerHTML = S.fees.map((x, i) => `<option value="${i}">${esc(x.course)}</option>`).join("");
    const run = () => {
      const fee = S.fees[+course.value];
      const yearly = plan.value === "yearly";
      let total = yearly ? fee.yearly : fee.monthly * 10;
      const parts = [yearly ? `Yearly plan ${rupee(fee.yearly)}` : `10 months × ${rupee(fee.monthly)}`];
      if (sib.checked) { const d = Math.round(total * S.siblingDiscount / 100); total -= d; parts.push(`sibling −${rupee(d)}`); }
      if (early.checked) { total -= S.earlyOffer.amount; parts.push(`early admission −${rupee(S.earlyOffer.amount)}`); }
      out.textContent = rupee(total);
      note.textContent = parts.join(" · ") + " for the full academic year";
    };
    [course, plan, sib, early].forEach(x => x.addEventListener("change", run));
    run();
  }

  function renderToppers() {
    const card = t => `<article class="topper rv" data-tilt><span class="tag">Sample</span><div class="av ${t.tone === "y" ? "y" : ""}" aria-hidden="true">${initials(t.name)}</div><div><div class="score">${esc(t.marks)}</div><p class="muted" style="margin-top:6px">${esc(t.course)}</p></div><h3 style="font-size:1.2rem">${esc(t.name)}</h3></article>`;
    const g = $("#toppers");
    if (g) g.innerHTML = S.toppers.map(card).join("");
    const m = $("#marquee");
    if (m) {
      const items = S.toppers.map(t => `<div class="mq"><span class="av ${t.tone === "y" ? "y" : ""}" aria-hidden="true">${initials(t.name)}</span><span>${esc(t.name)} · ${esc(t.course)}</span><b>${esc(t.marks)}</b></div>`).join("");
      m.innerHTML = `<div class="marquee-track"><div style="display:flex;gap:16px">${items}</div><div style="display:flex;gap:16px" aria-hidden="true">${items}</div></div>`;
    }
  }

  function renderChart() {
    const el = $("#chart");
    if (!el) return;
    const W = 760, H = 340, L = 48, R = 24, T = 36, B = 44;
    const min = 85, max = 100;
    const data = S.results;
    const x = i => L + (i * (W - L - R)) / (data.length - 1);
    const y = v => T + ((max - v) * (H - T - B)) / (max - min);
    const ticks = [85, 90, 95, 100];
    const pts = data.map((d, i) => [x(i), y(d.pass)]);
    const line = pts.map((p, i) => (i ? "L" : "M") + p[0].toFixed(1) + " " + p[1].toFixed(1)).join(" ");
    const area = line + ` L ${x(data.length - 1)} ${H - B} L ${x(0)} ${H - B} Z`;
    el.innerHTML = `<svg class="chart" viewBox="0 0 ${W} ${H}" role="img" aria-label="Pass percentage by year: ${data.map(d => d.year + " " + d.pass + "%").join(", ")}">
      <defs><linearGradient id="ga" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0e5a3a" stop-opacity=".22"/><stop offset="1" stop-color="#0e5a3a" stop-opacity="0"/></linearGradient></defs>
      ${ticks.map(t => `<line class="grid" x1="${L}" x2="${W - R}" y1="${y(t)}" y2="${y(t)}"/><text x="${L - 10}" y="${y(t) + 4}" text-anchor="end">${t}%</text>`).join("")}
      <path class="c-area" d="${area}" fill="url(#ga)"/>
      <path class="c-line" d="${line}" fill="none" stroke="#0e5a3a" stroke-width="3.5" stroke-linejoin="round" stroke-linecap="round"/>
      ${pts.map((p, i) => `<g class="c-pt"><circle cx="${p[0]}" cy="${p[1]}" r="${i === pts.length - 1 ? 9 : 6}" fill="${i === pts.length - 1 ? "#f2a900" : "#fbf8f1"}" stroke="#0e5a3a" stroke-width="3"/><text class="val" x="${p[0]}" y="${p[1] - 18}" text-anchor="middle">${data[i].pass}%</text></g>`).join("")}
      ${data.map((d, i) => `<text x="${x(i)}" y="${H - B + 26}" text-anchor="middle">${d.year}</text>`).join("")}
    </svg>`;
  }

  function renderTeam() {
    const el = $("#team");
    if (!el) return;
    el.innerHTML = S.teachers.slice(1).map((t, i) => `<article class="member rv"><div class="av ${i % 2 ? "y" : ""}" aria-hidden="true">${initials(t.name)}</div><h3 style="font-size:1.15rem">${esc(t.name)}</h3><p class="muted">${esc(t.role)}</p><p style="font-size:.9rem"><b>${esc(t.exp)}</b> · ${esc(t.qual)}</p></article>`).join("");
  }

  function renderReviews() {
    const el = $("#reviews");
    if (!el) return;
    el.innerHTML = S.reviews.map((r, i) => `<article class="review rv"><div class="stars" aria-label="5 out of 5">★★★★★</div><p>${esc(r.text)}</p><div class="review-by"><span class="av ${i % 2 ? "y" : ""}" aria-hidden="true">${esc(r.who.replace(/\./g, ""))}</span><div><b>${esc(r.who)}</b><br><span class="muted">${esc(r.rel)}</span></div><span class="tag">Sample review</span></div></article>`).join("");
  }

  function renderFaq() {
    const el = $("#faq");
    if (!el) return;
    el.innerHTML = S.faqs.map((f, i) => `<details class="rv"${i === 0 ? " open" : ""}><summary>${esc(f.q)}</summary><p>${esc(f.a)}</p></details>`).join("");
    const ld = document.createElement("script");
    ld.type = "application/ld+json";
    ld.textContent = JSON.stringify({ "@context": "https://schema.org", "@type": "FAQPage", mainEntity: S.faqs.map(f => ({ "@type": "Question", name: f.q, acceptedAnswer: { "@type": "Answer", text: f.a } })) });
    document.head.appendChild(ld);
  }

  function admissions() {
    const form = $("#enquiry");
    if (!form) return;
    const steps = $$(".fstep", form);
    const bars = $$(".progress i", form);
    const back = $("#f-back"), next = $("#f-next"), label = $("#f-label");
    const cls = $("#f-class"), subBox = $("#f-subjects"), batchBox = $("#f-batch");
    const classes = [
      ["Class 6", "6-8"], ["Class 7", "6-8"], ["Class 8", "6-8"], ["Class 9", "9-10"], ["Class 10", "9-10"],
      ["Inter 1st year MPC", "mpc"], ["Inter 2nd year MPC", "mpc"], ["Inter 1st year BiPC", "bipc"], ["Inter 2nd year BiPC", "bipc"],
      ["EAMCET / NEET Foundation (Class 8–10)", "foundation"]
    ];
    cls.innerHTML = '<option value="">Select class</option>' + classes.map(c => `<option value="${esc(c[0])}" data-b="${c[1]}">${esc(c[0])}</option>`).join("");
    const batchOf = () => S.batches.find(b => b.id === (cls.selectedOptions[0] && cls.selectedOptions[0].dataset.b));
    const fillOptions = () => {
      const b = batchOf();
      if (!b) return;
      subBox.innerHTML = b.subjects.map((s, i) => `<label class="opt"><input type="checkbox" name="subjects" value="${esc(s)}" id="sub-${i}"><span>${esc(s)}</span></label>`).join("") + `<label class="opt"><input type="checkbox" name="subjects" value="All subjects" id="sub-all"><span>All subjects</span></label>`;
      batchBox.innerHTML = b.timings.map((t, i) => `<label class="opt"><input type="radio" name="batch" value="${esc(t)}" id="bt-${i}"${i === 0 ? " checked" : ""}><span>${esc(t)}</span></label>`).join("");
      const all = $("#sub-all");
      all.addEventListener("change", () => $$('input[name="subjects"]', subBox).forEach(x => { if (x !== all) x.checked = all.checked; }));
    };
    cls.addEventListener("change", fillOptions);
    const hash = location.hash.replace("#", "");
    const pre = classes.find(c => c[1] === hash);
    if (pre) { cls.value = pre[0]; fillOptions(); }

    let cur = 0;
    const setErr = (id, msg) => {
      const f = $("#" + id), e = $("#" + id + "-err");
      if (f) f.setAttribute("aria-invalid", msg ? "true" : "false");
      if (e) e.textContent = msg || "";
      return !msg;
    };
    const validate = i => {
      if (i === 0) {
        const n = $("#f-name").value.trim();
        const a = setErr("f-name", n.length < 2 ? "Enter the student's name." : "");
        const b = setErr("f-class", !cls.value ? "Choose the class." : "");
        return a && b;
      }
      if (i === 1) return setErr("f-subjects", $$('input[name="subjects"]:checked', subBox).length ? "" : "Pick at least one subject.");
      if (i === 2) return setErr("f-batch", $('input[name="batch"]:checked', batchBox) ? "" : "Pick a batch timing.");
      if (i === 3) {
        const p = $("#f-phone").value.replace(/\D/g, "").replace(/^91(?=\d{10}$)/, "");
        return setErr("f-phone", /^[6-9]\d{9}$/.test(p) ? "" : "Enter a 10-digit mobile number starting with 6, 7, 8 or 9.");
      }
      return true;
    };
    const message = () => {
      const subs = $$('input[name="subjects"]:checked', subBox).map(x => x.value).filter((v, i, a) => !(v === "All subjects" && a.length > 1) || v === "All subjects");
      const pick = subs.includes("All subjects") ? "All subjects" : subs.join(", ");
      const phone = $("#f-phone").value.replace(/\D/g, "").replace(/^91(?=\d{10}$)/, "");
      const pname = $("#f-parent").value.trim();
      const demo = $("#f-demo").checked;
      const data = [
        ["Student", $("#f-name").value.trim()],
        ["Class", cls.value],
        ["Subjects", pick],
        ["Preferred batch", $('input[name="batch"]:checked', batchBox).value],
        ["Parent", (pname ? pname + " · " : "") + "+91 " + phone],
        ["Free demo class", demo ? "Yes, please book one" : "No"]
      ];
      const text = `Hello ${S.name}, I would like to enquire about admission for ${S.academicYear}.\n\n` + data.map(d => `${d[0]}: ${d[1]}`).join("\n") + "\n\nPlease share the next steps.";
      return { data, text };
    };
    const show = i => {
      cur = i;
      steps.forEach((s, j) => { s.hidden = j !== i; });
      bars.forEach((b, j) => b.classList.toggle("on", j <= i));
      label.textContent = `Step ${i + 1} of ${steps.length}`;
      back.hidden = i === 0;
      next.hidden = i === steps.length - 1;
      if (i === steps.length - 1) {
        const m = message();
        $("#f-review").innerHTML = m.data.map(d => `<div><dt>${esc(d[0])}</dt><dd>${esc(d[1])}</dd></div>`).join("");
        $("#f-preview").textContent = m.text;
        $("#f-send").href = waLink(m.text);
      }
      const h = steps[i].querySelector("h2");
      if (h && i > 0) { h.tabIndex = -1; h.focus({ preventScroll: true }); }
    };
    next.addEventListener("click", () => { if (validate(cur)) show(cur + 1); });
    back.addEventListener("click", () => show(cur - 1));
    form.addEventListener("submit", e => { e.preventDefault(); if (cur < steps.length - 1) next.click(); });
    $("#f-edit").addEventListener("click", () => show(0));
    $("#f-send").addEventListener("click", () => { $("#f-done").hidden = false; });
    show(0);
  }

  function quickContact() {
    const f = $("#quick");
    if (!f) return;
    const go = $("#q-send");
    const upd = () => {
      const n = $("#q-name").value.trim(), m = $("#q-msg").value.trim();
      go.href = waLink(`Hello ${S.name},${n ? " this is " + n + "." : ""}\n\n${m || "I have a question about classes and fees."}`);
    };
    f.addEventListener("input", upd);
    f.addEventListener("submit", e => { e.preventDefault(); upd(); go.click(); });
    upd();
  }

  function copyButtons() {
    $$("[data-copy]").forEach(b => b.addEventListener("click", () => {
      const v = S[b.dataset.copy];
      const done = () => { const t = b.textContent; b.textContent = "Copied"; setTimeout(() => { b.textContent = t; }, 1600); };
      if (navigator.clipboard) navigator.clipboard.writeText(v).then(done).catch(() => selectText(b));
      else selectText(b);
    }));
    function selectText(b) {
      const t = b.parentElement.querySelector(".big");
      if (!t) return;
      const r = document.createRange(); r.selectNodeContents(t);
      const s = getSelection(); s.removeAllRanges(); s.addRange(r);
    }
  }

  function motion() {
    if (!window.gsap) return;
    if (window.ScrollTrigger) gsap.registerPlugin(ScrollTrigger);
    if (reduce) return;
    document.documentElement.classList.add("reveal-ready");

    if (window.Lenis) {
      const lenis = new Lenis({ duration: 1.1, smoothWheel: true });
      lenis.on("scroll", () => window.ScrollTrigger && ScrollTrigger.update());
      gsap.ticker.add(t => lenis.raf(t * 1000));
      gsap.ticker.lagSmoothing(0);
      $$('a[href^="#"]').forEach(a => a.addEventListener("click", e => {
        const id = a.getAttribute("href");
        if (id.length > 1 && $(id)) { e.preventDefault(); lenis.scrollTo(id, { offset: -90 }); }
      }));
    }

    const h1 = $(".hero h1[data-split]");
    if (h1 && window.SplitType) {
      const st = new SplitType(h1, { types: "lines,words" });
      st.lines.forEach(l => { const w = document.createElement("span"); w.className = "line"; l.parentNode.insertBefore(w, l); w.appendChild(l); });
      gsap.from(st.words, { yPercent: 115, duration: 1.05, ease: "expo.out", stagger: .06, delay: .1 });
    }
    gsap.from(".hero .hero-in > *:not(h1)", { y: 26, opacity: 0, duration: .9, ease: "power3.out", stagger: .08, delay: .35 });
    gsap.from(".hero-photo", { clipPath: "inset(12% 12% 12% 12% round 32px)", duration: 1.4, ease: "expo.out", delay: .1 });
    gsap.from(".hero-photo img", { scale: 1.3, duration: 1.8, ease: "expo.out" });
    gsap.from(".hero-sun", { scale: 0, duration: 1.2, ease: "back.out(1.6)", delay: .5 });
    gsap.from(".hero-chip", { y: 30, opacity: 0, duration: .8, ease: "back.out(1.7)", stagger: .15, delay: .9 });
    if ($(".hero-photo img")) gsap.to(".hero-photo img", { yPercent: 8, ease: "none", scrollTrigger: { trigger: ".hero", start: "top top", end: "bottom top", scrub: true } });

    if (!window.ScrollTrigger) return;
    ScrollTrigger.batch(".rv", {
      start: "top 88%",
      once: true,
      onEnter: els => gsap.from(els, { y: 40, opacity: 0, duration: .9, ease: "power3.out", stagger: .08, overwrite: true })
    });

    $$("[data-count]").forEach(el => {
      const end = +el.dataset.count, suf = el.dataset.suffix || "";
      const o = { v: 0 };
      ScrollTrigger.create({
        trigger: el, start: "top 90%", once: true,
        onEnter: () => gsap.to(o, { v: end, duration: 2, ease: "power2.out", onUpdate: () => { el.textContent = Math.round(o.v).toLocaleString("en-IN") + suf; } })
      });
    });

    $$("[data-parallax]").forEach(el => {
      gsap.fromTo(el, { yPercent: -6 }, { yPercent: 6, ease: "none", scrollTrigger: { trigger: el.parentElement, start: "top bottom", end: "bottom top", scrub: true } });
    });

    const tl = $(".track-line i");
    if (tl) {
      const vertical = window.matchMedia("(max-width: 860px)").matches;
      gsap.fromTo(tl, vertical ? { scaleY: 0 } : { scaleX: 0 }, { scaleX: 1, scaleY: 1, ease: "none", scrollTrigger: { trigger: ".track", start: "top 75%", end: "bottom 55%", scrub: true } });
      gsap.from(".step-dot", { scale: .4, opacity: 0, duration: .7, ease: "back.out(2)", stagger: .25, scrollTrigger: { trigger: ".track", start: "top 75%" } });
    }

    const line = $(".c-line");
    if (line) {
      const len = line.getTotalLength();
      gsap.set(line, { strokeDasharray: len, strokeDashoffset: len });
      const t = gsap.timeline({ scrollTrigger: { trigger: "#chart", start: "top 75%", once: true } });
      t.to(line, { strokeDashoffset: 0, duration: 1.8, ease: "power2.inOut" })
        .from(".c-area", { opacity: 0, duration: .8 }, "-=1")
        .from(".c-pt", { opacity: 0, y: 10, duration: .4, stagger: .1 }, "-=1.6");
    }

    $$(".bento .tile").forEach((t, i) => gsap.from(t, { y: 60, opacity: 0, duration: 1, ease: "power3.out", delay: (i % 3) * .08, scrollTrigger: { trigger: t, start: "top 90%", once: true } }));
  }

  function tilt() {
    if (!fine || reduce || !window.VanillaTilt) return;
    VanillaTilt.init($$("[data-tilt]"), { max: 7, speed: 600, glare: true, "max-glare": .15, scale: 1.02 });
  }

  function magnetic() {
    if (!fine || reduce || !window.gsap) return;
    $$("[data-mag]").forEach(el => {
      el.addEventListener("mousemove", e => {
        const r = el.getBoundingClientRect();
        gsap.to(el, { x: (e.clientX - r.left - r.width / 2) * .25, y: (e.clientY - r.top - r.height / 2) * .35, duration: .4, ease: "power3.out" });
      });
      el.addEventListener("mouseleave", () => gsap.to(el, { x: 0, y: 0, duration: .7, ease: "elastic.out(1,.4)" }));
    });
  }

  function ctaScene() {
    const host = $(".cta");
    if (!host || reduce || !window.THREE) return;
    let started = false;
    const io = new IntersectionObserver(es => {
      if (!es[0].isIntersecting || started) return;
      started = true;
      io.disconnect();
      const canvas = document.createElement("canvas");
      canvas.setAttribute("aria-hidden", "true");
      host.prepend(canvas);
      const renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true });
      renderer.setPixelRatio(Math.min(devicePixelRatio, 1.6));
      const scene = new THREE.Scene();
      const cam = new THREE.PerspectiveCamera(40, 1, .1, 100);
      cam.position.z = 14;
      scene.add(new THREE.AmbientLight(0xffffff, .7));
      const dl = new THREE.DirectionalLight(0xffffff, .9); dl.position.set(4, 6, 8); scene.add(dl);
      const geos = [new THREE.IcosahedronGeometry(.9, 0), new THREE.TorusGeometry(.7, .26, 16, 40), new THREE.OctahedronGeometry(.9, 0), new THREE.ConeGeometry(.75, 1.3, 4)];
      const mats = [new THREE.MeshStandardMaterial({ color: 0xffc83d, flatShading: true, roughness: .5 }), new THREE.MeshStandardMaterial({ color: 0x1b7a52, flatShading: true, roughness: .6 }), new THREE.MeshStandardMaterial({ color: 0xf6fbf3, flatShading: true, roughness: .7 })];
      const items = [];
      for (let i = 0; i < 16; i++) {
        const m = new THREE.Mesh(geos[i % geos.length], mats[i % mats.length]);
        m.position.set((Math.random() - .5) * 22, (Math.random() - .5) * 10, (Math.random() - .5) * 6 - 2);
        const s = .5 + Math.random() * .8; m.scale.set(s, s, s);
        m.userData = { r: (Math.random() - .5) * .01, f: Math.random() * 6, y: m.position.y };
        scene.add(m); items.push(m);
      }
      const size = () => { const w = host.clientWidth, h = host.clientHeight; renderer.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix(); };
      size();
      window.addEventListener("resize", size);
      let mx = 0, my = 0, visible = true;
      host.addEventListener("mousemove", e => { const r = host.getBoundingClientRect(); mx = (e.clientX - r.left) / r.width - .5; my = (e.clientY - r.top) / r.height - .5; });
      new IntersectionObserver(e => { visible = e[0].isIntersecting; }).observe(host);
      const clock = new THREE.Clock();
      const loop = () => {
        requestAnimationFrame(loop);
        if (!visible) return;
        const t = clock.getElapsedTime();
        items.forEach(m => { m.rotation.x += m.userData.r + .003; m.rotation.y += m.userData.r + .004; m.position.y = m.userData.y + Math.sin(t * .6 + m.userData.f) * .35; });
        cam.position.x += (mx * 2 - cam.position.x) * .04;
        cam.position.y += (-my * 1.4 - cam.position.y) * .04;
        cam.lookAt(0, 0, 0);
        renderer.render(scene, cam);
      };
      loop();
    }, { rootMargin: "200px" });
    io.observe(host);
  }

  document.addEventListener("DOMContentLoaded", () => {
    bindConfig();
    countdown();
    renderStats();
    renderBatchTabs();
    renderCourses();
    renderFees();
    feeCalc();
    renderToppers();
    renderChart();
    renderTeam();
    renderReviews();
    renderFaq();
    admissions();
    quickContact();
    copyButtons();
    lang();
    header();
    motion();
    tilt();
    magnetic();
    ctaScene();
  });
})();
