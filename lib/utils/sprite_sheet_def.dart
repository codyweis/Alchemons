// lib/utils/sprite_sheet_def.dart
import 'dart:ui';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
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
  final String? variantFaction; // 'Pyro', 'Aqua', etc. for elemental aura color

  const SpriteVisuals({
    this.scale = 1.0,
    this.saturation = 1.0,
    this.brightness = 1.0,
    this.hueShiftDeg = 0.0,
    this.isPrismatic = false,
    this.tint,
    this.isAlbino = false,
    this.alchemyEffect,
    this.variantFaction,
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

  final isPrismatic = inst?.isPrismaticSkin ?? creature!.isPrismaticSkin;

  // Special case: albino rendering (high brightness, no prismatic)
  final isAlbino = (bri == 1.45) && !isPrismatic;

  return SpriteVisuals(
    scale: scale,
    saturation: sat,
    brightness: bri,
    hueShiftDeg: hue,
    isPrismatic: isPrismatic,
    tint: tint,
    isAlbino: isAlbino,
    alchemyEffect: inst?.alchemyEffect, // Pull from instance if available
    variantFaction: inst?.variantFaction, // Pull from instance if available
  );
}
