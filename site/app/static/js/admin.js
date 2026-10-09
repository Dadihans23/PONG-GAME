// Demande confirmation avant d'envoyer un formulaire marqué data-confirm.
document.addEventListener("submit", (event) => {
  const message = event.target.dataset && event.target.dataset.confirm;
  if (message && !window.confirm(message)) {
    event.preventDefault();
  }
});
