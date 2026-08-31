// Damage numbers must not cost a blur pass each.
//
// The field was already careful about ONE raster trap — the fade is quantised
// so a fading number is a cached painter rather than a saveLayer — and walked
// straight into two others.
//
// A `Shadow` with a blurRadius is a gaussian over the glyph mask, on the
// raster thread, per shadow per number per frame; there were two. And a
// number's 0.15s pop-in scaled by a value that changed every frame, so
// nothing about it could be cached either. Neither is visible to any Dart
// timing — recording a paragraph is cheap, and the whole cost lands on a
// thread Dart cannot measure.
//
// That is also why it hid: the cost tracked the HIT RATE (how many numbers
// are mid-pop) and not the number count, so a window with 18 numbers ran
// clean while one with 8 was the worst of the fight.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/shared/damage_numbers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/games/shared/damage_numbers.dart')
      .readAsStringSync();

  test('no shadow is blurred', () {
    expect(
      RegExp(r'blurRadius:\s*[1-9]').hasMatch(source),
      isFalse,
      reason: 'a blurred text shadow is a gaussian pass per number per frame',
    );
  });

  test('the shadows are offsets, and there are still some', () {
    // The outline has to survive the fix — white numbers on a bright burst
    // are unreadable without it.
    expect(RegExp(r'offset:\s*Offset\(').allMatches(source).length,
        greaterThanOrEqualTo(3));
  });

  test('the pop-in scale is quantised', () {
    expect(source, contains('final rawScale'));
    expect(
      source,
      contains('_fadeSteps).round()'),
      reason: 'an unquantised scale re-rasterises the glyphs every frame',
    );
  });

  group('and it still behaves', () {
    test('a hit shows a number, and it expires', () {
      final f = DamageNumberField();
      f.spawn(Offset.zero, 12);
      expect(f.length, 1);
      for (var i = 0; i < 300; i++) {
        f.update(1 / 60);
      }
      expect(f.isEmpty, isTrue, reason: 'numbers must not pile up');
    });

    test('sub-1 damage is not worth a number', () {
      final f = DamageNumberField();
      f.spawn(Offset.zero, 0.4);
      expect(f.isEmpty, isTrue);
    });

    test('the field is capped', () {
      final f = DamageNumberField(maxNumbers: 8);
      for (var i = 0; i < 50; i++) {
        f.spawn(Offset.zero, 10);
      }
      expect(f.length, lessThanOrEqualTo(8));
    });

    test('rendering a full field does not throw', () {
      final f = DamageNumberField();
      for (var i = 0; i < 20; i++) {
        f.spawn(Offset(i * 3, 0), i * 7 + 1);
      }
      f.update(1 / 60); // some mid-pop, some settled
      final rec = ui.PictureRecorder();
      expect(() => f.render(Canvas(rec)), returnsNormally);
      rec.endRecording().dispose();
    });
  });
}
