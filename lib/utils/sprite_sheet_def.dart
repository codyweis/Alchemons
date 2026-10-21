// lib/utils/sprite_sheet_def.dart
import 'dart:ui';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/models/wild_fusion.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flame/components.dart';

/// Sprite sheet configuration for animated creatures
class SpriteSheetDef {
  final String path;
  final int totalFrames;
  final int rows;
  final Vector2 frameSize;
  final double stepTime;

  const SpriteSheetDef({
    required this.path,
    required this.totalFrames,
    required this.rows,
    required this.frameSize,
    required this.stepTime,
  });
}

/// Visual modifiers applied to a creature sprite (genetics + effects)
class SpriteVisuals {
  final double scale; // from size genes (0.75-1.3)
  final double saturation; // S channel
  final double brightness; // V channel
  final double hueShiftDeg; // hue rotation in degrees
  final bool isPrismatic; // animated rainbow effect
  final Color? tint; // optional lineage-based tint
  final bool isAlbino; // computed flag for special rendering
  final String? alchemyEffect; // 'alchemy_glow', 'volcanic_aura', etc.

  /// The costumes worn (a `WornCostumes`, encoded), drawn by the sprite.
  final String? costumes;
  final String? variantFaction; // off-faction pigment ('Volcanic'…), if any
  final String? elementType; // the creature's own first type ('Fire'…)
  final double prismaticHueDeg; // Hue for prismatic visuals

  /// A wild-fusion mutation id ([AlchemonMutation.id]), or null. Draw its
  /// sheet through [mutatedSheet]; a Transmuted one carries no tint here.
  final String? mutation;

  /// The species ('LET01'…), when known: whose sheet a variant's palette
  /// swap is baked for (variant_look.dart).
  final String? speciesId;

  /// What the Elemental Aura shows: the pigment's faction when it has an
  /// off-faction one, so the aura matches its tint, else its own element.
  String? get auraElement => variantFaction ?? elementType;

  const SpriteVisuals({
    this.scale = 1.0,
    this.saturation = 1.0,
    this.brightness = 1.0,
    this.hueShiftDeg = 0.0,
    this.isPrismatic = false,
    this.tint,
    this.isAlbino = false,
    this.alchemyEffect,
    this.costumes,
    this.variantFaction,
    this.elementType,
    this.prismaticHueDeg = 0.0, // Default value
    this.mutation,
    this.speciesId,
  });
}

/// Extract sprite sheet configuration from creature definition
SpriteSheetDef sheetFromCreature(Creature c) => SpriteSheetDef(
  path: c.spriteData!.spriteSheetPath,
  totalFrames: c.spriteData!.totalFrames,
  rows: c.spriteData!.rows,
  frameSize: Vector2(
    c.spriteData!.frameWidth.toDouble(),
    c.spriteData!.frameHeight.toDouble(),
  ),
  stepTime: c.spriteData!.frameDurationMs / 1000.0,
);

/// Extract visual modifiers from creature instance genetics
SpriteVisuals visualsFromInstance(Creature? creature, CreatureInstance? inst) {
  final g = inst != null
      ? decodeGenetics(inst.geneticsJson)
      : creature!.genetics;

  final scale = scaleFromGenes(g);
  final hue = hueFromGenes(g);
  final sat = satFromGenes(g);
  final bri = briFromGenes(g);
  final tint = deriveLineageTint(inst);

  // Prismatic is a mutation; a creature that still carries the old flag (a
  // rift's or the Nexus's wild Alchemon) is drawn as one.
  final legacyPrismatic =
      inst?.isPrismaticSkin ?? creature?.isPrismaticSkin ?? false;
  final mutation =
      inst?.mutation ??
      creature?.wildMutation ??
      (legacyPrismatic ? AlchemonMutation.prismatic.id : null);

  // A material replaces the color: a Transmuted, Prismatic, Silverlite,
  // Starlit or Obsidian creature shows no tint, pigment (so no variant
  // faction either — its aura takes its own element) or albino. Only
  // Alchemized keeps the creature's own colors, in its grains. A Prismatic's
  // rainbow flows by the prismatic hue cycle.
  if (mutation != null && mutation != AlchemonMutation.alchemized.id) {
    return SpriteVisuals(
      scale: scale,
      isPrismatic: mutation == AlchemonMutation.prismatic.id,
      alchemyEffect: inst?.alchemyEffect?.isNotEmpty == true
          ? inst!.alchemyEffect
          : creature?.alchemyEffect,
      costumes: inst?.costumes ?? creature?.costumes,
      elementType: creature?.types.isNotEmpty == true
          ? creature!.types.first
          : null,
      mutation: mutation,
      speciesId: creature?.id ?? inst?.baseId,
    );
  }

  // Special case: albino rendering (high brightness)
  final isAlbino = bri == 1.45;

  // Improved fallback logic for alchemyEffect and variantFaction
  final alchemyEffect = inst?.alchemyEffect?.isNotEmpty == true
      ? inst!.alchemyEffect
      : creature?.alchemyEffect;

  final variantFaction = inst?.variantFaction?.isNotEmpty == true
      ? inst!.variantFaction
      : creature?.variantFaction;

  return SpriteVisuals(
    scale: scale,
    saturation: sat,
    brightness: bri,
    hueShiftDeg: hue,
    tint: tint,
    isAlbino: isAlbino,
    alchemyEffect: alchemyEffect,
    costumes: inst?.costumes ?? creature?.costumes,
    variantFaction: variantFaction,
    elementType: creature?.types.isNotEmpty == true
        ? creature!.types.first
        : null,
    mutation: mutation,
    speciesId: creature?.id ?? inst?.baseId,
  );
}
