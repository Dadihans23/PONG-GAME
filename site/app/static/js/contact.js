// Formulaire de contact.
// 1. Compteur de caractères du message (le texte de départ, sans JavaScript, annonce la limite).
//    Les lecteurs d'écran le lisent avec le champ (aria-describedby) ; il n'est annoncé en direct
//    qu'à l'approche de la limite, pour ne pas parler à chaque touche.
// 2. Après un envoi refusé, le message d'erreur en tête reçoit le focus.
(function () {
  "use strict";

  var field = document.getElementById("contact-message");
  var count = document.getElementById("contact-message-count");
  if (field && count) {
    var max = parseInt(count.getAttribute("data-max"), 10) || field.maxLength || 2000;
    var warnAt = Math.round(max * 0.9);
    // Textes dans la langue de la page : data-live (« {used} / {max} caractères »),
    // data-full (limite atteinte), data-left (« encore {left} »).
    var text = function (name, fallback) {
      return count.getAttribute("data-" + name) || fallback;
    };
    var fill = function (template, used, left) {
      return template.replace("{used}", used).replace("{max}", max).replace("{left}", left);
    };
    var render = function () {
      var used = field.value.length;
      var left = max - used;
      count.textContent = fill(text("live", "{used} / {max} caractères"), used, left) +
        (left <= 0 ? text("full", " : limite atteinte.")
          : used >= warnAt ? fill(text("left", " : encore {left}."), used, left) : "");
      var near = used >= warnAt;
      count.classList.toggle("is-near", near);
      if (near) {
        count.setAttribute("aria-live", "polite");
      } else {
        count.removeAttribute("aria-live");
      }
    };
    field.addEventListener("input", render);
    render();
  }

  var alertBox = document.getElementById("form-alert");
  if (alertBox) {
    alertBox.focus();
  }
})();
