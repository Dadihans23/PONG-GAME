// Page d'accueil : petits compléments, sans dépendance.
// 1. Le terrain du héros (animé en CSS) se met en pause quand il sort de l'écran.
// 2. La rangée de captures devient focalisable au clavier seulement quand elle défile.
// 3. FAQ : une question visée par une ancre (#internet, lien du pied de page…) s'ouvre.
(function () {
  "use strict";

  var court = document.querySelector(".court");
  if (court && "IntersectionObserver" in window) {
    new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        court.classList.toggle("is-paused", !entry.isIntersecting);
      });
    }).observe(court);
  }

  var shots = document.querySelector(".shots__list");
  if (shots) {
    var update = function () {
      if (shots.scrollWidth > shots.clientWidth + 1) {
        shots.setAttribute("tabindex", "0");
      } else {
        shots.removeAttribute("tabindex");
      }
    };
    update();
    window.addEventListener("resize", update, { passive: true });
  }

  function openFromHash() {
    var id;
    try {
      id = decodeURIComponent(window.location.hash.slice(1));
    } catch (e) {
      return;
    }
    if (!id) {
      return;
    }
    var target = document.getElementById(id);
    if (!target || target.tagName !== "DETAILS" || !target.classList.contains("faq__item")) {
      return;
    }
    target.open = true;
    var summary = target.querySelector("summary");
    var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    target.scrollIntoView({ block: "start", behavior: reduce ? "auto" : "smooth" });
    if (summary) {
      summary.focus({ preventScroll: true });
    }
  }

  openFromHash();
  window.addEventListener("hashchange", openFromHash);
})();
