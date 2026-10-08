import 'model/game_state.dart';
import 'model/player.dart';

/// Ce qu'un joueur voit de la partie : sa raquette toujours en bas.
///
/// Le joueur 1 (Host) voit le terrain tel quel. Le joueur 2 (Client) le voit
/// tourné d'un demi-tour (x → -x, y → -y), comme deux joueurs face à face
/// autour d'une table. L'inversion se fait uniquement ici, à l'affichage :
/// le moteur et le protocole restent en coordonnées du terrain du Host.
class DuelView {
  const DuelView({
    required this.ballX,
    required this.ballY,
    required this.ballVX,
    required this.ballVY,
    required this.myPaddleX,
    required this.opponentPaddleX,
    required this.myScore,
    required this.opponentScore,
  });

  /// Vue de [state] pour le joueur [viewer].
  factory DuelView.of(GameState state, PlayerSlot viewer) {
    final double sign = viewer == PlayerSlot.player1 ? 1 : -1;
    return DuelView(
      ballX: state.ballX * sign,
      ballY: state.ballY * sign,
      ballVX: state.ballVX * sign,
      ballVY: state.ballVY * sign,
      myPaddleX: state.paddleOf(viewer) * sign,
      opponentPaddleX: state.paddleOf(viewer.opponent) * sign,
      myScore: state.scoreOf(viewer),
      opponentScore: state.scoreOf(viewer.opponent),
    );
  }

  /// Balle à l'écran (-1 à 1, y = 1 en bas) et sa vitesse par pas.
  final double ballX;
  final double ballY;
  final double ballVX;
  final double ballVY;

  /// Ma raquette, dessinée en bas ; celle de l'adversaire, en haut.
  final double myPaddleX;
  final double opponentPaddleX;

  final int myScore;
  final int opponentScore;

  /// Convertit une position X à l'écran de [viewer] en position X du
  /// terrain : le Client s'en sert pour envoyer la position de sa raquette.
  static double courtXFromScreen(double screenX, PlayerSlot viewer) =>
      viewer == PlayerSlot.player1 ? screenX : -screenX;

  @override
  String toString() => 'DuelView(balle ($ballX, $ballY), moi $myPaddleX, adversaire $opponentPaddleX, '
      'score $myScore-$opponentScore)';
}
