// Champs ajoutés à GameState pour le contrôleur (pause de service, dernier
// marqueur, échanges, temps de jeu) et leur suivi par DuelEngine.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/game/duel_engine.dart';
import 'package:pong_game/game/game_tuning.dart';
import 'package:pong_game/multiplayer/model/duel_phase.dart';
import 'package:pong_game/multiplayer/model/game_state.dart';
import 'package:pong_game/multiplayer/model/player.dart';

Map<String, dynamic> roundTrip(Map<String, dynamic> json) => jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

Map<String, dynamic> baseJson() => roundTrip({
      'tick': 10,
      'phase': 'playing',
      'ball': {'x': 0.0, 'y': 0.0, 'vx': 0.002, 'vy': 0.002},
      'paddles': {'p1': 0.0, 'p2': 0.0},
      'score': {'p1': 1, 'p2': 0},
    });

DuelEngine newDuel() => DuelEngine(
    stepsPerSecond: GameTuning.stepsPerSecond, paddleMaxSpeed: GameTuning.paddleMaxSpeed, random: Random(7));

void main() {
  group('GameState : nouveaux champs', () {
    test('aller-retour JSON avec tous les champs', () {
      const state = GameState(
        tick: 900,
        phase: DuelPhase.playing,
        ballX: 0,
        ballY: 0,
        ballVX: 0.002,
        ballVY: -0.002,
        paddle1X: 0.2,
        paddle2X: -0.3,
        score1: 3,
        score2: 2,
        serveMs: 1500,
        lastScorer: PlayerSlot.player2,
        rally: 0,
        longestRally: 14,
        hits: 40,
        timeMs: 96000,
      );
      final copy = GameState.fromJson(roundTrip(state.toJson()));
      expect(copy, state);
      expect(copy.isServing, isTrue);
      expect(copy.hashCode, state.hashCode);
    });

    test('un état de la première version (sans ces champs) reste lisible', () {
      final state = GameState.fromJson(baseJson());
      expect(state.serveMs, 0);
      expect(state.lastScorer, isNull);
      expect(state.rally, 0);
      expect(state.longestRally, 0);
      expect(state.hits, 0);
      expect(state.timeMs, 0);
      expect(state.isServing, isFalse);
    });

    test('lastScorer null explicite accepté', () {
      final json = baseJson()..['lastScorer'] = null;
      expect(GameState.fromJson(json).lastScorer, isNull);
    });

    test('valeurs invalides rejetées', () {
      final mutations = <String, Object?>{
        'serveMs': -1,
        'lastScorer': 'player3',
        'rally': 1.5,
        'longestRally': '3',
        'hits': -2,
        'timeMs': double.nan,
      };
      for (final entry in mutations.entries) {
        final json = baseJson()..[entry.key] = entry.value;
        expect(() => GameState.fromJson(json), throwsFormatException, reason: entry.key);
      }
      final tooLong = baseJson()..['serveMs'] = GameState.maxServeMs + 1;
      expect(() => GameState.fromJson(tooLong), throwsFormatException);
    });
  });

  group('DuelEngine : échanges et pause de service', () {
    test('renvois comptés, plus long échange retenu, remise à zéro au service', () {
      final engine = newDuel();
      engine.serveTicksRemaining = 0;
      for (int i = 0; i < 3; i++) {
        engine.ballX = engine.player1X;
        engine.ballY = 0.85;
        engine.ballYDirection = BallDirection.down;
        expect(engine.tick(), contains(const DuelEvent.paddleHit(PlayerSlot.player1)));
      }
      expect(engine.rally, 3);
      expect(engine.longestRally, 3);
      expect(engine.totalHits, 3);

      // Point pour le joueur 1 : l'échange repart de zéro
      engine.player2X = -0.9;
      engine.setPlayer2Target(-0.9);
      engine.ballX = 0.9;
      engine.ballSpeedX = 0;
      engine.ballY = -0.999;
      engine.ballYDirection = BallDirection.up;
      expect(engine.tick(), contains(const DuelEvent.pointScored(PlayerSlot.player1)));
      expect(engine.lastScorer, PlayerSlot.player1);
      expect(engine.rally, 0);
      expect(engine.longestRally, 3);
      expect(engine.totalHits, 3);

      final state = engine.snapshot();
      expect(state.lastScorer, PlayerSlot.player1);
      expect(state.serveMs, 2000);
      expect(state.isServing, isTrue);
      expect(state.longestRally, 3);
      expect(state.hits, 3);
      expect(state.timeMs, engine.elapsed.inMilliseconds);
      expect(GameState.fromJson(roundTrip(state.toJson())), state);
    });

    test('reset efface échanges et dernier marqueur', () {
      final engine = newDuel()
        ..rally = 4
        ..longestRally = 9
        ..totalHits = 20
        ..lastScorer = PlayerSlot.player2;
      engine.reset();
      expect(engine.rally, 0);
      expect(engine.longestRally, 0);
      expect(engine.totalHits, 0);
      expect(engine.lastScorer, isNull);
      expect(engine.snapshot().serveMs, 0);
    });

    test('temps de jeu en temps de moteur', () {
      final engine = newDuel();
      for (int i = 0; i < 450; i++) {
        engine.tick();
      }
      expect(engine.elapsed, const Duration(seconds: 1));
      expect(engine.snapshot().timeMs, 1000);
    });
  });
}
