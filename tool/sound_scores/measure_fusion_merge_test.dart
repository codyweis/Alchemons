// Measures the fusion merge for tool/material_sounds.py: steps the real
// FusionParticleField and records, per parent, how fast its grains move and
// how fast they are being made (the sparkle line). The sound is scored from
// the JSON this writes, so re-run it whenever the merge's timing changes:
//
//   flutter test tool/sound_scores/measure_fusion_merge_test.dart
//   python tool/material_sounds.py sfx_fusion_merge
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';

void main() {
  test('dump merge motion', () {
    final f = FusionParticleField(
      specimens: [
        SpecimenGrains.disc(const Color(0xFFE05030), radius: 40),
        SpecimenGrains.disc(const Color(0xFF3080E0), radius: 40),
      ],
      centres: const [Offset(95, 300), Offset(305, 300)],
      scales: const [1.0, 1.0],
      core: const Offset(200, 340),
      coreRadius: 75,
      colors: const [Color(0xFFE05030), Color(0xFF3080E0)],
    );
    const dt = 1 / 200;
    final n = f.length;
    final side = List<int>.generate(n, (i) => i < n ~/ 2 ? 0 : 1);
    final prev = List<Offset?>.filled(n, null);
    final speed = [<double>[], <double>[]];
    final born = [<double>[], <double>[]];
    final times = <double>[];
    for (var k = 0; k <= (FusionParticleField.duration / dt).round() + 10; k++) {
      final t = k * dt;
      final sp = [0.0, 0.0], bn = [0.0, 0.0];
      for (var i = 0; i < n; i++) {
        final p = f.debugGrain(i, t);
        final q = prev[i];
        if (p != null && q == null) bn[side[i]] += 1;
        if (p != null && q != null) sp[side[i]] += (p - q).distance / dt;
        prev[i] = p;
      }
      times.add(t);
      for (var s = 0; s < 2; s++) {
        speed[s].add(sp[s] / n);
        born[s].add(bn[s] / dt / n);
      }
    }
    File('tool/sound_scores/fusion_merge_motion.json').writeAsStringSync(jsonEncode({
      'grains': n, 'dt': dt, 't': times, 'speed': speed, 'born': born,
    }));
  });
}
