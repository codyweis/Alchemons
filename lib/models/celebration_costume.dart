import 'package:alchemons/models/inventory.dart';
import 'package:flutter/painting.dart';

/// The family costumes, each sold on its own and used like any alchemy
/// effect: one dresses one creature of its family, from its Effect slot, and
/// taken off goes back to the inventory. Worn, either is saved as
/// `celebration.<species>` — the species says which, and carries the fitted
/// place every renderer draws it at. It is part of the sprite, not an effect
/// round it: each sprite renderer paints it after the frame, in the frame's
/// own space (see `CostumePaint.paintWorn`). Each also carries its colour,
/// picked as it goes on and changed free after:
/// `celebration.<species>#RRGGBB`, and with no colour the one it was
/// designed in.
enum FamilyCostume {
  /// Alchemical Celebration: a stardust party hat, for Wings.
  partyHat(
    family: 'WNG',
    familyName: 'Wings',
    title: 'Alchemical Celebration',
    itemKey: InvKeys.alchemyCelebration,
    offerId: 'effects.celebration',
    previewKey: FamilyCostume.hatPreview,
    noun: 'hat',
    // The velvet's lit flank; the shading below it is the same for all, so
    // every pick reads as the same dark velvet.
    defaultColor: Color(0xFF4C3388),
    presets: [
      Color(0xFF4C3388), // violet
      Color(0xFF26478F), // sapphire
      Color(0xFF1F6A6A), // teal
      Color(0xFF3E6B2C), // moss
      Color(0xFF8C6A1F), // old gold
      Color(0xFF9A4A1E), // ember
      Color(0xFF8A2338), // ruby
      Color(0xFF8C3A6E), // rose
      Color(0xFF4A4852), // graphite
    ],
    ringSaturation: 0.62,
    ringValue: 0.53,
  ),

  /// Alchemical Nose: a ruby bubble nose, for Pips.
  nose(
    family: 'PIP',
    familyName: 'Pips',
    title: 'Alchemical Nose',
    itemKey: InvKeys.alchemyNose,
    offerId: 'effects.alchemical_nose',
    previewKey: FamilyCostume.nosePreview,
    noun: 'nose',
    // The glass's own colour, between its lit cap and its deep edge.
    defaultColor: Color(0xFFEE254B),
    presets: [
      Color(0xFFEE254B), // ruby
      Color(0xFFE8551E), // ember
      Color(0xFFE8B021), // gold
      Color(0xFF2BB24C), // emerald
      Color(0xFF1FB5B0), // teal
      Color(0xFF2F6BEA), // sapphire
      Color(0xFF8A4BE8), // violet
      Color(0xFFD9D4E6), // pearl
      Color(0xFF3A3640), // obsidian
    ],
    ringSaturation: 0.84,
    ringValue: 0.93,
  );

  const FamilyCostume({
    required this.family,
    required this.familyName,
    required this.title,
    required this.itemKey,
    required this.offerId,
    required this.previewKey,
    required this.noun,
    required this.defaultColor,
    required this.presets,
    required this.ringSaturation,
    required this.ringValue,
  });

  /// The species id prefix of the family that wears it.
  final String family;
  final String familyName;

  /// What it is called in the shop and the inventory.
  final String title;
  final String itemKey;
  final String offerId;

  /// Drawn on its own, with no creature (the shop and inventory cards).
  final String previewKey;

  /// What it is, in a line of UI: "hat", "nose".
  final String noun;

  /// Its colour when none was picked: the one it was designed in.
  final Color defaultColor;

  /// Hand-picked colours, offered beside the hue ring.
  final List<Color> presets;

  /// How strong and how light every colour round the ring is.
  final double ringSaturation, ringValue;

  /// Its colour at [hue] in turns round the wheel (0..1): the same depth in
  /// every hue, so no pick reads as another material.
  Color colorForHue(double hue) => HSVColor.fromAHSV(
    1,
    (hue % 1) * 360,
    ringSaturation,
    ringValue,
  ).toColor();

  /// Its colour as worn as [effect]: the picked one, or its default when
  /// none was picked or [effect] is not this costume.
  Color colorIn(String? effect) {
    if (ofEffect(effect) != this) return defaultColor;
    final mark = effect!.indexOf(_colorMark);
    if (mark < 0) return defaultColor;
    final rgb = int.tryParse(effect.substring(mark + 1), radix: 16);
    return rgb == null || rgb > 0xFFFFFF
        ? defaultColor
        : Color(0xFF000000 | rgb);
  }

