// lib/screens/shop/shop_scene_card.dart
//
// A realm for sale (models/shop_scenes.dart), as the shop's SCENES tab shows
// it: the realm itself, live, drifting slowly along under the phone's own sky
// — the real field, not a picture of it — then what is found only there, and
// the price. Not touchable: the shop scrolls under the finger.
//
// The field is a Flame game, which ticks on its own loop and does not hear
// TickerMode, so the card holds it still whenever [active] is false (another
// tab, another route on top, scrolled away).

import 'dart:math' as math;

import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/models/scenes/dunes/dunes_scene.dart';
import 'package:alchemons/models/scenes/geode/geode_scene.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/shop_scenes.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// The wild scene a realm for sale is drawn from.
SceneDefinition sceneForShop(String sceneId) => switch (sceneId) {
  'geode' => geodeScene,
  _ => dunesScene,
};

/// The realm, live and drifting.
class ShopScenePreview extends StatefulWidget {
  const ShopScenePreview({
    super.key,
    required this.scene,
    required this.active,
  });

  final ShopScene scene;

  /// Runs while true; held still while false.
  final bool active;

  @override
  State<ShopScenePreview> createState() => _ShopScenePreviewState();
}

class _ShopScenePreviewState extends State<ShopScenePreview> {
  late final SceneGame _game = SceneGame(
    scene: sceneForShop(widget.scene.sceneId),
  )..panDrift = 14;

  @override
  void initState() {
    super.initState();
    if (!widget.active) _game.pauseEngine();
  }

  @override
  void didUpdateWidget(covariant ShopScenePreview old) {
    super.didUpdateWidget(old);
    if (old.active == widget.active) return;
    widget.active ? _game.resumeEngine() : _game.pauseEngine();
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
    return IgnorePointer(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox.fromSize(
          size: wide,
          child: GameWidget(game: _game),
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
    required this.onTap,
  });

  final ShopScene scene;
  final ShopOffer offer;
  final FactionTheme theme;
  final bool owned;
  final List<Widget> costWidgets;
  final bool active;
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
                  child: ShopScenePreview(scene: scene, active: active),
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
                    const SizedBox(height: 10),
                    Text(
                      'ONLY FOUND HERE IN THE WILD',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: palette.muted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scene.species.join('  ·  '),
                      style: bracketText(
                        context,
                        12,
                        palette.ink,
                        weight: FontWeight.w600,
                      ).copyWith(height: 1.4),
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
