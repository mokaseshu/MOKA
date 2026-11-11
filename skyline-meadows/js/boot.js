(function () {
  var d = document.documentElement;
  d.classList.add("js");
  try {
    var still = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (!still && !window.sessionStorage.getItem("sm-intro")) d.classList.add("is-preloading");
  } catch (e) {}
})();
