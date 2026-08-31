// Two ceremonies a minute apart put SKIP in the same place.
//
// The hatching cinematic had it bottom-right in a soft translucent slab; the
// fusion had it top-right in a black pill with a fast-forward icon. Same
// player, same session, same word, two different corners — so whichever one
// you learned first was wrong for the other.
//
// Source-scanned, because the two live in different layers with different
// hosts and neither can be pumped without its whole ceremony behind it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final hatch = File(
    'lib/widgets/animations/hatching_cinematic.dart',
  ).readAsStringSync();
  final fusion = File(
    'lib/widgets/fx/breed_cinematic_fx.dart',
  ).readAsStringSync();

  test('both anchor SKIP to the same corner', () {
    for (final src in [hatch, fusion]) {
      expect(src, contains('bottom: 24'));
      expect(src, contains('right: 24'));
    }
    expect(
      fusion.contains('top: MediaQuery.of(context).padding.top + 12'),
      isFalse,
      reason: 'the fusion used to hide it in the opposite corner',
    );
  });

  test('and dress it the same', () {
    for (final src in [hatch, fusion]) {
      expect(src, contains('0x14FFFFFF'), reason: 'the same slab fill');
      expect(src, contains('0x2EFFFFFF'), reason: 'the same hairline');
      expect(src, contains('Radius.circular(12)'));
      expect(src, contains("'SKIP'"));
    }
  });

  test('the silhouette does not hold to the end of the run', () {
    // It landed at 0.80 and sat fully revealed for the last fifth — a second
    // and a half of still frame at the end of a cinematic.
    expect(hatch, contains('Interval(0.84, 0.95'));
    expect(
      hatch.contains('Interval(0.80, 0.92'),
      isFalse,
      reason: 'the old reveal window',
    );
  });

  test('and the ceremony is shorter for it', () {
    final service = File(
      'lib/services/egg_hatching_service.dart',
    ).readAsStringSync();
    expect(service, contains('milliseconds: 6400'));
    expect(service.contains('milliseconds: 7200'), isFalse);
  });
}
