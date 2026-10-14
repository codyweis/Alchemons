// lib/widgets/fx/variant_look.dart
//
// HOW A FACTION VARIANT LOOKS.
//
// A variant of a polished species (Lets, Pips, Horns, Wings) is a palette
// swap: its main color turns to its faction's, and every other color turns
// with it by the same amount, so its parts keep their contrast with each
// other. The turn is made in OKLab, so nothing darkens or greys on the way:
// its light and shade, its glints and outlines stay as drawn, and its eyes
// keep their own color (the eye overlays beside the sheets, built for the
// albino look, say where they are). Earthen is muted toward ochre-brown,
// clear of Volcanic's orange.
//
// It is baked into the variant's own copy of the sheet (mutation_sheets.dart),
// so every place that draws a sprite draws it with no faction tint of its own:
// see [variantBaked]. The other families still wear their faction's color
// multiplied over them until their sprites are polished.

import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/fx/albino_look.dart';

/// The families whose variants are a palette swap.
const Set<String> kVariantSwapFamilies = {'LET', 'PIP', 'HOR', 'WNG'};

/// Each faction's swap: the hue its variants' main color lands on (OKLCh,
/// degrees), and how much of the creature's color strength and light it
/// keeps. Bloodborn has none: it wears no pigment of its own.
const Map<String, ({double hue, double chroma, double light})> kVariantPalette =
    {
      'Volcanic': (hue: 38, chroma: 1.0, light: 1.0),
      'Oceanic': (hue: 245, chroma: 1.0, light: 1.0),
      'Verdant': (hue: 150, chroma: 1.0, light: 1.0),
      'Earthen': (hue: 72, chroma: 0.5, light: 0.93),
      'Arcane': (hue: 308, chroma: 1.0, light: 1.0),
    };

/// The species a sheet at [sheetPath] draws ('LET01'…), from its file name.
String? speciesOfSheet(String sheetPath) {
  final file = sheetPath.split('/').last;
  return file.length < 5 ? null : file.substring(0, 5);
}

/// The faction a variant of [speciesId] in [faction] is swapped to, in
/// [kVariantPalette]'s spelling, or null when it is not baked: no variant,
/// Bloodborn, another family, an albino (no pigment to turn) or a mutated one
/// (its sheet carries the mutation, and the faction is tinted over it).
String? variantSwap({
  required String? speciesId,
  required String? faction,
  bool albino = false,
  String? mutation,
}) {
  if (albino || mutation != null || faction == null || speciesId == null) {
    return null;
  }
  if (speciesId.length < 3 ||
      !kVariantSwapFamilies.contains(speciesId.substring(0, 3))) {
    return null;
  }
  final key = faction.trim().toLowerCase();
  for (final name in kVariantPalette.keys) {
    if (name.toLowerCase() == key) return name;
  }
  return null;
}

/// Whether [v]'s variant is in its sheet ([sheetForVisuals] names that
/// sheet), so it is drawn with no faction tint over it.
bool variantBaked(SpriteVisuals v) =>
    variantSwap(
      speciesId: v.speciesId,
      faction: v.variantFaction,
      albino: isAlbinoLook(v),
      mutation: v.mutation,
    ) !=
    null;
