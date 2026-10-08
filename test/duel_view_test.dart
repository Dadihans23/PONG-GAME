import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/multiplayer/duel_view.dart';
import 'package:pong_game/multiplayer/model/duel_phase.dart';
import 'package:pong_game/multiplayer/model/game_state.dart';
import 'package:pong_game/multiplayer/model/player.dart';

// Balle en haut à droite, qui monte vers le joueur 2 ; le joueur 1 mène 3 à 1
const state = GameState(
  tick: 10,
  phase: DuelPhase.playing,
  ballX: 0.3,
  ballY: -0.8,
  ballVX: 0.002,
  ballVY: -0.0025,
  paddle1X: 0.5,
  paddle2X: -0.25,
  score1: 3,
  score2: 1,
);

void main() {
  test('le joueur 1 (Host) voit le terrain tel quel', () {
    final view = DuelView.of(state, PlayerSlot.player1);
    expect(view.ballX, 0.3);
    expect(view.ballY, -0.8);
    expect(view.ballVX, 0.002);
    expect(view.ballVY, -0.0025);
    expect(view.myPaddleX, 0.5);
    expect(view.opponentPaddleX, -0.25);
    expect(view.myScore, 3);
    expect(view.opponentScore, 1);
  });

  test('le joueur 2 (Client) voit le terrain tourné d\'un demi-tour', () {
    final view = DuelView.of(state, PlayerSlot.player2);
    // Balle près de sa raquette, donc en bas de son écran, et qui descend vers lui
    expect(view.ballX, -0.3);
    expect(view.ballY, 0.8);
    expect(view.ballVX, -0.002);
    expect(view.ballVY, 0.0025);
    // Sa raquette en bas, celle du Host en haut
    expect(view.myPaddleX, 0.25);
    expect(view.opponentPaddleX, -0.5);
    // Son score d'abord
    expect(view.myScore, 1);
    expect(view.opponentScore, 3);
  });

  test('chacun voit la balle arriver vers sa propre raquette', () {
    // Balle qui descend vers le joueur 1 dans le terrain du Host
    const towardHost = GameState(
      tick: 0,
      phase: DuelPhase.playing,
      ballX: 0,
      ballY: 0,
      ballVX: 0,
      ballVY: 0.002,
      paddle1X: 0,
      paddle2X: 0,
      score1: 0,
      score2: 0,
    );
    expect(DuelView.of(towardHost, PlayerSlot.player1).ballVY, greaterThan(0)); // vers le bas : vers moi
    expect(DuelView.of(towardHost, PlayerSlot.player2).ballVY, lessThan(0)); // vers le haut : vers l'adversaire
    // Et l'inverse pour la balle de l'exemple, qui monte vers le joueur 2
    expect(DuelView.of(state, PlayerSlot.player2).ballVY, greaterThan(0));
  });

  test('la position de la raquette à l\'écran du Client revient en coordonnées du terrain', () {
    final view = DuelView.of(state, PlayerSlot.player2);
    expect(DuelView.courtXFromScreen(view.myPaddleX, PlayerSlot.player2), state.paddle2X);
    expect(DuelView.courtXFromScreen(0.7, PlayerSlot.player1), 0.7);
    // Le Client penche à droite de son écran : vers la gauche du terrain du Host
    expect(DuelView.courtXFromScreen(0.7, PlayerSlot.player2), -0.7);
  });
}
