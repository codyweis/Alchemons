// lib/screens/shop/shop_scene_card.dart
//
// A realm for sale (models/shop_scenes.dart), as the shop's SCENES tab shows
// it: the realm itself, live, drifting slowly along under the phone's own sky
// — the real field, not a picture of it — then what is found only there, and
// the price. Not touchable: the shop scrolls under the finger.
//
// The field is a Flame game, which ticks on its own loop and does not hear
// TickerMode, so the card holds it still whenever [active] is false (another
// tab, another route on top, scrolled away). Fields load one at a time behind
// a dark placeholder the first time the tab is shown, and stay built after.

import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/games/wilderness/field/home_sand_field.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/models/scenes/dunes/dunes_scene.dart';
import 'package:alchemons/models/scenes/geode/geode_scene.dart';
import 'package:alchemons/models/scenes/tidal/tidal_scene.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/shop_scenes.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// The wild scene a realm for sale is drawn from.
SceneDefinition sceneForShop(String sceneId) => switch (sceneId) {
  'sand' => homeSandScene(),
  'geode' => geodeScene,
  'tidal' => tidalScene,
  _ => dunesScene,
};

/// The realm, live and drifting.
///
/// Each field is a whole Flame game whose first frames (art layout, layer
/// mounting, first paint) are heavy, so the previews are built one at a time
/// through [_loadQueue] once the tab is on screen ([warm]), each warmed with
/// two still steps behind a dark placeholder before it is shown. Scrolling
/// then only moves pictures that already exist.
class ShopScenePreview extends StatefulWidget {
  const ShopScenePreview({
    super.key,
    required this.scene,
    required this.active,
    required this.warm,
  });

  final ShopScene scene;

  /// Runs while true; held still while false.
  final bool active;

  /// The Scenes tab is on screen: time to load, if not loaded already.
  final bool warm;

  @override
  State<ShopScenePreview> createState() => _ShopScenePreviewState();
}

class _ShopScenePreviewState extends State<ShopScenePreview> {
  /// Previews load one after another, never two in the same frames.
  static Future<void> _loadQueue = Future.value();

  SceneGame? _game;
  bool _queued = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (widget.warm) _enqueue();
  }

  @override
  void didUpdateWidget(covariant ShopScenePreview old) {
    super.didUpdateWidget(old);
    if (widget.warm && !_queued) _enqueue();
    if (!_ready || old.active == widget.active) return;
    widget.active ? _game!.resumeEngine() : _game!.pauseEngine();
  }

  void _enqueue() {
    _queued = true;
    final turn = Completer<void>();
    final previous = _loadQueue;
    _loadQueue = turn.future;
    previous.whenComplete(() async {
      try {
        await _load();
      } finally {
        turn.complete();
      }
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    // Paused before it is mounted, so the loop never starts on its own.
    final game = SceneGame(scene: sceneForShop(widget.scene.sceneId))
      ..panDrift = 14
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
    if (widget.active) game.resumeEngine();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    // Laid out as on the phone turned on its side, so the field and its
    // scenery are the size they are when you are there.
    final wide = Size(
      math.max(screen.width, screen.height),
      math.min(screen.width, screen.height),
    );
    final game = _game;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          if (game != null)
            RepaintBoundary(
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox.fromSize(
                  size: wide,
                  child: GameWidget(game: game),
                ),
              ),
            ),
          AnimatedOpacity(
            opacity: _ready ? 0 : 1,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOut,
            child: const _PreviewLoading(),
          ),
        ],
      ),
    );
  }
}

/// The dark field a preview sits behind until it has drawn itself.
class _PreviewLoading extends StatelessWidget {
  const _PreviewLoading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            color: Color(0x66E8D9B5),
          ),
        ),
      ),
    );
  }
}

/// A realm for sale: the realm, its name, a line on it, the Alchemons the
/// wild has nowhere else, and the price — or that it is already open.
class ShopSceneCard extends StatelessWidget {
  const ShopSceneCard({
    super.key,
    required this.scene,
    required this.offer,
    required this.theme,
    required this.owned,
    required this.costWidgets,
    required this.active,
    required this.warm,
    required this.onTap,
  });

  final ShopScene scene;
  final ShopOffer offer;
  final FactionTheme theme;
  final bool owned;
  final List<Widget> costWidgets;
  final bool active;
  final bool warm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.fromTheme(theme);
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: palette.line.withValues(alpha: 0.9),
          bracketSize: 11,
        ),
        child: Container(
          color: palette.surfaceFill(),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRect(
                  child: ShopScenePreview(
                    scene: scene,
                    active: active,
                    warm: warm,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scene.title.toUpperCase(),
                      style: bracketText(
                        context,
                        15,
                        palette.ink,
                        weight: FontWeight.w800,
                      ).copyWith(letterSpacing: 2),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      scene.line,
                      style: bracketText(
                        context,
                        12,
                        palette.muted,
                      ).copyWith(height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: palette.lineSoft),
              Container(
                height: 36,
                color: palette.chromeFill(darkAlpha: 0.7),
                alignment: Alignment.center,
                child: owned
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            AppIcons.check_rounded,
                            size: 14,
                            color: palette.muted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'OWNED',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: palette.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < costWidgets.length; i++) ...[
                            if (i > 0) const SizedBox(width: 10),
                            costWidgets[i],
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
