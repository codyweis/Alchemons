
import 'package:alchemons/games/shared/damage_numbers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Damage numbers are the only combat feedback that tells you whether you are
/// actually hurting a boss. They must stay legible and must never grow without
/// bound during a sustained beam.
void main() {
  group('spawning', () {
    test('sub-1 chip damage is dropped rather than rendered as "0"', () {
      final f = DamageNumberField();
      f.spawn(Offset.zero, 0.4);
      expect(f.isEmpty, isTrue);
    });

    test('small hits keep one decimal so they never read as zero', () {
      final f = DamageNumberField();
      f.spawn(Offset.zero, 4.26);
      expect(f.numbers.single.label, '4.3');
    });

    test('real hits round to whole numbers', () {
      final f = DamageNumberField();
      f.spawn(Offset.zero, 137.6);
      expect(f.numbers.single.label, '138');
    });

    test('heavy hits are flagged big', () {
      final f = DamageNumberField(bigThreshold: 40);
      f.spawn(Offset.zero, 39);
      f.spawn(Offset.zero, 40);
      expect(f.numbers.first.isBig, isFalse);
      expect(f.numbers.last.isBig, isTrue);
    });

    test('jitter offsets the spawn so stacked hits stay readable', () {
      final f = DamageNumberField();
      f.spawn(const Offset(100, 100), 10, jitter: const Offset(6, -20));
      expect(f.numbers.single.position, const Offset(106, 80));
    });
  });

  group('the pool is bounded', () {
    test('a sustained beam cannot grow the list without bound', () {
      final f = DamageNumberField(maxNumbers: 40);
      for (var i = 0; i < 500; i++) {
        f.spawn(Offset.zero, 10);
      }
      expect(f.length, lessThanOrEqualTo(40));
    });

    test('the newest hit always survives the cap', () {
      final f = DamageNumberField(maxNumbers: 3);
      for (var i = 1; i <= 10; i++) {
        f.spawn(Offset.zero, i * 100.0);
      }
      expect(f.numbers.last.label, '1000');
      expect(f.length, 3);
    });
  });

  group('lifetime', () {
    test('numbers rise and then expire', () {
      final f = DamageNumberField();
      f.spawn(Offset.zero, 10);
      final startY = f.numbers.single.position.dy;
      f.update(0.1);
      expect(f.numbers.single.position.dy, lessThan(startY));
      f.update(2.0);
      expect(f.isEmpty, isTrue, reason: 'nothing may linger on screen');
    });

    test('t runs 0 to 1 across the life', () {
      final f = DamageNumberField();
      f.spawn(Offset.zero, 10);
      final d = f.numbers.single;
      expect(d.t, closeTo(0, 1e-9));
      f.update(d.maxLife / 2);
      expect(d.t, closeTo(0.5, 1e-6));
    });

    test('clear empties the pool', () {
      final f = DamageNumberField();
      f.spawn(Offset.zero, 10);
      f.clear();
      expect(f.isEmpty, isTrue);
    });
  });
}
