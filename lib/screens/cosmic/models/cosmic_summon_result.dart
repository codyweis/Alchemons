import 'dart:convert';
import 'dart:math';

class CosmicSummonResult {
  final String resolvedElement;
  final String sceneKey; // volcano, swamp, valley, sky, arcane
  final String speciesId;
  final String speciesName;
  final String rarity;

  const CosmicSummonResult({
    required this.resolvedElement,
    required this.sceneKey,
    required this.speciesId,
    required this.speciesName,
    required this.rarity,
  });
}

// ─────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────