  static const hatPreview = 'celebration';
  static const nosePreview = 'alchemical_nose';
  static const _prefix = 'celebration.';
  static const _colorMark = '#';

  /// Normalized sprite coordinates (not the opaque pixel bounding box):
  /// (head/snout x, y, hat width or nose radius).
  static const placements = <String, (double, double, double)>{
    'WNG01': (0.44, 0.335, 0.23),
    'WNG02': (0.37, 0.31, 0.19),
    'WNG03': (0.375, 0.33, 0.25),
    'WNG04': (0.37, 0.315, 0.2),
    'WNG05': (0.365, 0.305, 0.21),
    'WNG06': (0.37, 0.325, 0.21),
    'WNG07': (0.36, 0.335, 0.16),
    'WNG08': (0.31, 0.3, 0.22),
    'WNG09': (0.355, 0.335, 0.2),
    'WNG10': (0.36, 0.3, 0.19),
    'WNG11': (0.33, 0.36, 0.19),
    'WNG12': (0.36, 0.31, 0.18),
    'WNG13': (0.36, 0.315, 0.19),
    'WNG14': (0.365, 0.305, 0.19),
    'WNG15': (0.38, 0.325, 0.19),
    'WNG16': (0.38, 0.3, 0.2),
    'WNG17': (0.36, 0.32, 0.19),
    'PIP01': (0.159, 0.526, 0.044),
    'PIP02': (0.161, 0.51, 0.044),
    'PIP03': (0.134, 0.54, 0.044),
    'PIP04': (0.149, 0.525, 0.044),
    'PIP05': (0.15, 0.525, 0.044),
    'PIP06': (0.144, 0.53, 0.044),
    'PIP07': (0.15, 0.53, 0.044),
    'PIP08': (0.135, 0.52, 0.044),
    'PIP09': (0.111, 0.49, 0.044),
    'PIP10': (0.121, 0.535, 0.044),
    'PIP11': (0.146, 0.525, 0.044),
    'PIP12': (0.132, 0.515, 0.044),
    'PIP13': (0.15, 0.525, 0.044),
    'PIP14': (0.136, 0.525, 0.044),
    'PIP15': (0.142, 0.535, 0.044),
    'PIP16': (0.18, 0.52, 0.044),
    'PIP17': (0.141, 0.515, 0.044),
  };

