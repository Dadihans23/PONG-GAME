// Langue du site : aucune redirection. Si la langue préférée du visiteur diffère de
// celle de la page, un bandeau discret propose la même page dans sa langue.
//
// Langue préférée = le dernier choix retenu (clic sur FR · EN · ES ou sur le lien du
// bandeau, ou fermeture du bandeau : « je reste dans cette langue »), sinon la
// première langue du navigateur que le site parle (fr, en, es), sinon l'anglais.
// Le bandeau vient d'un <template> de la page (texte déjà écrit dans la langue
// proposée) ; il n'est jamais montré aux robots d'indexation.
(function () {
  "use strict";

  var KEY = "tilto-lang";
  var LANGS = ["fr", "en", "es"];
  var root = document.documentElement;
  var pageLang = (root.getAttribute("lang") || "fr").slice(0, 2).toLowerCase();

  // localStorage peut être absent ou lever une exception (navigation privée, cookies bloqués).
  function stored() {
    try {
      var value = window.localStorage.getItem(KEY);
      return LANGS.indexOf(value) >= 0 ? value : null;
    } catch (e) {
      return null;
    }
  }

  function remember(lang) {
    try {
      window.localStorage.setItem(KEY, lang);
    } catch (e) {
      // Le choix vaut pour la page en cours seulement.
    }
  }

  function browserLang() {
    var list = navigator.languages && navigator.languages.length
      ? navigator.languages : [navigator.language || navigator.userLanguage || ""];
    var any = false;
    for (var i = 0; i < list.length; i++) {
      var code = String(list[i] || "").slice(0, 2).toLowerCase();
      if (!code) {
        continue;
      }
      any = true;
      if (LANGS.indexOf(code) >= 0) {
        return code;
      }
    }
    // Aucune langue du site : l'anglais, comme l'app.
    return any ? "en" : null;
  }

  // Tout lien qui choisit une langue (sélecteur, bandeau) retient ce choix.
  document.addEventListener("click", function (event) {
    var link = event.target.closest ? event.target.closest("[data-set-lang]") : null;
    if (link) {
      remember(link.getAttribute("data-set-lang"));
    }
  });

  if (/bot|crawl|spider|slurp|lighthouse/i.test(navigator.userAgent || "")) {
    return;
  }
  var preferred = stored() || browserLang();
  if (!preferred || preferred === pageLang) {
    return;
  }
  var template = document.getElementById("lang-suggest");
  if (!template || !template.content) {
    return;
  }
  var source = template.content.querySelector('[data-suggest="' + preferred + '"]');
  if (!source) {
    return;
  }
  var bar = source.cloneNode(true);
  var header = document.querySelector(".masthead");
  if (header && header.parentNode) {
    header.parentNode.insertBefore(bar, header.nextSibling);
  } else {
    document.body.insertBefore(bar, document.body.firstChild);
  }

  var close = bar.querySelector("[data-lang-close]");
  if (close) {
    close.addEventListener("click", function () {
      // Fermer = rester dans la langue de la page : le bandeau ne revient plus.
      remember(pageLang);
      var hadFocus = bar.contains(document.activeElement);
      bar.parentNode.removeChild(bar);
      if (hadFocus) {
        var main = document.getElementById("contenu");
        if (main) {
          main.focus();
        }
      }
    });
  }
})();
