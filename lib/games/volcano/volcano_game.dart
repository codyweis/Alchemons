import 'dart:math';
import 'package:alchemons/screens/scenes/volcano_scene.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class VolcanoGame extends FlameGame with PanDetector {
  VolcanoGame({required this.slots});

  final List<TrophySlot> slots;
  void Function(TrophySlot slot)? onShowDetails;

  // How far you *intend* to allow scrolling, in world units.
  // The clouds layer will be built large enough to cover this,
  // and the actual scroll end is derived from its built width.
  final Vector2 worldSize = Vector2(20000, 10000);

  // Camera early-construct to avoid late-init on resize
  final CameraComponent cam = CameraComponent();

  // Parallax parent (constructed up-front)
  final PositionComponent layersRoot = PositionComponent()..priority = -200;

  // Half-speed scroll
  double scrollSensitivity = 0.5;

  // Optional overall parallax art scale (before fitting to screen height)
  double sceneScale = 1.0;

  // Camera X in world units
  double _cameraX = 0;

  // Actual max camera X computed from the clouds width
  double _maxCamX = 0;

  // Screen helpers (world units == logical pixels at zoom=1)
  double get _screenW => size.x;
  double get _screenH => size.y;

  // Parallax factors (0 = static, 1 = camera speed)
  static const double _fSky = 0.0;
  static const double _fClouds = 0.2; // longest layer; defines scroll end
  static const double _fBackHills = 0.4;
  static const double _fHills = 0.8;
  static const double _fForeground = 0.9;

  // Extra width per layer (multiplying one tile). Tunable.
  static const double _wSky = 1.0;
  static const double _wClouds = 1.2;
  static const double _wBackHills = 1.5;
  static const double _wHills = 2.0;
  static const double _wForeground = 2.5;

  // Layers are nullable until onLoad wires them up
  _FiniteLayer? _skyLayer;
  _FiniteLayer? _cloudsLayer;
  _FiniteLayer? _backHillsLayer;
  _FiniteLayer? _hillsLayer;
  _FiniteLayer? _foregroundLayer;

  @override
  Future<void> onLoad() async {
    await images.loadAll([
      'backgrounds/scenes/volcano/sky.png',
      'backgrounds/scenes/volcano/clouds.png',
      'backgrounds/scenes/volcano/backhills.png',
      'backgrounds/scenes/volcano/hills.png',
      'backgrounds/scenes/volcano/foreground.png',
      ...slots.map((s) => s.spritePath),
    ]);

    final world = World()..priority = 0;
    add(world);

    // Parallax root affected by camera
    layersRoot.scale = Vector2.all(sceneScale);
    world.add(layersRoot);

    // Build layers (tiling decided during layout)
    _skyLayer = _FiniteLayer(
      layersRoot,
      Sprite(images.fromCache('backgrounds/scenes/volcano/sky.png')),
      priority: -105,
      parallaxFactor: _fSky,
      widthMul: _wSky,
    );
    _cloudsLayer = _FiniteLayer(
      layersRoot,
      Sprite(images.fromCache('backgrounds/scenes/volcano/clouds.png')),
      priority: -104,
      parallaxFactor: _fClouds,
      widthMul: _wClouds,
    );
    _backHillsLayer = _FiniteLayer(
      layersRoot,
      Sprite(images.fromCache('backgrounds/scenes/volcano/backhills.png')),
      priority: -103,
      parallaxFactor: _fBackHills,
      widthMul: _wBackHills,
    );
    _hillsLayer = _FiniteLayer(
      layersRoot,
      Sprite(images.fromCache('backgrounds/scenes/volcano/hills.png')),
      priority: -102,
      parallaxFactor: _fHills,
      widthMul: _wHills,
    );
    _foregroundLayer = _FiniteLayer(
      layersRoot,
      Sprite(images.fromCache('backgrounds/scenes/volcano/foreground.png')),
      priority: -101,
      parallaxFactor: _fForeground,
      widthMul: _wForeground,
    );

    // Camera
    cam
      ..world = world
      ..viewfinder.anchor = Anchor.center
      ..viewfinder.zoom = 1.0
      ..priority = 100;
    add(cam);

    // Trophies
    _addTrophySlots(world);

    // Layout + start position
    _layoutLayersForScreen();
    _cameraX = 0;
    cam.viewfinder.position = Vector2(_screenW / 2, _screenH / 2);
    _updateParallaxLayers();
  }

  @override
  void onGameResize(Vector2 canvasSize) {
    super.onGameResize(canvasSize);
    _layoutLayersForScreen();
    if (cam.isMounted) {
      _cameraX = _cameraX.clamp(0, _maxCamX);
      cam.viewfinder.position = Vector2(_cameraX + _screenW / 2, _screenH / 2);
    }
    _updateParallaxLayers();
  }

  void _layoutLayersForScreen() {
    if (_cloudsLayer == null) return;

    final invRootScale = 1.0 / layersRoot.scale.x;
    final Vr = _screenW * invRootScale; // viewport width in root-space
    final Vh = _screenH * invRootScale; // viewport height in root-space
    final targetTravel = max(
      0.0,
      worldSize.x - _screenW,
    ); // desired camera travel

    // Helper: compute per-sprite tile size when fitted by height
    Vector2 heightFitTile(Sprite s) {
      final imgW = s.image.width.toDouble();
      final imgH = s.image.height.toDouble();
      final scale = Vh / imgH;
      return Vector2(imgW * scale, imgH * scale); // root-space
    }

    // 1) Build clouds wide enough to cover desired travel:
    final cloudsTile = heightFitTile(_cloudsLayer!.sprite);
    final cloudsTileW = cloudsTile.x * _cloudsLayer!.widthMul;
    final cloudsRequiredW =
        Vr + _fClouds * targetTravel; // root-space width needed
    final cloudsTilesNeeded = max(
      2,
      (cloudsRequiredW / max(1e-6, cloudsTileW)).ceil(),
    );
    _cloudsLayer!.buildOrUpdate(
      Vector2(cloudsTileW, cloudsTile.y),
      cloudsTilesNeeded,
    );

    // From clouds final width, derive actual max camera X (finite end)
    final cloudsTotalW = _cloudsLayer!.totalWidth; // root-space
    _maxCamX = max(
      0.0,
      (cloudsTotalW - Vr) / max(1e-6, _fClouds),
    ); // back to world units

    // 2) Build the rest wide enough for *their* drift over maxCamX
    void layoutOther(_FiniteLayer? layer) {
      if (layer == null) return;
      final t = heightFitTile(layer.sprite);
      final tileW = t.x * layer.widthMul;
      final requiredW =
          Vr + layer.parallaxFactor * _maxCamX; // root-space coverage
      final tilesNeeded = max(2, (requiredW / max(1e-6, tileW)).ceil());
      layer.buildOrUpdate(Vector2(tileW, t.y), tilesNeeded);
    }

    layoutOther(_skyLayer);
    layoutOther(_backHillsLayer);
    layoutOther(_hillsLayer);
    layoutOther(_foregroundLayer);
  }

  void _updateParallaxLayers() {
    // Each layer clamps inside [-(totalWidth - Vr), 0]
    final invRootScale = 1.0 / layersRoot.scale.x;
    final Vr = _screenW * invRootScale;

    _skyLayer?.updateOffsetClamped(_cameraX, Vr);
    _cloudsLayer?.updateOffsetClamped(_cameraX, Vr);
    _backHillsLayer?.updateOffsetClamped(_cameraX, Vr);
    _hillsLayer?.updateOffsetClamped(_cameraX, Vr);
    _foregroundLayer?.updateOffsetClamped(_cameraX, Vr);
  }

  void _addTrophySlots(World world) {
    for (final slot in slots) {
      final worldPos = Vector2(
        slot.normalizedPos.dx * worldSize.x,
        _screenH / 2,
      );

      world.add(
        TrophyComponent(
          slot: slot,
          position: worldPos,
          size: Vector2(120, 120),
          onTapUnlocked: () => onShowDetails?.call(slot),
          onTapLocked: () => onShowDetails?.call(slot),
        ),
      );
    }
  }

  // --- Pan handling (half speed, clamped to end) ---
  @override
  void onPanUpdate(DragUpdateInfo info) {
    final deltaX = info.delta.global.x;

    final desired = _cameraX - deltaX * scrollSensitivity;
    _cameraX = desired.clamp(0.0, _maxCamX);

    cam.viewfinder.position = Vector2(_cameraX + _screenW / 2, _screenH / 2);
    _updateParallaxLayers();
  }

  @override
  void onPanEnd(DragEndInfo info) {
    // no inertia
  }
}