  /// Where it sits in each frame of a species' sheet — every Wing's hat and
  /// every Pip's nose: (x, y, tilt in radians) per frame, x and y as in
  /// [placements] and the size kept from there. Measured from the frame-0
  /// fit by test/costume_anchor_track_test.dart; a species not here wears it
  /// at its [placements] fit in every frame.
  static const frameFits = <String, List<(double, double, double)>>{
    'WNG01': [
      (0.440, 0.335, 0.0),
      (0.441, 0.340, 0.0),
      (0.438, 0.322, 0.0),
      (0.433, 0.316, 0.0),
    ],
    'WNG02': [
      (0.370, 0.310, 0.0),
      (0.372, 0.314, 0.0),
      (0.365, 0.301, 0.0),
      (0.365, 0.298, 0.0),
    ],
    'WNG03': [
      (0.375, 0.330, 0.0),
      (0.376, 0.329, 0.0),
      (0.372, 0.327, 0.0),
      (0.375, 0.323, 0.0),
    ],
    'WNG04': [
      (0.370, 0.315, 0.0),
      (0.367, 0.307, 0.0),
      (0.365, 0.305, 0.0),
      (0.365, 0.303, 0.0),
    ],
    'WNG05': [
      (0.365, 0.305, 0.0),
      (0.367, 0.311, 0.0),
      (0.365, 0.299, 0.0),
      (0.363, 0.295, 0.0),
    ],
    'WNG06': [
      (0.370, 0.325, 0.0),
      (0.370, 0.327, 0.0),
      (0.370, 0.317, 0.0),
      (0.371, 0.315, 0.0),
    ],
    'WNG07': [
      (0.360, 0.335, 0.0),
      (0.361, 0.338, 0.0),
      (0.361, 0.318, 0.0),
      (0.360, 0.307, 0.0),
    ],
    'WNG08': [
      (0.310, 0.300, 0.0),
      (0.310, 0.313, 0.0),
      (0.310, 0.289, 0.0),
      (0.310, 0.282, 0.0),
    ],
    'WNG09': [
      (0.355, 0.335, 0.0),
      (0.355, 0.337, 0.0),
      (0.355, 0.324, 0.0),
      (0.355, 0.320, 0.0),
    ],
    'WNG10': [
      (0.360, 0.300, 0.0),
      (0.360, 0.306, 0.0),
      (0.358, 0.289, 0.0),
      (0.356, 0.276, 0.0),
    ],
    'WNG11': [
      (0.330, 0.360, 0.0),
      (0.330, 0.366, 0.0),
      (0.330, 0.351, 0.0),
      (0.333, 0.343, 0.0),
    ],
    'WNG12': [
      (0.360, 0.310, 0.0),
      (0.360, 0.317, 0.0),
      (0.360, 0.292, 0.0),
      (0.364, 0.287, 0.0),
    ],
    'WNG13': [
      (0.360, 0.315, 0.0),
      (0.360, 0.327, 0.0),
      (0.361, 0.304, 0.0),
      (0.360, 0.292, 0.0),
    ],
    'WNG14': [
      (0.365, 0.305, 0.0),
      (0.365, 0.317, 0.0),
      (0.365, 0.295, 0.0),
      (0.365, 0.292, 0.0),
    ],
    'WNG15': [
      (0.380, 0.325, 0.0),
      (0.375, 0.343, 0.0),
      (0.380, 0.312, 0.0),
      (0.380, 0.310, 0.0),
    ],
    'WNG16': [
      (0.380, 0.300, 0.0),
      (0.380, 0.303, 0.0),
      (0.381, 0.288, 0.0),
      (0.378, 0.283, 0.0),
    ],
    'WNG17': [
      (0.360, 0.320, 0.0),
      (0.360, 0.322, 0.0),
      (0.360, 0.316, 0.0),
      (0.360, 0.311, 0.0),
    ],
    'PIP01': [
      (0.159, 0.526, 0.0),
      (0.163, 0.526, 0.0),
      (0.167, 0.528, 0.0),
      (0.164, 0.523, 0.0),
    ],
    'PIP02': [
      (0.161, 0.510, 0.0),
      (0.159, 0.504, 0.0),
      (0.161, 0.495, 0.0),
      (0.160, 0.504, 0.0),
    ],
    'PIP03': [
      (0.134, 0.540, 0.0),
      (0.133, 0.551, 0.0),
      (0.135, 0.540, 0.0),
      (0.134, 0.552, 0.0),
    ],
    'PIP04': [
      (0.149, 0.525, 0.0),
      (0.147, 0.516, 0.0),
      (0.149, 0.518, 0.0),
      (0.148, 0.525, 0.0),
    ],
    'PIP05': [
      (0.150, 0.525, 0.0),
      (0.148, 0.525, 0.0),
      (0.146, 0.522, 0.0),
      (0.150, 0.522, 0.0),
    ],
    'PIP06': [
      (0.144, 0.530, 0.0),
      (0.141, 0.530, 0.0),
      (0.140, 0.535, 0.0),
      (0.142, 0.540, 0.0),
    ],
    'PIP07': [
      (0.150, 0.530, 0.0),
      (0.152, 0.530, 0.0),
      (0.150, 0.525, 0.0),
      (0.150, 0.528, 0.0),
    ],
    'PIP08': [
      (0.135, 0.520, 0.0),
      (0.133, 0.518, 0.0),
      (0.134, 0.513, 0.0),
      (0.133, 0.518, 0.0),
    ],
    'PIP09': [
      (0.111, 0.490, 0.0),
      (0.111, 0.488, 0.0),
      (0.109, 0.487, 0.0),
      (0.112, 0.485, 0.0),
    ],
    'PIP10': [
      (0.121, 0.535, 0.0),
      (0.116, 0.531, 0.0),
      (0.116, 0.532, 0.0),
      (0.116, 0.532, 0.0),
    ],
    'PIP11': [
      (0.146, 0.525, 0.0),
      (0.148, 0.523, 0.0),
      (0.150, 0.521, 0.0),
      (0.148, 0.525, 0.0),
    ],
    'PIP12': [
      (0.132, 0.515, 0.0),
      (0.130, 0.513, 0.0),
      (0.127, 0.514, 0.0),
      (0.128, 0.513, 0.0),
    ],
    'PIP13': [
      (0.150, 0.525, 0.0),
      (0.145, 0.522, 0.0),
      (0.148, 0.523, 0.0),
      (0.143, 0.521, 0.0),
    ],
    'PIP14': [
      (0.136, 0.525, 0.0),
      (0.132, 0.522, 0.0),
      (0.134, 0.521, 0.0),
      (0.134, 0.516, 0.0),
    ],
    'PIP15': [
      (0.142, 0.535, 0.0),
      (0.140, 0.532, 0.0),
      (0.140, 0.530, 0.0),
      (0.140, 0.535, 0.0),
    ],
    'PIP16': [
      (0.180, 0.520, 0.0),
      (0.176, 0.517, 0.0),
      (0.179, 0.515, 0.0),
      (0.176, 0.512, 0.0),
    ],
    'PIP17': [
      (0.141, 0.515, 0.0),
      (0.141, 0.540, 0.0),
      (0.136, 0.510, 0.0),
      (0.134, 0.537, 0.0),
    ],
  };

