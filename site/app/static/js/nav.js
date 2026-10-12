// Menu des petits écrans (élément <details> de l'en-tête).
// Sans ce script, le menu s'ouvre et se ferme quand même au toucher ; ici on le referme
// après le choix d'un lien, avec Échap, ou quand on touche ailleurs sur la page.
(function () {
  "use strict";

  var menu = document.querySelector(".menu");
  if (!menu) {
    return;
  }
  var button = menu.querySelector("summary");

  function close(focusButton) {
    if (!menu.open) {
      return;
    }
    menu.open = false;
    if (focusButton && button) {
      button.focus();
    }
  }

  function sync() {
    if (button) {
      button.setAttribute("aria-label", menu.open ? "Fermer le menu" : "Menu");
    }
  }

  menu.addEventListener("toggle", sync);
  sync();

  menu.addEventListener("click", function (event) {
    if (event.target.closest && event.target.closest("a")) {
      close(false);
    }
  });

  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape" && menu.open) {
      close(true);
    }
  });

  document.addEventListener("click", function (event) {
    if (menu.open && !menu.contains(event.target)) {
      close(false);
    }
  });

  // Passage au format ordinateur : le menu n'a plus lieu d'être ouvert.
  if (window.matchMedia) {
    var wide = window.matchMedia("(min-width: 1180px)");
    var onWide = function () {
      if (wide.matches) {
        close(false);
      }
    };
    if (wide.addEventListener) {
      wide.addEventListener("change", onWide);
    } else if (wide.addListener) {
      wide.addListener(onWide);
    }
  }
})();

// Pastille « active » de la navigation : la section de l'accueil en cours de lecture.
// Amélioration progressive : sans script (ou hors de l'accueil), aucun lien n'est allumé.
(function () {
  "use strict";

  var links = document.querySelectorAll("[data-section]");
  var sections = [];
  var seen = {};
  for (var i = 0; i < links.length; i++) {
    var id = links[i].getAttribute("data-section");
    var el = seen[id] === undefined ? document.getElementById(id) : null;
    if (el) {
      seen[id] = true;
      sections.push(el);
    }
  }
  if (!sections.length) {
    return;
  }
  var bar = document.querySelector(".topbar");
  var current = null;
  var queued = false;

  function update() {
    queued = false;
    var line = (bar ? bar.getBoundingClientRect().bottom : 0) + window.innerHeight * 0.3;
    // Avant la première section (le héros), la première pastille est allumée, comme la maquette.
    var active = sections[0].id;
    for (var j = 0; j < sections.length; j++) {
      if (sections[j].getBoundingClientRect().top <= line) {
        active = sections[j].id;
      }
    }
    if (active === current) {
      return;
    }
    current = active;
    for (var k = 0; k < links.length; k++) {
      var on = links[k].getAttribute("data-section") === active;
      links[k].classList.toggle("is-active", on);
      if (on) {
        links[k].setAttribute("aria-current", "true");
      } else {
        links[k].removeAttribute("aria-current");
      }
    }
  }

  function queue() {
    if (!queued) {
      queued = true;
      window.requestAnimationFrame(update);
    }
  }

  window.addEventListener("scroll", queue, { passive: true });
  window.addEventListener("resize", queue, { passive: true });
  update();
})();
