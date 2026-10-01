// The all-specimens grid draws hundreds of these cards. The old alchemy
// effects were AnimationControllers driving MaskFilter blurs, per frame, per
// visible card, and scrolling stuttered, so lists opted out. They are one
// blur-free painter on a shared clock now (its cost is pinned by
// alchemy_effects_census_test), so every card wears its effect.
//
// The other half of this file pins the Dominant marker: it is gold in both
// themes now. In light mode it used to ride on the faction accent, which for
// the pale factions was near-invisible against the surface.

import 'package:alchemons/database/alchemons_db.dart' as db;
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/alchemy_effects/alchemy_effect_paint.dart';
import 'package:alchemons/widgets/fx/alchemy_effects/alchemy_effect_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Creature _species() => Creature(
  id: 'TST01',
  name: 'Test Specimen',
  types: const ['Water'],
  rarity: 'Common',
  description: 'A specimen that exists only to be rendered.',
  image: 'creatures/common/LET02_waterlet.png',
  spriteData: SpriteData(
    frameWidth: 64,
    frameHeight: 64,
    totalFrames: 4,
    frameDurationMs: 120,
    rows: 1,
    spriteSheetPath: 'creatures/common/LET02_waterlet_spritesheet.png',
  ),
);

db.CreatureInstance _instance({String? effect}) => db.CreatureInstance(
  instanceId: 'i1',
  baseId: 'TST01',
  level: 1,
  xp: 0,
  locked: false,
  isPrismaticSkin: false,
  source: 'test',
  staminaMax: 3,
  staminaBars: 3,
  staminaLastUtcMs: 0,
  createdAtUtcMs: 0,
  statSpeed: 3,
  statIntelligence: 3,
  statStrength: 3,
  statBeauty: 3,
  statSpeedPotential: 40,
  statIntelligencePotential: 40,
  statStrengthPotential: 40,
  statBeautyPotential: 40,
  statSpeedEnhancement: 0,
  statIntelligenceEnhancement: 0,
  statStrengthEnhancement: 0,
  statBeautyEnhancement: 0,
  generationDepth: 0,
  isPure: true,
  isFavorite: false,
  alchemyEffect: effect,
);

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('an InstanceSprite mounts its alchemy effect by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        InstanceSprite(
          creature: _species(),
          instance: _instance(effect: 'prismatic_cascade'),
          size: 96,
        ),
      ),
    );
    expect(find.byType(AlchemyEffectView), findsOneWidget);
  });

  testWidgets('every effect key mounts through the shared view', (
    tester,
  ) async {
    for (final effect in AlchemyEffectPaint.keys) {
      await tester.pumpWidget(
        _host(
          InstanceSprite(
            key: ValueKey(effect),
            creature: _species(),
            instance: _instance(effect: effect),
            size: 96,
          ),
        ),
      );
      expect(find.byType(AlchemyEffectView), findsOneWidget, reason: effect);
    }
    // No effect, or one this build does not know: just the sprite.
    for (final effect in const [null, 'not_an_effect']) {
      await tester.pumpWidget(
        _host(
          InstanceSprite(
            key: ValueKey('none $effect'),
            creature: _species(),
            instance: _instance(effect: effect),
            size: 96,
          ),
        ),
      );
      expect(find.byType(AlchemyEffectView), findsNothing);
    }
  });

  test('the reward palette stays legible on a light surface', () {
    // Achievements were drawn in a dark-only gold / mint / silver. On light
    // parchment those read as blank space, so light mode gets its own values.
    for (final id in FactionId.values) {
      final light = ForgeTokens(
        factionThemeFor(id, brightness: Brightness.light),
      );
      final dark = ForgeTokens(factionThemeFor(id));

      for (final entry in {
        'reward gold': (light.rewardGold, dark.rewardGold),
        'reward silver': (light.rewardSilver, dark.rewardSilver),
        'mint': (light.mint, dark.mint),
      }.entries) {
        final (lightColor, darkColor) = entry.value;
        expect(
          HSLColor.fromColor(lightColor).lightness,
          lessThan(0.45),
          reason: '${entry.key} must be dark enough to read in light mode',
        );
        expect(
          HSLColor.fromColor(darkColor).lightness,
          greaterThan(0.5),
          reason: '${entry.key} must stay bright in dark mode',
        );
      }
    }
  });

  test('the Dominant marker is gold in light mode, not the faction accent', () {
    for (final id in FactionId.values) {
      final light = factionThemeFor(id, brightness: Brightness.light);
      final dark = factionThemeFor(id);
      final lightGold = ForgeTokens(light).dominant;
      final darkGold = ForgeTokens(dark).dominant;

      // Gold, in both themes, whatever faction the player is wearing.
      final lightHsl = HSLColor.fromColor(lightGold);
      expect(
        lightHsl.hue,
        inInclusiveRange(35, 55),
        reason: 'light Dominant for $id should read as gold',
      );
      expect(
        HSLColor.fromColor(darkGold).hue,
        inInclusiveRange(35, 55),
        reason: 'dark Dominant for $id should read as gold',
      );

      // Dark enough to sit on a light surface. The old value was the faction
      // accent, which for the pale factions failed exactly here.
      expect(
        lightHsl.lightness,
        lessThan(0.45),
        reason: 'light Dominant for $id must be legible on a light surface',
      );
    }
  });
}
