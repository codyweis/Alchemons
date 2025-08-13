import 'dart:math';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/trophy_slot.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class SceneGame extends FlameGame with ScaleDetector {
  bool _initialized = false;

  void Function(TrophySlot slot)? onShowDetails;
  final SceneDefinition scene;
  final CameraComponent cam = CameraComponent();

  final Map<SceneLayer, _FiniteLayer> _layers = {};
  final PositionComponent layersRoot = PositionComponent()..priority = -200;

  // Camera state
  double _cameraX = 0;
  double _cameraY = 0;
  double _maxCamX = 0;
  double _maxCamY = 0;

  // Zoom state
  double _targetZoom = 1.0;
  final double minZoom = 1.0;
  final double maxZoom = 2.0;
  final double zoomEase = 20.0;
  double? _pinchStartZoom;

  // Scroll feel
  double scrollSensitivity = 0.3;

  // Viewport height in root space
  double _Vh = 0;

  SceneGame({required this.scene});

  @override
  Future<void> onLoad() async {
    print("we here");
    // Load all layer and slot images
    await images.loadAll(
      {
        ...scene.layers.map((l) => l.imagePath),
        ...scene.slots
            .where((s) => s.spritePath != null)
            .map((s) => s.spritePath!),
      }.toList(),
    );

    final world = World()..priority = 0;
    add(world);
    world.add(layersRoot);

    // Build layers
    for (final layerDef in scene.layers) {
      final sprite = Sprite(images.fromCache(layerDef.imagePath));
      final layer = _FiniteLayer(
        layersRoot,
        sprite,
        priority: -100 + layerDef.id.index,
        parallaxFactor: layerDef.parallaxFactor,
        widthMul: layerDef.widthMul,
      );
      _layers[layerDef.id] = layer;
    }

    // Camera setup
    cam
      ..world = world
      ..viewfinder.anchor = Anchor.center
      ..viewfinder.zoom = 1.0
      ..priority = 100;
    add(cam);

    _targetZoom = 1.0;

    _layoutLayersForScreen();
    _recomputeMaxCamBounds();

    _initialized = true;

    _cameraX = 0;
    _cameraY = 0;

    _addTrophySlots();

    cam.viewfinder.position = Vector2(size.x / 2, size.y / 2);
    _applyCamera();
    _updateParallaxLayers();
  }

  // ---------- Gesture Handling ----------
  @override
  void onScaleStart(ScaleStartInfo info) {
    _pinchStartZoom = cam.viewfinder.zoom;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    final start = _pinchStartZoom ?? cam.viewfinder.zoom;
    final globalScale = info.scale.global.x;
    _targetZoom = (start * globalScale).clamp(minZoom, maxZoom);

    // Adjust scroll sensitivity dynamically
    final zoomFactor = cam.viewfinder.zoom;
    final effectiveScroll = scrollSensitivity * zoomFactor;

    // Horizontal pan
    final dx = info.delta.global.x;
    if (dx != 0) {
      _cameraX = (_cameraX - (dx / zoomFactor) * effectiveScroll).clamp(
        0.0,
        _maxCamX,
      );
    }

    // Vertical pan only when zoomed in
    if (_targetZoom > minZoom) {
      final dy = info.delta.global.y;
      if (dy != 0) {
        _cameraY = (_cameraY - (dy / zoomFactor) * effectiveScroll).clamp(
          0.0,
          _maxCamY,
        );
      }
    }
  }

  @override
  void onScaleEnd(ScaleEndInfo info) {
    _pinchStartZoom = null;
  }

  // ---------- Update Loop ----------
  @override
  void update(double dt) {
    super.update(dt);

    // Smooth zoom interpolation
    final z = cam.viewfinder.zoom;
    if ((z - _targetZoom).abs() > 0.0005) {
      final t = 1 - pow(1 / (1 + zoomEase), dt).toDouble();
      cam.viewfinder.zoom = z + (_targetZoom - z) * t;
      _recomputeMaxCamBounds();
      _cameraX = _cameraX.clamp(0.0, _maxCamX);
      _cameraY = _cameraY.clamp(0.0, _maxCamY);
    }
    _applyCamera();
    _updateParallaxLayers();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!_initialized) return;
    _layoutLayersForScreen();
    _recomputeMaxCamBounds();
    _cameraX = _cameraX.clamp(0.0, _maxCamX);
    _cameraY = _cameraY.clamp(0.0, _maxCamY);
    _applyCamera();
    _updateParallaxLayers();
  }

  // ---------- Layout & Camera ----------
  void _layoutLayersForScreen() {
    final invRootScale = 1.0 / layersRoot.scale.x;
    final Vr = size.x * invRootScale;
    final Vh = size.y * invRootScale;
    _Vh = Vh;

    final double worldMaxCamX = max(0.0, scene.worldWidth - size.x);

    Vector2 heightFitTile(Sprite s) {
      final imgW = s.image.width.toDouble();
      final imgH = s.image.height.toDouble();
      final scale = Vh / imgH;
      return Vector2(imgW * scale, imgH * scale);
    }

    void buildForLayer(_FiniteLayer layer) {
      final t = heightFitTile(layer.sprite);
      final tileW = t.x * layer.widthMul;
      final requiredW = Vr + layer.parallaxFactor * worldMaxCamX;
      final tiles = max(3, (requiredW / max(1e-6, tileW)).ceil() + 2);
      layer.buildOrUpdate(Vector2(tileW, t.y), tiles);
    }

    for (final l in _layers.values) {
      buildForLayer(l);
    }
  }

  void _recomputeMaxCamBounds() {
    final inv = 1.0 / (layersRoot.scale.x * cam.viewfinder.zoom);
    final Vr = size.x * inv;
    final Vh = size.y * inv;

    double layerMaxCamX(_FiniteLayer layer, double pf) {
      final exposed = layer.totalWidth - Vr;
      if (pf == 0.0) return exposed >= -1e-3 ? double.infinity : 0.0;
      return max(0.0, exposed / pf);
    }

    final limits = <double>[
      max(0.0, scene.worldWidth - (size.x / cam.viewfinder.zoom)),
    ];

    for (final ld in scene.layers) {
      final fl = _layers[ld.id];
      if (fl == null) continue; // not built yet (first resize before onLoad)
      limits.add(layerMaxCamX(fl, ld.parallaxFactor));
    }

    _maxCamX = limits.isEmpty ? 0.0 : limits.reduce(min);

    final contentHeight = (_Vh == 0) ? size.y : _Vh; // safe default pre-onLoad
    _maxCamY = max(0.0, contentHeight - Vh);
  }

  void _applyCamera() {
    final vwWorld = size.x / cam.viewfinder.zoom;
    final vhWorld = size.y / cam.viewfinder.zoom;
    cam.viewfinder.position = Vector2(
      _cameraX + vwWorld / 2,
      _cameraY + vhWorld / 2,
    );
  }

  void _updateParallaxLayers() {
    final invRootAndZoom = 1.0 / (layersRoot.scale.x * cam.viewfinder.zoom);
    final Vr = size.x * invRootAndZoom;
    for (final l in _layers.values) {
      l.updateOffsetClamped(_cameraX, Vr);
    }
  }

  // ---------- Slots ----------
  void _addTrophySlots() {
    for (final slot in scene.slots) {
      final layer = _layers[slot.anchor];
      if (layer == null) continue;

      final x = slot.normalizedPos.dx * scene.worldWidth;
      final y = slot.normalizedPos.dy * _Vh;

      final sizeVec = (slot.frameWidth != null && slot.frameHeight != null)
          ? Vector2(slot.frameWidth!, slot.frameHeight!)
          : Vector2.all(
              (min(size.x, size.y) * 0.12).clamp(72.0, 144.0).toDouble(),
            );

      layer.container.add(
        TrophyComponent(
          slot: slot,
          parallaxFactor: scene.layers
              .firstWhere((l) => l.id == slot.anchor)
              .parallaxFactor,
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
    with TapCallbacks, HasGameRef<SceneGame> {
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
