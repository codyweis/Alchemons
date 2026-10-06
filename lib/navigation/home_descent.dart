// lib/navigation/home_descent.dart
//
// The way down to the home biome under the home planet, shared by the two
// doors to it: DESCEND on the cosmic rail by the home planet, and the portal
// drawn round the featured Alchemon on the home screen. The first descent
// from space is what opens the second door.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/home_biome.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/screens/home_biome/home_biome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Settings rows for the home screen's portal.
abstract final class HomePortalKeys {
  /// Set by the first descent from space.
  static const unlocked = 'home_portal_unlocked';

  /// Whether the portal stands open on the home screen ('1').
  static const open = 'home_portal_open';

  /// The story notice telling how it works has been shown.
  static const told = 'home_portal_tutorial_seen';

  /// A circle has been drawn once: the traced guide stops showing.
  static const drawn = 'home_portal_drawn';
}

/// Descends to the home biome (landscape there, portrait back) and
/// resolves when the player comes back up.
///
/// [from] is the home screen's window onto it: that circle lifts off as
/// sand and comes undone into the biome. Without it (from space) the glyph
/// portal is the way down. [back] is where the biome's sand pours when it
/// is left. [fromSpace] marks the descent that unlocks the home screen's
/// portal.
Future<void> descendToHomeBiome(
  BuildContext context, {
  bool fromSpace = false,
  SandSource? from,
  SandLanding Function(String element)? back,
}) async {
  final settings = context.read<AlchemonsDatabase>().settingsDao;
  final layout = await HomeBiomeLayout.loadOpen(settings);
  if (!context.mounted) return;
  final ready = ValueNotifier<bool>(false);
  // The realm it is now borrows the light (and portal) of the wild one.
  final element = layout.realm.portalElement;
  const wide = [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];
  const tall = [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown];
  final page = HomeBiomeScreen(revealReady: ready);
  final way = back?.call(element) ?? SandLanding(element: element);
  if (from != null) {
    await VoidPortal.pushThroughSand<void>(
      context,
      page: page,
      from: from,
      title: 'Home',
      element: element,
      ready: ready,
      orientation: wide,
      returnOrientation: tall,
      back: way,
    );
  } else {
    await VoidPortal.pushThroughGlyphs<void>(
      context,
      page: page,
      title: 'Home',
      label: 'DESCENDING',
      element: element,
      ready: ready,
      orientation: wide,
      returnOrientation: tall,
      back: way,
    );
  }
  if (fromSpace) await settings.setSetting(HomePortalKeys.unlocked, '1');
}
