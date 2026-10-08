import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/game/duel_engine.dart';
import 'package:pong_game/game/pong_engine.dart';
import 'package:pong_game/multiplayer/model/duel_phase.dart';
import 'package:pong_game/multiplayer/model/game_state.dart';
import 'package:pong_game/multiplayer/model/player.dart';

// Mêmes réglages que l'écran de jeu du solo
const int stepsPerSecond = 450;
const double paddleMaxSpeed = 1.42;
const double maxStep = paddleMaxSpeed / stepsPerSecond;

const p1 = PlayerSlot.player1;
const p2 = PlayerSlot.player2;

// Moteur avec un Random à graine fixe : les tests sont reproductibles
DuelEngine newDuel({int seed = 42}) =>
    DuelEngine(stepsPerSecond: stepsPerSecond, paddleMaxSpeed: paddleMaxSpeed, random: Random(seed));

// Place la raquette du joueur 2 (position et cible) en [x]
void placePlayer2(DuelEngine engine, double x) {
  engine.player2X = x;
  engine.setPlayer2Target(x);
}

// La balle passe derrière la raquette du perdant au prochain pas
List<DuelEvent> scorePoint(DuelEngine engine, PlayerSlot scorer) {
  engine.serveTicksRemaining = 0;
  engine.ballX = 0.9;
  engine.ballSpeedX = 0.0;
  if (scorer == p2) {
    engine.player1X = -0.9;
    engine.ballY = 0.999;
    engine.ballYDirection = BallDirection.down;
  } else {
    placePlayer2(engine, -0.9);
    engine.ballY = -0.999;
    engine.ballYDirection = BallDirection.up;
  }
  return engine.tick();
}

// Place la balle sur la raquette de [player], à [offset] de son centre, et joue un pas
List<DuelEvent> hitWith(DuelEngine engine, PlayerSlot player, {double offset = 0.0}) {
  engine.serveTicksRemaining = 0;
  if (player == p1) {
    engine.ballX = engine.player1X + offset;
    engine.ballY = 0.85;
    engine.ballYDirection = BallDirection.down;
  } else {
    engine.ballX = engine.player2X + offset;
    engine.ballY = -0.85;
    engine.ballYDirection = BallDirection.up;
  }
  return engine.tick();
}