  /// Where a costume sits on [species] in sprite frame [frame]: its place
  /// as fractions of the frame, its size as a fraction of the frame's
  /// width (a hat's width, a nose's radius), and its tilt.
  static ({double x, double y, double size, double tilt})? fitAt(
    String species,
    int frame,
  ) {
    final fit = placements[species];
    if (fit == null) return null;
    final frames = frameFits[species];
    if (frames == null || frames.isEmpty) {
      return (x: fit.$1, y: fit.$2, size: fit.$3, tilt: 0.0);
    }
    final f = frames[frame % frames.length];
    return (x: f.$1, y: f.$2, size: fit.$3, tilt: f.$3);
  }

  /// Whether a creature of [baseId] can wear this one.
  bool fits(String baseId) =>
      baseId.startsWith(family) && placements.containsKey(baseId);

  /// What a creature of [baseId] is saved as wearing this in [color] (its
  /// default if none), or null if it cannot.
  String? effectOn(String baseId, {Color? color}) {
    if (!fits(baseId)) return null;
    final argb = color?.toARGB32() ?? defaultColor.toARGB32();
    if (argb == defaultColor.toARGB32()) return '$_prefix$baseId';
    final hex = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '$_prefix$baseId$_colorMark${hex.toUpperCase()}';
  }

  /// The one a creature of [baseId] could wear, if any.
  static FamilyCostume? forSpecies(String baseId) =>
      values.where((c) => c.fits(baseId)).firstOrNull;

  /// What a creature of [baseId] is saved as wearing its costume, or null
  /// for a family that has none.
  static String? effectFor(String baseId) =>
      forSpecies(baseId)?.effectOn(baseId);

  static FamilyCostume? ofItem(String? itemKey) =>
      values.where((c) => c.itemKey == itemKey).firstOrNull;

  static FamilyCostume? ofOffer(String? offerId) =>
      values.where((c) => c.offerId == offerId).firstOrNull;

  static FamilyCostume? ofPreview(String? key) =>
      values.where((c) => c.previewKey == key).firstOrNull;

  /// The species a worn costume was fitted to, or null for anything else.
  static String? speciesFor(String? effect) {
    if (effect == null || !effect.startsWith(_prefix)) return null;
    final mark = effect.indexOf(_colorMark);
    final id = effect.substring(_prefix.length, mark < 0 ? null : mark);
    return placements.containsKey(id) ? id : null;
  }

  /// The colour of the costume worn as [effect]: its picked one, or its
  /// default.
  static Color colorOf(String? effect) =>
      (ofEffect(effect) ?? partyHat).colorIn(effect);

  /// The costume a creature is wearing as [effect], or null.
  static FamilyCostume? ofEffect(String? effect) {
    final species = speciesFor(effect);
    return species == null ? null : forSpecies(species);
  }

  static bool isEffect(String? effect) => ofEffect(effect) != null;
}
