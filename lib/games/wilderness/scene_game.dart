import 'dart:math';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/services/encounter_service.dart';
import 'package:alchemons/widgets/wilderness/creature_sprite_component.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// Resolve a Flame SpriteAnimationComponent for a species,
/// sized to `desiredSize`. Return null to fall back to a blob.
typedef SpeciesSpriteResolver =
    Future<SpriteAnimationComponent?> Function(
      String speciesId,
      Vector2 desiredSize,
    );

/// Resolve a fully hydrated Creature (genes/nature/prismatic) for a spawn.
typedef WildVisualResolver =
    Future<Creature?> Function(String speciesId, EncounterRarity rarity);

class SceneGame extends FlameGame with ScaleDetector {
  SceneGame({required this.scene});

  final SceneDefinition scene;
  final CameraComponent cam = CameraComponent();

  // Injected at runtime
  EncounterService? encounters;
  void attachEncounters(EncounterService svc) => encounters = svc;

  SpeciesSpriteResolver? speciesSpriteResolver;
  WildVisualResolver? wildVisualResolver;
  void Function(EncounterRoll roll)? onEncounter;
  void Function(String speciesId, Creature? hydrated)? onStartEncounter;

  // Internal
  bool _initialized = false;
  final Random _rng = Random();

  final Map<SceneLayer, _FiniteLayer> _layers = {};
  final PositionComponent layersRoot = PositionComponent()..priority = -200;

  // Spawn-point anchors (id -> tiny component we can position at)
  final Map<String, PositionComponent> _spawnPointComps = {};

  // Active wild mon (at most one)
  WildMonComponent? _activeWild;

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

  @override
  Future<void> onLoad() async {
    // Load only layer images now (trophies removed)
    await images.loadAll(scene.layers.map((l) => l.imagePath).toList());

    final world = World()..priority = 0;
    add(world);
    world.add(layersRoot);

    // Build parallax layers
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

    _addSpawnPoints();

    cam.viewfinder.position = Vector2(size.x / 2, size.y / 2);
    _applyCamera();
    _updateParallaxLayers();

    _spawnOneWildInstant();
  }

  // -------- Spawns --------
  void _addSpawnPoints() {
    for (final p in scene.spawnPoints) {
      if (!p.enabled) continue;
      final layer = _layers[p.anchor];
      if (layer == null) continue;

      final baseW = layer.tileWidth > 0 ? layer.tileWidth : scene.worldWidth;
      final x = p.normalizedPos.dx * baseW;
      final y = p.normalizedPos.dy * _Vh;

      final anchor = PositionComponent(
        position: Vector2(x, y),
        size: Vector2.all(1), // just a marker
        priority: 10,
        anchor: Anchor.center,
      );

      layer.container.add(anchor);
      _spawnPointComps[p.id] = anchor;
    }
  }

  void _spawnOneWildInstant() async {
    final svc = encounters;
    if (svc == null || scene.spawnPoints.isEmpty) return;

    final sp = scene.spawnPoints[_rng.nextInt(scene.spawnPoints.length)];
    final roll = svc.roll(spawnId: sp.id);
    onEncounter?.call(roll);

    final anchor = _spawnPointComps[sp.id];
    if (anchor == null) return;

    Creature? hydrated;
    if (wildVisualResolver != null) {
      hydrated = await wildVisualResolver!(roll.speciesId, roll.rarity);
    }

    _activeWild?.removeFromParent();
    _activeWild =
        WildMonComponent(
            hydrated: hydrated,
            speciesId: roll.speciesId,
            rarityLabel: roll.rarity.name,
            desiredSize: sp.size,
            onTap: () => onStartEncounter?.call(roll.speciesId, hydrated),
            resolver: speciesSpriteResolver,
          )
          ..anchor = Anchor.center
          ..position = Vector2.zero(); // ⟵ centered on the anchor
    // ⟵ attach to the anchor, not the layer container
    anchor.add(_activeWild!);
  }

  void clearWild() {
    _activeWild?.removeFromParent();
    _activeWild = null;
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

    final zoomFactor = cam.viewfinder.zoom;
    final effectiveScroll = scrollSensitivity * zoomFactor;

    final dx = info.delta.global.x;
    if (dx != 0) {
      _cameraX = (_cameraX - (dx / zoomFactor) * effectiveScroll).clamp(
        0.0,
        _maxCamX,
      );
    }

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
    _repositionSpawnPoints();
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
      if (fl == null) continue;
      limits.add(layerMaxCamX(fl, ld.parallaxFactor));
    }

    _maxCamX = limits.isEmpty ? 0.0 : limits.reduce(min);

    final contentHeight = (_Vh == 0) ? size.y : _Vh;
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

