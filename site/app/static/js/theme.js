// Thème clair / sombre. Chargé SANS defer dans le <head>, avant la feuille de style :
// data-theme est posé sur <html> avant le premier rendu, donc aucun flash de mauvais thème.
// Sans ce script, le CSS suit simplement prefers-color-scheme et le bouton reste caché.
(function () {
  "use strict";

  var root = document.documentElement;
  var KEY = "tilto-theme";
  var COLORS = { dark: "#0B0B10", light: "#F6F6F9" };
  var media = window.matchMedia ? window.matchMedia("(prefers-color-scheme: light)") : null;

  // localStorage peut être absent ou lever une exception (navigation privée, cookies bloqués).
  function stored() {
    try {
      var value = window.localStorage.getItem(KEY);
      return value === "light" || value === "dark" ? value : null;
    } catch (e) {
      return null;
    }
  }

  function remember(theme) {
    try {
      window.localStorage.setItem(KEY, theme);
    } catch (e) {
      // Le choix vaut pour la page en cours seulement.
    }
  }

  function system() {
    return media && media.matches ? "light" : "dark";
  }

  function label(button, theme) {
    var text = theme === "dark" ? "Passer en mode clair" : "Passer en mode sombre";
    button.setAttribute("aria-label", text);
    button.setAttribute("title", text);
  }

  function apply(theme) {
    root.setAttribute("data-theme", theme);
    var metas = document.querySelectorAll('meta[name="theme-color"]');
    for (var i = 0; i < metas.length; i++) {
      metas[i].setAttribute("content", COLORS[theme]);
    }
    var button = document.querySelector(".theme-toggle");
    if (button) {
      label(button, theme);
    }
    // Sélecteur « Sombre / Clair » de l'administration.
    var choices = document.querySelectorAll("[data-set-theme]");
    for (var j = 0; j < choices.length; j++) {
      choices[j].setAttribute("aria-pressed", choices[j].getAttribute("data-set-theme") === theme ? "true" : "false");
    }
  }

  apply(stored() || system());
  root.classList.add("has-theme-toggle");

  // Tant que le visiteur n'a rien choisi, le site suit le système en direct.
  if (media) {
    var follow = function () {
      if (!stored()) {
        apply(system());
      }
    };
    if (media.addEventListener) {
      media.addEventListener("change", follow);
    } else if (media.addListener) {
      media.addListener(follow);
    }
  }

  // Boutons qui choisissent un thème précis (administration), y compris dans un
  // contenu remplacé après coup : écoute déléguée.
  document.addEventListener("click", function (event) {
    var choice = event.target.closest ? event.target.closest("[data-set-theme]") : null;
    if (!choice) {
      return;
    }
    var theme = choice.getAttribute("data-set-theme");
    if (theme === "light" || theme === "dark") {
      apply(theme);
      remember(theme);
    }
  });

  document.addEventListener("DOMContentLoaded", function () {
    apply(root.getAttribute("data-theme"));
    var button = document.querySelector(".theme-toggle");
    if (!button) {
      return;
    }
    label(button, root.getAttribute("data-theme"));
    button.addEventListener("click", function () {
      var next = root.getAttribute("data-theme") === "dark" ? "light" : "dark";
      apply(next);
      remember(next);
    });
  });
})();
