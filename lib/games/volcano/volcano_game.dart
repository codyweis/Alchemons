import 'dart:math';
import 'package:alchemons/models/trophy_slot.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class VolcanoGame extends FlameGame with ScaleDetector {
  VolcanoGame({required this.slots});

  final List<TrophySlot> slots;
  void Function(TrophySlot slot)? onShowDetails;

  // --- World & camera ---
  final Vector2 worldSize = Vector2(1000, 1000);
  final CameraComponent cam = CameraComponent();

  // Parallax root
  final PositionComponent layersRoot = PositionComponent()..priority = -200;

  // Camera state
  double _cameraX = 0;
  double _cameraY = 0;
  double _maxCamX = 0;
  double _maxCamY = 0;

  // Smooth zoom state
  double _targetZoom = 1.0; // where we want to be
  final double minZoom = 1.0; // don't zoom out past default
  final double maxZoom = 2.0;
  final double zoomEase = 15.0; // bigger = snappier; 8–16 feels good

  // Pan feel
  double scrollSensitivity = 0.25;

  // Scene scale (pre-fit)
  double sceneScale = 1.0;

  // Screen helpers
  double get _screenW => size.x;
  double get _screenH => size.y;

  // Parallax factors
  static const double _fSky = 0.0;
  static const double _fClouds = 0.05;
  static const double _fForeground = 0.2;
  static const double _fBackHills = 0.4;
  static const double _fHills = 1.0;

  // Width multipliers (one tile)
  static const double _wSky = 1.0;
  static const double _wClouds = 1.0;
  static const double _wBackHills = 1.0;
  static const double _wHills = 1.0;
  static const double _wForeground = 1.0;

  // Layers
  _FiniteLayer? _skyLayer;
  _FiniteLayer? _cloudsLayer;
  _FiniteLayer? _backHillsLayer;
  _FiniteLayer? _hillsLayer;
  _FiniteLayer? _foregroundLayer;

  double _Vh = 0; // viewport height in root-space

  _FiniteLayer? _layerFor(AnchorLayer a) => switch (a) {
    AnchorLayer.layer1 => _hillsLayer,
    AnchorLayer.layer2 => _backHillsLayer,
    AnchorLayer.layer3 => _cloudsLayer,
    AnchorLayer.layer4 => _skyLayer,
  };

  double _pfFor(AnchorLayer a) => switch (a) {
    AnchorLayer.layer1 => _fHills,
    AnchorLayer.layer2 => _fBackHills,
    AnchorLayer.layer3 => _fClouds,
    AnchorLayer.layer4 => _fSky,
  };

  double? _pinchStartZoom;

  @override
  Future<void> onLoad() async {
    try {
      await images.loadAll(
        {
          'backgrounds/scenes/volcano/sky.png',
          'backgrounds/scenes/volcano/clouds.png',
          'backgrounds/scenes/volcano/backhills.png',
          'backgrounds/scenes/volcano/hills.png',
          'backgrounds/scenes/volcano/foreground.png',
          'ui/wood_texture.jpg',
          ...slots.where((s) => s.spritePath != null).map((s) => s.spritePath!),
        }.toList(),
      );
    } catch (e) {
      print('Error loading images: $e');
    }

    final world = World()..priority = 0;
    add(world);

    layersRoot.scale = Vector2.all(sceneScale);
    world.add(layersRoot);

    // Build layers
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
    _targetZoom = 1.0; // default

    // Layout + start
    _layoutLayersForScreen();
    _recomputeMaxCamX(); // initial clamp
    _cameraX = 0;
    _cameraY = 0;

    _addTrophySlots();

    cam.viewfinder.position = Vector2(_screenW / 2, _screenH / 2);
    _applyCamera();
    _updateParallaxLayers();
  }

  @override
  void onScaleStart(ScaleStartInfo info) {
    _pinchStartZoom = cam.viewfinder.zoom;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    // Smooth zoom
    final start = _pinchStartZoom ?? cam.viewfinder.zoom;
    final globalScale = info.scale.global.x;
    _targetZoom = (start * globalScale).clamp(minZoom, maxZoom).toDouble();

    // Horizontal pan (always allowed)
    final dx = info.delta.global.x;
    if (dx != 0) {
      final desiredX =
          _cameraX - (dx / cam.viewfinder.zoom) * scrollSensitivity;
      _cameraX = desiredX.clamp(0.0, _maxCamX);
    }

    // Vertical pan (only when zoomed in)

    if (_targetZoom > minZoom) {
      final dy = info.delta.global.y;
      if (dy != 0) {
        final desiredY =
            _cameraY - (dy * cam.viewfinder.zoom) * scrollSensitivity;
        _cameraY = desiredY.clamp(0.0, _maxCamY);
      }
    }
  }

  @override
  void onScaleEnd(ScaleEndInfo info) {
    _pinchStartZoom = null;
  }

  void _applyCamera() {
    final vwWorld = _screenW / cam.viewfinder.zoom;
    final vhWorld = _screenH / cam.viewfinder.zoom;
    cam.viewfinder.position = Vector2(
      _cameraX + vwWorld / 2,
      _cameraY + vhWorld / 2,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    final z = cam.viewfinder.zoom;
    if ((z - _targetZoom).abs() > 0.0005) {
      final isZoomingOut = _targetZoom < z;
      final ease = isZoomingOut ? 35.0 : zoomEase; // faster when zooming out
      final t = 1 - pow(1 / (1 + ease), dt).toDouble();
      cam.viewfinder.zoom = z + (_targetZoom - z) * t;
      _recomputeMaxCamX();
      _cameraX = _cameraX.clamp(0.0, _maxCamX);
      _cameraY = _cameraY.clamp(0.0, _maxCamY);
    }
    _applyCamera();
    _updateParallaxLayers();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layoutLayersForScreen();
    _recomputeMaxCamX();
    _cameraX = _cameraX.clamp(0.0, _maxCamX);
    _cameraY = _cameraY.clamp(0.0, _maxCamY);
    _applyCamera();
    _updateParallaxLayers();
  }

  void _layoutLayersForScreen() {
    if (_cloudsLayer == null) return;

    final invRootScale = 1.0 / layersRoot.scale.x;
    final Vr = _screenW * invRootScale;
    final Vh = _screenH * invRootScale;
    _Vh = Vh;

    final double worldMaxCamX = max(0.0, worldSize.x - _screenW);

    Vector2 heightFitTile(Sprite s) {
      final imgW = s.image.width.toDouble();
      final imgH = s.image.height.toDouble();
      final scale = Vh / imgH;
      return Vector2(imgW * scale, imgH * scale);
    }

    void buildForTarget(_FiniteLayer? layer) {
      if (layer == null) return;
      final t = heightFitTile(layer.sprite);
      final tileW = t.x * layer.widthMul;
      final requiredW = Vr + layer.parallaxFactor * worldMaxCamX;
      final tiles = max(3, (requiredW / max(1e-6, tileW)).ceil() + 2);
      layer.buildOrUpdate(Vector2(tileW, t.y), tiles);
    }

    buildForTarget(_skyLayer);
    buildForTarget(_cloudsLayer);
    buildForTarget(_backHillsLayer);
    buildForTarget(_hillsLayer);
    buildForTarget(_foregroundLayer);
  }

  void _recomputeMaxCamX() {
    final invRootAndZoom = 1.0 / (layersRoot.scale.x * cam.viewfinder.zoom);
    final Vr = _screenW * invRootAndZoom;
    final Vh = _screenH * invRootAndZoom;

    double layerMaxCamX(_FiniteLayer? layer, double pf) {
      if (layer == null) return double.infinity;
      final totalW = layer.totalWidth;
      final exposed = totalW - Vr;
      if (pf == 0.0) return exposed >= -1e-3 ? double.infinity : 0.0;
      return max(0.0, exposed / pf);
    }

    // Horizontal clamp
    final worldMaxCamX = max(
      0.0,
      worldSize.x - (_screenW / cam.viewfinder.zoom),
    );
    final limits = <double>[
      worldMaxCamX,
      layerMaxCamX(_skyLayer, _fSky),
      layerMaxCamX(_cloudsLayer, _fClouds),
      layerMaxCamX(_backHillsLayer, _fBackHills),
      layerMaxCamX(_hillsLayer, _fHills),
      layerMaxCamX(_foregroundLayer, _fForeground),
    ];
    _maxCamX = limits.reduce(min);

    // Vertical clamp — use actual world height (_Vh) instead of worldSize.y
    final contentHeight =
        _Vh; // Or _Vh if your world height = viewport height at zoom=1
    _maxCamY = max(0.0, contentHeight - Vh);
  }

  void _updateParallaxLayers() {
    final invRootAndZoom = 1.0 / (layersRoot.scale.x * cam.viewfinder.zoom);
    final Vr = _screenW * invRootAndZoom;
    _skyLayer?.updateOffsetClamped(_cameraX, Vr);
    _cloudsLayer?.updateOffsetClamped(_cameraX, Vr);
    _backHillsLayer?.updateOffsetClamped(_cameraX, Vr);
    _hillsLayer?.updateOffsetClamped(_cameraX, Vr);
    _foregroundLayer?.updateOffsetClamped(_cameraX, Vr);
  }

  void _addTrophySlots() {
    for (final slot in slots) {
      final layer = _layerFor(slot.anchor);
      if (layer == null) continue;

      final x = slot.normalizedPos.dx * worldSize.x;
      final y = slot.normalizedPos.dy * _Vh;

      // If explicit frameWidth/Height set, use those; else use default proportional size
      final sizeVec = (slot.frameWidth != null && slot.frameHeight != null)
          ? Vector2(slot.frameWidth!, slot.frameHeight!)
          : Vector2.all(
              (min(_screenW, _screenH) * 0.12).clamp(72.0, 144.0).toDouble(),
            );

      layer.container.add(
        TrophyComponent(
          slot: slot,
          parallaxFactor: _pfFor(slot.anchor),
          position: Vector2(x, y),
          size: sizeVec,
          onTapUnlocked: () => onShowDetails?.call(slot),
          onTapLocked: () => onShowDetails?.call(slot),
        ),
      );
    }
  }
}