// --- Trophy Component (unchanged) ---
class TrophyComponent extends SpriteComponent
    with TapCallbacks, HasGameRef<VolcanoGame> {
  final TrophySlot slot;
  final VoidCallback onTapUnlocked;
  final VoidCallback onTapLocked;

  TrophyComponent({
    required this.slot,
    required this.onTapUnlocked,
    required this.onTapLocked,
    required super.position,
    required super.size,
  }) : super(anchor: Anchor.center, priority: 10);

  @override
  Future<void> onLoad() async {
    sprite = Sprite(gameRef.images.fromCache(slot.spritePath));

    if (slot.isUnlocked) {
      add(
        OpacityEffect.to(
          0.9,
          EffectController(
            duration: 1.5,
            reverseDuration: 1.5,
            alternate: true,
            infinite: true,
          ),
        ),
      );

      add(
        ScaleEffect.to(
          Vector2.all(1.05),
          EffectController(
            duration: 2.5,
            reverseDuration: 2.5,
            alternate: true,
            infinite: true,
          ),
        ),
      );
    } else {
      paint = Paint()..color = Colors.white.withOpacity(0.6);
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    slot.isUnlocked ? onTapUnlocked() : onTapLocked();

    add(
      ScaleEffect.to(
        Vector2.all(1.2),
        EffectController(duration: 0.1, reverseDuration: 0.1),
      ),
    );

    final screenW = gameRef.size.x;
    final targetX = (position.x - screenW / 2).clamp(0.0, gameRef._maxCamX);
    gameRef._cameraX = targetX;
    gameRef.cam.viewfinder.position = Vector2(
      gameRef._cameraX + screenW / 2,
      gameRef.size.y / 2,
    );
    gameRef._updateParallaxLayers();
  }
}

/// Finite (non-wrapping) tiled parallax layer.
/// Builds N tiles wide and clamps offset so edges line up at the ends.
class _FiniteLayer {
  _FiniteLayer(
    this.parent,
    this.sprite, {
    required this.priority,
    required this.parallaxFactor,
    required this.widthMul,
  }) : container = PositionComponent()
         ..priority = priority
         ..position = Vector2.zero();

  final PositionComponent parent;
  final Sprite sprite;
  final int priority;
  final double parallaxFactor;
  final double widthMul;

  final PositionComponent container;

  final List<SpriteComponent> _tiles = [];
  Vector2 _tileSize = Vector2.zero();
  double totalWidth = 0.0; // root-space

  void buildOrUpdate(Vector2 tileSize, int tilesNeeded) {
    _tileSize = tileSize;
    totalWidth = tileSize.x * tilesNeeded;

    if (!container.isMounted) {
      parent.add(container);
    }

    // Match tile count
    while (_tiles.length < tilesNeeded) {
      final tile = SpriteComponent(
        sprite: sprite,
        size: tileSize.clone(),
        position: Vector2.zero(),
        priority: priority,
      )..paint.filterQuality = FilterQuality.high;
      container.add(tile);
      _tiles.add(tile);
    }
    while (_tiles.length > tilesNeeded) {
      _tiles.removeLast().removeFromParent();
    }

    // Lay out side-by-side
    for (var i = 0; i < _tiles.length; i++) {
      _tiles[i].size = tileSize.clone();
      _tiles[i].position = Vector2(i * tileSize.x, 0);
    }

    container.position = Vector2.zero();
  }

  void updateOffsetClamped(double cameraX, double viewportWidthRootSpace) {
    // Desired offset for this parallax factor
    final raw = -(cameraX * parallaxFactor);
    // Clamp so we never expose beyond the edges
    final minX = -(max(0.0, totalWidth - viewportWidthRootSpace));
    final clamped = raw.clamp(minX, 0.0);
    container.position = Vector2(clamped, 0);
  }

  double get totalWidthRoot => totalWidth;
}
