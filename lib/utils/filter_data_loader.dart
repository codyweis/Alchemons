import 'package:alchemons/helpers/genetics_loader.dart';
import 'package:alchemons/helpers/nature_loader.dart';

/// Centralized loader for all filter options and labels from JSON configs
class FilterDataLoader {
  // ============================================================================
  // SIZE GENETICS
  // ============================================================================

  static List<String> getSizeVariants() {
    try {
      final track = GeneticsCatalog.track('size');
      return track.variants.map((v) => v.id).toList();
    } catch (e) {
      return ['tiny', 'small', 'normal', 'large', 'giant'];
    }
  }

  static Map<String, String> getSizeLabels() {
    try {
      final track = GeneticsCatalog.track('size');
      return Map.fromEntries(track.variants.map((v) => MapEntry(v.id, v.name)));
    } catch (e) {
      return {
        'tiny': 'Tiny',
        'small': 'Small',
        'normal': 'Normal',
        'large': 'Large',
        'giant': 'Giant',
      };
    }
  }

  // ============================================================================
  // TINTING GENETICS
  // ============================================================================

  static List<String> getTintingVariants() {
    try {
      final track = GeneticsCatalog.track('tinting');
      return track.variants.map((v) => v.id).toList();
    } catch (e) {
      return ['pale', 'normal', 'vibrant', 'warm', 'cool', 'albino'];
    }
  }

  static Map<String, String> getTintingLabels() {
    try {
      final track = GeneticsCatalog.track('tinting');
      return Map.fromEntries(track.variants.map((v) => MapEntry(v.id, v.name)));
    } catch (e) {
      return {
        'pale': 'Diminished',
        'normal': 'Normal',
        'vibrant': 'Saturated',
        'warm': 'Thermal',
        'cool': 'Cryogenic',
        'albino': 'Albino',
      };
    }
  }

  // ============================================================================
  // NATURES
  // ============================================================================

  static List<String> getAllNatures() {
    return NatureCatalog.all.map((n) => n.id).toList();
  }

  static Map<String, String> getNatureLabels() {
    // Natures use their ID as their display name
    return Map.fromEntries(NatureCatalog.all.map((n) => MapEntry(n.id, n.id)));
  }

  // ============================================================================
  // COMBINED HELPERS (for utils that need all labels at once)
  // ============================================================================

  /// Get all size labels (backward compatible with genetics_util.dart)
  static Map<String, String> get sizeLabels => getSizeLabels();

  /// Get all tint labels (backward compatible with genetics_util.dart)
  static Map<String, String> get tintLabels => getTintingLabels();

  /// Get all nature labels
  static Map<String, String> get natureLabels => getNatureLabels();
}
