// Incidents du multijoueur (maquettes X1, X2, X3) : un seul gabarit pour
// tous, celui du dialogue Pong. Une icône, un titre en mots simples, une
// phrase de cause probable, une action. Jamais de code d'erreur ni
// d'adresse. Textes dans lib/l10n/ (clés `incident…`).
//
// ```dart
// final action = await showDuelIncident(
//   context,
//   DuelIncident.opponentDisconnected('Tom'),
// );
// if (action == DuelIncidentAction.primary) { /* retour au salon */ }
// ```
import 'package:flutter/material.dart';
import 'package:pong_game/l10n/l10n.dart';
import 'package:pong_game/ui/pong_ui.dart';

/// Bouton choisi dans un dialogue d'incident.
enum DuelIncidentAction {
  /// L'action principale (rose).
  primary,

  /// Le bouton texte, quand il y en a un.
  secondary,
}

/// Les incidents prévus par la maquette et le parcours.
enum DuelIncidentKind {
  opponentDisconnected,
  hostLeft,
  connectionLost,
  connectionFailed,
  gameFull,
  noNetwork,
  leaveDuel,
  versionMismatch,
  closedInBackground,
}

/// Contenu d'un incident : son cas et, s'il y a lieu, le pseudo de l'autre
/// joueur. Les textes sont lus dans la langue de ce téléphone au moment de
/// l'affichage ([title], [message]…) : rien de traduit ne passe par le
/// réseau.
class DuelIncident {
  const DuelIncident._(this.kind, [this.name = '']);

  /// X1, côté hôte : l'invité a perdu la connexion ou a quitté. La partie
  /// reste ouverte, retour au salon.
  const DuelIncident.opponentDisconnected(String name)
      : this._(DuelIncidentKind.opponentDisconnected, name);

  /// X2, côté invité : l'hôte a quitté. Icône neutre : ce n'est pas une
  /// panne, c'est un choix de l'autre joueur.
  const DuelIncident.hostLeft(String name)
      : this._(DuelIncidentKind.hostLeft, name);

  /// Côté invité : l'hôte ne répond plus (Wi-Fi coupé, app fermée).
  const DuelIncident.connectionLost(String name)
      : this._(DuelIncidentKind.connectionLost, name);

  /// X3 : la connexion à une partie trouvée a échoué.
  const DuelIncident.connectionFailed()
      : this._(DuelIncidentKind.connectionFailed);

  /// La partie s'est remplie entre la recherche et le toucher.
  const DuelIncident.gameFull(String name)
      : this._(DuelIncidentKind.gameFull, name);

  /// Le téléphone n'est relié à aucun réseau local : impossible de créer
  /// ou de chercher une partie.
  const DuelIncident.noNetwork() : this._(DuelIncidentKind.noNetwork);

  /// Retour Android pendant le duel : confirmer avant d'abandonner. L'action
  /// principale est la plus sûre (continuer).
  const DuelIncident.leaveDuel(String name)
      : this._(DuelIncidentKind.leaveDuel, name);

  /// L'hôte a une autre version de l'app.
  const DuelIncident.versionMismatch()
      : this._(DuelIncidentKind.versionMismatch);

  /// L'app est passée en arrière-plan : pas de pause en duel.
  const DuelIncident.closedInBackground()
      : this._(DuelIncidentKind.closedInBackground);

  final DuelIncidentKind kind;

  /// Pseudo de l'autre joueur (vide si l'incident n'en parle pas).
  final String name;

  IconData get icon => switch (kind) {
        DuelIncidentKind.opponentDisconnected => Icons.link_off_rounded,
        DuelIncidentKind.hostLeft ||
        DuelIncidentKind.leaveDuel =>
          Icons.logout_rounded,
        DuelIncidentKind.connectionLost ||
        DuelIncidentKind.connectionFailed ||
        DuelIncidentKind.noNetwork =>
          Icons.wifi_off_rounded,
        DuelIncidentKind.gameFull => Icons.group_rounded,
        DuelIncidentKind.versionMismatch => Icons.system_update_rounded,
        DuelIncidentKind.closedInBackground =>
          Icons.pause_circle_outline_rounded,
      };

