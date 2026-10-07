// lib/widgets/fx/portal_harvest.dart
//
// Harvesting the creature that is standing in a portal screen.
//
// The shared encounter overlay hands a harvest to its host
// (EncounterOverlay.onHarvestInScene). A screen with no Flame scene to give
// the field to used to fall back to a full-screen card holding a freshly built
// copy of the sprite — the animal you were looking at blinked out and a
// stand-in was taken in front of you. This wraps the REAL sprite instead: the
// apparatus plays transparently over it, the sprite is read into grains, and on
// a take those grains are cut away behind the crest. One creature, taken.
//
// Used by the rift interior's pattern, the First Crossing and the Elemental
// Nexus.

import 'dart:math' as math;

import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/harvest_cinematic.dart';
import 'package:alchemons/widgets/fx/harvester_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class PortalHarvest {
  PortalHarvest({this.box = 240});

  /// Edge of the square the sprite is captured in. Wide enough for a size
  /// gene over 1, which draws past the sprite's nominal size.
  final double box;

  final GlobalKey _key = GlobalKey();

  /// The take's crest in grain units, or null while the creature is whole.
  final ValueNotifier<double?> cut = ValueNotifier<double?>(null);

  /// Wrap the live sprite so it can be read and cut away.
  Widget wrap(Widget sprite) {
    return ValueListenableBuilder<double?>(
      valueListenable: cut,
      builder: (context, crest, child) => ClipRect(
        clipper: SpriteCrestClipper(crest ?? double.negativeInfinity),
        clipBehavior: crest == null ? Clip.none : Clip.hardEdge,
        child: child,
      ),
      child: RepaintBoundary(
        key: _key,
        child: SizedBox.square(
          dimension: box,
          child: Center(child: sprite),
        ),
      ),
    );
  }

  /// The [EncounterOverlay.onHarvestInScene] callback.
  Future<bool> run(
    BuildContext context,
    Color accent,
    Future<bool> Function() task,
    HarvesterProfile profile,
  ) {
    return showHarvestCinematic(
      context: context,
      targetSprite: null,
      targetColor: accent,
      profile: profile,
      liveTarget: HarvestTarget(
        read: () async {
          final box = _key.currentContext?.findRenderObject();
          if (box is! RenderRepaintBoundary || !box.attached) return null;
          final centre = box.localToGlobal(box.size.center(Offset.zero));
          final grains = await SpecimenGrains.capture(
            box,
            pixelRatio: math.min(MediaQuery.devicePixelRatioOf(context), 2.5),
          );
          return grains == null ? null : (grains, centre, 1.0);
        },
        onCut: (crest) => cut.value = crest,
      ),
      task: task,
    );
  }

  /// Hand the creature back whole after a failed take.
  void restore() => cut.value = null;

  void dispose() => cut.dispose();
}
