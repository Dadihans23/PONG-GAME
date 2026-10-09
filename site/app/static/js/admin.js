// Administration : améliorations progressives. Tout marche sans ce fichier
// (formulaires HTML classiques) ; il ajoute les compteurs de caractères, les
// boutons « Copier », la confirmation des suppressions, la barre de progression
// de l'envoi d'un APK, les onglets de la confidentialité, le menu mobile et
// l'heure locale. Chargé avec defer ; CSP stricte : aucun code en ligne.
(function () {
  "use strict";

  var MONTHS = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet",
    "août", "septembre", "octobre", "novembre", "décembre"];
  var MONTHS_SHORT = ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.",
    "août", "sept.", "oct.", "nov.", "déc."];

  function announce(text) {
    var live = document.getElementById("live");
    if (live) {
      live.textContent = "";
      window.setTimeout(function () { live.textContent = text; }, 50);
    }
  }

  function formatNumber(n) {
    return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, " ");
  }

  // --- Compteurs « n / max » (le maximum vient de maxlength, posé par le serveur) ---
  function updateCounter(counter) {
    var input = document.getElementById(counter.getAttribute("data-count-for"));
    if (!input) {
      return;
    }
    var length = input.value.length;
    if (counter.getAttribute("data-count-mode") === "chars") {
      counter.textContent = formatNumber(length) + (length > 1 ? " caractères" : " caractère");
      return;
    }
    var max = input.getAttribute("maxlength");
    counter.textContent = max ? length + " / " + max : String(length);
    counter.classList.toggle("is-full", max && length >= Number(max));
  }

  document.addEventListener("input", function (event) {
    var id = event.target.id;
    if (!id) {
      return;
    }
    var counters = document.querySelectorAll('[data-count-for="' + id + '"]');
    for (var i = 0; i < counters.length; i++) {
      updateCounter(counters[i]);
    }
  });

  // --- Heure locale ---------------------------------------------------------------
  function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() &&
      a.getDate() === b.getDate();
  }

  function localTime(el) {
    var d = new Date(el.getAttribute("datetime"));
    if (isNaN(d.getTime())) {
      return;
    }
    var hour = d.getHours() + " h " + String(d.getMinutes()).padStart(2, "0");
    if (el.getAttribute("data-local") === "long") {
      el.textContent = d.getDate() + " " + MONTHS[d.getMonth()] + " " + d.getFullYear() + ", " + hour;
      return;
    }
    var now = new Date();
    var yesterday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
    if (sameDay(d, now)) {
      el.textContent = "aujourd'hui, " + hour;
    } else if (sameDay(d, yesterday)) {
      el.textContent = "hier, " + hour;
    } else {
      el.textContent = d.getDate() + " " + MONTHS_SHORT[d.getMonth()] +
        (d.getFullYear() === now.getFullYear() ? "" : " " + d.getFullYear());
    }
  }

  // --- Copier ------------------------------------------------------------------------
  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text);
    }
    return new Promise(function (resolve, reject) {
      var area = document.createElement("textarea");
      area.value = text;
      area.setAttribute("readonly", "");
      area.className = "sr-only";
      document.body.appendChild(area);
      area.select();
      var ok = false;
      try {
        ok = document.execCommand("copy");
      } catch (e) {
        ok = false;
      }
      document.body.removeChild(area);
      if (ok) {
        resolve();
      } else {
        reject();
      }
    });
  }

  document.addEventListener("click", function (event) {
    var button = event.target.closest("[data-copy]");
    if (!button) {
      return;
    }
    var label = button.getAttribute("data-label") || button.textContent;
    button.setAttribute("data-label", label);
    copyText(button.getAttribute("data-copy")).then(function () {
      button.textContent = "Copié";
      announce("Copié dans le presse-papiers.");
    }, function () {
      button.textContent = "Copie impossible";
    }).then(function () {
      window.setTimeout(function () { button.textContent = label; }, 2000);
    });
  });

  // --- Confirmation des suppressions (<dialog>) --------------------------------------
  var pending = null;

  document.addEventListener("click", function (event) {
    var button = event.target.closest("button[data-confirm-title]");
    if (!button || button.disabled || !button.form) {
      return;
    }
    if (pending && pending.confirmed === button) {
      pending = null;
      return; // confirmé : l'envoi continue
    }
    event.preventDefault();
    var title = button.getAttribute("data-confirm-title");
    var text = button.getAttribute("data-confirm-text") || "";
    var dialog = document.getElementById("confirm");
    if (!dialog || typeof dialog.showModal !== "function") {
      if (window.confirm(title + (text ? "\n\n" + text : ""))) {
        submitWith(button);
      }
      return;
    }
    document.getElementById("confirm-title").textContent = title;
    document.getElementById("confirm-text").textContent = text;
    document.getElementById("confirm-ok").textContent = button.getAttribute("data-confirm-ok") || "Supprimer";
    dialog.returnValue = "";
    pending = { button: button, opener: button };
    dialog.showModal();
  });

  function submitWith(button) {
    if (typeof button.form.requestSubmit === "function") {
      pending = null;
      button.form.requestSubmit(button);
    } else {
      pending = { confirmed: button };
      button.click();
    }
  }

  document.addEventListener("close", function (event) {
    if (event.target.id !== "confirm" || !pending || !pending.button) {
      return;
    }
    var button = pending.button;
    pending = null;
    if (event.target.returnValue === "ok") {
      submitWith(button);
    } else {
      button.focus();
    }
  }, true);

  // --- Annuler dans un élément déplié : referme sans recharger -----------------------
  document.addEventListener("click", function (event) {
    var link = event.target.closest("[data-close-details]");
    if (!link) {
      return;
    }
    var details = link.closest("details");
    if (!details) {
      return;
    }
    event.preventDefault();
    var form = link.closest("form");
    if (form) {
      form.reset();
      var counters = form.querySelectorAll("[data-count-for]");
      for (var i = 0; i < counters.length; i++) {
        updateCounter(counters[i]);
      }
    }
    details.open = false;
    var summary = details.querySelector("summary");
    if (summary) {
      summary.focus();
    }
  });

  // --- Menu mobile ----------------------------------------------------------------------
  function setMenu(open) {
    document.body.classList.toggle("menu-open", open);
    var toggles = document.querySelectorAll("[data-menu-toggle]");
    for (var i = 0; i < toggles.length; i++) {
      toggles[i].setAttribute("aria-expanded", open ? "true" : "false");
    }
  }

  document.addEventListener("click", function (event) {
    var toggle = event.target.closest("[data-menu-toggle]");
    if (toggle) {
      event.preventDefault();
      setMenu(!document.body.classList.contains("menu-open"));
      return;
    }
    if (event.target.closest(".side__close")) {
      event.preventDefault();
      setMenu(false);
    }
  });

  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape" && document.body.classList.contains("menu-open")) {
      setMenu(false);
      var toggle = document.querySelector("[data-menu-toggle]");
      if (toggle) {
        toggle.focus();
      }
    }
  });

  // --- Onglets Modifier / Aperçu (confidentialité, sur mobile) --------------------------
  function selectTab(tabs, tab) {
    var all = tabs.querySelectorAll('[role="tab"]');
    for (var i = 0; i < all.length; i++) {
      var selected = all[i] === tab;
      all[i].setAttribute("aria-selected", selected ? "true" : "false");
      all[i].tabIndex = selected ? 0 : -1;
      var pane = document.getElementById(all[i].getAttribute("aria-controls"));
      if (pane) {
        pane.classList.toggle("is-hidden-tab", !selected);
      }
    }
  }

  document.addEventListener("click", function (event) {
    var tab = event.target.closest('[data-tabs] [role="tab"]');
    if (tab) {
      selectTab(tab.closest("[data-tabs]"), tab);
    }
  });

  document.addEventListener("keydown", function (event) {
    var tab = event.target.closest && event.target.closest('[data-tabs] [role="tab"]');
    if (!tab || (event.key !== "ArrowRight" && event.key !== "ArrowLeft")) {
      return;
    }
    var all = Array.prototype.slice.call(tab.closest("[data-tabs]").querySelectorAll('[role="tab"]'));
    var next = all[(all.indexOf(tab) + (event.key === "ArrowRight" ? 1 : all.length - 1)) % all.length];
    selectTab(tab.closest("[data-tabs]"), next);
    next.focus();
  });

  // --- Envoi d'un APK avec barre de progression ----------------------------------------
  function mb(bytes) {
    return (bytes / (1024 * 1024)).toFixed(1).replace(".", ",");
  }

  function uploadError(form, message) {
    var error = form.querySelector("[data-upload-error]");
    if (error) {
      error.textContent = message;
      error.hidden = false;
    }
  }

  document.addEventListener("submit", function (event) {
    var form = event.target;
    if (!form.hasAttribute || !form.hasAttribute("data-upload") || !window.FormData || !window.XMLHttpRequest) {
      return;
    }
    var input = form.querySelector('input[type="file"]');
    var file = input && input.files && input.files[0];
    if (!file) {
      return; // le serveur répond « Choisis un fichier APK. »
    }
    var max = Number(form.getAttribute("data-max-bytes") || 0);
    if (max && file.size > max) {
      event.preventDefault();
      uploadError(form, "Fichier trop volumineux : " + mb(file.size) + " Mo, pour " +
        Math.round(max / (1024 * 1024)) + " Mo au plus.");
      return;
    }
    event.preventDefault();
    var zone = form.querySelector("[data-upload-zone]");
    var box = form.querySelector("[data-upload-progress]");
    var bar = form.querySelector("[data-upload-bar]");
    var status = form.querySelector("[data-upload-status]");
    var submit = form.querySelector("[data-upload-submit]");
    var errorBox = form.querySelector("[data-upload-error]");
    if (errorBox) {
      errorBox.hidden = true;
    }
    form.querySelector("[data-upload-name]").textContent = file.name;
    form.querySelector("[data-upload-total]").textContent = mb(file.size) + " Mo";
    zone.hidden = true;
    box.hidden = false;
    submit.disabled = true;
    submit.textContent = "Envoi en cours…";
    status.textContent = "Envoi… 0 sur " + mb(file.size) + " Mo";

    var xhr = new XMLHttpRequest();
    var data = new FormData(form);

    function reset(message) {
      zone.hidden = false;
      box.hidden = true;
      submit.disabled = false;
      submit.textContent = "Déposer";
      bar.value = 0;
      if (message) {
        uploadError(form, message);
      }
    }

    xhr.upload.addEventListener("progress", function (e) {
      if (e.lengthComputable) {
        bar.value = Math.round((e.loaded / e.total) * 100);
        status.textContent = e.loaded >= e.total ? "Vérification du fichier…" :
          "Envoi… " + mb(e.loaded) + " sur " + mb(e.total) + " Mo";
      }
    });
    xhr.addEventListener("load", function () {
      if (xhr.status === 413) {
        reset("Fichier trop volumineux pour le serveur.");
        return;
      }
      var type = xhr.getResponseHeader("content-type") || "";
      if (type.indexOf("text/html") === -1) {
        reset("L'envoi a échoué. Réessaie.");
        return;
      }
      // Page renvoyée par le serveur (après redirection, ou réaffichée avec les erreurs).
      var doc = new DOMParser().parseFromString(xhr.responseText, "text/html");
      document.title = doc.title;
      document.body.className = doc.body.className;
      document.body.innerHTML = doc.body.innerHTML;
      if (xhr.responseURL && window.history && window.history.replaceState) {
        window.history.replaceState(null, "", xhr.responseURL);
      }
      init(document);
      window.scrollTo(0, 0);
      var banner = document.querySelector(".banner");
      if (banner) {
        announce(banner.textContent);
      }
    });
    xhr.addEventListener("error", function () {
      reset("L'envoi a échoué. Vérifie ta connexion, puis réessaie.");
    });
    xhr.addEventListener("abort", function () {
      reset("Envoi annulé. Rien n'a été déposé.");
    });
    form.querySelector("[data-upload-cancel]").onclick = function () {
      xhr.abort();
    };
    xhr.open("POST", form.action);
    xhr.send(data);
  });

  // --- Initialisation (aussi après le remplacement de la page par un envoi) -----------
  function init(root) {
    var i;
    var counters = root.querySelectorAll("[data-count-for]");
    for (i = 0; i < counters.length; i++) {
      updateCounter(counters[i]);
    }
    var times = root.querySelectorAll("time[data-local]");
    for (i = 0; i < times.length; i++) {
      localTime(times[i]);
    }
    var copies = root.querySelectorAll("[data-copy]");
    for (i = 0; i < copies.length; i++) {
      copies[i].hidden = false;
    }
    var tabs = root.querySelectorAll("[data-tabs]");
    for (i = 0; i < tabs.length; i++) {
      tabs[i].hidden = false;
      document.documentElement.classList.add("has-tabs");
      selectTab(tabs[i], tabs[i].querySelector('[aria-selected="true"]'));
    }
    var theme = document.documentElement.getAttribute("data-theme");
    var choices = root.querySelectorAll("[data-set-theme]");
    for (i = 0; i < choices.length; i++) {
      choices[i].setAttribute("aria-pressed", choices[i].getAttribute("data-set-theme") === theme ? "true" : "false");
    }
    document.documentElement.classList.add("js");
  }

  init(document);
})();
