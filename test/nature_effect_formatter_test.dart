import 'dart:convert';
import 'dart:io';

import 'package:alchemons/models/nature.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/utils/nature_effect_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats Nature mechanics in player-facing percentages', () {
    expect(
      formatNatureEffectSummary(NatureEffect({'stat_strength_bonus': 0.05})),
      'Strength +5%',
    );
    expect(
      formatNatureEffectSummary(NatureEffect({'xp_gain_mult': 1.15})),
      'XP gain +15%',
    );
    expect(
      formatNatureEffectSummary(NatureEffect({'xp_gain_mult': 0.85})),
      'XP gain -15%',
    );
    expect(
      formatNatureEffectSummary(
        NatureEffect({'breed_same_species_chance_mult': 0.70}),
      ),
      'Same-species breeding -30%',
    );
    expect(
      formatNatureEffectSummary(NatureEffect({'stamina_extra': 1})),
      'Stamina +1',
    );
    expect(
      formatNatureEffectSummary(NatureEffect({'sale_value_mult': 1.5})),
      'Sale value +50%',
    );
    expect(
      formatNatureEffectSummary(
        NatureEffect({'wild_fusion_stability_add': 0.05}),
      ),
      'Wild Fusion stability +5%',
    );
    expect(
      formatNatureEffectSummary(
        NatureEffect({'guarantee_second_nature_inheritance': 1}),
      ),
      'Guarantees second Nature inheritance',
    );
    expect(
      formatNatureEffectSummary(
        NatureEffect({
          'stat_speed_bonus': 0.10,
          'stat_intelligence_bonus': -0.05,
        }),
      ),
      'Speed +10% • Intelligence -5%',
    );
  });

  test('stat Nature data matches the canonical gameplay bonus', () {
    final json =
        jsonDecode(
              File('assets/data/alchemons_natures.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final natures = {
      for (final raw in json['natures'] as List<dynamic>)
        (raw as Map<String, dynamic>)['id'] as String: raw,
    };
    const keys = {
      'Swift': 'stat_speed_bonus',
      'Clever': 'stat_intelligence_bonus',
      'Mighty': 'stat_strength_bonus',
      'Elegant': 'stat_beauty_bonus',
    };

    for (final entry in keys.entries) {
      final nature = natures[entry.key] as Map<String, dynamic>;
      final effect = nature['effect'] as Map<String, dynamic>;
      expect(effect[entry.value], AlchemonStatSystem.matchingNatureBonus);
    }
  });

  test('rare utility Nature data exposes one focused effect each', () {
    final json =
        jsonDecode(
              File('assets/data/alchemons_natures.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final natures = {
      for (final raw in json['natures'] as List<dynamic>)
        (raw as Map<String, dynamic>)['id'] as String: raw,
    };

    expect((natures['Coveted']!['effect'] as Map<String, dynamic>), {
      'sale_value_mult': 1.5,
    });
    expect((natures['Hereditary']!['effect'] as Map<String, dynamic>), {
      'guarantee_second_nature_inheritance': 1,
    });
    expect(natures['Coveted']!['tier'], 'Rare');
    expect(natures['Hereditary']!['tier'], 'Rare');
  });
}
