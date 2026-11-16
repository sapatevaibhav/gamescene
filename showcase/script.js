// Theme (system, light, dark), the phone menu and the style tabs. No network, no tracking.
(function () {
  var root = document.documentElement;
  var ORDER = ["system", "light", "dark"];
  var ICONS = {
    system: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="4" width="18" height="12" rx="2"/><path d="M8 20h8M12 16v4"/></svg>',
    light: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>',
    dark: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"/></svg>'
  };

  function saved() {
    try { return localStorage.getItem("theme") || "system"; } catch (e) { return "system"; }
  }
  function apply(mode) {
    if (mode === "system") root.removeAttribute("data-theme");
    else root.setAttribute("data-theme", mode);
    var b = document.querySelector("[data-theme-btn]");
    if (b) {
      b.innerHTML = ICONS[mode];
      b.setAttribute("aria-label", "Theme: " + mode + ". Change theme");
      b.title = "Theme: " + mode;
    }
  }
  var mode = saved();
  if (ORDER.indexOf(mode) < 0) mode = "system";
  apply(mode);

  document.addEventListener("click", function (e) {
    var t = e.target.closest("[data-theme-btn]");
    if (t) {
      mode = ORDER[(ORDER.indexOf(mode) + 1) % ORDER.length];
      try { localStorage.setItem("theme", mode); } catch (err) {}
      apply(mode);
      return;
    }
    var m = e.target.closest("[data-menu-btn]");
    var links = document.getElementById("nav-links");
    if (m && links) {
      var open = links.classList.toggle("open");
      m.setAttribute("aria-expanded", open ? "true" : "false");
      document.body.style.overflow = open ? "hidden" : "";
      return;
    }
    if (links && links.classList.contains("open") && e.target.closest("#nav-links a")) {
      links.classList.remove("open");
      document.body.style.overflow = "";
      var mb = document.querySelector("[data-menu-btn]");
      if (mb) mb.setAttribute("aria-expanded", "false");
    }
    var tab = e.target.closest("[role=tab]");
    if (tab) pick(tab);
  });

  function pick(tab) {
    var list = tab.closest("[role=tablist]");
    list.querySelectorAll("[role=tab]").forEach(function (t) {
      var on = t === tab;
      t.setAttribute("aria-selected", on ? "true" : "false");
      t.tabIndex = on ? 0 : -1;
      var panel = document.getElementById(t.getAttribute("aria-controls"));
      if (panel) panel.hidden = !on;
    });
  }
  document.addEventListener("keydown", function (e) {
    var tab = e.target.closest && e.target.closest("[role=tab]");
    if (!tab) return;
    var tabs = Array.prototype.slice.call(tab.closest("[role=tablist]").querySelectorAll("[role=tab]"));
    var i = tabs.indexOf(tab);
    var n = -1;
    if (e.key === "ArrowDown" || e.key === "ArrowRight") n = (i + 1) % tabs.length;
    if (e.key === "ArrowUp" || e.key === "ArrowLeft") n = (i - 1 + tabs.length) % tabs.length;
    if (n < 0) return;
    e.preventDefault();
    tabs[n].focus();
    pick(tabs[n]);
  });
  // Screenshots open in a popup (close button, Esc, click outside, arrows).
  var lb, lbImg, lbCount, shots = [], at = 0;
  var X = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M6 6l12 12M18 6L6 18"/></svg>';
  var L = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M15 5l-7 7 7 7"/></svg>';
  var R = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 5l7 7-7 7"/></svg>';

  function buildLightbox() {
    lb = document.createElement("dialog");
    lb.className = "lightbox";
    lb.setAttribute("aria-label", "Screenshot");
    lb.innerHTML = '<span class="lightbox-count" aria-live="polite"></span>' +
      '<button type="button" class="lightbox-close" aria-label="Close the screenshot" autofocus>' + X + '</button>' +
      '<button type="button" class="lightbox-prev" aria-label="Previous screenshot">' + L + '</button>' +
      '<img alt="">' +
      '<button type="button" class="lightbox-next" aria-label="Next screenshot">' + R + '</button>';
    document.body.appendChild(lb);
    lbImg = lb.querySelector("img");
    lbCount = lb.querySelector(".lightbox-count");
    lb.addEventListener("click", function (e) {
      if (e.target.closest(".lightbox-prev")) return show(at - 1);
      if (e.target.closest(".lightbox-next")) return show(at + 1);
      // The close button, or anywhere that isn't the picture.
      if (e.target !== lbImg) lb.close();
    });
    lb.addEventListener("keydown", function (e) {
      if (e.key === "ArrowLeft") show(at - 1);
      if (e.key === "ArrowRight") show(at + 1);
    });
    lb.addEventListener("close", function () {
      document.body.style.overflow = "";
      if (shots[at]) shots[at].focus();
    });
  }
  function show(i) {
    at = (i + shots.length) % shots.length;
    var img = shots[at].querySelector("img");
    lbImg.src = shots[at].getAttribute("href");
    lbImg.alt = img ? img.alt : "";
    lbCount.textContent = shots.length > 1 ? (at + 1) + " / " + shots.length : "";
    var many = shots.length > 1;
    lb.querySelector(".lightbox-prev").hidden = !many;
    lb.querySelector(".lightbox-next").hidden = !many;
  }
  document.addEventListener("click", function (e) {
    var a = e.target.closest("a.shot");
    if (!a || e.metaKey || e.ctrlKey || e.shiftKey || e.button) return;
    if (!window.HTMLDialogElement) return; // old browsers: the link opens the picture
    e.preventDefault();
    if (!lb) buildLightbox();
    // Only the pictures on show (not the hidden style tabs).
    shots = Array.prototype.filter.call(document.querySelectorAll("a.shot"), function (s) { return s.offsetParent !== null; });
    document.body.style.overflow = "hidden";
    lb.showModal();
    show(Math.max(0, shots.indexOf(a)));
  });
})();
