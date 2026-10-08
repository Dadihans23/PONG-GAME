import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/game/pong_engine.dart';

// Moteur avec un Random à graine fixe : les tests sont reproductibles
PongEngine newEngine({String difficulty = 'Normal', int seed = 42}) {
  final engine = PongEngine(difficulty: difficulty, random: Random(seed));
  engine.paddleHalfWidth = 0.3;
  return engine;
}

// Place la balle sur la raquette du joueur, à [offset] du centre, et joue un pas
List<PongEvent> hitWithPlayer(PongEngine engine, {double offset = 0.0}) {
  engine.ballX = engine.playerX + offset;
  engine.ballY = 0.85;
  engine.ballYDirection = BallDirection.down;
  return engine.tick();
}

void main() {
  group('Etat initial', () {
    test('balle au centre, vers le bas et la gauche, score nul', () {
      final engine = newEngine();
      expect(engine.ballX, 0.0);
      expect(engine.ballY, 0.0);
      expect(engine.ballSpeedX, 0.002);
      expect(engine.ballSpeedY, 0.002);
      expect(engine.ballYDirection, BallDirection.down);
      expect(engine.ballXDirection, BallDirection.left);
      expect(engine.playerScore, 0);
      expect(engine.currentStreak, 0);
      expect(engine.isPlayerDead, isFalse);
    });

    test('un pas déplace la balle de sa vitesse, sans événement', () {
      final engine = newEngine();
      final events = engine.tick();
      expect(events, isEmpty);
      expect(engine.ballX, closeTo(-0.002, 1e-12));
      expect(engine.ballY, closeTo(0.002, 1e-12));
    });
  });

  group('Rebond sur les murs', () {
    test('mur gauche : la balle repart vers la droite', () {
      final engine = newEngine();
      engine.ballX = -0.999;
      engine.ballXDirection = BallDirection.left;

      engine.tick(); // La balle atteint le mur, bornée à -1
      expect(engine.ballX, -1.0);
      expect(engine.ballXDirection, BallDirection.left);

      engine.tick(); // Le pas suivant inverse la direction
      expect(engine.ballXDirection, BallDirection.right);
      expect(engine.ballX, closeTo(-0.998, 1e-12));
    });

    test('mur droit : la balle repart vers la gauche', () {
      final engine = newEngine();
      engine.ballX = 0.999;
      engine.ballXDirection = BallDirection.right;

      engine.tick();
      expect(engine.ballX, 1.0);

      engine.tick();
      expect(engine.ballXDirection, BallDirection.left);
      expect(engine.ballX, closeTo(0.998, 1e-12));
    });

    test('la balle ne sort jamais du terrain', () {
      final engine = newEngine();
      for (int i = 0; i < 5000; i++) {
        engine.playerX = engine.ballX; // Le joueur renvoie tout
        engine.tick();
        expect(engine.ballX, inInclusiveRange(-1.0, 1.0));
        expect(engine.ballY, inInclusiveRange(-1.0, 1.0));
      }
    });
  });

  group('Renvoi par le joueur', () {
    test('+50 points, série +1, la balle repart vers le haut', () {
      final engine = newEngine();
      final events = hitWithPlayer(engine);

      expect(events, [PongEvent.playerHit]);
      expect(engine.playerScore, 50);
      expect(engine.currentStreak, 1);
      expect(engine.ballYDirection, BallDirection.up);
      expect(engine.ballY, closeTo(0.848, 1e-12));
    });

    test('un seul renvoi compté par contact', () {
      final engine = newEngine();
      hitWithPlayer(engine);
      for (int i = 0; i < 20; i++) {
        expect(engine.tick(), isEmpty);
      }
      expect(engine.playerScore, 50);
      expect(engine.currentStreak, 1);
    });

    test('pas de renvoi avant la zone de contact', () {
      final engine = newEngine();
      engine.ballY = 0.84;
      engine.ballSpeedY = 0.001;
      final events = engine.tick();
      expect(events, isEmpty);
      expect(engine.ballYDirection, BallDirection.down);
      expect(engine.playerScore, 0);
    });

    test('pas de renvoi si la balle est à côté de la raquette', () {
      final engine = newEngine();
      engine.playerX = -0.5;
      engine.ballX = 0.5;
      engine.ballY = 0.85;
      final events = engine.tick();
      expect(events, isEmpty);
      expect(engine.ballYDirection, BallDirection.down);
      expect(engine.playerScore, 0);
    });

    test('le bord de la raquette compte encore', () {
      final engine = newEngine();
      final events = hitWithPlayer(engine, offset: 0.3);
      expect(events, [PongEvent.playerHit]);
    });
  });

  group('Rebond angulaire', () {
    test('impact au centre : balle verticale, direction horizontale inchangée', () {
      final engine = newEngine();
      hitWithPlayer(engine, offset: 0.0);
      expect(engine.ballSpeedX, 0.0);
      expect(engine.ballXDirection, BallDirection.left);
    });

    test('impact à droite : balle vers la droite, vitesse selon la distance', () {
      final engine = newEngine();
      hitWithPlayer(engine, offset: 0.15); // Moitié de la demi-largeur
      expect(engine.ballXDirection, BallDirection.right);
      expect(engine.ballSpeedX, closeTo(0.5 * 0.002 * 1.5, 1e-12));
    });

    test('impact au bord gauche : balle vers la gauche, vitesse maximale', () {
      final engine = newEngine();
      engine.ballXDirection = BallDirection.right;
      hitWithPlayer(engine, offset: -0.3);
      expect(engine.ballXDirection, BallDirection.left);
      expect(engine.ballSpeedX, closeTo(0.002 * 1.5, 1e-12));
    });

    test('plus l\'impact est loin du centre, plus la balle part en diagonale', () {
      final near = newEngine();
      final far = newEngine();
      hitWithPlayer(near, offset: 0.05);
      hitWithPlayer(far, offset: 0.25);
      expect(far.ballSpeedX, greaterThan(near.ballSpeedX));
    });

    test('le rebond angulaire s\'applique aussi à la raquette ennemie', () {
      final engine = newEngine(difficulty: 'Difficile');
      engine.enemyX = 0.0;
      engine.ballX = 0.2;
      engine.ballY = -0.85;
      engine.ballYDirection = BallDirection.up;
      engine.ballSpeedX = 0.0; // La balle ne bouge pas en X avant le contact

      final events = engine.tick();
      expect(events, [PongEvent.enemyHit]);
      expect(engine.ballYDirection, BallDirection.down);
      expect(engine.ballXDirection, BallDirection.right);
      // L'ennemi s'est rapproché de 0.05 avant le contact : écart de 0.15
      expect(engine.ballSpeedX, closeTo(0.15 / 0.3 * 0.002 * 1.5, 1e-12));
      expect(engine.playerScore, 0);
    });
  });

  group('Accélération', () {
    test('la vitesse verticale augmente de 0.0005 tous les 4 renvois', () {
      final engine = newEngine();
      for (int hit = 1; hit <= 8; hit++) {
        expect(hitWithPlayer(engine), [PongEvent.playerHit]);
        engine.tick(); // La balle quitte la raquette

        final double expected = hit < 4 ? 0.002 : (hit < 8 ? 0.0025 : 0.003);
        expect(engine.ballSpeedY, closeTo(expected, 1e-12), reason: 'après $hit renvois');
      }
      expect(engine.playerScore, 400);
      expect(engine.currentStreak, 8);
    });
  });

  group('Niveau de vitesse', () {
    test('vitesse 1 au service, jauge vide', () {
      final engine = newEngine();
      expect(engine.speedUps, 0);
      expect(engine.speedLevel, 1);
      expect(engine.hitsSinceSpeedUp, 0);
    });

    test('la jauge compte les renvois et repart à zéro à chaque accélération', () {
      final engine = newEngine();
      final gauge = <int>[];
      final levels = <int>[];
      for (int hit = 1; hit <= 9; hit++) {
        hitWithPlayer(engine);
        engine.tick();
        gauge.add(engine.hitsSinceSpeedUp);
        levels.add(engine.speedLevel);
      }
      expect(gauge, [1, 2, 3, 0, 1, 2, 3, 0, 1]);
      expect(levels, [1, 1, 1, 2, 2, 2, 2, 3, 3]);
      expect(engine.speedUps, 2);
    });

    test('le niveau suit exactement les accélérations de la balle', () {
      final engine = newEngine();
      for (int hit = 1; hit <= 12; hit++) {
        hitWithPlayer(engine);
        engine.tick();
        expect(
          engine.ballSpeedY,
          closeTo(PongEngine.initialBallSpeed + engine.speedUps * 0.0005, 1e-12),
          reason: 'après $hit renvois',
        );
      }
      expect(engine.speedUps, 12 ~/ PongEngine.hitsPerSpeedUp);
    });

    test("un point marqué contre l'ennemi ne change ni le niveau ni la jauge", () {
      final engine = newEngine();
      for (int hit = 0; hit < 5; hit++) {
        hitWithPlayer(engine);
        engine.tick();
      }
      engine.ballX = 0.9;
      engine.enemyX = -1.0;
      engine.ballY = -0.85;
      engine.ballYDirection = BallDirection.up;
      expect(engine.tick(), contains(PongEvent.enemyMissed));
      expect(engine.speedLevel, 2);
      expect(engine.hitsSinceSpeedUp, 1);
    });

    test('reset remet le niveau et la jauge à zéro', () {
      final engine = newEngine();
      for (int hit = 0; hit < 6; hit++) {
        hitWithPlayer(engine);
        engine.tick();
      }
      expect(engine.speedLevel, 2);
      engine.reset();
      expect(engine.speedUps, 0);
      expect(engine.speedLevel, 1);
      expect(engine.hitsSinceSpeedUp, 0);
    });
  });

  group('Ennemi', () {
    test('l\'ennemi renvoie la balle : pas de point', () {
      final engine = newEngine();
      engine.ballY = -0.85;
      engine.ballYDirection = BallDirection.up;

      final events = engine.tick();
      expect(events, [PongEvent.enemyHit]);
      expect(engine.ballYDirection, BallDirection.down);
      expect(engine.playerScore, 0);
    });

    test('l\'ennemi rate : +100 points et balle remise au centre', () {
      final engine = newEngine();
      engine.enemyX = -0.9;
      engine.ballX = 0.9;
      engine.ballY = -0.85;
      engine.ballYDirection = BallDirection.up;
      engine.ballSpeedX = 0.004;
      engine.ballSpeedY = 0.003;

      final events = engine.tick();
      expect(events, [PongEvent.enemyMissed]);
      expect(engine.playerScore, 100);
      expect(engine.currentStreak, 0);
      expect(engine.ballYDirection, BallDirection.down);
      expect(engine.ballSpeedX, 0.002);
      // La vitesse verticale acquise est conservée
      expect(engine.ballSpeedY, 0.003);
      // Remise au centre, puis déplacement d'un pas
      expect(engine.ballX, closeTo(-0.002, 1e-12));
      expect(engine.ballY, closeTo(0.003, 1e-12));
    });

    test('vitesse maximale par pas : Facile < Normal < Difficile', () {
      double moveOf(String difficulty) {
        final engine = newEngine(difficulty: difficulty);
        engine.enemyX = -1.0;
        engine.ballX = 1.0;
        engine.tick();
        return engine.enemyX + 1.0;
      }

      final facile = moveOf('Facile');
      final normal = moveOf('Normal');
      final difficile = moveOf('Difficile');

      expect(facile, closeTo(0.01, 1e-12));
      expect(normal, closeTo(0.03, 1e-12));
      expect(difficile, closeTo(0.05, 1e-12));
      expect(facile, lessThan(difficile));
    });

    test('une difficulté inconnue se comporte comme Difficile', () {
      final engine = newEngine(difficulty: 'Autre');
      engine.enemyX = -1.0;
      engine.ballX = 1.0;
      engine.tick();
      expect(engine.enemyX, closeTo(-0.95, 1e-12));
    });

    test('l\'ennemi rejoint la balle quand elle est à portée', () {
      final engine = newEngine(difficulty: 'Difficile');
      engine.ballSpeedX = 0.0;
      engine.ballX = 0.02;
      engine.tick();
      // Premier pas : pas encore de décalage aléatoire appliqué à la cible
      expect(engine.enemyX, closeTo(0.02, 1e-12));
    });
  });

  group('Défaite', () {
    test('la balle passe à côté de la raquette : playerDead', () {
      final engine = newEngine();
      engine.playerX = -0.9;
      engine.ballX = 0.9;
      engine.ballY = 0.999;
      engine.ballXDirection = BallDirection.right;

      final events = engine.tick();
      expect(events, [PongEvent.playerDead]);
      expect(engine.isPlayerDead, isTrue);
      expect(engine.ballY, 1.0);
      expect(engine.playerScore, 0);
    });

    test('partie sans bouger : le joueur perd au premier passage, score nul', () {
      final engine = newEngine();
      int ticks = 0;
      List<PongEvent> events = [];
      while (!events.contains(PongEvent.playerDead) && ticks < 2000) {
        events = engine.tick();
        ticks++;
      }
      // Balle partie du centre à 0.002 par pas : 500 pas pour atteindre le bas
      // (501 selon l'arrondi des additions en virgule flottante)
      expect(ticks, inInclusiveRange(500, 501));
      expect(engine.isPlayerDead, isTrue);
      expect(engine.playerScore, 0);
      expect(engine.currentStreak, 0);
    });

    test('pas de défaite tant que la balle n\'a pas atteint le bas', () {
      final engine = newEngine();
      engine.playerX = -0.9;
      engine.ballX = 0.9;
      engine.ballY = 0.9;
      expect(engine.tick(), isEmpty);
      expect(engine.isPlayerDead, isFalse);
    });
  });

  group('reset', () {
    test('remet la balle, le score, les vitesses et le joueur à zéro', () {
      final engine = newEngine();
      engine.movePlayer(0.4);
      for (int hit = 0; hit < 5; hit++) {
        hitWithPlayer(engine, offset: 0.1);
        engine.tick();
      }
      expect(engine.playerScore, 250);
      expect(engine.ballSpeedY, greaterThan(0.002));

      engine.reset();

      expect(engine.ballX, 0.0);
      expect(engine.ballY, 0.0);
      expect(engine.ballSpeedX, 0.002);
      expect(engine.ballSpeedY, 0.002);
      expect(engine.ballXDirection, BallDirection.left);
      expect(engine.playerX, 0.0);
      expect(engine.playerScore, 0);
      expect(engine.currentStreak, 0);
      expect(engine.isPlayerDead, isFalse);
    });

    test('le compteur d\'accélération repart de zéro', () {
      final engine = newEngine();
      for (int hit = 0; hit < 3; hit++) {
        hitWithPlayer(engine);
        engine.tick();
      }
      engine.reset();

      // 3 renvois après la remise à zéro : toujours pas d'accélération
      for (int hit = 0; hit < 3; hit++) {
        hitWithPlayer(engine);
        engine.tick();
      }
      expect(engine.ballSpeedY, closeTo(0.002, 1e-12));
    });

    test('après une défaite, la partie suivante démarre vers le bas', () {
      final engine = newEngine();
      while (!engine.tick().contains(PongEvent.playerDead)) {}
      engine.reset();
      expect(engine.ballYDirection, BallDirection.down);
      expect(engine.tick(), isEmpty);
      expect(engine.ballY, closeTo(0.002, 1e-12));
    });
  });

  group('Bornes des raquettes', () {
    test('la raquette du joueur reste entre -1 et 1', () {
      final engine = newEngine();
      engine.movePlayer(0.25);
      expect(engine.playerX, 0.25);
      engine.movePlayer(5);
      expect(engine.playerX, 1.0);
      engine.movePlayer(-10);
      expect(engine.playerX, -1.0);
    });

    test('la raquette ennemie reste entre -1 et 1 dans les trois difficultés', () {
      for (final difficulty in ['Facile', 'Normal', 'Difficile']) {
        final engine = newEngine(difficulty: difficulty);
        for (int i = 0; i < 20000; i++) {
          engine.playerX = engine.ballX; // Le joueur renvoie tout
          engine.tick();
          expect(engine.enemyX, inInclusiveRange(-1.0, 1.0), reason: difficulty);
        }
      }
    });
  });

  group('Vitesse de la raquette du joueur', () {
    test('vitesse nulle par défaut : la raquette ne bouge pas', () {
      final engine = newEngine();
      engine.playerX = 0.3;
      expect(engine.playerSpeed, 0.0);
      for (int i = 0; i < 100; i++) {
        engine.tick();
      }
      expect(engine.playerX, 0.3);
    });

    test('la raquette avance de playerSpeed à chaque pas', () {
      final engine = newEngine();
      engine.playerSpeed = 0.002;
      engine.tick();
      expect(engine.playerX, closeTo(0.002, 1e-12));
      for (int i = 0; i < 99; i++) {
        engine.tick();
      }
      expect(engine.playerX, closeTo(0.2, 1e-9));
    });

    test('vitesse négative : la raquette va vers la gauche', () {
      final engine = newEngine();
      engine.playerSpeed = -0.003;
      for (int i = 0; i < 10; i++) {
        engine.tick();
      }
      expect(engine.playerX, closeTo(-0.03, 1e-12));
    });

    test('la raquette s\'arrête dès que la vitesse revient à zéro', () {
      final engine = newEngine();
      engine.playerSpeed = 0.01;
      for (int i = 0; i < 5; i++) {
        engine.tick();
      }
      engine.playerSpeed = 0.0;
      final double stoppedAt = engine.playerX;
      for (int i = 0; i < 50; i++) {
        engine.tick();
      }
      expect(engine.playerX, stoppedAt);
    });

    test('la raquette reste entre -1 et 1', () {
      final engine = newEngine();
      engine.playerX = 0.99;
      engine.playerSpeed = 0.004;
      for (int i = 0; i < 10; i++) {
        engine.tick();
        expect(engine.playerX, inInclusiveRange(-1.0, 1.0));
      }
      expect(engine.playerX, 1.0);

      engine.playerX = -0.99;
      engine.playerSpeed = -0.004;
      for (int i = 0; i < 10; i++) {
        engine.tick();
      }
      expect(engine.playerX, -1.0);
    });

    test('la raquette est déplacée avant le test de contact du même pas', () {
      final engine = newEngine();
      // Balle juste hors de portée de la raquette (demi-largeur 0.3)
      engine.playerX = 0.0;
      engine.ballX = 0.305;
      engine.ballY = 0.85;
      engine.ballSpeedX = 0.0;
      engine.playerSpeed = 0.01;

      final events = engine.tick();
      expect(events, [PongEvent.playerHit]);
      expect(engine.playerX, closeTo(0.01, 1e-12));
    });

    test('la vitesse de la raquette ne change pas la balle', () {
      final still = newEngine();
      final moving = newEngine();
      moving.playerSpeed = 0.002;
      for (int i = 0; i < 300; i++) {
        still.tick();
        moving.tick();
      }
      expect(moving.ballX, still.ballX);
      expect(moving.ballY, still.ballY);
      expect(moving.enemyX, still.enemyX);
    });

    test('reset remet la vitesse de la raquette à zéro', () {
      final engine = newEngine();
      engine.playerSpeed = 0.002;
      engine.tick();
      engine.reset();
      expect(engine.playerSpeed, 0.0);
      expect(engine.playerX, 0.0);
      engine.tick();
      expect(engine.playerX, 0.0);
    });
  });

  group('Déterminisme', () {
    test('même graine et mêmes entrées : même partie', () {
      final a = newEngine(difficulty: 'Facile', seed: 7);
      final b = newEngine(difficulty: 'Facile', seed: 7);
      for (int i = 0; i < 20000; i++) {
        a.playerX = a.ballX;
        b.playerX = b.ballX;
        expect(a.tick(), b.tick());
      }
      expect(a.ballX, b.ballX);
      expect(a.ballY, b.ballY);
      expect(a.enemyX, b.enemyX);
      expect(a.playerScore, b.playerScore);
      expect(a.playerScore, greaterThan(0));
    });
  });
}
