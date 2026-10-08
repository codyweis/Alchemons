// lib/screens/heart_puzzle/altar_realm.dart
//
// THE ALTARS' backdrops: each chapter is played in one of the game's own
// realms (the author, 2026-10-08: "each chapter should be a different
// backdrop, similar to the wilderness scene"). The real field, live but
// quiet — no creatures, no encounters, no touch — drifting slowly behind
// the stage, at an hour chosen so the puzzle reads over it, and darkened
// above so the orbs and the goal stand out against its sky.
//
// Like the shop's realm previews, the field is built paused, warmed with
// two still steps behind black, then faded up — so its heavy first frames
// never show, and the stage opens over it smoothly.

import 'package:alchemons/games/heart_puzzle/heart_puzzle_levels.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/scenes/dunes/dunes_scene.dart';
import 'package:alchemons/models/scenes/geode/geode_scene.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/sky/sky_scene.dart';
import 'package:alchemons/models/scenes/swamp/swamp_scene.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/models/scenes/volcano/volcano_scene.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// One chapter's realm: the field, the hour it is shown at, and how much
/// its sky is darkened under the puzzle (0 none, 1 black).
class AltarRealm {
  const AltarRealm(this.scene, this.hour, {this.dim = .55, this.drift = 5});
  final SceneDefinition Function() scene;
  final double hour, dim, drift;
}

/// Which realm each chapter is played in (the author's picks, 2026-10-08).
AltarRealm altarRealmFor(AltarChapter c) => switch (c.name) {
  'Basics' => AltarRealm(() => valleySceneCorrected, 18.4),
  'Rising' => AltarRealm(() => skyScene, 19.6),
  'The Split' => AltarRealm(() => swampScene, 21.2),
  'Species' => AltarRealm(() => dunesScene, 17.6),
  'Stacks' => AltarRealm(() => geodeScene, 20.5),
  _ => AltarRealm(() => volcanoScene, 22.5),
};

/// The realm behind the stage, faded up once it has drawn itself.
class AltarRealmView extends StatefulWidget {
  const AltarRealmView({super.key, required this.realm, this.onReady});
  final AltarRealm realm;
  final VoidCallback? onReady;

  @override
  State<AltarRealmView> createState() => _AltarRealmViewState();
}

class _AltarRealmViewState extends State<AltarRealmView> {
  SceneGame? _game;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final r = widget.realm;
    // Paused before it is mounted, so the loop never starts on its own.
    final game = SceneGame(scene: r.scene(), showcase: true)
      ..fieldHourOverride = r.hour
      ..panDrift = r.drift
      ..pauseEngine();
    setState(() => _game = game);
    try {
      await game.loaded.timeout(const Duration(seconds: 8));
    } catch (_) {}
    // Two still steps: the first mounts the world and camera, the second
    // lays them out; each is painted before the next.
    for (var i = 0; i < 2; i++) {
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      game.stepEngine(stepTime: 0);
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    setState(() => _ready = true);
    game.resumeEngine();
    widget.onReady?.call();
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    final dim = widget.realm.dim;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          if (game != null)
            AnimatedOpacity(
              opacity: _ready ? 1 : 0,
              duration: const Duration(milliseconds: 1400),
              curve: Curves.easeOut,
              child: RepaintBoundary(child: GameWidget(game: game)),
            ),
          // Its sky darkened under the puzzle, most at the top where the goal
          // hangs; the ground the altars stand on left nearly as it is, and
          // the foreground, where the hand waits, brought down again.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: dim),
                  Colors.black.withValues(alpha: dim * .8),
                  Colors.black.withValues(alpha: dim * .3),
                  Colors.black.withValues(alpha: dim * .45),
                  Colors.black.withValues(alpha: dim * .95),
                ],
                stops: const [0, .42, .66, .82, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
