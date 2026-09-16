import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the hazard that crashed the hatching ceremony at its final beat.
///
/// `Curves.easeOutBack` overshoots ABOVE 1.0, and `TweenSequence.transform`
/// asserts its input is within 0..1. Driving a TweenSequence with an
/// overshooting curve therefore throws the moment the overshoot peaks — which
/// in the ceremony was right at the end, after everything else had played.
///
/// The fix is to drive the sequence with a LINEAR interval and put the springy
/// curve inside the individual TweenSequenceItem, where a Tween is free to
/// extrapolate.
void main() {
  final overshooting = <String, Curve>{
    'easeOutBack': Curves.easeOutBack,
    'elasticOut': Curves.elasticOut,
    'easeInOutBack': Curves.easeInOutBack,
  };

  test('these curves really do exceed 1.0', () {
    for (final e in overshooting.entries) {
      var peak = 0.0;
      for (var i = 0; i <= 1000; i++) {
        final v = e.value.transform(i / 1000);
        if (v > peak) peak = v;
      }
      expect(peak, greaterThan(1.0), reason: '\${e.key} peaked at \$peak');
    }
  });

  test('TweenSequence rejects an out-of-range input', () {
    final seq = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.6, end: 1.0), weight: 79),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.28),
        weight: 21,
      ),
    ]);
    expect(() => seq.transform(1.0868), throwsAssertionError);
    // ...and is fine across the legal range, which is what the linear-interval
    // fix guarantees.
    for (var i = 0; i <= 100; i++) {
      expect(() => seq.transform(i / 100), returnsNormally);
    }
  });

  test(
    'the safe composition survives an overshooting curve inside an item',
    () {
      final safe = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 1.6,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 79,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.28),
          weight: 21,
        ),
      ]);
      for (var i = 0; i <= 100; i++) {
        expect(() => safe.transform(i / 100), returnsNormally);
      }
    },
  );
}
