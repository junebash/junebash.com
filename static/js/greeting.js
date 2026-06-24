// greeting.js — random per-visit homepage greeting for junebash.com
// Usage: give the hero headline element id="greeting" (or [data-greeting]) and a
// sensible default text in the template. This swaps it on load.
(function () {
  var greetings = [
    "Oh, hey. I'm June.",
    "'Sup. I'm June.",
    "Hi! I'm June!",
    "Greetings! I'm June.",
    "Howdy! I'm June.",
    "Yo. I'm June.",
    function () {
      var h = new Date().getHours();
      var t = h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening";
      return t + "! I'm June.";
    }
  ];

  function pickGreeting() {
    var g = greetings[Math.floor(Math.random() * greetings.length)];
    return typeof g === "function" ? g() : g;
  }

  function apply() {
    var els = document.querySelectorAll("#greeting, [data-greeting]");
    if (!els.length) return;
    var text = pickGreeting();
    els.forEach(function (el) { el.textContent = text; });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", apply);
  } else {
    apply();
  }
})();