  /// Rouge pour une panne, neutre pour un choix de l'autre joueur.
  Color get iconColor => switch (kind) {
        DuelIncidentKind.opponentDisconnected ||
        DuelIncidentKind.connectionLost ||
        DuelIncidentKind.connectionFailed ||
        DuelIncidentKind.noNetwork =>
          PongColors.error,
        _ => PongColors.textBody,
      };

  /// Titre en mots simples. « Tom s'est déconnecté » dans la maquette :
  /// « Connexion perdue avec Tom », tournure neutre qui vaut pour tous.
  String title(AppLocalizations l10n) => switch (kind) {
        DuelIncidentKind.opponentDisconnected =>
          l10n.incidentOpponentLostTitle(name),
        DuelIncidentKind.hostLeft => l10n.opponentLeftGame(name),
        DuelIncidentKind.connectionLost => l10n.incidentConnectionLostTitle,
        DuelIncidentKind.connectionFailed =>
          l10n.incidentConnectionFailedTitle,
        DuelIncidentKind.gameFull => l10n.incidentGameFullTitle,
        DuelIncidentKind.noNetwork => l10n.incidentNoWifiTitle,
        DuelIncidentKind.leaveDuel => l10n.incidentLeaveDuelTitle,
        DuelIncidentKind.versionMismatch => l10n.incidentVersionTitle,
        DuelIncidentKind.closedInBackground => l10n.incidentClosedTitle,
      };

  /// Cause probable, en une phrase qui dit quoi faire.
  String message(AppLocalizations l10n) => switch (kind) {
        DuelIncidentKind.opponentDisconnected =>
          l10n.incidentOpponentLostMessage(name),
        DuelIncidentKind.hostLeft => l10n.incidentHostLeftMessage,
        DuelIncidentKind.connectionLost =>
          l10n.incidentConnectionLostMessage(name),
        DuelIncidentKind.connectionFailed =>
          l10n.incidentConnectionFailedMessage,
        DuelIncidentKind.gameFull => l10n.incidentGameFullMessage(name),
        DuelIncidentKind.noNetwork => l10n.incidentNoWifiMessage,
        DuelIncidentKind.leaveDuel => l10n.incidentLeaveDuelMessage(name),
        DuelIncidentKind.versionMismatch => l10n.incidentVersionMessage,
        DuelIncidentKind.closedInBackground => l10n.incidentClosedMessage,
      };

  String primaryLabel(AppLocalizations l10n) => switch (kind) {
        DuelIncidentKind.opponentDisconnected => l10n.incidentBackToLobby,
        DuelIncidentKind.hostLeft ||
        DuelIncidentKind.connectionLost ||
        DuelIncidentKind.closedInBackground =>
          l10n.incidentBackToMenu,
        DuelIncidentKind.connectionFailed ||
        DuelIncidentKind.noNetwork =>
          l10n.incidentRetry,
        DuelIncidentKind.gameFull ||
        DuelIncidentKind.versionMismatch =>
          l10n.incidentBackToList,
        DuelIncidentKind.leaveDuel => l10n.incidentKeepPlaying,
      };

  /// Bouton texte facultatif (« Retour »).
  String? secondaryLabel(AppLocalizations l10n) => switch (kind) {
        DuelIncidentKind.connectionFailed ||
        DuelIncidentKind.noNetwork =>
          l10n.incidentBack,
        DuelIncidentKind.leaveDuel => l10n.commonQuit,
        _ => null,
      };
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
    final l10n = context.l10n;
    final String? secondary = incident.secondaryLabel(l10n);
    return PongDialogCard(
      icon: incident.icon,
      iconColor: incident.iconColor,
      title: incident.title(l10n),
      message: incident.message(l10n),
      padding: EdgeInsets.fromLTRB(PongSpacing.lg, PongSpacing.lg,
          PongSpacing.lg, secondary == null ? PongSpacing.lg : PongSpacing.sm),
      actions: [
        PongPrimaryButton(
          label: incident.primaryLabel(l10n),
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
