(function () {
  "use strict";

  const C = window.SM_CONFIG;
  const SM = (window.SM = window.SM || {});
  const form = document.querySelector("[data-qualifier]");
  if (!form) return;

  window.dataLayer = window.dataLayer || [];
  const track = (event, data) => window.dataLayer.push(Object.assign({ event }, data || {}));

  const ANSWERS = {
    budget: {
      u15: { label: "Under ₹15 L", max: 1500000, exclusive: true, score: 5 },
      "15-25": { label: "₹15–25 L", max: 2500000, score: 25 },
      "25-40": { label: "₹25–40 L", max: 4000000, score: 30 },
      "40+": { label: "₹40 L+", max: Infinity, score: 30 }
    },
    timeline: {
      "1m": { label: "Within 1 month", score: 35, soon: true },
      "1-3m": { label: "1–3 months", score: 30, soon: true },
      "3-6m": { label: "3–6 months", score: 10 },
      exploring: { label: "Just exploring", score: 0 }
    },
    size: {
      150: { label: "150 sq. yd", sqyd: 150 },
      200: { label: "200 sq. yd", sqyd: 200 },
      267: { label: "267 sq. yd", sqyd: 267 },
      "300+": { label: "300+ sq. yd", sqyd: 300 },
      unsure: { label: "Not sure yet", sqyd: null }
    },
    payment: {
      own: { label: "Own funds", score: 20 },
      loan: { label: "Bank loan", score: 15 },
      undecided: { label: "Not decided", score: 5 }
    },
    visit: {
      person: { label: "In person", phrase: "an in-person site visit" },
      video: { label: "Video tour (NRI)", phrase: "a video tour" }
    }
  };

  const steps = Array.from(form.querySelectorAll("[data-step]"));
  const total = steps.length;
  const progressText = form.querySelector("[data-progress-text]");
  const progressBar = form.querySelector("[data-progress-bar]");
  const backBtn = form.querySelector("[data-back]");
  const nextBtn = form.querySelector("[data-next]");
  const hint = form.querySelector(".q-hint");
  const hintMax = form.querySelector("[data-hint-max]");
  const live = form.querySelector("[data-live]");
  const plotChip = form.querySelector("[data-plot-chip]");
  const plotChipText = form.querySelector("[data-plot-chip-text]");
  const plotChipClear = form.querySelector("[data-plot-chip-clear]");
  const results = Array.from(form.querySelectorAll("[data-result]"));
  const chrome = form.querySelector(".q-chrome");
  const slotWrap = form.querySelector("[data-slots]");

  let index = 0;
  let busy = false;
  let started = false;
  let arrowNav = false;
  let selectedPlot = null;
  let advanceTimer = 0;

  C.visitSlots.forEach((slot, i) => {
    const id = `q-slot-${i}`;
    const label = document.createElement("label");
    label.className = "chip-opt";
    label.setAttribute("for", id);
    const input = document.createElement("input");
    input.type = "radio";
    input.name = "slot";
    input.id = id;
    input.value = slot;
    input.className = "chip-opt__input";
    const span = document.createElement("span");
    span.textContent = slot;
    label.append(input, span);
    slotWrap.appendChild(label);
  });

  const utm = (() => {
    const keys = ["utm_source", "utm_medium", "utm_campaign"];
    const params = new URLSearchParams(window.location.search);
    let stored = {};
    try {
      stored = JSON.parse(sessionStorage.getItem("sm-utm") || "{}");
    } catch (e) {
      stored = {};
    }
    const out = {};
    keys.forEach((k) => {
      out[k] = params.get(k) || stored[k] || "";
    });
    try {
      sessionStorage.setItem("sm-utm", JSON.stringify(out));
    } catch (e) {}
    return out;
  })();

  const motion = () => window.gsap && !SM.reduceMotion;
  const value = (name) => {
    const checked = form.querySelector(`input[name="${name}"]:checked`);
    return checked ? checked.value : "";
  };
  const legendText = (step) => {
    const q = step.querySelector(".q-title");
    return q ? q.textContent.trim() : "";
  };

  function announce(msg) {
    live.textContent = "";
    setTimeout(() => {
      live.textContent = msg;
    }, 40);
  }

  function updateProgress(i, done) {
    const n = done ? total : i + 1;
    progressText.textContent = done ? "Done" : `Step ${n} of ${total}`;
    const scale = done ? 1 : n / total;
    if (motion()) window.gsap.to(progressBar, { scaleX: scale, duration: 0.6, ease: "expo.out" });
    else progressBar.style.transform = `scaleX(${scale})`;
    backBtn.hidden = done || i === 0;
    nextBtn.hidden = done || i === total - 1;
    hint.hidden = done || i === total - 1;
    if (!done && i < total - 1) hintMax.textContent = String(steps[i].querySelectorAll("input[type=radio]").length);
  }

  function focusStep(step) {
    const target =
      step.querySelector("input[type=radio]:checked") ||
      step.querySelector("input[type=radio], input[type=text], input[type=tel]");
    if (target) target.focus({ preventScroll: true });
  }

  function swap(from, to, dir) {
    return new Promise((resolve) => {
      if (!motion()) {
        from.hidden = true;
        to.hidden = false;
        resolve();
        return;
      }
      const gsap = window.gsap;
      gsap.to(from, {
        opacity: 0,
        y: -14 * dir,
        duration: 0.2,
        ease: "power2.in",
        onComplete() {
          from.hidden = true;
          gsap.set(from, { clearProps: "opacity,transform" });
          to.hidden = false;
          gsap.fromTo(
            to,
            { opacity: 0, y: 22 * dir },
            { opacity: 1, y: 0, duration: 0.5, ease: "expo.out", clearProps: "opacity,transform", onComplete: resolve }
          );
        }
      });
    });
  }

  let pending = null;

  async function goTo(i, opts) {
    if (busy) {
      pending = { i, opts };
      return;
    }
    if (i < 0 || i >= total || i === index) return;
    busy = true;
    clearTimeout(advanceTimer);
    const from = steps[index];
    const to = steps[i];
    const dir = i > index ? 1 : -1;
    index = i;
    updateProgress(i, false);
    await swap(from, to, dir);
    busy = false;
    if (pending) {
      const next = pending;
      pending = null;
      if (next.i !== index) {
        goTo(next.i, next.opts);
        return;
      }
    }
    announce(`Step ${i + 1} of ${total}. ${legendText(to)}`);
    track("form_step", { step: i + 1 });
    if (!opts || opts.focus !== false) focusStep(to);
  }

  function setError(container, msg) {
    const err = container.querySelector(".q-error");
    if (err) err.textContent = msg || "";
  }

  function validateChoice(step) {
    const name = step.getAttribute("data-name");
    const ok = !!value(name);
    setError(step, ok ? "" : "Choose an option to continue.");
    return ok;
  }

  function normalisePhone(raw) {
    let digits = String(raw || "").replace(/\D/g, "");
    if (digits.length === 12 && digits.startsWith("91")) digits = digits.slice(2);
    if (digits.length === 11 && digits.startsWith("0")) digits = digits.slice(1);
    return digits;
  }

  const fieldRules = {
    name(v) {
      return v.trim().length >= 2 ? "" : "Please enter your name.";
    },
    phone(v) {
      const d = normalisePhone(v);
      if (!d) return "Please enter your mobile number.";
      return /^[6-9]\d{9}$/.test(d) ? "" : "Enter a 10-digit Indian mobile number starting with 6, 7, 8 or 9.";
    }
  };

  function checkField(input, show) {
    const rule = fieldRules[input.name];
    if (!rule) return true;
    const msg = rule(input.value);
    const err = document.getElementById(input.getAttribute("aria-describedby").split(" ")[0]);
    if (show || !msg) {
      err.textContent = msg;
      input.setAttribute("aria-invalid", msg ? "true" : "false");
    }
    return !msg;
  }

  function validateContact(step) {
    const inputs = Array.from(step.querySelectorAll("input[name=name], input[name=phone]"));
    let firstBad = null;
    inputs.forEach((input) => {
      if (!checkField(input, true) && !firstBad) firstBad = input;
    });
    const groups = [
      { name: "visit", msg: "Choose how you would like to visit." },
      { name: "slot", msg: "Pick a slot that suits you." }
    ];
    groups.forEach((g) => {
      const wrap = step.querySelector(`[data-group="${g.name}"]`);
      const ok = !!value(g.name);
      setError(wrap, ok ? "" : g.msg);
      if (!ok && !firstBad) firstBad = wrap.querySelector("input");
    });
    if (firstBad) {
      firstBad.focus();
      return false;
    }
    return true;
  }

  function fits(budgetKey, sizeKey) {
    const budget = ANSWERS.budget[budgetKey];
    const size = ANSWERS.size[sizeKey];
    if (!budget || !size) return false;
    if (size.sqyd === null) return budgetKey !== "u15";
    const price = size.sqyd * C.pricePerSqYd;
    return budget.exclusive ? price < budget.max : price <= budget.max;
  }

  function score(a) {
    let s = ANSWERS.budget[a.budget].score + ANSWERS.timeline[a.timeline].score + ANSWERS.payment[a.payment].score;
    if (fits(a.budget, a.size)) s += 15;
    return s;
  }

  function tierFor(s, a) {
    if (s >= 70 && ANSWERS.timeline[a.timeline].soon) return "hot";
    if (s >= 40) return "warm";
    return "cold";
  }

  function formatPhone(d) {
    return `+91 ${d.slice(0, 5)} ${d.slice(5)}`;
  }

  function refCode(tier, s) {
    const src = (utm.utm_source || "web").toLowerCase().replace(/[^a-z0-9]/g, "").slice(0, 12) || "web";
    return `SM-${tier.charAt(0).toUpperCase()}${s}-${src}`;
  }

  function buildMessage(lead) {
    const visit = ANSWERS.visit[lead.visit];
    const first = lead.name.trim().split(/\s+/)[0];
    const opener = {
      hot: `Hi ${C.brand} team, this is ${first}. I'd like to confirm ${visit.phrase} on ${lead.slot}.`,
      warm: `Hi ${C.brand} team, this is ${first}. Please send me the brochure and price sheet for ${C.brand}.`,
      cold: `Hi ${C.brand} team, this is ${first}. Please add me to your WhatsApp updates on new phases and offers.`
    }[lead.tier];
    const lines = [opener, ""];
    lines.push(`Name: ${lead.name.trim()}`);
    lines.push(`Phone: ${formatPhone(lead.phone)}`);
    lines.push(`Budget: ${ANSWERS.budget[lead.budget].label}`);
    lines.push(`Planning to buy: ${ANSWERS.timeline[lead.timeline].label}`);
    lines.push(`Plot size: ${ANSWERS.size[lead.size].label}`);
    lines.push(`Paying with: ${ANSWERS.payment[lead.payment].label}`);
    if (lead.plot) lines.push(`Plot I liked: ${lead.plot.number} (${lead.plot.size} sq. yd, ${lead.plot.facing} facing, ${SM.lakh(lead.plot.price)})`);
    lines.push(`Visit: ${visit.label}, ${lead.slot}`);
    lines.push("");
    lines.push(`Ref: ${lead.ref}`);
    return lines.join("\n");
  }

  function waLink(text) {
    return `https://wa.me/${C.whatsappNumber}?text=${encodeURIComponent(text)}`;
  }

  function sendToSheet(lead) {
    if (!C.sheetEndpoint) return;
    const payload = {
      timestamp: new Date().toISOString(),
      name: lead.name.trim(),
      phone: lead.phone,
      tier: lead.tier,
      score: lead.score,
      budget: ANSWERS.budget[lead.budget].label,
      timeline: ANSWERS.timeline[lead.timeline].label,
      size: ANSWERS.size[lead.size].label,
      payment: ANSWERS.payment[lead.payment].label,
      plot: lead.plot ? `${lead.plot.number} · ${lead.plot.size} sq. yd · ${lead.plot.facing}` : "",
      visit: ANSWERS.visit[lead.visit].label,
      slot: lead.slot,
      ref: lead.ref,
      utm_source: utm.utm_source,
      utm_medium: utm.utm_medium,
      utm_campaign: utm.utm_campaign,
      page: window.location.href
    };
    try {
      fetch(C.sheetEndpoint, {
        method: "POST",
        mode: "no-cors",
        headers: { "Content-Type": "text/plain;charset=utf-8" },
        body: JSON.stringify(payload)
      }).catch(() => {});
    } catch (e) {}
  }

  function showResult(tier, lead) {
    const result = results.find((r) => r.getAttribute("data-result") === tier);
    results.forEach((r) => {
      r.hidden = r !== result;
    });
    if (lead) {
      const message = buildMessage(lead);
      result.querySelectorAll("[data-r-wa]").forEach((a) => {
        a.href = waLink(message);
      });
      result.querySelectorAll("[data-r-slot]").forEach((s) => {
        s.textContent = lead.slot;
      });
      result.querySelectorAll("[data-r-visit]").forEach((s) => {
        s.textContent = lead.visit === "video" ? "Video tour · IST" : `In person · free pickup from ${C.pickupFrom}`;
      });
      result.querySelectorAll("[data-r-name]").forEach((s) => {
        s.textContent = lead.name.trim().split(/\s+/)[0];
      });
      result.querySelectorAll("[data-r-plot]").forEach((s) => {
        s.hidden = !lead.plot;
        if (lead.plot) s.textContent = `Plot ${lead.plot.number} · ${lead.plot.size} sq. yd · ${lead.plot.facing} facing`;
      });
    }
    form.classList.add("is-complete");
    updateProgress(index, true);
    const step = steps[index];
    const reveal = () => {
      const heading = result.querySelector(".q-result__title");
      heading.focus({ preventScroll: true });
      announce(heading.textContent);
    };
    if (!motion()) {
      step.hidden = true;
      result.hidden = false;
      reveal();
      return;
    }
    const gsap = window.gsap;
    gsap.to(step, {
      opacity: 0,
      y: -14,
      duration: 0.2,
      ease: "power2.in",
      onComplete() {
        step.hidden = true;
        gsap.set(step, { clearProps: "opacity,transform" });
        result.hidden = false;
        const tl = gsap.timeline({ defaults: { ease: "expo.out" } });
        tl.fromTo(result.querySelector(".q-result__mark"), { scale: 0.4, opacity: 0, rotate: -12 }, { scale: 1, opacity: 1, rotate: 0, duration: 0.9, ease: "back.out(1.8)" })
          .fromTo(result.querySelectorAll(".q-result__item"), { opacity: 0, y: 22 }, { opacity: 1, y: 0, duration: 0.7, stagger: 0.07 }, 0.12);
        reveal();
      }
    });
  }

  function submit() {
    const honeypot = form.querySelector("input[name=company]");
    const answers = {
      budget: value("budget"),
      timeline: value("timeline"),
      size: value("size"),
      payment: value("payment")
    };
    const name = form.querySelector("input[name=name]").value;
    const phone = normalisePhone(form.querySelector("input[name=phone]").value);
    if (honeypot && honeypot.value) {
      showResult("cold", null);
      return;
    }
    const s = score(answers);
    const tier = tierFor(s, answers);
    const lead = Object.assign({}, answers, {
      name,
      phone,
      visit: value("visit"),
      slot: value("slot"),
      plot: selectedPlot,
      score: s,
      tier
    });
    lead.ref = refCode(tier, s);
    track("generate_lead", { tier, score: s, lead_ref: lead.ref });
    sendToSheet(lead);
    showResult(tier, lead);
  }

  function next() {
    const step = steps[index];
    if (index < total - 1) {
      if (validateChoice(step)) goTo(index + 1);
      else focusStep(step);
      return;
    }
    if (validateContact(step)) submit();
  }

  function markStarted() {
    if (started) return;
    started = true;
    track("form_start");
    track("form_step", { step: index + 1 });
  }

  form.addEventListener("submit", (e) => {
    e.preventDefault();
    if (busy || form.classList.contains("is-complete")) return;
    next();
  });

  form.addEventListener("pointerdown", () => {
    arrowNav = false;
  });

  form.addEventListener("keydown", (e) => {
    if (form.classList.contains("is-complete")) return;
    if (e.key.startsWith("Arrow")) {
      arrowNav = true;
      return;
    }
    const step = steps[index];
    const isText = e.target.matches("input[type=text], input[type=tel]");
    if (!isText && index < total - 1 && /^[1-9]$/.test(e.key) && !e.altKey && !e.ctrlKey && !e.metaKey) {
      const options = step.querySelectorAll("input[type=radio]");
      const opt = options[Number(e.key) - 1];
      if (opt) {
        e.preventDefault();
        arrowNav = false;
        opt.focus({ preventScroll: true });
        opt.click();
      }
    }
  });

  const seen = {};

  form.addEventListener("click", (e) => {
    const input = e.target;
    if (!input.matches || !input.matches("input[type=radio]") || index >= total - 1) return;
    if (!steps[index].contains(input)) return;
    if (seen[input.name] === input.value && input.checked) {
      clearTimeout(advanceTimer);
      advanceTimer = setTimeout(() => goTo(index + 1), 250);
    }
  });

  form.addEventListener("change", (e) => {
    const input = e.target;
    if (input.type !== "radio") return;
    seen[input.name] = input.value;
    markStarted();
    const step = steps[index];
    if (!step.contains(input)) return;
    if (index < total - 1) {
      setError(step, "");
      if (!arrowNav) {
        clearTimeout(advanceTimer);
        advanceTimer = setTimeout(() => goTo(index + 1), 250);
      }
    } else {
      const group = input.closest("[data-group]");
      if (group) setError(group, "");
    }
  });

  form.querySelectorAll("input[name=name], input[name=phone]").forEach((input) => {
    input.addEventListener("input", () => {
      markStarted();
      if (input.getAttribute("aria-invalid") === "true") checkField(input, true);
    });
    input.addEventListener("blur", () => {
      if (input.value) checkField(input, true);
    });
  });

  backBtn.addEventListener("click", () => goTo(index - 1));

  function sizeKeyFor(sqyd) {
    if (sqyd >= 300) return "300+";
    return ANSWERS.size[sqyd] ? String(sqyd) : "unsure";
  }

  function preselectSize(sqyd) {
    const key = sizeKeyFor(sqyd);
    const input = form.querySelector(`input[name="size"][value="${key}"]`);
    if (input) {
      input.checked = true;
      seen.size = key;
    }
  }

  function reset() {
    form.reset();
    Object.keys(seen).forEach((k) => delete seen[k]);
    results.forEach((r) => {
      r.hidden = true;
    });
    form.classList.remove("is-complete");
    steps.forEach((s, i) => {
      s.hidden = i !== 0;
      setError(s, "");
    });
    form.querySelectorAll("[aria-invalid]").forEach((i) => i.setAttribute("aria-invalid", "false"));
    form.querySelectorAll(".q-error").forEach((e) => {
      e.textContent = "";
    });
    index = 0;
    updateProgress(0, false);
    if (selectedPlot) preselectSize(selectedPlot.size);
  }

  form.querySelectorAll("[data-restart]").forEach((b) =>
    b.addEventListener("click", () => {
      reset();
      focusStep(steps[0]);
    })
  );

  function setPlot(plot) {
    selectedPlot = plot;
    if (plot) {
      plotChipText.textContent = `Plot ${plot.number} · ${plot.size} sq. yd · ${plot.facing} facing · ${SM.lakh(plot.price)}`;
      plotChip.hidden = false;
      preselectSize(plot.size);
    } else {
      plotChip.hidden = true;
    }
  }

  plotChipClear.addEventListener("click", () => {
    setPlot(null);
    focusStep(steps[index]);
  });

  function bringIntoView() {
    const section = document.getElementById("eligibility");
    const go = SM.scrollTo || ((t) => t.scrollIntoView({ behavior: SM.reduceMotion ? "auto" : "smooth" }));
    go(section, () => focusStep(steps[index]));
  }

  document.addEventListener("sm:enquire", (e) => {
    if (form.classList.contains("is-complete")) reset();
    setPlot(e.detail);
    markStarted();
    bringIntoView();
  });

  document.addEventListener("sm:focus-form", () => {
    if (form.classList.contains("is-complete")) {
      const visible = results.find((r) => !r.hidden);
      if (visible) visible.querySelector(".q-result__title").focus({ preventScroll: true });
      return;
    }
    focusStep(steps[index]);
  });

  document.addEventListener("sm:size", (e) => {
    if (form.classList.contains("is-complete")) reset();
    preselectSize(e.detail);
    bringIntoView();
  });

  chrome.hidden = false;
  steps.forEach((s, i) => {
    s.hidden = i !== 0;
  });
  updateProgress(0, false);

  SM.form = { score, tierFor, fits, buildMessage, refCode };
})();
