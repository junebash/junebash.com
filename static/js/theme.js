// Three-way theme preference: "light" | "dark" | "system".
// "system" follows the OS prefers-color-scheme and tracks live changes.
// Replaces Apollo's two-state themetoggle.js (loaded only in `toggle` mode).
(function () {
  var KEY = "theme-storage";
  var ORDER = ["light", "dark", "system"];
  var media = window.matchMedia("(prefers-color-scheme: dark)");

  function getPref() {
    var p = localStorage.getItem(KEY);
    return p === "light" || p === "dark" || p === "system" ? p : "system";
  }

  // Resolve a preference to the concrete theme actually shown.
  function resolve(pref) {
    if (pref === "light" || pref === "dark") return pref;
    return media.matches ? "dark" : "light";
  }

  function apply() {
    var pref = getPref();
    var effective = resolve(pref);

    var html = document.documentElement;
    html.classList.remove("light", "dark");
    html.classList.add(effective);

    var darkSheet = document.getElementById("darkModeStyle");
    if (darkSheet) darkSheet.disabled = effective === "light";

    updateIcons(pref);
  }

  function updateIcons(pref) {
    ["light", "dark", "system"].forEach(function (name) {
      var el = document.getElementById("theme-icon-" + name);
      if (el) el.style.display = name === pref ? "inline-block" : "none";
    });
    var btn = document.getElementById("theme-toggle-btn");
    if (btn) {
      btn.setAttribute("aria-label", "Theme: " + pref + " (click to change)");
      btn.setAttribute("title", "Theme: " + pref);
    }
  }

  function toggleTheme() {
    var next = ORDER[(ORDER.indexOf(getPref()) + 1) % ORDER.length];
    localStorage.setItem(KEY, next);
    apply();
  }

  // Keep Apollo-compatible globals so existing markup keeps working.
  window.setTheme = function (mode) { localStorage.setItem(KEY, mode); apply(); };
  window.getSavedTheme = getPref;
  window.toggleTheme = toggleTheme;
  window.updateItemToggleTheme = apply;

  // React to OS theme changes while on "system".
  var onMediaChange = function () { if (getPref() === "system") apply(); };
  if (media.addEventListener) media.addEventListener("change", onMediaChange);
  else if (media.addListener) media.addListener(onMediaChange);

  // Apply immediately (before paint) for the <html> class, then again once the
  // nav button exists so the correct icon is shown.
  apply();
  document.addEventListener("DOMContentLoaded", apply);
})();