  void _repositionSpawnPoints() {
    for (final p in scene.spawnPoints) {
      final layer = _layers[p.anchor];
      final comp = _spawnPointComps[p.id];
      if (layer == null || comp == null) continue;

      final baseW = layer.tileWidth > 0 ? layer.tileWidth : scene.worldWidth;
      final x = p.normalizedPos.dx * baseW;
      final y = p.normalizedPos.dy * _Vh;
      comp.position.setValues(x, y);
    }
  }
}

// ------------------------------------------------------------
// WildMonComponent: shows a single wild mon at a spawn point.
// If a hydrated Creature is provided, builds animation from it;
// else asks resolver; else draws a blob.
// ------------------------------------------------------------
class WildMonComponent extends PositionComponent
    with TapCallbacks, HasGameRef<SceneGame> {
  final String speciesId;
  final String rarityLabel;
  final VoidCallback onTap;
  final Vector2 desiredSize;

  final Creature? hydrated; // hydrated visual state
  final SpeciesSpriteResolver? resolver;

  WildMonComponent({
    required this.speciesId,
    required this.rarityLabel,
    required this.onTap,
    required this.desiredSize,
    this.hydrated,
    this.resolver,
    Vector2? position,
  }) : super(
         position: position ?? Vector2.zero(),
         anchor: Anchor.center,
         priority: 20,
       );

  @override
  Future<void> onLoad() async {
    size = desiredSize;

    // 1) Hydrated Creature → build from spriteData (scales by size gene)
    if (hydrated?.spriteData != null) {
      final sd = hydrated!.spriteData!;
      final scale = () {
        switch (hydrated!.genetics?.get('size')) {
          case 'tiny':
            return 0.75;
          case 'small':
            return 0.90;
          case 'large':
            return 1.15;
          case 'giant':
            return 1.30;
          default:
            return 1.0;
        }
      }();

      final hue = () {
        switch (hydrated!.genetics?.get('tinting')) {
          case 'warm':
            return 15.0;
          case 'cool':
            return -15.0;
          default:
            return 0.0;
        }
      }();

      final sat = () {
        switch (hydrated!.genetics?.get('tinting')) {
          case 'warm':
          case 'cool':
            return 1.1;
          case 'vibrant':
            return 1.4;
          case 'pale':
            return 0.6;
          default:
            return 1.0;
        }
      }();

      final bri = () {
        switch (hydrated!.genetics?.get('tinting')) {
          case 'warm':
          case 'cool':
            return 1.05;
          case 'vibrant':
            return 1.1;
          case 'pale':
            return 1.2;
          default:
            return 1.0;
        }
      }();

      add(
        CreatureSpriteComponent(
            spritePath: sd.spriteSheetPath,
            totalFrames: sd.totalFrames,
            rows: sd.rows,
            frameSize: Vector2(
              sd.frameWidth.toDouble(),
              sd.frameHeight.toDouble(),
            ),
            stepTime: sd.frameDurationMs / 1000.0,
            scaleFactor: scale,
            saturation: sat,
            brightness: bri,
            baseHueShift: hue,
            isPrismatic: hydrated!.isPrismaticSkin == true,
            desiredSize: size, // keep same bounding box you already picked
          )
          ..anchor = Anchor.center
          ..position = size / 2,
      );
      _addTapPulse();
      return;
    }

    // 2) Try resolver (species → SpriteAnimationComponent)
    if (resolver != null) {
      final comp = await resolver!.call(speciesId, size);
      if (comp != null) {
        comp
          ..anchor = Anchor.center
          ..position = size / 2
          ..priority = 20;
        add(comp);
        _addTapPulse();
        return;
      }
    }

    // 3) Fallback: simple blob + label
    final circle = CircleComponent(
      radius: size.x * 0.4,
      anchor: Anchor.center,
      position: size / 2,
      paint: Paint()..color = Colors.amber.withOpacity(0.9),
      priority: 20,
    );
    add(circle);
    add(
      TextComponent(
        text: speciesId,
        anchor: Anchor.center,
        position: size / 2,
        priority: 21,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    _addTapPulse();
  }

  void _addTapPulse() {
    add(
      ScaleEffect.to(
        Vector2.all(1.05),
        EffectController(
          duration: 0.5,
          reverseDuration: 0.5,
          infinite: true,
          curve: Curves.easeInOut,
          alternate: true,
        ),
      ),
    );
  }

  @override
  void onTapDown(TapDownEvent event) => onTap();
}

// ------------------------------------------------------------
// Minimal finite parallax layer helper (unchanged).
// ------------------------------------------------------------
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
  double get tileWidth => _tileSize.x;
  double get tileHeight => _tileSize.y;
  double totalWidth = 0.0;

  void buildOrUpdate(Vector2 tileSize, int tilesNeeded) {
    final sameSize = (_tileSize - tileSize).length2 < 1e-6;
    if (sameSize && _tiles.length == tilesNeeded && container.isMounted) {
      return;
    }

    _tileSize = tileSize;
    if (!container.isMounted) parent.add(container);

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
