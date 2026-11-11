(() => {
  const C = window.SITE_CONFIG || {};
  const doc = document;
  const root = doc.documentElement;
  const body = doc.body;
  const page = body.dataset.page || "";
  const mqReduce = window.matchMedia("(prefers-reduced-motion: reduce)");
  const reduce = mqReduce.matches;
  const finePointer = window.matchMedia("(hover: hover) and (pointer: fine)").matches;
  const hasGsap = typeof window.gsap !== "undefined";
  const hasST = hasGsap && typeof window.ScrollTrigger !== "undefined";
  if (hasST) gsap.registerPlugin(ScrollTrigger);
  if (reduce) root.classList.add("reduced");

  const $ = (s, el = doc) => el.querySelector(s);
  const $$ = (s, el = doc) => Array.from(el.querySelectorAll(s));
  const get = (path) => path.split(".").reduce((o, k) => (o == null ? o : o[k]), C);
  const fullAddress = () => {
    const a = C.address || {};
    return [a.line1, a.line2, `${a.city}, ${a.state} ${a.pin}`].filter(Boolean).join(", ");
  };
  const waLink = (text) => `https://wa.me/${C.whatsapp}${text ? `?text=${encodeURIComponent(text)}` : ""}`;
  const defaultWaText = `Hi ${C.clinicName}, I'd like to book an appointment.`;

  const ICONS = {
    phone: '<path d="M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2.1 4.2 2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1.9.4 1.8.7 2.7a2 2 0 0 1-.5 2.1L8 9.8a16 16 0 0 0 6 6l1.3-1.3a2 2 0 0 1 2.1-.4c.9.3 1.8.6 2.7.7a2 2 0 0 1 1.7 2z"/>',
    wa: '<path fill="currentColor" stroke="none" d="M12 2a10 10 0 0 0-8.6 15.1L2 22l5-1.3A10 10 0 1 0 12 2zm0 18.2a8.2 8.2 0 0 1-4.2-1.2l-.3-.2-3 .8.8-2.9-.2-.3A8.2 8.2 0 1 1 12 20.2zm4.5-6.1c-.2-.1-1.5-.7-1.7-.8s-.4-.1-.6.1-.6.8-.8 1-.3.2-.5.1a6.7 6.7 0 0 1-3.3-2.9c-.3-.4.3-.4.7-1.3a.5.5 0 0 0 0-.5l-.8-1.8c-.2-.5-.4-.4-.6-.4h-.5a1 1 0 0 0-.7.3 3 3 0 0 0-.9 2.2 5.2 5.2 0 0 0 1.1 2.7 11.8 11.8 0 0 0 4.5 4c1.7.7 2.3.8 3.2.6a2.7 2.7 0 0 0 1.8-1.2 2.2 2.2 0 0 0 .1-1.3c0-.1-.2-.2-.5-.3z"/>',
    star: '<path fill="currentColor" stroke="none" d="m12 2.8 2.8 5.8 6.3.9-4.6 4.4 1.1 6.3L12 17.2l-5.6 3 1.1-6.3-4.6-4.4 6.3-.9z"/>',
    play: '<path fill="currentColor" stroke="none" d="M8 5.5v13l10.5-6.5z"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    pin: '<path d="M12 21s-7-6.2-7-11.5a7 7 0 0 1 14 0C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>',
    calendar: '<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M3 10h18M8 3v4M16 3v4"/>',
    arrow: '<path d="M5 12h14M13 6l6 6-6 6"/>',
    chev: '<path d="m6 9 6 6 6-6"/>',
    check: '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
    checkc: '<circle cx="12" cy="12" r="9"/><path d="m8 12.5 2.7 2.7L16 9.8"/>',
    shield: '<path d="M12 3 4.5 6v5.5c0 4.6 3.2 8.3 7.5 9.5 4.3-1.2 7.5-4.9 7.5-9.5V6z"/><path d="m9 12 2 2 4-4"/>',
    scan: '<path d="M4 8V6a2 2 0 0 1 2-2h2M16 4h2a2 2 0 0 1 2 2v2M20 16v2a2 2 0 0 1-2 2h-2M8 20H6a2 2 0 0 1-2-2v-2"/><path d="M9.5 8.5c-1.5.6-2 2.4-1.6 4.2.4 1.9 1 4 2 4 .8 0 .8-2 1.4-2.5h1.4c.6.5.6 2.5 1.4 2.5 1 0 1.6-2.1 2-4 .4-1.8-.1-3.6-1.6-4.2-1-.4-1.8 0-2.5.4-.7-.4-1.5-.8-2.5-.4z"/>',
    timer: '<circle cx="12" cy="13" r="8"/><path d="M12 9v4l2.5 2.5M9 2h6"/>',
    card: '<rect x="3" y="5.5" width="18" height="13" rx="3"/><path d="M3 10h18M7 15h3"/>',
    rupee: '<path d="M7 4h10M7 8.5h10M11 4c3 0 4.5 2 4.5 4.5S14 13 11 13H7.5l7 7"/>',
    sparkle: '<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"/><path d="M19 15l.7 2 2 .7-2 .7-.7 2-.7-2-2-.7 2-.7z"/>',
    heart: '<path d="M12 20s-7.5-4.4-7.5-10A4.3 4.3 0 0 1 12 7.4 4.3 4.3 0 0 1 19.5 10c0 5.6-7.5 10-7.5 10z"/>',
    music: '<path d="M9 18V5l11-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="17" cy="16" r="3"/>',
    moon: '<path d="M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z"/>',
    chat: '<path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1-4.6A8 8 0 1 1 21 12z"/><path d="M8.5 11h7M8.5 14h4"/>',
    feather: '<path d="M20.2 3.8a6 6 0 0 0-8.5 0L5 10.5V19h8.5l6.7-6.7a6 6 0 0 0 0-8.5z"/><path d="M16 8 2 22M17.5 15H9"/>',
    tooth: '<path d="M12 5.5c-1.7-1.3-3.6-1.9-5.3-1.2C4 5.4 3.6 8.6 4.4 11.4c.5 1.9 1.2 3.6 1.6 5.6.4 1.8.8 3.5 2 3.5 1.3 0 1.4-2.4 1.8-4 .3-1.2.9-2 2.2-2s1.9.8 2.2 2c.4 1.6.5 4 1.8 4 1.2 0 1.6-1.7 2-3.5.4-2 1.1-3.7 1.6-5.6.8-2.8.4-6-2.3-7.1-1.7-.7-3.6-.1-5.3 1.2z"/>',
    implant: '<path d="M7 4.2c1.5-1 3.3-1 5 0 1.7-1 3.5-1 5 0 1.4 1 1.3 3 .5 4.5H6.5C5.7 7.2 5.6 5.2 7 4.2z"/><path d="M12 8.7V11M8 11.5h8M8.5 14.5h7M9 17.5h6M10.5 20.5h3"/>',
    aligner: '<path d="M3 9c0 6 4 10 9 10s9-4 9-10"/><path d="M6.5 9.5c0 4 2.4 6.5 5.5 6.5s5.5-2.5 5.5-6.5"/><path d="M9.5 12.5v2M12 13v2.5M14.5 12.5v2"/>',
    rootcanal: '<path d="M12 5.5c-1.7-1.3-3.6-1.9-5.3-1.2C4 5.4 3.6 8.6 4.4 11.4c.5 1.9 1.2 3.6 1.6 5.6.4 1.8.8 3.5 2 3.5 1.3 0 1.4-2.4 1.8-4 .3-1.2.9-2 2.2-2s1.9.8 2.2 2c.4 1.6.5 4 1.8 4 1.2 0 1.6-1.7 2-3.5.4-2 1.1-3.7 1.6-5.6.8-2.8.4-6-2.3-7.1-1.7-.7-3.6-.1-5.3 1.2z"/><path d="M10 9.5v3M14 9.5v3"/>',
    kids: '<circle cx="12" cy="12" r="9"/><path d="M8.5 14a4.5 4.5 0 0 0 7 0M9 9.5h.01M15 9.5h.01"/>',
    brush: '<path d="M4 20 14.5 9.5"/><rect x="13" y="2.5" width="6" height="9" rx="2" transform="rotate(45 16 7)"/><path d="M14.5 5.5l1 1M16.5 3.5l1 1"/>',
    mail: '<rect x="3" y="5" width="18" height="14" rx="3"/><path d="m4 7 8 6 8-6"/>',
    instagram: '<rect x="3" y="3" width="18" height="18" rx="5"/><circle cx="12" cy="12" r="4"/><path d="M17.5 6.5h.01"/>',
    facebook: '<path d="M15 3h-2.5A3.5 3.5 0 0 0 9 6.5V9H6.5v3.5H9V21h3.5v-8.5H15l.5-3.5h-3V7a1 1 0 0 1 1-1H15z"/>',
    youtube: '<rect x="2.5" y="5.5" width="19" height="13" rx="4"/><path d="m10 9 5 3-5 3z"/>',
    info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/>',
    lock: '<rect x="4.5" y="10.5" width="15" height="10" rx="2.5"/><path d="M8 10.5V7.5a4 4 0 0 1 8 0v3"/>',
    user: '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
    award: '<circle cx="12" cy="9" r="6"/><path d="m8.5 14-1.5 7 5-3 5 3-1.5-7"/>',
    grad: '<path d="M2 9.5 12 5l10 4.5-10 4.5z"/><path d="M6 11.5V16c0 1.5 2.7 3 6 3s6-1.5 6-3v-4.5M22 9.5V15"/>',
    mobile: '<rect x="6" y="2.5" width="12" height="19" rx="3"/><path d="M10.5 18.5h3"/>',
    cash: '<rect x="2.5" y="6" width="19" height="12" rx="2.5"/><circle cx="12" cy="12" r="2.5"/><path d="M6 9.5v.01M18 14.5v.01"/>',
    bank: '<path d="M3 10 12 4l9 6M5 10v8M9.5 10v8M14.5 10v8M19 10v8M3 20h18"/>',
    file: '<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5M9 13h6M9 17h4"/>',
    download: '<path d="M12 4v11M7 10l5 5 5-5M5 20h14"/>',
    alert: '<path d="M12 3.5 2.5 20h19z"/><path d="M12 10v4.5M12 17.5h.01"/>',
    sofa: '<path d="M4 11V8a3 3 0 0 1 3-3h10a3 3 0 0 1 3 3v3"/><path d="M2.5 13a2 2 0 0 1 4 0v2h11v-2a2 2 0 0 1 4 0v4a2 2 0 0 1-2 2h-15a2 2 0 0 1-2-2zM5 19v2M19 19v2"/>',
    car: '<path d="M5 16v-5l2-5h10l2 5v5M5 16h14M5 16v3M19 16v3M8 13h.01M16 13h.01"/>',
    refresh: '<path d="M3 12a9 9 0 0 1 15.5-6.3L21 8M21 3v5h-5M21 12a9 9 0 0 1-15.5 6.3L3 16M3 21v-5h5"/>',
    swipe: '<path d="M18 8l3 3-3 3M6 8l-3 3 3 3M3 11h18"/>',
    printer: '<path d="M7 9V3h10v6M7 17H5a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2h-2"/><rect x="7" y="14" width="10" height="7" rx="1"/>',
    home: '<path d="M3 11 12 4l9 7M5 10v10h14V10"/>',
    leaf: '<path d="M5 19c0-8 5-14 15-14 0 10-6 15-14 15"/><path d="M5 19 13 11"/>',
    users: '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0M16 4.5a3.5 3.5 0 0 1 0 7M18 14a6.5 6.5 0 0 1 3.5 6"/>',
    eye: '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>'
  };
  const SVC_ICON = { implants: "implant", "aligners-braces": "aligner", "teeth-whitening": "sparkle", "root-canal": "rootcanal", "kids-dentistry": "kids", "cleaning-checkup": "brush" };
  const icon = (n, cls = "") => `<svg class="i ${cls}" aria-hidden="true"><use href="#i-${n}"/></svg>`;

  const sprite = doc.createElement("div");
  sprite.setAttribute("aria-hidden", "true");
  sprite.style.cssText = "position:absolute;width:0;height:0;overflow:hidden";
  sprite.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg">${Object.entries(ICONS).map(([k, v]) => `<symbol id="i-${k}" viewBox="0 0 24 24">${v}</symbol>`).join("")}</svg>`;
  body.prepend(sprite);

  const toothMark = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONS.tooth}<path d="M8.5 8.2c.6-.8 1.6-1.1 2.4-.8" opacity=".7"/></svg>`;
  const logoHTML = (extra = "") => `<a class="logo ${extra}" href="index.html" aria-label="${C.clinicName} home"><span class="logo__mark">${toothMark}</span><span class="logo__text"><span class="logo__name">Bright<em>Smile</em></span><span class="logo__sub">Dental · ${C.address.city}</span></span></a>`;
  const pic = (name, alt, attrs = "") => `<picture><source srcset="assets/images/${name}.webp" type="image/webp"><img src="assets/images/${name}.jpg" alt="${alt}" loading="lazy" decoding="async" ${attrs}></picture>`;

  const NAV = [
    { key: "about", label: "About", href: "about.html" },
    { key: "services", label: "Services", href: "services.html", mega: true },
    { key: "gallery", label: "Smile Gallery", href: "smile-gallery.html" },
    { key: "patient", label: "Patient Info", href: "patient-info.html" },
    { key: "contact", label: "Contact", href: "contact.html" }
  ];
  const cur = (k) => (k === page ? ' aria-current="page"' : "");

  function renderChrome() {
    const t = C.treatments || [];
    const mega = `
      <div class="mega" id="mega-services">
        <div class="mega__panel">
          <ul class="mega__list" role="list">
            ${t.map((s, i) => `<li class="mega__item${i === 0 ? " is-active" : ""}" data-mega-index="${i}"><a href="${s.slug}.html"><span class="mega__icon">${icon(SVC_ICON[s.slug] || "tooth")}</span><span><span class="mega__title">${s.name}</span><span class="mega__line" style="display:block">${s.line}</span></span></a></li>`).join("")}
          </ul>
          <div class="mega__preview" aria-hidden="true">
            ${t.map((s, i) => `<div class="mega__img${i === 0 ? " is-active" : ""}"><div class="media ${i % 2 ? "media--mint" : ""}">${pic(s.image, "")}</div></div>`).join("")}
            <div class="mega__preview-foot"><span>Not sure what you need?</span><a class="link-arrow" href="services.html">All services ${icon("arrow")}</a></div>
          </div>
        </div>
      </div>`;
    const menu = NAV.map((n) => n.mega
      ? `<li class="has-mega"><button class="menu__link" type="button" aria-expanded="false" aria-controls="mega-services"${page === "services" ? ' aria-current="page"' : ""}>${n.label} ${icon("chev")}</button>${mega}</li>`
      : `<li><a class="menu__link" href="${n.href}"${cur(n.key)}>${n.label}</a></li>`).join("");

    const header = `
      <a class="skip-link" href="#main">Skip to content</a>
      <div class="chrome" data-chrome>
        <div class="topbar">
          <div class="container topbar__inner">
            <div class="topbar__group">
              <span><span class="status-dot" data-open-dot></span><span data-open-status>${C.timingsShort}</span></span>
              <span class="topbar__hide-md">${icon("pin")}${C.address.line2}, ${C.address.city}</span>
            </div>
            <div class="topbar__group">
              <a href="tel:${C.phone}" aria-label="Call ${C.clinicName}">${icon("phone")}<span class="topbar__hide-sm">${C.phoneDisplay}</span></a>
              <a href="${waLink(defaultWaText)}" target="_blank" rel="noopener">${icon("wa")}<span><span class="topbar__hide-sm">Book on&nbsp;</span>WhatsApp</span></a>
            </div>
          </div>
        </div>
        <div class="nav-wrap">
          <nav class="nav" aria-label="Main">
            ${logoHTML()}
            <ul class="menu" role="list">${menu}</ul>
            <div class="nav__actions">
              <a class="btn btn--coral btn--sm btn--book-desk" href="book.html" data-magnetic><span class="btn__label">Book Appointment ${icon("arrow", "i--arrow")}</span></a>
              <button class="burger" type="button" aria-expanded="false" aria-controls="mnav" aria-label="Open menu"><span></span><span></span><span></span></button>
            </div>
          </nav>
        </div>
      </div>
      <div class="mnav on-dark" id="mnav" aria-label="Mobile menu">
        <div>
          <ul class="mnav__list" role="list">
            <li><a href="index.html"${cur("home")}>Home <small>01</small></a></li>
            ${NAV.map((n, i) => `<li><a href="${n.href}"${cur(n.key)}>${n.label} <small>0${i + 2}</small></a></li>`).join("")}
            <li><a href="book.html"${cur("book")}>Book a visit <small>07</small></a></li>
          </ul>
          <div class="mnav__services">${t.map((s) => `<a href="${s.slug}.html">${s.name}</a>`).join("")}</div>
        </div>
        <div class="mnav__foot">
          <a class="btn btn--coral btn--lg" href="book.html">Book Appointment</a>
          <a class="btn btn--outline btn--lg" href="tel:${C.phone}">${icon("phone")} Call ${C.phoneDisplay}</a>
          <p class="mnav__meta">${C.timingsShort}</p>
        </div>
      </div>`;
    body.insertAdjacentHTML("afterbegin", header);

    const a = C.address;
    const footer = `
      <footer class="site-footer on-dark">
        <div class="container">
          <div class="footer__top">
            <div class="footer__brand">
              ${logoHTML()}
              <p>Gentle, on-time dental care for families in ${a.city}. Painless techniques, sterilised instruments and prices explained before we begin.</p>
              <div class="footer__social">
                ${C.social.instagram ? `<a href="${C.social.instagram}" target="_blank" rel="noopener" aria-label="Instagram">${icon("instagram")}</a>` : ""}
                ${C.social.facebook ? `<a href="${C.social.facebook}" target="_blank" rel="noopener" aria-label="Facebook">${icon("facebook")}</a>` : ""}
                ${C.social.youtube ? `<a href="${C.social.youtube}" target="_blank" rel="noopener" aria-label="YouTube">${icon("youtube")}</a>` : ""}
                <a href="${waLink(defaultWaText)}" target="_blank" rel="noopener" aria-label="WhatsApp">${icon("wa")}</a>
              </div>
            </div>
            <div>
              <p class="footer__title">Clinic</p>
              <ul class="footer__links" role="list">
                <li><a href="index.html">Home</a></li>
                <li><a href="about.html">About us</a></li>
                <li><a href="smile-gallery.html">Smile gallery</a></li>
                <li><a href="patient-info.html">Patient info</a></li>
                <li><a href="new-patient-form.html">New patient form</a></li>
                <li><a href="book.html">Book online</a></li>
                <li><a href="contact.html">Contact</a></li>
              </ul>
            </div>
            <div>
              <p class="footer__title">Treatments</p>
              <ul class="footer__links" role="list">
                ${t.map((s) => `<li><a href="${s.slug}.html">${s.name}</a></li>`).join("")}
                <li><a href="services.html">All services</a></li>
              </ul>
            </div>
            <div>
              <p class="footer__title">Visit us</p>
              <div class="footer__contact">
                <a href="${C.mapsLink}" target="_blank" rel="noopener">${icon("pin")}<span>${fullAddress()}</span></a>
                <a href="tel:${C.phone}">${icon("phone")}<span>${C.phoneDisplay}</span></a>
                <a href="mailto:${C.email}">${icon("mail")}<span>${C.email}</span></a>
                <div>${icon("clock")}<span class="footer__hours">${C.hours.map((h) => `<span><b style="color:var(--on-dark);font-weight:600">${h.label}</b><br>${fmtTime(h.open)} – ${fmtTime(h.close)}</span>`).join("")}</span></div>
              </div>
            </div>
          </div>
          <div class="footer__map" data-map></div>
          <div class="footer__bottom">
            <span>© <span data-year></span> ${C.clinicName}, ${a.city}. All rights reserved.</span>
            <span>Concept project — designed &amp; built by <a href="${C.agency.url}" target="_blank" rel="noopener">${C.agency.name}</a></span>
          </div>
        </div>
      </footer>
      <div class="wa-float">
        <span class="wa-float__tip" id="wa-tip">Chat with us</span>
        <a class="wa-float__btn" href="${waLink(defaultWaText)}" target="_blank" rel="noopener" aria-describedby="wa-tip" aria-label="Chat with ${C.clinicName} on WhatsApp">${icon("wa")}</a>
      </div>
      <nav class="mbar" aria-label="Quick actions">
        <a href="tel:${C.phone}">${icon("phone")}Call</a>
        <a class="mbar__wa" href="${waLink(defaultWaText)}" target="_blank" rel="noopener">${icon("wa")}WhatsApp</a>
        <a class="mbar__book" href="book.html">${icon("calendar")}Book</a>
      </nav>`;
    if (!body.hasAttribute("data-no-footer")) body.insertAdjacentHTML("beforeend", footer);
  }

  function fmtTime(hm) {
    const [h, m] = hm.split(":").map(Number);
    const ap = h >= 12 ? "PM" : "AM";
    const hh = ((h + 11) % 12) + 1;
    return `${hh}${m ? `:${String(m).padStart(2, "0")}` : ""} ${ap}`;
  }

  function nowIST() {
    const parts = new Intl.DateTimeFormat("en-GB", { timeZone: "Asia/Kolkata", weekday: "short", hour: "2-digit", minute: "2-digit", hourCycle: "h23" }).formatToParts(new Date());
    const p = Object.fromEntries(parts.map((x) => [x.type, x.value]));
    const day = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].indexOf(p.weekday);
    return { day, mins: Number(p.hour) * 60 + Number(p.minute) };
  }
  const toMins = (hm) => { const [h, m] = hm.split(":").map(Number); return h * 60 + m; };
  const hoursFor = (d) => (C.hours || []).find((h) => h.days.includes(d));

  function openStatus() {
    const { day, mins } = nowIST();
    const today = hoursFor(day);
    if (today && mins >= toMins(today.open) && mins < toMins(today.close)) return { open: true, text: `Open now · until ${fmtTime(today.close)}` };
    if (today && mins < toMins(today.open)) return { open: false, text: `Opens today at ${fmtTime(today.open)}` };
    for (let i = 1; i <= 7; i++) {
      const d = (day + i) % 7;
      const h = hoursFor(d);
      if (h) return { open: false, text: `Closed · opens ${i === 1 ? "tomorrow" : ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][d]} ${fmtTime(h.open)}` };
    }
    return { open: false, text: C.timingsShort };
  }

  function bindConfig() {
    $$("[data-cfg]").forEach((el) => { const v = get(el.dataset.cfg); if (v != null) el.textContent = v; });
    $$("[data-cfg-address]").forEach((el) => (el.textContent = fullAddress()));
    $$("[data-cfg-href]").forEach((el) => {
      const k = el.dataset.cfgHref;
      if (k === "tel") el.href = `tel:${C.phone}`;
      if (k === "wa") { el.href = waLink(el.dataset.waText || defaultWaText); el.target = "_blank"; el.rel = "noopener"; }
      if (k === "mail") el.href = `mailto:${C.email}`;
      if (k === "maps") { el.href = C.mapsLink; el.target = "_blank"; el.rel = "noopener"; }
    });
    $$("[data-year]").forEach((el) => (el.textContent = new Date().getFullYear()));
    const st = openStatus();
    $$("[data-open-status]").forEach((el) => (el.textContent = st.text));
    $$("[data-open-dot]").forEach((el) => el.classList.toggle("is-closed", !st.open));
    $$("[data-hours-table]").forEach((el) => {
      const { day } = nowIST();
      const names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
      el.innerHTML = `<tbody>${[1, 2, 3, 4, 5, 6, 0].map((d) => { const h = hoursFor(d); return `<tr class="${d === day ? "is-today" : ""}"><td>${names[d]}${d === day ? " · Today" : ""}</td><td>${h ? `${fmtTime(h.open)} – ${fmtTime(h.close)}` : "Closed"}</td></tr>`; }).join("")}</tbody>`;
    });
    $$("[data-treatments]").forEach((sel) => {
      const pre = sel.dataset.preselect || "";
      const opts = (C.treatments || []).map((t) => `<option value="${t.name}"${t.slug === pre ? " selected" : ""}>${t.name}</option>`).join("");
      sel.insertAdjacentHTML("beforeend", `${opts}<option value="General consultation">General consultation / Not sure</option><option value="Dental emergency">Dental emergency / Pain</option>`);
    });
    $$("[data-days]").forEach((sel) => {
      const fmt = new Intl.DateTimeFormat("en-IN", { weekday: "short", day: "numeric", month: "short" });
      const { day } = nowIST();
      let html = "";
      for (let i = 0; i < 10; i++) {
        const d = new Date(Date.now() + i * 864e5);
        const label = fmt.format(d);
        if (!hoursFor((day + i) % 7)) continue;
        html += `<option value="${label}">${i === 0 ? "Today · " : i === 1 ? "Tomorrow · " : ""}${label}</option>`;
      }
      sel.insertAdjacentHTML("beforeend", html);
    });
    $$('input[type="date"]').forEach((inp) => {
      const d = new Date();
      inp.min = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
    });
  }

  function mapEmbeds() {
    const els = $$("[data-map]");
    if (!els.length) return;
    const src = `https://maps.google.com/maps?q=${encodeURIComponent(C.mapEmbedQuery || fullAddress())}&t=m&z=15&ie=UTF8&iwloc=&output=embed`;
    const load = (el) => { if (el.dataset.loaded) return; el.dataset.loaded = "1"; el.innerHTML = `<a class="map-fallback" href="${C.mapsLink}" target="_blank" rel="noopener">${icon("pin")}<span>Open in Google Maps</span></a><iframe src="${src}" title="Map showing ${C.clinicName}, ${C.address.city}" loading="lazy" referrerpolicy="no-referrer-when-downgrade" allowfullscreen></iframe>`; };
    if (!("IntersectionObserver" in window)) return els.forEach(load);
    const io = new IntersectionObserver((en) => en.forEach((e) => { if (e.isIntersecting) { load(e.target); io.unobserve(e.target); } }), { rootMargin: "400px" });
    els.forEach((el) => io.observe(el));
  }

  function mediaFallback() {
    const fail = (img) => {
      const p = img.parentElement;
      const source = p && p.tagName === "PICTURE" ? p.querySelector("source") : null;
      if (source) { source.remove(); return; }
      img.classList.add("is-broken");
      const m = img.closest(".media, .hero__media");
      if (m) m.classList.add("is-missing");
    };
    doc.addEventListener("error", (e) => { if (e.target && e.target.tagName === "IMG") fail(e.target); }, true);
    $$("img").forEach((img) => { if (img.complete && img.naturalWidth === 0 && img.currentSrc) fail(img); });
  }

  function lazyVideos() {
    const vids = $$("video[data-lazy]");
    if (!vids.length) return;
    const saveData = navigator.connection && navigator.connection.saveData;
    const mobile = window.innerWidth < 768;
    const markMissing = (v) => { v.dataset.failed = "1"; v.classList.remove("is-playing"); const m = v.closest(".media"); if (m && !m.querySelector("img:not(.is-broken)")) m.classList.add("is-missing"); };
    const load = (v) => {
      if (v.dataset.loaded) return;
      v.dataset.loaded = "1";
      const sources = $$("source", v);
      sources.forEach((s) => { const src = (mobile && s.dataset.srcMobile) || s.dataset.src; if (src) s.src = src; });
      const last = sources[sources.length - 1];
      if (last) last.addEventListener("error", () => markMissing(v));
      v.addEventListener("playing", () => v.classList.add("is-playing"));
      v.load();
      if (v.hasAttribute("data-autoplay")) { const pr = v.play(); if (pr && pr.catch) pr.catch(() => {}); }
    };
    vids.forEach((v) => { v._load = () => load(v); });
    if (reduce || saveData) return;
    const io = new IntersectionObserver((en) => en.forEach((e) => {
      const v = e.target;
      if (e.isIntersecting) {
        load(v);
        if (v.hasAttribute("data-autoplay") && !v.dataset.failed) { const pr = v.play(); if (pr && pr.catch) pr.catch(() => {}); }
      } else if (v.dataset.loaded && !v.paused && v.hasAttribute("data-autoplay")) v.pause();
    }), { rootMargin: "200px 0px" });
    vids.filter((v) => !v.hasAttribute("data-manual")).forEach((v) => io.observe(v));
  }

  function doctorVideo() {
    const wrap = $("[data-doctor-video]");
    if (!wrap) return;
    const v = $("video", wrap);
    const btn = $(".doctor__play", wrap);
    if (!v) return;
    const play = () => { if (reduce) return; v._load && v._load(); if (v.dataset.failed) return; const p = v.play(); if (p && p.catch) p.catch(() => {}); };
    v.addEventListener("playing", () => { if (btn) btn.innerHTML = `${icon("check")} Playing`; });
    v.addEventListener("pause", () => { if (btn) btn.innerHTML = `${icon("play")} Watch intro`; });
    const lastSrc = v.querySelector("source:last-of-type");
    if (lastSrc) lastSrc.addEventListener("error", () => { if (btn) btn.hidden = true; });
    if (btn && lastSrc && lastSrc.dataset.src && location.protocol.startsWith("http")) {
      btn.hidden = true;
      fetch(lastSrc.dataset.src, { method: "HEAD" }).then((r) => { if (r.ok) btn.hidden = false; else v.dataset.failed = "1"; }).catch(() => { v.dataset.failed = "1"; });
    }
    const pause = () => v.pause();
    wrap.addEventListener("mouseenter", play);
    if (btn) btn.addEventListener("click", () => (v.paused ? play() : pause()));
    if (reduce) { if (btn) btn.hidden = true; return; }
    const io = new IntersectionObserver((en) => en.forEach((e) => (e.isIntersecting ? play() : pause())), { threshold: 0.55 });
    io.observe(wrap);
  }

  function tourVideo() {
    $$("[data-tour]").forEach((wrap) => {
      const v = $("video", wrap);
      const btn = $(".tour__play", wrap);
      if (!v || !btn) return;
      const label = $("span", btn);
      const unavailable = () => {
        wrap.classList.remove("is-playing");
        wrap.classList.add("is-unavailable");
        v.controls = false;
        if (label) label.innerHTML = `${icon("info")}Clinic tour video coming soon`;
        btn.disabled = true;
      };
      const srcs = $$("source", v);
      if (srcs.length) srcs[srcs.length - 1].addEventListener("error", unavailable);
      btn.addEventListener("click", () => {
        if (!v.dataset.loaded) {
          v.dataset.loaded = "1";
          srcs.forEach((s) => { if (s.dataset.src) s.src = s.dataset.src; });
          v.load();
        }
        v.controls = true;
        v.muted = false;
        wrap.classList.add("is-playing");
        const p = v.play();
        if (p && p.catch) p.catch(() => { v.muted = true; v.play().catch(() => {}); });
        v.focus();
      });
    });
  }

  let lenis = null;
  function smoothScroll() {
    if (reduce || typeof window.Lenis === "undefined") return;
    lenis = new Lenis({ lerp: 0.085, smoothWheel: true, wheelMultiplier: 0.95 });
    if (hasST) {
      lenis.on("scroll", ScrollTrigger.update);
      gsap.ticker.add((t) => lenis.raf(t * 1000));
      gsap.ticker.lagSmoothing(0);
    } else {
      const raf = (t) => { lenis.raf(t); requestAnimationFrame(raf); };
      requestAnimationFrame(raf);
    }
    doc.addEventListener("click", (e) => {
      const a = e.target.closest('a[href^="#"]');
      if (!a) return;
      const id = a.getAttribute("href");
      if (id.length < 2) return;
      const target = doc.querySelector(id);
      if (!target) return;
      e.preventDefault();
      lenis.scrollTo(target, { offset: -110, duration: 1.4 });
      if (id === "#main") target.focus({ preventScroll: true });
      history.replaceState(null, "", id);
    });
  }

  function headerBehaviour() {
    const chrome = $("[data-chrome]");
    if (!chrome) return;
    let lastY = window.scrollY;
    let ticking = false;
    const update = () => {
      const y = window.scrollY;
      const megaOpen = $(".has-mega.is-open");
      chrome.classList.toggle("is-scrolled", y > 24);
      if (y < 80) chrome.classList.remove("is-hidden", "is-compact");
      else if (y > lastY + 6 && !megaOpen && !body.classList.contains("menu-open")) chrome.classList.add("is-hidden");
      else if (y < lastY - 6) { chrome.classList.remove("is-hidden"); chrome.classList.add("is-compact"); }
      lastY = y;
      ticking = false;
    };
    window.addEventListener("scroll", () => { if (!ticking) { requestAnimationFrame(update); ticking = true; } }, { passive: true });
    chrome.addEventListener("focusin", () => chrome.classList.remove("is-hidden"));
    update();

    const li = $(".has-mega");
    if (li) {
      const btn = $("button", li);
      let t;
      const open = () => { clearTimeout(t); li.classList.add("is-open"); btn.setAttribute("aria-expanded", "true"); };
      const close = () => { li.classList.remove("is-open"); btn.setAttribute("aria-expanded", "false"); };
      if (finePointer) {
        li.addEventListener("mouseenter", open);
        li.addEventListener("mouseleave", () => { t = setTimeout(close, 160); });
      }
      btn.addEventListener("click", () => (li.classList.contains("is-open") ? close() : open()));
      li.addEventListener("focusout", (e) => { if (!li.contains(e.relatedTarget)) close(); });
      doc.addEventListener("keydown", (e) => { if (e.key === "Escape" && li.classList.contains("is-open")) { close(); btn.focus(); } });
      doc.addEventListener("click", (e) => { if (!li.contains(e.target)) close(); });
      const items = $$(".mega__item", li);
      const imgs = $$(".mega__img", li);
      const activate = (i) => { items.forEach((x, j) => x.classList.toggle("is-active", i === j)); imgs.forEach((x, j) => x.classList.toggle("is-active", i === j)); };
      items.forEach((it, i) => { it.addEventListener("mouseenter", () => activate(i)); it.addEventListener("focusin", () => activate(i)); });
    }

    const burger = $(".burger");
    const mnav = $("#mnav");
    if (burger && mnav) {
      mnav.inert = true;
      const set = (on) => {
        body.classList.toggle("menu-open", on);
        burger.setAttribute("aria-expanded", String(on));
        burger.setAttribute("aria-label", on ? "Close menu" : "Open menu");
        mnav.inert = !on;
        if (lenis) on ? lenis.stop() : lenis.start();
        body.style.overflow = on ? "hidden" : "";
      };
      burger.addEventListener("click", () => set(!body.classList.contains("menu-open")));
      doc.addEventListener("keydown", (e) => { if (e.key === "Escape" && body.classList.contains("menu-open")) { set(false); burger.focus(); } });
      $$("a", mnav).forEach((a) => a.addEventListener("click", () => set(false)));
      window.addEventListener("resize", () => { if (window.innerWidth >= 1024 && body.classList.contains("menu-open")) set(false); });
    }
  }

  function reveals() {
    $$("[data-stagger]").forEach((wrap) => {
      const step = parseFloat(wrap.dataset.stagger) || 0.08;
      Array.from(wrap.children).forEach((c, i) => { if (!c.hasAttribute("data-reveal")) c.setAttribute("data-reveal", ""); c.style.setProperty("--d", `${(i * step).toFixed(2)}s`); });
    });
    const els = $$("[data-reveal]");
    if (reduce || !("IntersectionObserver" in window)) return;
    root.classList.add("reveal-ready");
    const io = new IntersectionObserver((en) => en.forEach((e) => { if (e.isIntersecting) { e.target.classList.add("is-in"); io.unobserve(e.target); } }), { threshold: 0.12, rootMargin: "0px 0px -6% 0px" });
    els.forEach((el) => io.observe(el));
  }

  function counters() {
    const els = $$("[data-count]");
    if (!els.length) return;
    const fmt = (el, v) => {
      const dec = parseInt(el.dataset.decimals || "0", 10);
      return dec ? v.toFixed(dec) : Math.round(v).toLocaleString("en-IN");
    };
    if (reduce || !("IntersectionObserver" in window)) return;
    els.forEach((el) => { el.dataset.final = el.textContent; el.textContent = fmt(el, 0); });
    const run = (el) => {
      const target = parseFloat(el.dataset.count);
      const dur = 2200;
      const t0 = performance.now();
      const tick = (now) => {
        const t = Math.min((now - t0) / dur, 1);
        const e = 1 - Math.pow(1 - t, 4);
        el.textContent = fmt(el, target * e);
        if (t < 1) requestAnimationFrame(tick);
        else el.textContent = el.dataset.final;
      };
      requestAnimationFrame(tick);
    };
    const io = new IntersectionObserver((en) => en.forEach((e) => { if (e.isIntersecting) { run(e.target); io.unobserve(e.target); } }), { threshold: 0.6 });
    els.forEach((el) => io.observe(el));
  }

  function tilt() {
    if (reduce || !finePointer || typeof window.VanillaTilt === "undefined") return;
    const els = $$("[data-tilt]");
    if (els.length) VanillaTilt.init(els, { max: 6, speed: 1400, perspective: 1400, scale: 1.015, glare: true, "max-glare": 0.18, easing: "cubic-bezier(0.16, 1, 0.3, 1)", gyroscope: false });
  }

  function pinnedSteps() {
    const sec = $("[data-steps]");
    if (!sec || !hasST || reduce) return;
    const track = $(".steps__track", sec);
    const bar = $(".steps__progress i", sec);
    const mm = gsap.matchMedia();
    mm.add("(min-width: 1024px)", () => {
      sec.classList.add("is-pinned");
      const dist = () => Math.max(0, track.scrollWidth - doc.documentElement.clientWidth);
      const tw = gsap.to(track, {
        x: () => -dist(),
        ease: "none",
        scrollTrigger: {
          trigger: sec, start: "top top", end: () => `+=${dist()}`, pin: true, scrub: 1, invalidateOnRefresh: true, anticipatePin: 1,
          onUpdate: (s) => { if (bar) bar.style.transform = `scaleX(${s.progress})`; }
        }
      });
      return () => { tw.scrollTrigger && tw.scrollTrigger.kill(); tw.kill(); gsap.set(track, { clearProps: "transform" }); sec.classList.remove("is-pinned"); };
    });
  }

  function parallax() {
    if (!hasST || reduce) return;
    $$("[data-parallax]").forEach((el) => {
      const amt = parseFloat(el.dataset.parallax) || 8;
      gsap.fromTo(el, { yPercent: -amt }, { yPercent: amt, ease: "none", scrollTrigger: { trigger: el.parentElement, start: "top bottom", end: "bottom top", scrub: true } });
    });
  }

  function fan() {
    $$("[data-fan]").forEach((f) => {
      const cards = $$(".fan__card", f);
      const open = () => f.classList.add("is-open");
      if (reduce || !("IntersectionObserver" in window)) open();
      else {
        const io = new IntersectionObserver((en) => en.forEach((e) => { if (e.isIntersecting) { setTimeout(open, 250); io.disconnect(); } }), { threshold: 0.35 });
        io.observe(f);
      }
      cards.forEach((c) => c.addEventListener("click", () => {
        const p = Number(c.dataset.pos);
        if (p === 0) { const n = cards.find((x) => x.dataset.pos === "1"); return n && n.click(); }
        cards.forEach((x) => { const q = Number(x.dataset.pos); x.dataset.pos = String(q === p ? 0 : q === 0 ? p : q); });
        cards.forEach((x) => x.setAttribute("aria-pressed", x.dataset.pos === "0" ? "true" : "false"));
      }));
    });
  }

  function compare() {
    $$("[data-compare]").forEach((c) => {
      const r = $(".compare__range", c);
      if (!r) return;
      const set = () => c.style.setProperty("--p", r.value);
      r.addEventListener("input", set);
      set();
    });
  }

  function checklistStore() {
    $$("[data-checklist]").forEach((list) => {
      const key = `bs-check-${list.dataset.checklist}`;
      const boxes = $$('input[type="checkbox"]', list);
      const bar = $(`[data-progress="${list.dataset.checklist}"] i`);
      let saved = [];
      try { saved = JSON.parse(localStorage.getItem(key) || "[]"); } catch (e) { saved = []; }
      boxes.forEach((b, i) => { b.checked = saved.includes(i); });
      const upd = () => {
        const on = boxes.map((b, i) => (b.checked ? i : -1)).filter((i) => i > -1);
        try { localStorage.setItem(key, JSON.stringify(on)); } catch (e) {}
        if (bar) bar.style.setProperty("--v", boxes.length ? on.length / boxes.length : 0);
      };
      boxes.forEach((b) => b.addEventListener("change", upd));
      upd();
    });
  }

  function subnav() {
    const nav = $("[data-subnav]");
    if (!nav) return;
    const links = $$("a", nav);
    const map = new Map(links.map((a) => [a.getAttribute("href").slice(1), a]));
    const io = new IntersectionObserver((en) => en.forEach((e) => {
      if (e.isIntersecting) { links.forEach((l) => l.classList.remove("is-active")); const a = map.get(e.target.id); if (a) a.classList.add("is-active"); }
    }), { rootMargin: "-45% 0px -50% 0px" });
    map.forEach((_, id) => { const s = doc.getElementById(id); if (s) io.observe(s); });
  }

  function forms() {
    $$("form[data-wa-form]").forEach((form) => {
      const wrap = form.closest(".form-wrap") || form.parentElement;
      const success = wrap.querySelector(".form-success");
      const msg = (name, text) => {
        const f = form.querySelector(`[name="${name}"]`);
        const field = f && f.closest(".field, .slots");
        if (!field) return;
        field.classList.toggle("is-invalid", !!text);
        let err = field.querySelector(".field__error");
        if (!err) { err = doc.createElement("span"); err.className = "field__error"; err.id = `${form.id || "f"}-${name}-err`; field.appendChild(err); }
        err.textContent = text || "";
        if (f) { f.setAttribute("aria-invalid", text ? "true" : "false"); if (text) f.setAttribute("aria-describedby", err.id); }
      };
      const val = (n) => { const el = form.elements[n]; if (!el) return ""; if (el instanceof RadioNodeList) return el.value || ""; return (el.value || "").trim(); };
      const has = (n) => !!form.elements[n];
      const validate = () => {
        let ok = true;
        const name = val("name");
        if (has("name")) { if (name.length < 2) { msg("name", "Please enter your name."); ok = false; } else msg("name"); }
        if (has("phone")) {
          const digits = val("phone").replace(/\D/g, "");
          const valid = /^[6-9]\d{9}$/.test(digits) || /^91[6-9]\d{9}$/.test(digits) || /^0[6-9]\d{9}$/.test(digits);
          if (!valid) { msg("phone", "Enter a valid 10-digit mobile number."); ok = false; } else msg("phone");
        }
        if (has("treatment")) { if (!val("treatment")) { msg("treatment", "Choose a treatment, or ‘Not sure’."); ok = false; } else msg("treatment"); }
        if (has("date") && form.elements.date.required) {
          const d = val("date");
          if (!d) { msg("date", "Pick a preferred date."); ok = false; }
          else if (form.elements.date.type === "date" && form.elements.date.min && d < form.elements.date.min) { msg("date", "Please choose today or a later date."); ok = false; }
          else msg("date");
        }
        if (has("slot") && form.querySelector('[name="slot"][required]')) { if (!val("slot")) { msg("slot", "Choose a time of day."); ok = false; } else msg("slot"); }
        return ok;
      };
      form.addEventListener("input", (e) => { const f = e.target.closest(".field, .slots"); if (f && f.classList.contains("is-invalid")) validate(); });
      form.addEventListener("submit", (e) => {
        e.preventDefault();
        if (!validate()) { const bad = form.querySelector('[aria-invalid="true"]'); if (bad) bad.focus(); return; }
        let date = val("date");
        if (date && form.elements.date.type === "date") {
          const [y, m, d] = date.split("-").map(Number);
          date = new Intl.DateTimeFormat("en-IN", { weekday: "short", day: "numeric", month: "short", year: "numeric" }).format(new Date(y, m - 1, d));
        }
        const lines = [
          `Hi ${C.clinicName}, ${form.dataset.waIntro || "I'd like to book an appointment."}`,
          "",
          `Name: ${val("name")}`,
          `Phone: ${val("phone")}`
        ];
        if (has("treatment")) lines.push(`Treatment: ${val("treatment")}`);
        if (date) lines.push(`Date: ${date}`);
        if (has("slot") && val("slot")) lines.push(`Time: ${val("slot")}`);
        if (val("message")) lines.push(`Message: ${val("message")}`);
        const url = waLink(lines.join("\n"));
        window.__lastWhatsAppURL = url;
        window.open(url, "_blank", "noopener");
        if (success) {
          const again = success.querySelector("[data-wa-again]");
          if (again) again.href = url;
          const who = success.querySelector("[data-success-name]");
          if (who) who.textContent = val("name").split(" ")[0];
          wrap.classList.add("is-sent");
          const h = success.querySelector("h3, [tabindex]");
          if (h) { h.setAttribute("tabindex", "-1"); h.focus({ preventScroll: true }); }
        }
      });
      const reset = wrap.querySelector("[data-form-reset]");
      if (reset) reset.addEventListener("click", () => { form.reset(); wrap.classList.remove("is-sent"); const f = form.querySelector("input, select"); if (f) f.focus(); });
    });
  }

  function calEmbed() {
    const wrap = $("[data-cal-wrap]");
    if (!wrap) return;
    const link = (C.calLink || "").trim().replace(/^https?:\/\/(app\.)?cal\.com\//, "");
    if (!link) { wrap.hidden = true; body.classList.add("no-cal"); return; }
    wrap.hidden = false;
    (function (W, A, L) {
      const p = (a, ar) => a.q.push(ar);
      const d = W.document;
      W.Cal = W.Cal || function () {
        const cal = W.Cal; const ar = arguments;
        if (!cal.loaded) { cal.ns = {}; cal.q = cal.q || []; d.head.appendChild(d.createElement("script")).src = A; cal.loaded = true; }
        if (ar[0] === L) { const api = function () { p(api, arguments); }; const ns = ar[1]; api.q = api.q || []; if (typeof ns === "string") { cal.ns[ns] = cal.ns[ns] || api; p(cal.ns[ns], ar); p(cal, ["initNamespace", ns]); } else p(cal, ar); return; }
        p(cal, ar);
      };
    })(window, "https://app.cal.com/embed/embed.js", "init");
    window.Cal("init", { origin: "https://cal.com" });
    window.Cal("inline", { elementOrSelector: "#cal-inline", calLink: link, layout: "month_view" });
    window.Cal("ui", { theme: "light", styles: { branding: { brandColor: "#1f5a63" } }, hideEventTypeDetails: false, layout: "month_view" });
  }

  function schema() {
    const a = C.address;
    const dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
    const short = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"];
    const ohShort = (C.hours || []).map((h) => { const ds = h.days.slice().sort((x, y) => ((x + 6) % 7) - ((y + 6) % 7)); const range = ds.length > 1 ? `${short[ds[0]]}-${short[ds[ds.length - 1]]}` : short[ds[0]]; return `${range} ${h.open}-${h.close}`; });
    const clinic = {
      "@context": "https://schema.org",
      "@type": ["Dentist", "MedicalClinic"],
      "@id": `${C.siteUrl}/#clinic`,
      name: C.clinicName,
      url: `${C.siteUrl}/`,
      image: `${C.siteUrl}/assets/og-image.jpg`,
      logo: `${C.siteUrl}/assets/favicon.svg`,
      telephone: C.phone,
      email: C.email,
      priceRange: C.priceRange,
      currenciesAccepted: "INR",
      paymentAccepted: "Cash, UPI, Credit Card, Debit Card, EMI",
      address: { "@type": "PostalAddress", streetAddress: `${a.line1}, ${a.line2}`, addressLocality: a.city, addressRegion: a.state, postalCode: a.pin, addressCountry: a.country },
      geo: { "@type": "GeoCoordinates", latitude: C.geo.lat, longitude: C.geo.lng },
      hasMap: C.mapsLink,
      openingHours: ohShort,
      openingHoursSpecification: (C.hours || []).map((h) => ({ "@type": "OpeningHoursSpecification", dayOfWeek: h.days.map((d) => dayNames[d]), opens: h.open, closes: h.close })),
      areaServed: [{ "@type": "City", name: a.city }, { "@type": "State", name: a.state }],
      founder: { "@type": "Person", name: C.doctorName, jobTitle: `Dentist, ${C.doctorTitle}` },
      sameAs: Object.values(C.social || {}).filter(Boolean),
      availableService: (C.treatments || []).map((t) => ({ "@type": "MedicalProcedure", name: t.name, url: `${C.siteUrl}/${t.slug}.html` }))
    };
    const add = (obj) => { const s = doc.createElement("script"); s.type = "application/ld+json"; s.textContent = JSON.stringify(obj); doc.head.appendChild(s); };
    add(clinic);
    const faqs = $$("[data-faq-schema] details");
    if (faqs.length) add({ "@context": "https://schema.org", "@type": "FAQPage", mainEntity: faqs.map((d) => ({ "@type": "Question", name: $(".accordion__q", d).textContent.trim(), acceptedAnswer: { "@type": "Answer", text: $(".accordion__body", d).textContent.trim().replace(/\s+/g, " ") } })) });
    const crumbs = $$(".crumbs a, .crumbs [aria-current]");
    if (crumbs.length) add({ "@context": "https://schema.org", "@type": "BreadcrumbList", itemListElement: crumbs.map((c, i) => ({ "@type": "ListItem", position: i + 1, name: c.textContent.trim(), item: c.href ? c.href : location.href })) });
  }

  function cursor() {
    if (reduce || !finePointer) return;
    const dot = doc.createElement("div");
    dot.className = "cursor";
    dot.setAttribute("aria-hidden", "true");
    body.appendChild(dot);
    let x = -100, y = -100, cx = -100, cy = -100, raf = null;
    const loop = () => {
      cx += (x - cx) * 0.16; cy += (y - cy) * 0.16;
      dot.style.transform = `translate3d(${cx}px, ${cy}px, 0)`;
      raf = Math.abs(x - cx) + Math.abs(y - cy) > 0.1 ? requestAnimationFrame(loop) : null;
    };
    doc.addEventListener("mousemove", (e) => { x = e.clientX; y = e.clientY; dot.classList.add("is-visible"); if (!raf) raf = requestAnimationFrame(loop); }, { passive: true });
    doc.addEventListener("mouseleave", () => dot.classList.remove("is-visible"));
    doc.addEventListener("mouseover", (e) => { dot.classList.toggle("is-hover", !!e.target.closest("a, button, summary, label, select, [data-cursor], .fan__card, .compare")); });
  }

  function magnetic() {
    if (reduce || !finePointer) return;
    $$("[data-magnetic]").forEach((el) => {
      const label = $(".btn__label", el);
      const move = (e) => {
        const r = el.getBoundingClientRect();
        const dx = e.clientX - (r.left + r.width / 2);
        const dy = e.clientY - (r.top + r.height / 2);
        el.style.transform = `translate3d(${dx * 0.22}px, ${dy * 0.32}px, 0)`;
        if (label) label.style.transform = `translate3d(${dx * 0.1}px, ${dy * 0.14}px, 0)`;
      };
      el.addEventListener("mousemove", move);
      el.addEventListener("mouseleave", () => { el.style.transform = ""; if (label) label.style.transform = ""; });
    });
  }

  function printButtons() {
    $$("[data-print]").forEach((b) => b.addEventListener("click", () => window.print()));
  }

  function waHint() {
    const w = $(".wa-float");
    if (!w || reduce) return;
    setTimeout(() => { w.classList.add("is-hinting"); setTimeout(() => w.classList.remove("is-hinting"), 4200); }, 6000);
  }

  function heroIntro() {
    const hero = $("[data-hero-root]");
    const pre = $(".preloader");
    const done = () => { if (pre) pre.remove(); if (hasST) ScrollTrigger.refresh(); };
    if (!hero) { if (pre) pre.remove(); return; }
    if (reduce || !hasGsap) { if (pre) { pre.style.transition = "opacity .4s"; pre.style.opacity = "0"; setTimeout(done, 450); } return; }

    let words = [];
    if (typeof window.SplitType !== "undefined") {
      $$(".hero__title .line__inner").forEach((el) => { const s = new SplitType(el, { types: "words", tagName: "span" }); words = words.concat(s.words || []); });
    }
    const items = $$("[data-hero-item]", hero);
    const tl = gsap.timeline({ paused: true, defaults: { ease: "expo.out" } });
    if (words.length) tl.from(words, { yPercent: 115, rotate: 3, duration: 1.5, stagger: 0.07 }, 0);
    tl.from(items, { y: 26, opacity: 0, duration: 1.4, stagger: 0.09 }, 0.25);
    const card = $(".hero__aside .glass-card", hero);
    if (card) tl.from(card, { y: 40, opacity: 0, duration: 1.6 }, 0.35);
    const stats = $(".stats-band");
    if (stats) tl.from(stats, { y: 30, opacity: 0, duration: 1.4 }, 0.6);

    const first = (() => { try { return !sessionStorage.getItem("bs-visited"); } catch (e) { return true; } })();
    try { sessionStorage.setItem("bs-visited", "1"); } catch (e) {}
    const start = () => {
      if (!pre) { tl.play(); return done(); }
      const bar = $(".preloader__bar i", pre);
      if (bar) bar.style.animationDuration = first ? "0.6s" : "0.25s";
      gsap.timeline({ onComplete: done })
        .to(pre, { yPercent: -100, duration: first ? 0.75 : 0.55, ease: "expo.inOut", delay: first ? 0.35 : 0.08 })
        .add(() => tl.play(), "-=0.45");
    };
    const fontsReady = doc.fonts && doc.fonts.ready ? Promise.race([doc.fonts.ready, new Promise((r) => setTimeout(r, first ? 350 : 120))]) : Promise.resolve();
    fontsReady.then(start);
  }

  function loadPearl() {
    const el = $("[data-pearl]");
    if (!el || reduce || !finePointer || window.innerWidth < 1024) return;
    const cv = doc.createElement("canvas");
    if (!(cv.getContext("webgl2") || cv.getContext("webgl"))) return;
    const go = () => {
      const s = doc.createElement("script");
      s.src = "https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js";
      s.async = true;
      s.onload = () => { const p = doc.createElement("script"); p.src = "js/pearl.js"; p.async = true; p.onload = () => window.initPearl && window.initPearl(el); doc.head.appendChild(p); };
      doc.head.appendChild(s);
    };
    const idle = () => ("requestIdleCallback" in window ? requestIdleCallback(go, { timeout: 2000 }) : setTimeout(go, 600));
    if (doc.readyState === "complete") idle(); else window.addEventListener("load", idle, { once: true });
  }

  renderChrome();
  mediaFallback();
  bindConfig();
  mapEmbeds();
  smoothScroll();
  headerBehaviour();
  reveals();
  counters();
  lazyVideos();
  doctorVideo();
  tourVideo();
  fan();
  compare();
  checklistStore();
  subnav();
  forms();
  calEmbed();
  schema();
  cursor();
  magnetic();
  printButtons();
  waHint();
  heroIntro();
  pinnedSteps();
  parallax();
  tilt();
  loadPearl();
  if (hasST) window.addEventListener("load", () => ScrollTrigger.refresh());
})();
