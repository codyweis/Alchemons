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

/// Descends to the home biome through the glyph portal (landscape there,
/// portrait back) and resolves when the player comes back up.
///
/// [fromSpace] marks the descent that unlocks the home screen's portal.
Future<void> descendToHomeBiome(
  BuildContext context, {
  bool fromSpace = false,
}) async {
  final settings = context.read<AlchemonsDatabase>().settingsDao;
  final layout = await HomeBiomeLayout.loadOpen(settings);
  if (!context.mounted) return;
  final ready = ValueNotifier<bool>(false);
  await VoidPortal.pushThroughGlyphs<void>(
    context,
    page: HomeBiomeScreen(revealReady: ready),
    title: 'Home',
    label: 'DESCENDING',
    // The realm it is now borrows the portal of the wild one.
    element: layout.realm.portalElement,
    ready: ready,
    orientation: const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ],
    returnOrientation: const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ],
  );
  if (fromSpace) await settings.setSetting(HomePortalKeys.unlocked, '1');
}
