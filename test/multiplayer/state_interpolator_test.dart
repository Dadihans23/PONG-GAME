import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/multiplayer/controller/state_interpolator.dart';
import 'package:pong_game/multiplayer/model/duel_phase.dart';
import 'package:pong_game/multiplayer/model/game_state.dart';

GameState state({
  int tick = 0,
  double ballX = 0,
  double ballY = 0,
  double p1 = 0,
  double p2 = 0,
  int score1 = 0,
  int score2 = 0,
  int serveMs = 0,
}) =>
    GameState(
      tick: tick,
      phase: DuelPhase.playing,
      ballX: ballX,
      ballY: ballY,
      ballVX: 0.002,
      ballVY: 0.002,
      paddle1X: p1,
      paddle2X: p2,
      score1: score1,
      score2: score2,
      serveMs: serveMs,
    );

Duration ms(int value) => Duration(milliseconds: value);

void main() {
  test('rien reçu : rien à afficher', () {
    expect(StateInterpolator().sample(Duration.zero), isNull);
  });

  test('premier état affiché tel quel', () {
    final interpolator = StateInterpolator();
    final first = state(ballX: 0.2);
    interpolator.push(first, ms(100));
    expect(interpolator.sample(ms(100)), same(first));
    expect(interpolator.sample(ms(500)), same(first));
  });

  test('glisse en ligne droite vers le nouvel état en un intervalle', () {
    final interpolator = StateInterpolator(duration: ms(40));
    interpolator.push(state(ballX: 0, ballY: 0, p1: 0), ms(0));
    interpolator.push(state(tick: 15, ballX: 0.4, ballY: -0.2, p1: 0.8), ms(40));

    final mid = interpolator.sample(ms(60))!;
    expect(mid.ballX, closeTo(0.2, 1e-9));
    expect(mid.ballY, closeTo(-0.1, 1e-9));
    expect(mid.paddle1X, closeTo(0.4, 1e-9));
    expect(mid.tick, 15);

    expect(interpolator.sample(ms(40))!.ballX, closeTo(0, 1e-9));
    expect(interpolator.sample(ms(80))!.ballX, closeTo(0.4, 1e-9));
  });

  test('pas d\'extrapolation : un état en retard fige l\'affichage sur le dernier reçu', () {
    final interpolator = StateInterpolator(duration: ms(40));
    interpolator.push(state(ballX: 0), ms(0));
    final last = state(tick: 15, ballX: 0.3);
    interpolator.push(last, ms(40));
    expect(interpolator.sample(ms(200))!.ballX, 0.3);
    expect(interpolator.sample(ms(1000)), same(last));
  });

  test('un état arrivé en avance repart de la position affichée, sans saut', () {
    final interpolator = StateInterpolator(duration: ms(40));
    interpolator.push(state(ballX: 0), ms(0));
    interpolator.push(state(tick: 15, ballX: 0.4), ms(40));
    // À mi-chemin (0,2), un nouvel état arrive déjà
    interpolator.push(state(tick: 30, ballX: 0.6), ms(60));
    expect(interpolator.sample(ms(60))!.ballX, closeTo(0.2, 1e-9));
    expect(interpolator.sample(ms(80))!.ballX, closeTo(0.4, 1e-9));
    expect(interpolator.sample(ms(100))!.ballX, closeTo(0.6, 1e-9));
  });

  test('point marqué : saut direct, la balle ne traverse pas le terrain', () {
    final interpolator = StateInterpolator(duration: ms(40));
    interpolator.push(state(ballX: 0.1, ballY: 0.99), ms(0));
    interpolator.push(state(tick: 15, ballX: 0, ballY: 0, score2: 1, serveMs: 2000), ms(40));
    final shown = interpolator.sample(ms(41))!;
    expect(shown.ballY, 0);
    expect(shown.score2, 1);
  });

  test('grand écart de balle : saut direct', () {
    final interpolator = StateInterpolator(duration: ms(40));
    interpolator.push(state(ballX: -0.5), ms(0));
    interpolator.push(state(tick: 15, ballX: 0.5), ms(40));
    expect(interpolator.sample(ms(41))!.ballX, 0.5);
  });

  test('clear oublie tout', () {
    final interpolator = StateInterpolator()..push(state(), Duration.zero);
    interpolator.clear();
    expect(interpolator.sample(ms(10)), isNull);
    expect(interpolator.latest, isNull);
  });
}
