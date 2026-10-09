import 'package:alchemons/models/inventory.dart';
import 'package:flutter/painting.dart';

part 'costume_fits.dart';

/// The costumes: a hat, a nose, sunglasses. Bought in the shop, kept in the
/// inventory, and worn all at once if wanted — beside an alchemy effect, not
/// in its place. Each fits the species it has been fitted to (see
/// costume_fits.dart) and is part of the sprite, not an effect round it:
/// each sprite renderer paints it after the frame, in the frame's own space
/// (see `CostumePaint.paintWorn`). Each carries its color, picked as it goes
/// on and changed free after. What a creature wears is a [WornCostumes].
enum FamilyCostume {
  /// Alchemical Celebration: a stardust party hat.
  partyHat(
    tag: 'hat',
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

  /// Alchemical Nose: a ruby bubble nose.
  nose(
    tag: 'nose',
    title: 'Alchemical Nose',
    itemKey: InvKeys.alchemyNose,
    offerId: 'effects.alchemical_nose',
    previewKey: FamilyCostume.nosePreview,
    noun: 'nose',
    // The glass's own color, between its lit cap and its deep edge.
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
  ),

  /// Alchemical Sunglasses: smoked glass in an obsidian frame.
  sunglasses(
    tag: 'sunglasses',
    title: 'Alchemical Sunglasses',
    itemKey: InvKeys.alchemySunglasses,
    offerId: 'effects.alchemical_sunglasses',
    previewKey: FamilyCostume.sunglassesPreview,
    noun: 'sunglasses',
    // The lenses' tint at the cheek; they darken toward the brow the same
    // way in every tint.
    defaultColor: Color(0xFF2B2738),
    presets: [
      Color(0xFF2B2738), // smoke
      Color(0xFF8C5A14), // amber
      Color(0xFF8A1F33), // ruby
      Color(0xFF8C2F6A), // rose
      Color(0xFF5A2E8F), // violet
      Color(0xFF1F3F8C), // sapphire
      Color(0xFF16706C), // teal
      Color(0xFF256B2E), // emerald
      Color(0xFF8C7A2A), // gold
    ],
    ringSaturation: 0.78,
    ringValue: 0.55,
  );

  const FamilyCostume({
    required this.tag,
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

  /// What it is saved as in a [WornCostumes]: never change one.
  final String tag;

  /// What it is called in the shop and the inventory.
  final String title;
  final String itemKey;
  final String offerId;

  /// Drawn on its own, with no creature (the shop and inventory cards).
  final String previewKey;

  /// What it is, in a line of UI: "hat", "nose", "sunglasses".
  final String noun;

  /// Its color when none was picked: the one it was designed in.
  final Color defaultColor;

  /// Hand-picked colors, offered beside the hue ring.
  final List<Color> presets;

  /// How strong and how light every color round the ring is.
  final double ringSaturation, ringValue;

  static const hatPreview = 'celebration';
  static const nosePreview = 'alchemical_nose';
  static const sunglassesPreview = 'alchemical_sunglasses';

  /// The order they are drawn in over a sprite: the glasses on the face,
  /// the nose over their bridge, the hat over everything above.
  static const paintOrder = [sunglasses, nose, partyHat];

  /// Its color at [hue] in turns round the wheel (0..1): the same depth in
  /// every hue, so no pick reads as another material.
  Color colorForHue(double hue) => HSVColor.fromAHSV(
    1,
    (hue % 1) * 360,
    ringSaturation,
    ringValue,
  ).toColor();

  /// Frame-0 fits by species: see [_placements].
  Map<String, (double, double, double)> get placements =>
      _placements[this] ?? const {};

  /// Per-frame fits by species: see [_frameFits].
  Map<String, List<(double, double, double)>> get frameFits =>
      _frameFits[this] ?? const {};

  /// Frame-0 head tilts by species: see [_tilts].
  Map<String, double> get tilts => _tilts[this] ?? const {};

  /// Whether a creature of [baseId] can wear this one.
  bool fits(String baseId) => placements.containsKey(baseId);

  /// Where it sits on [species] in sprite frame [frame]: its place as
  /// fractions of the frame, its size as a fraction of the frame's width (a
  /// hat's width, a nose's radius, the glasses' eye-to-eye), and its tilt.
  /// Null for a species it does not fit.
  ({double x, double y, double size, double tilt})? fitAt(
    String species,
    int frame,
  ) {
    final fit = placements[species];
    if (fit == null) return null;
    final tilt = tilts[species] ?? 0.0;
    final frames = frameFits[species];
    if (frames == null || frames.isEmpty) {
      return (x: fit.$1, y: fit.$2, size: fit.$3, tilt: tilt);
    }
    final f = frames[frame % frames.length];
    return (x: f.$1, y: f.$2, size: fit.$3, tilt: tilt + f.$3);
  }

  /// The species prefixes it fits, in the order of [familyNames].
  static List<String> get fittedFamilies => [
    for (final family in familyNames.keys)
      if (values.every(
        (c) => c.placements.keys.any((s) => s.startsWith(family)),
      ))
        family,
  ];

  /// What each family is called, for "fits Wings, Pips…".
  static const familyNames = {
    'WNG': 'Wings',
    'PIP': 'Pips',
    'HOR': 'Horns',
    'LET': 'Lets',
    'MAN': 'Manes',
    'MSK': 'Masks',
    'KIN': 'Kins',
    'MYS': 'Mystics',
  };

  /// "Wings, Pips, Horns and Lets": who any costume fits, for a line of UI.
  static String get fittedFamiliesText {
    final names = [for (final f in fittedFamilies) familyNames[f]!];
    if (names.length < 2) return names.join();
    return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }

  static FamilyCostume? ofTag(String? tag) =>
      values.where((c) => c.tag == tag).firstOrNull;

  static FamilyCostume? ofItem(String? itemKey) =>
      values.where((c) => c.itemKey == itemKey).firstOrNull;

  static FamilyCostume? ofOffer(String? offerId) =>
      values.where((c) => c.offerId == offerId).firstOrNull;

  static FamilyCostume? ofPreview(String? key) =>
      values.where((c) => c.previewKey == key).firstOrNull;
}

/// What one creature wears: which costumes, each in its color. Saved in
/// its `costumes` column as `<species>:<tag>[#RRGGBB],<tag>…` — the species
/// says where each is fitted, so a renderer needs nothing else; no color is
/// the costume's own.
class WornCostumes {
  const WornCostumes(this.species, this.colors);

  final String species;

  /// Each costume worn, in its color.
  final Map<FamilyCostume, Color> colors;

  bool get isEmpty => colors.isEmpty;
  bool wears(FamilyCostume costume) => colors.containsKey(costume);

  /// Its color on this creature: the picked one, or its own.
  Color colorOf(FamilyCostume costume) =>
      colors[costume] ?? costume.defaultColor;

  /// The same with [costume] on in [color] (its own if null).
  WornCostumes wear(FamilyCostume costume, {Color? color}) => WornCostumes(
    species,
    {...colors, costume: color ?? costume.defaultColor},
  );

  /// The same with [costume] off.
  WornCostumes without(FamilyCostume costume) =>
      WornCostumes(species, {...colors}..remove(costume));

  /// As saved; null when nothing is worn.
  String? encode() {
    if (colors.isEmpty) return null;
    final parts = <String>[];
    for (final costume in FamilyCostume.values) {
      final color = colors[costume];
      if (color == null) continue;
      final argb = color.toARGB32();
      if (argb == costume.defaultColor.toARGB32()) {
        parts.add(costume.tag);
      } else {
        final hex = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
        parts.add('${costume.tag}#${hex.toUpperCase()}');
      }
    }
    return '$species:${parts.join(',')}';
  }

  /// What [saved] says is worn — only costumes that fit its species, in
  /// colors that read. Read every frame by the renderers, so kept.
  static WornCostumes? parse(String? saved) {
    if (saved == null || saved.isEmpty) return null;
    final kept = _parsed[saved];
    if (kept != null || _parsed.containsKey(saved)) return kept;
    if (_parsed.length >= 256) _parsed.clear();
    return _parsed[saved] = _read(saved);
  }

  static final _parsed = <String, WornCostumes?>{};

  static WornCostumes? _read(String saved) {
    final colon = saved.indexOf(':');
    if (colon < 0) return null;
    final species = saved.substring(0, colon);
    final colors = <FamilyCostume, Color>{};
    for (final part in saved.substring(colon + 1).split(',')) {
      final mark = part.indexOf('#');
      final costume = FamilyCostume.ofTag(
        mark < 0 ? part : part.substring(0, mark),
      );
      if (costume == null || !costume.fits(species)) continue;
      final rgb = mark < 0
          ? null
          : int.tryParse(part.substring(mark + 1), radix: 16);
      colors[costume] = rgb == null || rgb > 0xFFFFFF
          ? costume.defaultColor
          : Color(0xFF000000 | rgb);
    }
    return colors.isEmpty ? null : WornCostumes(species, colors);
  }

  /// What a creature of [species] wears, from its saved [saved]; nothing
  /// worn if none.
  static WornCostumes on(String species, String? saved) {
    final worn = parse(saved);
    return worn != null && worn.species == species
        ? worn
        : WornCostumes(species, const {});
  }
}
