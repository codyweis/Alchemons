import 'dart:ui';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flame/components.dart';

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

class SpriteVisuals {
  final double scale; // e.g. 0.75..1.3
  final double saturation; // S
  final double brightness; // V
  final double hueShiftDeg; // degrees
  final bool isPrismatic;
  final Color? tint; // lineage tint, optional
  final bool isAlbino; // convenience flag

  const SpriteVisuals({
    required this.scale,
    required this.saturation,
    required this.brightness,
    required this.hueShiftDeg,
    required this.isPrismatic,
    required this.tint,
    required this.isAlbino,
  });
}

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

  // keep your special-case albino/prismatic rules here
  final isAlbino = (bri == 1.45) && !isPrismatic;

  return SpriteVisuals(
    scale: scale,
    saturation: sat,
    brightness: bri,
    hueShiftDeg: hue,
    isPrismatic: isPrismatic,
    tint: tint,
    isAlbino: isAlbino,
  );
}
