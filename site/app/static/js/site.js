// Page d'accueil : deux petits compléments, sans dépendance.
// 1. Le terrain du héros (animé en CSS) se met en pause quand il sort de l'écran.
// 2. La rangée de captures devient focalisable au clavier seulement quand elle défile.
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
})();