// --- Trophy Component (spritesheet lives at spritePath; cols/rows REQUIRED) ---
class TrophyComponent extends PositionComponent
    with TapCallbacks, HasGameRef<VolcanoGame> {
  final TrophySlot slot;
  final VoidCallback onTapUnlocked;
  final VoidCallback onTapLocked;
  final double parallaxFactor;

  TrophyComponent({
    required this.slot,
    required this.onTapUnlocked,
    required this.onTapLocked,
    required this.parallaxFactor,
    required super.position,
    required Vector2 size,
  }) : super(anchor: Anchor.center, priority: 10) {
    this.size = size;
  }

  @override
  Future<void> onLoad() async {
    if (slot.spritePath == null) return;
    final image = gameRef.images.fromCache(slot.spritePath!);

    final cols = slot.sheetColumns ?? 1;
    final rows = slot.sheetRows ?? 1;
    final fw = image.width / cols;
    final fh = image.height / rows;

    // --- Scaling logic ---
    double scaleFactor;
    if (size.x > 0 && size.y > 0) {
      // Use width as reference for scale, so height matches proportionally
      scaleFactor = size.x / fw;
    } else {
      scaleFactor = 1.0; // natural size
    }

    final finalSize = Vector2(fw * scaleFactor, fh * scaleFactor);
    final center = finalSize / 2;

    if (slot.isUnlocked) {
      final data = SpriteAnimationData.sequenced(
        amount: cols * rows,
        amountPerRow: cols,
        textureSize: Vector2(fw, fh),
        stepTime: slot.stepTime ?? 0.12,
        loop: true,
      );

      add(
        SpriteAnimationComponent.fromFrameData(image, data)
          ..anchor = Anchor.center
          ..position = center
          ..size = finalSize
          ..priority = 10,
      );
    } else {
      add(
        SpriteComponent(
          sprite: Sprite(
            image,
            srcPosition: Vector2.zero(),
            srcSize: Vector2(fw, fh),
          ),
          anchor: Anchor.center,
          position: center,
          size: finalSize,
          priority: 10,
        )..paint = (Paint()..color = Colors.white.withOpacity(0.6)),
      );
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

    // Smooth camera nudge toward this slot
    final screenW = gameRef.size.x;
    final slotX = position.x; // local-in-layer X
    final desiredCameraX = (slotX - screenW / 2) / (1 + parallaxFactor);
    final clamped = desiredCameraX.clamp(0.0, gameRef._maxCamX);
    gameRef._cameraX = clamped.toDouble();

    // Center using game update's parallax sync
    gameRef.cam.viewfinder.add(
      MoveEffect.to(
        Vector2(gameRef._cameraX + (gameRef.size.x / 2), gameRef.size.y / 2),
        EffectController(duration: 0.5, curve: Curves.easeOut),
      ),
    );
  }
}

/// Finite (non-wrapping) tiled parallax layer.
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
  double totalWidth = 0.0;

  void buildOrUpdate(Vector2 tileSize, int tilesNeeded) {
    final sameSize = (_tileSize - tileSize).length2 < 1e-6;
    if (sameSize && _tiles.length == tilesNeeded && container.isMounted) {
      return;
    }

    _tileSize = tileSize;

    if (!container.isMounted) {
      parent.add(container);
    }

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

    for (var i = 0; i < _tiles.length; i++) {
      final t = _tiles[i];
      if (!sameSize) t.size = tileSize.clone();
      t.position = Vector2(i * tileSize.x, 0);
    }

    totalWidth = _tiles.isEmpty
        ? 0
        : (_tiles.length - 1) * tileSize.x + tileSize.x;
    container.position = Vector2.zero();
  }

  void updateOffsetClamped(double cameraX, double viewportWidthRootSpace) {
    final raw = -(cameraX * parallaxFactor);
    final minX = -(max(0.0, totalWidth - viewportWidthRootSpace));
    final clamped = raw.clamp(minX, 0.0);
    container.position = Vector2(clamped, 0);
  }
}
