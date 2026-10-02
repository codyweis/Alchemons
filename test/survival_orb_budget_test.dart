// THE ORB'S BUDGET. The survival core, its readings and its gravity field
// are drawn every frame of a run (lib/games/cosmic_survival/orb_art.dart).
// This keeps them blur-free and keeps each core's draw count where it was
// measured when the cores were rebuilt (2026-10-02).
//
// A budget test, not a golden: test/survival_orb_preview_test.dart renders
// what they look like.

import 'dart:math';
import 'dart:ui';

import 'package:alchemons/games/cosmic_survival/orb_art.dart';
import 'package:alchemons/models/survival_upgrades.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what a frame asks the GPU to do.
class _CensusCanvas implements Canvas {
  final Map<String, int> counts = {};
  int blurredDraws = 0;

  @override
  dynamic noSuchMethod(Invocation i) {
    final n = i.memberName.toString();
    final key = n.substring(8, n.length - 2);
    counts[key] = (counts[key] ?? 0) + 1;
    for (final a in i.positionalArguments) {
      if (a is Paint && a.maskFilter != null) blurredDraws++;
    }
    if (key == 'getSaveCount') return 1;
    return null;
  }

  int get draws => counts.entries
      .where((e) => e.key.startsWith('draw'))
      .fold(0, (s, e) => s + e.value);
}

void main() {
  // Peak draws per frame for the core, its readings (hurt, shielded, the
  // meter part-full) and the field, over a minute of time.
  const budget = <OrbBaseSkin, int>{
    OrbBaseSkin.defaultOrb: 18,
    OrbBaseSkin.voidforgeOrb: 23,
    OrbBaseSkin.celestialOrb: 17,
    OrbBaseSkin.infernalOrb: 26,
    OrbBaseSkin.frozenNexusOrb: 30,
    OrbBaseSkin.phantomWispOrb: 20,
    OrbBaseSkin.prismHeartOrb: 24,
    OrbBaseSkin.verdantBloomOrb: 29,
  };

  for (final MapEntry(key: skin, value: limit) in budget.entries) {
    test('${skin.name}: no blur, at most $limit draws', () {
      var peak = 0;
      for (var f = 0; f < 120; f++) {
        final t = f * 0.5;
        final c = _CensusCanvas();
        paintOrbField(c as Canvas, skin, t);
        paintOrbCore(c, skin, t, beat: (f % 17) / 17);
        paintOrbReadings(
          c,
          skin,
          hpFrac: 0.15 + 0.8 * (f % 10) / 10,
          meterFrac: (f % 7) / 7,
          shield: f.isEven ? 0.5 : 0,
          time: t,
        );
        expect(c.blurredDraws, 0, reason: 'frame $f');
        peak = max(peak, c.draws);
      }
      expect(peak, lessThanOrEqualTo(limit));
    });
  }
}
