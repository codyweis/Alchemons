// lib/screens/home_biome/home_biome_window.dart
//
// The home biome, live, small: the field the player descends into, laid out
// at the phone's landscape size and scaled down to fill the home screen's
// portal (home_portal.dart), with the residents standing where they were
// left and the view drifting slowly along. Not touchable; the portal owns the
// finger.
//
// Paused whenever [active] is false — home covered, another tab, or the
// player gone down into the real thing — since a Flame game ticks on its own
// loop and TickerMode does not reach it.

import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:alchemons/screens/home_biome/home_biome_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class HomeBiomeWindow extends StatefulWidget {
  const HomeBiomeWindow({super.key, required this.active, this.onReady});

  /// Runs while true; held still while false.
  final bool active;

  /// Once the field is built and its residents stand in it.
  final VoidCallback? onReady;

  @override
  State<HomeBiomeWindow> createState() => _HomeBiomeWindowState();
}

class _HomeBiomeWindowState extends State<HomeBiomeWindow> {
  SceneGame? _game;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant HomeBiomeWindow old) {
    super.didUpdateWidget(old);
    final game = _game;
    if (game == null || old.active == widget.active) return;
    widget.active ? game.resumeEngine() : game.pauseEngine();
  }

  Future<void> _load() async {
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();
    final (layout, _, looks) = await loadHomeBiome(db, catalog);
    if (!mounted) return;
    bool floats(String id) => speciesCanFloat(looks[id]?.$1.id ?? '');
    final mood = layout.mood;
    final game = SceneGame(scene: layout.scene(floats), showcase: true)
      ..fieldHourOverride = layout.hour
      ..fieldWeather = mood.weather
      ..fieldAftermath = mood.aftermath
      ..fieldStage = mood.stage
      // As down there: the residents stroll, sleep at night, take portals.
      ..lively = true
      ..panDrift = 16;
    // Loading needs the loop (components mount in its updates), so it runs
    // from the start unless home is already covered.
    if (!widget.active) game.pauseEngine();
    setState(() => _game = game);
    await game.loaded;
    if (!mounted || _game != game) return;
    for (final r in layout.residents) {
      final look = looks[r.instanceId];
      if (look == null) continue;
      await game.showResident(
        r.spawnId,
        look.$1,
        instance: look.$2,
        flip: r.flip,
      );
    }
    // The keepsakes placed there (the scenery the field draws itself).
    standHomePieces(game, layout, catalog);
    await game.residentsLoaded().timeout(
      const Duration(seconds: 3),
      onTimeout: () => const [],
    );
    if (!mounted || _game != game) return;
    widget.onReady?.call();
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    if (game == null) return const SizedBox.expand();
    final screen = MediaQuery.sizeOf(context);
    // The field as it would be on the phone turned on its side, so it is
    // laid out (and its creatures sized) exactly as down there.
    final wide = Size(
      math.max(screen.width, screen.height),
      math.min(screen.width, screen.height),
    );
    return IgnorePointer(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox.fromSize(
          size: wide,
          child: GameWidget(game: game),
        ),
      ),
    );
  }
}
