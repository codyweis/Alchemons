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

  // These used to assert on literal window strings, which meant every timing
  // tweak broke them for no reason and they spent most of their life red. They
  // now pull the constants out of the source and assert the RELATIONSHIPS
  // between them -- which is what actually has to hold for the ceremony not to
  // end on a still frame. Retuning the numbers is free; breaking the ordering
  // is not.
  double constant(String src, String name) {
    final match = RegExp('$name\\s*=\\s*([0-9.]+)').firstMatch(src);
    expect(match, isNotNull, reason: '$name should still exist');
    return double.parse(match!.group(1)!);
  }

  test('the silhouette lands before the ceremony starts dissolving', () {
    // The reveal is the only Interval driven with easeOut.
    final reveal = RegExp(
      r'Interval\(([0-9.]+),\s*([0-9.]+),\s*curve: Curves\.easeOut\)',
    ).firstMatch(hatch);
    expect(reveal, isNotNull, reason: 'the silhouette reveal window');

    final revealEnd = double.parse(reveal!.group(2)!);
    final dissolveFrom = constant(hatch, '_kDissolveFrom');

    expect(
      revealEnd,
      lessThanOrEqualTo(dissolveFrom),
      reason: 'the scale-in has to finish before the fade starts, or the '
          'silhouette is still arriving while it leaves',
    );
  });

  test('it hands over on an empty frame, before the timeline runs out', () {
    final dissolveFrom = constant(hatch, '_kDissolveFrom');
    final handover = constant(hatch, '_kHandoverAt');

    expect(
      dissolveFrom,
      lessThan(handover),
      reason: 'there has to be a dissolve window, not a cut',
    );
    expect(
      handover,
      lessThan(1.0),
      reason: 'waiting for the controller to complete is what left a '
          'motionless silhouette on screen at the end',
    );
  });

  test('and the ceremony is shorter than it was', () {
    // The service no longer hard-codes a duration; it takes the cinematic's
    // own constant, so there is one number to change instead of two that can
    // disagree.
    final service = File(
      'lib/services/egg_hatching_service.dart',
    ).readAsStringSync();
    expect(service, contains('kHatchCeremonyMs'));

    final ceremonyMs = constant(hatch, 'kHatchCeremonyMs');
    expect(ceremonyMs, lessThan(7500));
  });
}
