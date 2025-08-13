// models/trophy_slot.dart (or wherever yours lives)
import 'dart:ui';

import 'package:alchemons/models/scenes/scene_definition.dart';

class TrophySlot {
  final String id;
  final Offset normalizedPos; // 0..1
  final bool isUnlocked;
  final String spritePath; // static sprite (or silhouette)
  final String displayName;
  final String rarity;
  final String imagePath;

  // NEW: which parallax strip should this live on?
  final SceneLayer anchor;

  // NEW: optional spritesheet (if set, we show an animation instead of spritePath)
  final String? spriteSheetPath; // e.g. 'creatures/anim/lightmane_sheet.png'
  final int? sheetColumns; // e.g. 4
  final int? sheetRows; // e.g. 2
  final double? frameWidth; // if you prefer explicit size (optional)
  final double? frameHeight; // if you prefer explicit size (optional)
  final double? stepTime; // seconds per frame, e.g. 0.12

  const TrophySlot({
    required this.id,
    required this.normalizedPos,
    required this.isUnlocked,
    required this.spritePath,
    required this.displayName,
    required this.rarity,
    this.anchor = SceneLayer.layer1,
    this.spriteSheetPath,
    this.sheetColumns,
    this.sheetRows,
    this.frameWidth,
    this.frameHeight,
    this.stepTime,
    required this.imagePath,
  });
}

extension TrophySlotCopy on TrophySlot {
  TrophySlot copyWith({
    String? id,
    Offset? normalizedPos,
    bool? isUnlocked,
    String? spritePath,
    String? displayName,
    String? rarity,
    SceneLayer? anchor,
    String? spriteSheetPath,
    int? sheetColumns,
    int? sheetRows,
    double? frameWidth,
    double? frameHeight,
    double? stepTime,
    String? imagePath,
  }) {
    return TrophySlot(
      id: id ?? this.id,
      normalizedPos: normalizedPos ?? this.normalizedPos,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      spritePath: spritePath ?? this.spritePath,
      displayName: displayName ?? this.displayName,
      rarity: rarity ?? this.rarity,
      anchor: anchor ?? this.anchor,
      spriteSheetPath: spriteSheetPath ?? this.spriteSheetPath,
      sheetColumns: sheetColumns ?? this.sheetColumns,
      sheetRows: sheetRows ?? this.sheetRows,
      frameWidth: frameWidth ?? this.frameWidth,
      frameHeight: frameHeight ?? this.frameHeight,
      stepTime: stepTime ?? this.stepTime,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}
