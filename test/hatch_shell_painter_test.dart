import 'dart:ui' as ui;

import 'package:alchemons/widgets/animations/hatch_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shell writes into preallocated typed buffers with a hand-rolled cursor.
/// If any species' strand/sample count disagrees with its buffer size, or a
/// strand bails out without consuming its range, the indices desync and the
/// ceremony crashes mid-hatch. These render every species across the whole
/// timeline to catch that on the bench rather than on a device.
void main() {
  const size = Size(400, 720);

  Future<void> renderAt(
    HatchShellSpecies species,
    double t, {
    bool reduced = false,
    ShellRarity rarity = ShellRarity.normal,
  }) async {
    final model = HatchShellModel(species: species, reduced: reduced);
    final painter = HatchShellPainter(
      t: t,
      clock: t * 6.6,
      model: model,
      paletteA: const [Color(0xFF1574A1), Color(0xFF38BDF8), Color(0xFF7DD3FC)],
      paletteB: const [Color(0xFFFF7E57), Color(0xFFFF8C00), Color(0xFFFFD700)],
      paletteResult: const [
        Color(0xFF6C838E),
        Color(0xFF93C5FD),
        Color(0xFFFCA5A5),
      ],
      behaviorA: ShellElementBehavior.of('T002'),
      behaviorB: ShellElementBehavior.of('T001'),
      behaviorResult: ShellElementBehavior.of('T005'),
      rarity: rarity,
      variantColor: const Color(0xFF9C27B0),
      reduced: reduced,
    );
    final rec = ui.PictureRecorder();
    painter.paint(Canvas(rec), size);
    rec.endRecording().dispose();
  }

  for (final species in HatchShellSpecies.values) {
    test('$species renders across the whole timeline', () async {
      for (double t = 0; t <= 1.0001; t += 0.05) {
        await renderAt(species, t);
      }
    });

    test('$species renders at reduced quality', () async {
      for (final t in [0.1, 0.3, 0.5, 0.76, 0.95]) {
        await renderAt(species, t, reduced: true);
      }
    });
  }

  test('every species fits a Uint16 vertex index', () {
    for (final species in HatchShellSpecies.values) {
      for (final reduced in [false, true]) {
        final m = HatchShellModel(species: species, reduced: reduced);
        final verts = m.strandCount * m.sampleCount * 3;
        expect(
          verts,
          lessThanOrEqualTo(65535),
          reason: '$species (reduced=$reduced) needs $verts vertices, which '
              'overflows the Uint16 index buffer',
        );
      }
    }
  });

  test('rarity treatments render', () async {
    for (final r in ShellRarity.values) {
      await renderAt(HatchShellSpecies.mystic, 0.76, rarity: r);
      await renderAt(HatchShellSpecies.kin, 0.5, rarity: r);
    }
  });

  test('fully unravelled shell still paints without desync', () async {
    // t = 1 drives every strand past unrav >= 1, which takes the early-out
    // branch for all of them — the one path where the cursors could drift.
    for (final species in HatchShellSpecies.values) {
      await renderAt(species, 1.0);
    }
  });

  test('ambient motes render across the timeline', () async {
    for (double t = 0; t <= 1.0001; t += 0.1) {
      final painter = HatchShellAmbientPainter(
        t: t,
        clock: t * 6.6,
        tint: const Color(0xFF38BDF8),
        accent: const Color(0xFFFFD700),
      );
      final rec = ui.PictureRecorder();
      painter.paint(Canvas(rec), size);
      rec.endRecording().dispose();
    }
  });
}
