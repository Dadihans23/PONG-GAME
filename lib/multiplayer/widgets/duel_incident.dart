// Incidents du multijoueur (maquettes X1, X2, X3) : un seul gabarit pour
// tous, celui du dialogue Pong. Une icône, un titre en mots simples, une
// phrase de cause probable, une action. Jamais de code d'erreur ni
// d'adresse.
//
// ```dart
// final action = await showDuelIncident(
//   context,
//   DuelIncident.opponentDisconnected('Tom'),
// );
// if (action == DuelIncidentAction.primary) { /* retour au salon */ }
// ```
import 'package:flutter/material.dart';
import 'package:pong_game/ui/pong_ui.dart';

/// Bouton choisi dans un dialogue d'incident.
enum DuelIncidentAction {
  /// L'action principale (rose).
  primary,

  /// Le bouton texte, quand il y en a un.
  secondary,
}

/// Contenu d'un incident. Les constructeurs nommés couvrent les cas prévus
/// par la maquette et ceux du parcours ; le constructeur par défaut reste
/// ouvert pour un cas nouveau.
class DuelIncident {
  const DuelIncident({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.primaryLabel,
    this.secondaryLabel,
  });

  /// X1, côté hôte : l'invité a perdu la connexion ou a quitté. La partie
  /// reste ouverte, retour au salon.
  const DuelIncident.opponentDisconnected(String name)
      : icon = Icons.link_off_rounded,
        iconColor = PongColors.error,
        // « Tom s'est déconnecté » dans la maquette : tournure neutre, qui
        // vaut aussi pour « Inès »
        title = 'Connexion perdue avec $name',
        message = 'Ta partie reste ouverte : $name peut la rejoindre à '
            'nouveau.',
        primaryLabel = 'Retour au salon',
        secondaryLabel = null;

  /// X2, côté invité : l'hôte a quitté. Icône neutre : ce n'est pas une
  /// panne, c'est un choix de l'autre joueur.
  const DuelIncident.hostLeft(String name)
      : icon = Icons.logout_rounded,
        iconColor = PongColors.textBody,
        title = '$name a quitté la partie',
        message = 'La partie est terminée. Tu peux en rejoindre une autre '
            'ou créer la tienne.',
        primaryLabel = 'Retour au menu',
        secondaryLabel = null;

  /// Côté invité : l'hôte ne répond plus (Wi-Fi coupé, app fermée).
  const DuelIncident.connectionLost(String name)
      : icon = Icons.wifi_off_rounded,
        iconColor = PongColors.error,
        title = 'Connexion perdue',
        message = '$name ne répond plus. Vérifie que vous êtes toujours sur '
            'le même Wi‑Fi.',
        primaryLabel = 'Retour au menu',
        secondaryLabel = null;

  /// X3 : la connexion à une partie trouvée a échoué.
  const DuelIncident.connectionFailed()
      : icon = Icons.wifi_off_rounded,
        iconColor = PongColors.error,
        title = 'Connexion impossible',
        message = 'Vérifie que vous êtes sur le même Wi‑Fi, puis réessaie.',
        primaryLabel = 'Réessayer',
        secondaryLabel = 'Retour';

  /// La partie s'est remplie entre la recherche et le toucher.
  const DuelIncident.gameFull(String name)
      : icon = Icons.group_rounded,
        iconColor = PongColors.textBody,
        title = 'Partie complète',
        message = '$name joue déjà avec quelqu\'un. Choisis une autre '
            'partie ou crée la tienne.',
        primaryLabel = 'Retour à la liste',
        secondaryLabel = null;

  /// Le téléphone n'est relié à aucun réseau local : impossible de créer
  /// ou de chercher une partie.
  const DuelIncident.noNetwork()
      : icon = Icons.wifi_off_rounded,
        iconColor = PongColors.error,
        title = 'Pas de Wi‑Fi',
        message = "Connecte-toi à un Wi‑Fi ou au partage de connexion de "
            "l'autre joueur, puis réessaie.",
        primaryLabel = 'Réessayer',
        secondaryLabel = 'Retour';

  /// Retour Android pendant le duel : confirmer avant d'abandonner. L'action
  /// principale est la plus sûre (continuer).
  const DuelIncident.leaveDuel(String name)
      : icon = Icons.logout_rounded,
        iconColor = PongColors.textBody,
        title = 'Quitter le duel ?',
        message = 'Le duel s\'arrête pour $name aussi.',
        primaryLabel = 'Continuer le duel',
        secondaryLabel = 'Quitter';

  final IconData icon;
  final Color iconColor;
  final String title;

  /// Cause probable, en une phrase qui dit quoi faire.
  final String message;
  final String primaryLabel;

  /// Bouton texte facultatif (« Retour »).
  final String? secondaryLabel;
}

/// Carte d'incident, utilisable seule (dans un `Stack` au-dessus d'un écran)
/// ou via [showDuelIncident].
class DuelIncidentCard extends StatelessWidget {
  const DuelIncidentCard({
    super.key,
    required this.incident,
    required this.onAction,
  });

  final DuelIncident incident;
  final ValueChanged<DuelIncidentAction> onAction;

  @override
  Widget build(BuildContext context) {
    final String? secondary = incident.secondaryLabel;
    return PongDialogCard(
      icon: incident.icon,
      iconColor: incident.iconColor,
      title: incident.title,
      message: incident.message,
      padding: EdgeInsets.fromLTRB(PongSpacing.lg, PongSpacing.lg,
          PongSpacing.lg, secondary == null ? PongSpacing.lg : PongSpacing.sm),
      actions: [
        PongPrimaryButton(
          label: incident.primaryLabel,
          onPressed: () => onAction(DuelIncidentAction.primary),
        ),
        if (secondary != null)
          PongTextButton(
            label: secondary,
            onPressed: () => onAction(DuelIncidentAction.secondary),
          ),
      ],
    );
  }
}

/// Ouvre l'incident par-dessus l'écran courant et rend le bouton choisi
/// (`null` si le dialogue est fermé autrement, par exemple par le code).
/// Le retour Android ne ferme pas le dialogue : le joueur choisit une action.
Future<DuelIncidentAction?> showDuelIncident(
  BuildContext context,
  DuelIncident incident,
) {
  return showPongDialog<DuelIncidentAction>(
    context: context,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: SingleChildScrollView(
        child: DuelIncidentCard(
          incident: incident,
          onAction: (action) => Navigator.of(dialogContext).pop(action),
        ),
      ),
    ),
  );
}
