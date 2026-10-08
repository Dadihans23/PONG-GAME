import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/net/net.dart';

void main() {
  int countSends(NetRateLimiter limiter, int fps, Duration span) {
    var sends = 0;
    final frame = Duration(microseconds: 1000000 ~/ fps);
    for (var t = Duration.zero; t < span; t += frame) {
      if (limiter.shouldSend(t)) sends++;
    }
    return sends;
  }

  for (final fps in [60, 90, 120]) {
    test('30 envois par seconde à $fps images/s', () {
      expect(countSends(NetRateLimiter(), fps, const Duration(seconds: 1)), inInclusiveRange(29, 31));
    });
  }

  test('à 30 images/s ou moins, un envoi par image', () {
    expect(countSends(NetRateLimiter(), 20, const Duration(seconds: 1)), 20);
  });

  test('pas de rafale de rattrapage après une longue image', () {
    final limiter = NetRateLimiter();
    expect(limiter.shouldSend(Duration.zero), isTrue);
    expect(limiter.shouldSend(const Duration(seconds: 2)), isTrue);
    expect(limiter.shouldSend(const Duration(seconds: 2, milliseconds: 1)), isFalse);
  });

  test('reset : le prochain appel envoie', () {
    final limiter = NetRateLimiter();
    limiter.shouldSend(Duration.zero);
    expect(limiter.shouldSend(const Duration(milliseconds: 1)), isFalse);
    limiter.reset();
    expect(limiter.shouldSend(const Duration(milliseconds: 2)), isTrue);
  });
}
