// lib/screens/heart_puzzle/altar_bodies.dart
//
// THE ALTARS' creatures: each species on the stage as its own sprite sheet
// (drawn frame by frame) and as grains of itself (a RiteBody, read from its
// first frame) for the morphs and the rising — the same bodies the Heart
// uses, built from the catalog rather than a dungeon party.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/blood_rite_fx.dart';
import 'package:alchemons/games/wilderness/creature_feet.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/fx/element_orb.dart';
import 'package:alchemons/widgets/fx/mutation_sheets.dart';
import 'package:flame/flame.dart';
import 'package:flutter/painting.dart';

/// How big a Let stands, in theatre units; other families by the survival
/// and space family table, eased so a Kin still fits its seat.
const double kAltarLetBox = 38;

/// The box a body's grains are read in, and at how many pixels a unit.
const double kAltarSnapBox = 96, kAltarSnapRatio = 3;

double altarBoxOf(String fam) {
  final k = kCompanionSpeciesScale[fam.toLowerCase()] ?? 1.1;
  final let = kCompanionSpeciesScale['let'] ?? 1.1;
  return kAltarLetBox * math.pow(k / let, .6);
}

/// One species, ready to draw.
class AltarSpecies {
  AltarSpecies({
    required this.el,
    required this.fam,
    required this.id,
    required this.name,
    required this.sheet,
    required this.image,
    required this.body,
  }) : box = altarBoxOf(fam),
       feet = creatureFeetDrop(id);

  final String el, fam, id;

  /// The species' own name ('Poisonmane', 'Crystalet').
  final String name;
  final SpriteSheetDef sheet;
  final ui.Image image;
  final RiteBody body;

  /// The frame is drawn [box] units square; its feet sit [feet] of it below
  /// the frame's centre.
  final double box, feet;

  /// Where its centre is when its feet are at [feetAt].
  Offset centreFor(Offset feetAt) => feetAt - Offset(0, feet * box);

  int frameAt(double time) {
    final n = math.max(1, sheet.totalFrames);
    return (time / math.max(.03, sheet.stepTime)).floor() % n;
  }

  /// Its frame at [time], centred on [c].
  void paint(
    Canvas canvas,
    Offset c,
    double time, {
    double alpha = 1,
    double scale = 1,
    Rect? clip,
  }) {
    if (alpha <= .01) return;
    final rows = math.max(1, sheet.rows);
    final cols = (sheet.totalFrames + rows - 1) ~/ rows;
    final fw = sheet.frameSize.x, fh = sheet.frameSize.y;
    final f = frameAt(time);
    final s = box * scale / math.max(fw, fh);
    canvas.save();
    if (clip != null) canvas.clipRect(clip);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH((f % cols) * fw, (f ~/ cols) * fh, fw, fh),
      Rect.fromCenter(center: c, width: fw * s, height: fh * s),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0)),
    );
    canvas.restore();
  }
}

/// Loads each species once, by element and family.
class AltarBodies {
  AltarBodies(this.catalog);
  final CreatureCatalog catalog;
  final Map<String, Future<AltarSpecies?>> _loading = {};
  final Map<String, AltarSpecies> _ready = {};

  AltarSpecies? ready(String el, String fam) => _ready['$el $fam'];

  Future<AltarSpecies?> load(String el, String fam) =>
      _loading.putIfAbsent('$el $fam', () => _load(el, fam));

  Future<AltarSpecies?> _load(String el, String fam) async {
    final Creature? c = catalog.creatures
        .where(
          (c) =>
              c.types.isNotEmpty &&
              c.types.first == el &&
              (c.mutationFamily ?? '').toLowerCase() == fam.toLowerCase() &&
              c.spriteData != null,
        )
        .firstOrNull;
    if (c == null) return null;
    final sheet = sheetFromCreature(c);
    final ui.Image image;
    try {
      image = await loadCreatureSheet(Flame.images, sheet.path);
    } catch (_) {
      return null;
    }
    final body = RiteBody(elementOrbTint(EssenceElement.of(el)));
    final sp = AltarSpecies(
      el: el,
      fam: fam,
      id: c.id,
      name: c.name,
      sheet: sheet,
      image: image,
      body: body,
    );
    // Its grains, from its first frame in the snapshot box.
    final px = (kAltarSnapBox * kAltarSnapRatio).ceil();
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec)
      ..scale(kAltarSnapRatio)
      ..translate(kAltarSnapBox / 2, kAltarSnapBox / 2);
    sp.paint(canvas, Offset.zero, 0);
    await body.read(rec.endRecording().toImageSync(px, px), kAltarSnapRatio);
    body.force();
    return _ready['$el $fam'] = sp;
  }
}
