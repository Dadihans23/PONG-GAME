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
    var wide = window.matchMedia("(min-width: 1024px)");
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