void main() {
  group('Etat initial', () {
    test('score nul, balle au centre à la vitesse de départ, service immédiat', () {
      final engine = newDuel();
      expect(engine.score1, 0);
      expect(engine.score2, 0);
      expect(engine.ballX, 0.0);
      expect(engine.ballY, 0.0);
      expect(engine.ballSpeedX, PongEngine.initialBallSpeed);
      expect(engine.ballSpeedY, PongEngine.initialBallSpeed);
      expect(engine.player1X, 0.0);
      expect(engine.player2X, 0.0);
      expect(engine.isServing, isFalse);
      expect(engine.isFinished, isFalse);
      expect(engine.winner, isNull);
      expect(engine.tickCount, 0);
      expect(engine.speedLevel, 1);
    });

    test('pause de service et vitesse maximale déduites du rythme du moteur', () {
      final engine = newDuel();
      expect(engine.serveDelayTicks, 900);
      expect(engine.maxPaddleStep, closeTo(1.42 / 450, 1e-15));
    });

    test('le premier pas déplace déjà la balle', () {
      final engine = newDuel();
      final events = engine.tick();
      expect(events, isEmpty);
      expect(engine.ballY.abs(), closeTo(0.002, 1e-12));
      expect(engine.ballX.abs(), closeTo(0.002, 1e-12));
      expect(engine.tickCount, 1);
    });
  });

  group('Points', () {
    test('la balle passe en bas : point pour le joueur 2', () {
      final engine = newDuel();
      expect(scorePoint(engine, p2), [const DuelEvent.pointScored(p2)]);
      expect(engine.score1, 0);
      expect(engine.score2, 1);
    });

    test('la balle passe en haut : point pour le joueur 1', () {
      final engine = newDuel();
      expect(scorePoint(engine, p1), [const DuelEvent.pointScored(p1)]);
      expect(engine.score1, 1);
      expect(engine.score2, 0);
    });

    test('pas de point tant que la balle n\'a pas atteint le bord', () {
      final engine = newDuel();
      engine.player1X = -0.9;
      engine.ballX = 0.9;
      engine.ballY = 0.9;
      engine.ballYDirection = BallDirection.down;
      expect(engine.tick(), isEmpty);
      expect(engine.score2, 0);
    });

    test('la raquette rattrape encore la balle entre la zone de contact et le bord', () {
      final engine = newDuel();
      engine.ballX = 0.0;
      engine.ballSpeedX = 0.0;
      engine.ballY = 0.97;
      engine.ballYDirection = BallDirection.down;
      expect(engine.tick(), [const DuelEvent.paddleHit(p1)]);
      expect(engine.score2, 0);
    });
  });

  group('Remise en jeu', () {
    test('après un point : balle au centre, vitesse de départ, vers le perdant', () {
      final engine = newDuel();
      // Balle accélérée par 8 renvois
      for (int i = 0; i < 4; i++) {
        hitWith(engine, p1);
        hitWith(engine, p2);
      }
      expect(engine.ballSpeedY, greaterThan(PongEngine.initialBallSpeed));

      scorePoint(engine, p1);
      expect(engine.ballX, 0.0);
      expect(engine.ballY, 0.0);
      expect(engine.ballSpeedX, PongEngine.initialBallSpeed);
      expect(engine.ballSpeedY, PongEngine.initialBallSpeed);
      expect(engine.speedLevel, 1);
      expect(engine.hitsSinceSpeedUp, 0);
      // Le joueur 2 a perdu le point : la balle part vers lui (en haut)
      expect(engine.ballYDirection, BallDirection.up);

      scorePoint(engine, p2);
      // Le joueur 1 a perdu le point : la balle part vers lui (en bas)
      expect(engine.ballYDirection, BallDirection.down);
    });

    test('pause de deux secondes avant le service : balle immobile puis « served »', () {
      final engine = newDuel();
      scorePoint(engine, p2);
      expect(engine.isServing, isTrue);
      expect(engine.serveTicksRemaining, 900);
      expect(engine.serveRemainingMs, 2000);

      for (int i = 0; i < 899; i++) {
        expect(engine.tick(), isEmpty);
        expect(engine.ballX, 0.0);
        expect(engine.ballY, 0.0);
      }
      expect(engine.serveRemainingMs, 3); // 1 pas = 2,2 ms, arrondi au supérieur
      // 900e pas : fin de la pause, la balle part vers le joueur 1 qui a perdu
      expect(engine.tick(), [const DuelEvent.served(p1)]);
      expect(engine.isServing, isFalse);
      expect(engine.ballY, 0.0);

      engine.tick();
      expect(engine.ballY, closeTo(0.002, 1e-12));
      expect(engine.ballX.abs(), closeTo(0.002, 1e-12));
    });

    test('les raquettes bougent pendant la pause de service', () {
      final engine = newDuel();
      scorePoint(engine, p1);
      engine.player1X = 0.0;
      engine.player1Speed = maxStep;
      engine.setPlayer2Target(0.5);
      final double start2 = engine.player2X;
      for (int i = 0; i < 10; i++) {
        engine.tick();
      }
      expect(engine.isServing, isTrue);
      expect(engine.player1X, closeTo(10 * maxStep, 1e-12));
      expect(engine.player2X, closeTo(start2 + 10 * maxStep, 1e-12));
    });

    test('le numéro de pas avance aussi pendant la pause', () {
      final engine = newDuel();
      scorePoint(engine, p1);
      final int before = engine.tickCount;
      for (int i = 0; i < 100; i++) {
        engine.tick();
      }
      expect(engine.tickCount, before + 100);
    });

    test('le côté du service est tiré au sort', () {
      final sides = <BallDirection>{};
      for (int seed = 0; seed < 20; seed++) {
        final engine = newDuel(seed: seed);
        scorePoint(engine, p1);
        sides.add(engine.ballXDirection);
      }
      expect(sides, {BallDirection.left, BallDirection.right});
    });
  });

  group('Victoire', () {
    test('premier à 5 points : pointScored puis gameWon, partie figée', () {
      final engine = newDuel();
      for (int i = 0; i < 4; i++) {
        expect(scorePoint(engine, p1), [const DuelEvent.pointScored(p1)]);
      }
      expect(engine.isFinished, isFalse);

      expect(scorePoint(engine, p1), [const DuelEvent.pointScored(p1), const DuelEvent.gameWon(p1)]);
      expect(engine.score1, 5);
      expect(engine.winner, p1);
      expect(engine.isFinished, isTrue);
      expect(engine.isServing, isFalse);

      // Plus rien ne bouge après la victoire
      final int tickAtEnd = engine.tickCount;
      final double ballY = engine.ballY;
      engine.player1Speed = maxStep;
      for (int i = 0; i < 100; i++) {
        expect(engine.tick(), isEmpty);
      }
      expect(engine.tickCount, tickAtEnd);
      expect(engine.ballY, ballY);
      expect(engine.score1, 5);
    });

    test('4 à 4 : le point suivant décide', () {
      final engine = newDuel();
      for (int i = 0; i < 4; i++) {
        scorePoint(engine, p1);
        scorePoint(engine, p2);
      }
      expect(engine.score1, 4);
      expect(engine.score2, 4);
      expect(engine.isFinished, isFalse);

      expect(scorePoint(engine, p2), [const DuelEvent.pointScored(p2), const DuelEvent.gameWon(p2)]);
      expect(engine.winner, p2);
      expect(engine.score1, 4);
    });

    test('reset après une victoire : nouvelle partie', () {
      final engine = newDuel();
      for (int i = 0; i < 5; i++) {
        scorePoint(engine, p2);
      }
      expect(engine.isFinished, isTrue);

      engine.reset();
      expect(engine.isFinished, isFalse);
      expect(engine.winner, isNull);
      expect(engine.score1, 0);
      expect(engine.score2, 0);
      expect(engine.tickCount, 0);
      expect(engine.ballX, 0.0);
      expect(engine.ballY, 0.0);
      expect(engine.isServing, isFalse);
    });
  });

  group('Renvois', () {
    test('renvoi du joueur 1 : la balle repart vers le haut, sans point', () {
      final engine = newDuel();
      expect(hitWith(engine, p1), [const DuelEvent.paddleHit(p1)]);
      expect(engine.ballYDirection, BallDirection.up);
      expect(engine.score1 + engine.score2, 0);
    });

    test('renvoi du joueur 2 : la balle repart vers le bas, sans point', () {
      final engine = newDuel();
      expect(hitWith(engine, p2), [const DuelEvent.paddleHit(p2)]);
      expect(engine.ballYDirection, BallDirection.down);
      expect(engine.score1 + engine.score2, 0);
    });

    test('un seul renvoi par contact', () {
      final engine = newDuel();
      hitWith(engine, p1);
      for (int i = 0; i < 20; i++) {
        expect(engine.tick(), isEmpty);
      }
    });

    test('accélération tous les 8 renvois, des deux joueurs confondus', () {
      final engine = newDuel();
      for (int hit = 1; hit <= 16; hit++) {
        hitWith(engine, hit.isOdd ? p1 : p2);
        final double expected = hit < 8 ? 0.002 : (hit < 16 ? 0.0025 : 0.003);
        expect(engine.ballSpeedY, closeTo(expected, 1e-12), reason: 'après $hit renvois');
      }
      expect(engine.speedLevel, 3);
    });

    test('rebond angulaire identique au solo, pour les deux raquettes', () {
      for (final offset in [-0.37, -0.2, 0.0, 0.1, 0.3]) {
        // Même direction horizontale qu'au service du solo (vers la gauche)
        final duel = newDuel()..ballXDirection = BallDirection.left;
        final solo = PongEngine(difficulty: 'Normal', random: Random(1))..paddleHalfWidth = 0.37;
        hitWith(duel, p1, offset: offset);
        solo.ballX = solo.playerX + offset;
        solo.ballY = 0.85;
        solo.tick();
        expect(duel.ballSpeedX, solo.ballSpeedX, reason: 'décalage $offset');
        expect(duel.ballXDirection, solo.ballXDirection, reason: 'décalage $offset');
        expect(duel.ballY, solo.ballY, reason: 'décalage $offset');

        // Raquette du haut : même vitesse horizontale, même sens par rapport au centre
        final top = newDuel()..ballXDirection = BallDirection.left;
        hitWith(top, p2, offset: offset);
        expect(top.ballSpeedX, solo.ballSpeedX, reason: 'haut, décalage $offset');
        expect(top.ballXDirection, solo.ballXDirection, reason: 'haut, décalage $offset');
      }
    });
  });

  group('Largeur de raquette', () {
    test('demi-largeur de contact constante : 0,37, dont 0,10 de tolérance', () {
      final engine = newDuel();
      expect(engine.paddleHalfWidth, 0.37);
      expect(DuelEngine.contactHalfWidth, 0.37);
      expect(DuelEngine.visualHalfWidth, closeTo(0.27, 1e-12));
      // Elle ne change pas pendant la partie
      for (int i = 0; i < 2000; i++) {
        engine.tick();
      }
      expect(engine.paddleHalfWidth, 0.37);
    });

    test('le bord de la raquette compte, juste au-delà non', () {
      for (final player in PlayerSlot.values) {
        for (final side in [-1.0, 1.0]) {
          final edge = newDuel();
          expect(hitWith(edge, player, offset: side * 0.37), [DuelEvent.paddleHit(player)],
              reason: '$player, bord $side');

          final beyond = newDuel();
          beyond.ballSpeedX = 0.0;
          expect(hitWith(beyond, player, offset: side * 0.375), isEmpty, reason: '$player, au-delà $side');
        }
      }
    });
  });

  group('Raquette du joueur 1 (vitesse par pas)', () {
    test('avance de player1Speed à chaque pas', () {
      final engine = newDuel();
      engine.player1Speed = 0.001;
      for (int i = 0; i < 10; i++) {
        engine.tick();
      }
      expect(engine.player1X, closeTo(0.01, 1e-12));
    });

    test('vitesse plafonnée à la vitesse maximale commune', () {
      final engine = newDuel();
      engine.player1Speed = 0.5;
      engine.tick();
      expect(engine.player1X, closeTo(maxStep, 1e-15));
      engine.player1Speed = -0.5;
      engine.tick();
      engine.tick();
      expect(engine.player1X, closeTo(-maxStep, 1e-15));
    });

    test('reste entre -1 et 1', () {
      final engine = newDuel();
      engine.player1X = 0.999;
      engine.player1Speed = maxStep;
      for (int i = 0; i < 10; i++) {
        engine.tick();
      }
      expect(engine.player1X, 1.0);
    });
  });

  group('Raquette du joueur 2 (position reçue)', () {
    test('rejoint la position reçue à vitesse plafonnée, sans téléportation', () {
      final engine = newDuel();
      engine.setPlayer2Target(1.0);
      engine.tick();
      expect(engine.player2X, closeTo(maxStep, 1e-15));
      double previous = engine.player2X;
      int ticks = 1;
      while (engine.player2X < 1.0 && ticks < 10000) {
        engine.tick();
        ticks++;
        expect(engine.player2X - previous, lessThanOrEqualTo(maxStep + 1e-15));
        previous = engine.player2X;
      }
      // 1 unité à 1,42 unité par seconde : environ 0,7 s, soit 317 pas
      expect(ticks, (1.0 / maxStep).ceil());
      expect(engine.player2X, 1.0);

      // Arrivée : elle ne bouge plus
      for (int i = 0; i < 10; i++) {
        engine.tick();
      }
      expect(engine.player2X, 1.0);
    });

    test('une cible à moins d\'un pas est atteinte exactement', () {
      final engine = newDuel();
      engine.setPlayer2Target(maxStep / 2);
      engine.tick();
      expect(engine.player2X, maxStep / 2);
    });

    test('cible bornée au terrain, valeur non finie ignorée', () {
      final engine = newDuel();
      engine.setPlayer2Target(5.0);
      expect(engine.player2Target, 1.0);
      engine.setPlayer2Target(-3.0);
      expect(engine.player2Target, -1.0);
      engine.setPlayer2Target(double.nan);
      expect(engine.player2Target, -1.0);
      engine.setPlayer2Target(double.infinity);
      expect(engine.player2Target, -1.0);
    });

    test('suit une raquette envoyée 30 fois par seconde, sans retard qui s\'accumule', () {
      final engine = newDuel();
      // Le Client déplace sa raquette à la vitesse maximale, aller et retour,
      // et envoie sa position tous les 15 pas (450 / 30)
      double clientX = 0.0;
      double direction = 1.0;
      double previous = engine.player2X;
      for (int i = 1; i <= 3000; i++) {
        clientX += direction * maxStep;
        if (clientX >= 1.0 || clientX <= -1.0) {
          clientX = clientX.clamp(-1.0, 1.0);
          direction = -direction;
        }
        if (i % 15 == 0) {
          engine.setPlayer2Target(clientX);
        }
        engine.tick();
        expect((engine.player2X - previous).abs(), lessThanOrEqualTo(maxStep + 1e-12));
        previous = engine.player2X;
        // Retard borné à l'intervalle entre deux messages
        expect((engine.player2X - clientX).abs(), lessThanOrEqualTo(30 * maxStep + 1e-9), reason: 'pas $i');
      }
    });
  });

  group('État pour le réseau', () {
    test('snapshot reflète le moteur, vitesses signées', () {
      final engine = newDuel();
      engine.ballX = 0.2;
      engine.ballY = -0.3;
      engine.ballSpeedX = 0.001;
      engine.ballSpeedY = 0.0025;
      engine.ballXDirection = BallDirection.left;
      engine.ballYDirection = BallDirection.up;
      engine.player1X = 0.4;
      engine.player2X = -0.6;
      engine.score1 = 3;
      engine.score2 = 2;

      final state = engine.snapshot();
      expect(state.ballX, 0.2);
      expect(state.ballY, -0.3);
      expect(state.ballVX, -0.001);
      expect(state.ballVY, -0.0025);
      expect(state.paddle1X, 0.4);
      expect(state.paddle2X, -0.6);
      expect(state.score1, 3);
      expect(state.score2, 2);
      expect(state.phase, DuelPhase.playing);
      expect(state.tick, 0);
    });

    test('après la victoire : phase finished et gagnant', () {
      final engine = newDuel();
      for (int i = 0; i < 5; i++) {
        scorePoint(engine, p2);
      }
      final state = engine.snapshot();
      expect(state.phase, DuelPhase.finished);
      expect(state.winner, p2);
    });

    test('les états d\'une partie entière passent par JSON sans perte', () {
      final engine = newDuel(seed: 3);
      for (int i = 0; i < 5000; i++) {
        engine.player1Speed = (engine.ballX - engine.player1X).clamp(-maxStep, maxStep);
        engine.setPlayer2Target(engine.ballX * 0.5);
        engine.tick();
        if (i % 50 == 0) {
          final state = engine.snapshot();
          expect(GameState.fromJson(jsonDecode(jsonEncode(state.toJson()))), state);
        }
      }
    });
  });

  group('Déterminisme', () {
    // Entrées scriptées, imparfaites pour que des points soient marqués
    List<List<DuelEvent>> play(DuelEngine engine) {
      final history = <List<DuelEvent>>[];
      int i = 0;
      while (!engine.isFinished && i < 500000) {
        engine.player1Speed = engine.ballX + 0.45 * sin(i / 170) - engine.player1X;
        engine.setPlayer2Target(engine.ballX + 0.5 * cos(i / 230));
        history.add(engine.tick());
        i++;
      }
      return history;
    }

    test('même graine et mêmes entrées : même partie, jusqu\'à la victoire', () {
      final a = newDuel(seed: 7);
      final b = newDuel(seed: 7);
      final historyA = play(a);
      final historyB = play(b);

      expect(a.isFinished, isTrue);
      expect(historyA, historyB);
      expect(a.snapshot(), b.snapshot());
      expect(a.scoreOf(a.winner!), 5);
      // La partie a eu de vrais échanges, pas seulement des points
      expect(historyA.expand((e) => e).where((e) => e.type == DuelEventType.paddleHit), isNotEmpty);
    });
  });

  group('Vitesse propre à chaque raquette (sensibilités différentes)', () {
    // Plafond commun 3 unités/s ; joueur 1 à 1,2, joueur 2 à 2,4
    DuelEngine twoSpeeds() {
      final engine = DuelEngine(stepsPerSecond: stepsPerSecond, paddleMaxSpeed: 3.0, random: Random(42))
        ..setPaddleMaxSpeed(p1, 1.2)
        ..setPaddleMaxSpeed(p2, 2.4)
        ..serveTicksRemaining = 1000; // balle immobile
      return engine;
    }

    test('sans réglage : chaque raquette peut atteindre le plafond commun', () {
      final engine = DuelEngine(stepsPerSecond: stepsPerSecond, paddleMaxSpeed: 3.0, random: Random(1));
      expect(engine.maxStepOf(p1), closeTo(3.0 / stepsPerSecond, 1e-15));
      expect(engine.maxStepOf(p2), closeTo(3.0 / stepsPerSecond, 1e-15));
    });

    test('le joueur 1 est plafonné à sa propre vitesse', () {
      final engine = twoSpeeds()..player1Speed = 1.0;
      for (int i = 0; i < 45; i++) {
        engine.tick();
      }
      expect(engine.player1X, closeTo(1.2 * 45 / stepsPerSecond, 1e-12));
    });

    test('le joueur 2 rejoint sa cible à sa propre vitesse, plus vite que le joueur 1', () {
      final engine = twoSpeeds()..setPlayer2Target(1.0);
      engine.player1Speed = 1.0;
      for (int i = 0; i < 45; i++) {
        engine.tick();
      }
      expect(engine.player2X, closeTo(2.4 * 45 / stepsPerSecond, 1e-12));
      expect(engine.player1X, closeTo(1.2 * 45 / stepsPerSecond, 1e-12));
    });

    test('jamais au-delà du plafond commun', () {
      final engine = twoSpeeds()
        ..setPaddleMaxSpeed(p1, 50.0)
        ..setPaddleMaxSpeed(p2, 9.0);
      expect(engine.maxStepOf(p1), closeTo(3.0 / stepsPerSecond, 1e-15));
      expect(engine.maxStepOf(p2), closeTo(3.0 / stepsPerSecond, 1e-15));
      engine.player1Speed = 1.0;
      engine.setPlayer2Target(-1.0);
      engine.tick();
      expect(engine.player1X, closeTo(3.0 / stepsPerSecond, 1e-15));
      expect(engine.player2X, closeTo(-3.0 / stepsPerSecond, 1e-15));
    });

    test('valeur non finie ou nulle : ignorée', () {
      final engine = twoSpeeds()
        ..setPaddleMaxSpeed(p1, double.nan)
        ..setPaddleMaxSpeed(p2, 0)
        ..setPaddleMaxSpeed(p2, -1);
      expect(engine.maxStepOf(p1), closeTo(1.2 / stepsPerSecond, 1e-15));
      expect(engine.maxStepOf(p2), closeTo(2.4 / stepsPerSecond, 1e-15));
    });

    test('les vitesses survivent à reset (revanche)', () {
      final engine = twoSpeeds()..reset();
      expect(engine.maxStepOf(p1), closeTo(1.2 / stepsPerSecond, 1e-15));
      expect(engine.maxStepOf(p2), closeTo(2.4 / stepsPerSecond, 1e-15));
    });
  });
}
