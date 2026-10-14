// lib/widgets/fx/albino_look.dart
//
// HOW AN ALBINO LOOKS — one look everywhere.
//
//   • Its body: ivory, not grey. Pigment is what an albino lacks, so a dark
//     species comes out as pale as a light one: its light and shade evened
//     out, then laid on a warm ramp — cream in the light, a faint rose in the
//     shadow, as skin with no pigment shows the blood under it — with a
//     whisper of its own colors left in.
//   • Its eyes: red. Each polished species (Lets, Pips, Horns, Wings) has an
//     overlay beside its sheet, `…_albino_eyes.png`, the eyes already
//     colored crimson to pink in its own frames (built by
//     test/albino_eyes_build_test.dart).
//
// Both are baked into the albino's own copy of the sheet (mutation_sheets.dart),
// so every place that draws a sprite draws it unchanged, with no filter of its
// own: see [albinoBaked]. A mutated albino's sheet carries its mutation
// instead, and is drawn through [kAlbinoMatrix] — as are the grains an albino
// is read into.

import 'dart:ui' as ui;

import 'package:alchemons/utils/sprite_sheet_def.dart';

/// Whether [v] is drawn albino. A prismatic creature never is: its hue trumps.
bool isAlbinoLook(SpriteVisuals v) => v.brightness == 1.45 && !v.isPrismatic;

/// Whether an albino drawn with [mutation] has its look baked into its own
/// sheet: all but a mutated one.
bool albinoBakes({required bool albino, String? mutation}) =>
    albino && mutation == null;

/// Whether [v]'s albino look is in its sheet ([sheetForVisuals] names that
/// sheet), so it is drawn with no genetics filter at all.
bool albinoBaked(SpriteVisuals v) =>
    albinoBakes(albino: isAlbinoLook(v), mutation: v.mutation);

/// The filter an albino [v] is drawn with: none when its sheet carries the
/// look, the albino colors over a mutated one's sheet.
ui.ColorFilter? albinoFilter(SpriteVisuals v) =>
    albinoBaked(v) ? null : kAlbinoFilter;

const ui.ColorFilter kAlbinoFilter = ui.ColorFilter.matrix(kAlbinoMatrix);

/// The albino body's ramp, dark to light: a warm near-black for its
/// outlines, rose in the shadow, ivory, cream white.
const List<(double, int)> kAlbinoRamp = [
  (0.00, 0x2B2125),
  (0.22, 0x6B5A5B),
  (0.45, 0xB4A39F),
  (0.68, 0xE6D9CF),
  (0.86, 0xF6EEE4),
  (1.00, 0xFFFCF6),
];

/// How much of its own colors an albino keeps.
const double kAlbinoPigment = 0.18;

/// Where a species' middle light lands on [kAlbinoRamp] once evened out: a
/// dark species is lifted to it, a light one left as it is.
const double kAlbinoMid = 0.7;

/// An albino body's colors as one color matrix (translation in 0..255), for
/// where it is drawn without its sheet: its luminance lifted to ivory with
/// [kAlbinoPigment] of its own colors kept. Close to the baked look on a
/// light species; it does not even out a dark one.
const List<double> kAlbinoMatrix = [
  (_liftR - kAlbinoPigment) * _lr + kAlbinoPigment,
  (_liftR - kAlbinoPigment) * _lg,
  (_liftR - kAlbinoPigment) * _lb,
  0,
  12,
  (_liftG - kAlbinoPigment) * _lr,
  (_liftG - kAlbinoPigment) * _lg + kAlbinoPigment,
  (_liftG - kAlbinoPigment) * _lb,
  0,
  5,
  (_liftB - kAlbinoPigment) * _lr,
  (_liftB - kAlbinoPigment) * _lg,
  (_liftB - kAlbinoPigment) * _lb + kAlbinoPigment,
  0,
  9,
  0,
  0,
  0,
  1,
  0,
];

const double _lr = 0.299, _lg = 0.587, _lb = 0.114;

/// How much brighter each channel comes out than the luminance it is read
/// from: a mid-tone lands on warm ivory, the lights on cream white.
const double _liftR = 1.55, _liftG = 1.50, _liftB = 1.40;

/// The species whose albinos have red eyes: those with an eye overlay. Every
/// polished species but the Airlet, whose eyes are drawn shut.
const Set<String> kAlbinoEyeSpecies = {
  'HOR01', 'HOR02', 'HOR03', 'HOR04', 'HOR05', 'HOR06', 'HOR07', 'HOR08', //
  'HOR09', 'HOR10', 'HOR11', 'HOR12', 'HOR13', 'HOR14', 'HOR15', 'HOR16',
  'HOR17', 'LET01', 'LET02', 'LET03', 'LET05', 'LET06', 'LET07', 'LET08',
  'LET09', 'LET10', 'LET11', 'LET12', 'LET13', 'LET14', 'LET15', 'LET16',
  'LET17', 'PIP01', 'PIP02', 'PIP03', 'PIP04', 'PIP05', 'PIP06', 'PIP07',
  'PIP08', 'PIP09', 'PIP10', 'PIP11', 'PIP12', 'PIP13', 'PIP14', 'PIP15',
  'PIP16', 'PIP17', 'WNG01', 'WNG02', 'WNG03', 'WNG04', 'WNG05', 'WNG06',
  'WNG07', 'WNG08', 'WNG09', 'WNG10', 'WNG11', 'WNG12', 'WNG13', 'WNG14',
  'WNG15', 'WNG16', 'WNG17',
};

/// The eye overlay beside the sheet at [sheetPath] (a path under
/// `assets/images/`), or null for a species without one.
String? albinoEyesPath(String sheetPath) {
  final file = sheetPath.split('/').last;
  if (file.length < 5 || !kAlbinoEyeSpecies.contains(file.substring(0, 5))) {
    return null;
  }
  return sheetPath.replaceAll('_spritesheet.png', '_albino_eyes.png');
}
