// models/trophy_slot.dart (or wherever yours lives)
import 'dart:ui';

enum AnchorLayer { layer1, layer2, layer3, layer4 }

class TrophySlot {
  final String id;
  final Offset normalizedPos; // 0..1
  final bool isUnlocked;
  final String spritePath; // static sprite (or silhouette)
  final String displayName;
  final String rarity;

  // NEW: which parallax strip should this live on?
  final AnchorLayer anchor;

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
    this.anchor = AnchorLayer.layer1,
    this.spriteSheetPath,
    this.sheetColumns,
    this.sheetRows,
    this.frameWidth,
    this.frameHeight,
    this.stepTime,
  });
}
