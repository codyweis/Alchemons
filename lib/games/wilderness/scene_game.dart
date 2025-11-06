import 'dart:math';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/services/encounter_service.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
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

enum SceneMode { exploration, encounter }

class SceneGame extends FlameGame with ScaleDetector {
  SceneGame({required this.scene});

  final SceneDefinition scene;
  final CameraComponent cam = CameraComponent();

  // Injected at runtime by ScenePage
  EncounterService? encounters;
  void attachEncounters(EncounterService svc) => encounters = svc;

  SpeciesSpriteResolver? speciesSpriteResolver;
  WildVisualResolver? wildVisualResolver;
  void Function(EncounterRoll roll)? onEncounter;
  void Function(String speciesId, Creature? hydrated)? onStartEncounter;

  // Internal state
  bool _initialized = false;
  final Random _rng = Random();

  final Map<SceneLayer, _FiniteLayer> _layers = {};
  final PositionComponent layersRoot = PositionComponent()..priority = -200;

  // Spawn-point anchors we position creatures at
  final Map<String, PositionComponent> _spawnPointComps = {};

  // Active wild creature in the overworld
  WildMonComponent? _activeWild;

  // Party creature during encounter
  WildMonComponent? _partyCreature;

  // Which spawn point we're currently engaging with
  String? _currentEncounterSpawnId;

  // Camera state (in world coords)
  double _cameraX = 0;
  double _cameraY = 0;
  double _maxCamX = 0;
  double _maxCamY = 0;

  // Smooth interpolation targets
  double _targetCameraX = 0;
  double _targetCameraY = 0;

  // Zoom state
  double _targetZoom = 1.0;
  final double minZoom = 1.0;
  final double maxZoom = 2.0;
  final double zoomEase = 20.0; // higher = snappier
  double? _pinchStartZoom;

  // Gesture feel
  double scrollSensitivity = 0.3;

  // Viewport height in root space (used for spawnPoint world coords)
  double _Vh = 0;

  // Scene mode
  SceneMode _mode = SceneMode.exploration;
  SceneMode get mode => _mode;

  // ------------------------------------------------------------
  // Lifecycle / setup
  // ------------------------------------------------------------

  @override
  Future<void> onLoad() async {
    // Preload the layer art
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

    // Layout and camera bounds for initial viewport
    _layoutLayersForScreen();
    _recomputeMaxCamBounds();

    _initialized = true;

    // Start at origin
    _cameraX = 0;
    _cameraY = 0;
    _targetCameraX = 0;
    _targetCameraY = 0;

    // Add spawn anchors
    _addSpawnPoints();

    // Center camera initially
    cam.viewfinder.position = Vector2(size.x / 2, size.y / 2);
    _applyCamera();
    _updateParallaxLayers();

    // Spawn a starting wild
    _spawnOneWildInstant();
  }

  // ------------------------------------------------------------
  // Spawns
  // ------------------------------------------------------------

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
        size: Vector2.all(1),
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
            onTap: () => _handleWildTap(sp.id, roll.speciesId, hydrated),
            resolver: speciesSpriteResolver,
          )
          ..anchor = Anchor.center
          ..position = Vector2.zero();

    anchor.add(_activeWild!);
    _currentEncounterSpawnId = sp.id;
  }

  // ------------------------------------------------------------
  // Encounter mode flow
  // ------------------------------------------------------------

  void _handleWildTap(String spawnId, String speciesId, Creature? hydrated) {
    if (_mode == SceneMode.encounter) return; // already in encounter
    _enterEncounterMode(spawnId);
    onStartEncounter?.call(speciesId, hydrated);
  }

  /// Switches to cinematic encounter mode:
  /// - locks gestures
  /// - spawns party creature later
  /// - zooms & pans camera to frame wild + party
  void _enterEncounterMode(String spawnId) {
    _mode = SceneMode.encounter;
    _currentEncounterSpawnId = spawnId;

    final sp = scene.spawnPoints.firstWhere((s) => s.id == spawnId);
    final layer = _layers[sp.anchor];
    if (layer == null) return;

    final baseW = layer.tileWidth > 0 ? layer.tileWidth : scene.worldWidth;

    // World-space positions for wild + party
    final wildX = sp.normalizedPos.dx * baseW;
    final wildY = sp.normalizedPos.dy * _Vh;

    final partyPos = sp.getBattlePos();
    final partyX = partyPos.dx * baseW;
    final partyY = partyPos.dy * _Vh;

    // Midpoint between them (you can bias Y if you want more "ground" in frame)
    final focusX = (wildX + partyX) / 2;
    final focusY = (wildY + partyY) / 2;

    // Desired zoom level for encounter
    const desiredZoom = 1.8;

    // Compute the camera's top-left that would center `focusX/focusY` at that zoom
    final halfW = size.x / (2 * desiredZoom);
    final halfH = size.y / (2 * desiredZoom);

    var camX = focusX - halfW;
    var camY = focusY - halfH;

    // Save current camera/limits so we can restore after sim
    final prevZoom = cam.viewfinder.zoom;
    final prevMaxX = _maxCamX;
    final prevMaxY = _maxCamY;

    // Pretend we're already zoomed in, so bounds match the encounter shot
    cam.viewfinder.zoom = desiredZoom;
    _recomputeMaxCamBounds();

    // --- CLAMPING DECISIONS ---

    // 1. Always clamp X so we never see horizontal gaps.
    camX = camX.clamp(0.0, _maxCamX);

    // 2. Soft-clamp Y so we never show out-of-bounds,
    //    but still allow us to sit lower than "normal exploration".
    //
    //    We can optionally bias a little DOWN (show more ground vs sky)
    //    before clamping. For example +groundBias.
    const groundBias = 80.0; // tweak to taste
    camY += groundBias;

    // Now clamp to the legal vertical scroll range at this zoom.
    camY = camY.clamp(0.0, _maxCamY);

    // --- STORE TARGETS ---

    _targetZoom = desiredZoom;
    _targetCameraX = camX;
    _targetCameraY = camY;

    // Restore previous camera state for real runtime;
    cam.viewfinder.zoom = prevZoom;
    _maxCamX = prevMaxX;
    _maxCamY = prevMaxY;
  }

  /// Call from UI when the player picks a party creature.
  /// Places their creature at the "battle" position and leaves wild where it was.
  void spawnPartyCreature(Creature creature) {
    if (_currentEncounterSpawnId == null) return;

    final sp = scene.spawnPoints.firstWhere(
      (s) => s.id == _currentEncounterSpawnId!,
    );
    final layer = _layers[sp.anchor];
    if (layer == null) return;

    final baseW = layer.tileWidth > 0 ? layer.tileWidth : scene.worldWidth;
    final battlePos = sp.getBattlePos();
    final x = battlePos.dx * baseW;
    final y = battlePos.dy * _Vh;

    final anchor = PositionComponent(
      position: Vector2(x, y),
      size: Vector2.all(1),
      priority: 10,
      anchor: Anchor.center,
    );

    layer.container.add(anchor);

    _partyCreature?.removeFromParent();
    _partyCreature =
        WildMonComponent(
            hydrated: creature,
            speciesId: creature.id,
            rarityLabel: '', // we don't show rarity for party mons
            desiredSize: sp.size,
            onTap:
                () {}, // no-op: can't tap your own mon to start encounter again
            resolver: speciesSpriteResolver,
          )
          ..anchor = Anchor.center
          ..position = Vector2.zero();

    anchor.add(_partyCreature!);
  }

  /// Return to free-roam:
  /// - unlock gestures
  /// - zoom back out
  /// - clear encounter actors
  void exitEncounterMode() {
    _mode = SceneMode.exploration;
    // _currentEncounterSpawnId = null;

    _targetZoom = 1.0;
    _targetCameraX = _cameraX;
    _targetCameraY = 0; // vertical baseline for overworld

    _partyCreature?.removeFromParent();
    _partyCreature = null;
  }

  /// Called by ScenePage when we want to despawn the wild (e.g. after breeding)
  void clearWild() {
    _activeWild?.removeFromParent();
    _activeWild = null;
  }

  // ------------------------------------------------------------
  // Gesture handling
  // ------------------------------------------------------------

  @override
  void onScaleStart(ScaleStartInfo info) {
    // Disable gestures during encounter
    if (_mode == SceneMode.encounter) return;
    _pinchStartZoom = cam.viewfinder.zoom;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    if (_mode == SceneMode.encounter) return;

    // Pinch zoom
    final startZoom = _pinchStartZoom ?? cam.viewfinder.zoom;
    final globalScale = info.scale.global.x;
    _targetZoom = (startZoom * globalScale).clamp(minZoom, maxZoom);

    // Drag / pan
    final zoomFactor = cam.viewfinder.zoom;
    final effectiveScroll = scrollSensitivity * zoomFactor;

    final dx = info.delta.global.x;
    if (dx != 0) {
      _cameraX = (_cameraX - (dx / zoomFactor) * effectiveScroll).clamp(
        0.0,
        _maxCamX,
      );
      _targetCameraX = _cameraX;
    }

    // Only allow vertical pan while zoomed in at all
    if (_targetZoom > minZoom) {
      final dy = info.delta.global.y;
      if (dy != 0) {
        _cameraY = (_cameraY - (dy / zoomFactor) * effectiveScroll).clamp(
          0.0,
          _maxCamY,
        );
        _targetCameraY = _cameraY;
      }
    }
  }

  @override
  void onScaleEnd(ScaleEndInfo info) {
    if (_mode == SceneMode.encounter) return;
    _pinchStartZoom = null;
  }

  // ------------------------------------------------------------
  // Per-frame update
  // ------------------------------------------------------------

  @override
  void update(double dt) {
    super.update(dt);

    // 1. Smoothly tween zoom toward target
    final currentZoom = cam.viewfinder.zoom;
    if ((currentZoom - _targetZoom).abs() > 0.0005) {
      final t = 1 - pow(1 / (1 + zoomEase), dt).toDouble();
      cam.viewfinder.zoom = currentZoom + (_targetZoom - currentZoom) * t;
      _recomputeMaxCamBounds();
    }

    // 2. Horizontal clamping always (prevents gaps at edges)
    _cameraX = _cameraX.clamp(0.0, _maxCamX);
    _targetCameraX = _targetCameraX.clamp(0.0, _maxCamX);

    // 3. Vertical clamping only in exploration mode.
    // In encounter mode we allow "illegal" Y so we can frame both creatures.
    if (_mode == SceneMode.exploration) {
      _cameraY = _cameraY.clamp(0.0, _maxCamY);
      _targetCameraY = _targetCameraY.clamp(0.0, _maxCamY);
    }

    // 4. Smoothly tween camera world coords toward targets
    const camSpeed = 5.0;
    if ((_cameraX - _targetCameraX).abs() > 0.5) {
      final t = 1 - pow(1 / (1 + camSpeed), dt).toDouble();
      _cameraX += (_targetCameraX - _cameraX) * t;
    }
    if ((_cameraY - _targetCameraY).abs() > 0.5) {
      final t = 1 - pow(1 / (1 + camSpeed), dt).toDouble();
      _cameraY += (_targetCameraY - _cameraY) * t;
    }

    // 5. Push transforms to the Flame camera + parallax
    _applyCamera();
    _updateParallaxLayers();
  }

  // ------------------------------------------------------------
  // Resize / relayout
  // ------------------------------------------------------------

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!_initialized) return;

    _layoutLayersForScreen();
    _recomputeMaxCamBounds();

    // Same rules as update(): clamp X, but only clamp Y in exploration.
    _cameraX = _cameraX.clamp(0.0, _maxCamX);
    _targetCameraX = _targetCameraX.clamp(0.0, _maxCamX);

    if (_mode == SceneMode.exploration) {
      _cameraY = _cameraY.clamp(0.0, _maxCamY);
      _targetCameraY = _targetCameraY.clamp(0.0, _maxCamY);
    }

    _applyCamera();
    _updateParallaxLayers();
  }

  // ------------------------------------------------------------
  // Layout, camera math & parallax
  // ------------------------------------------------------------

  void _layoutLayersForScreen() {
    // Convert the current Flame game size into "root space"
    final invRootScale = 1.0 / layersRoot.scale.x;
    final Vr = size.x * invRootScale;
    final Vh = size.y * invRootScale;
    _Vh = Vh;

    final worldMaxCamX = max(0.0, scene.worldWidth - size.x);

    Vector2 heightFitTile(Sprite s) {
      final imgW = s.image.width.toDouble();
      final imgH = s.image.height.toDouble();
      final scale = Vh / imgH;
      return Vector2(imgW * scale, imgH * scale);
    }

    void buildForLayer(_FiniteLayer layer) {
      final t = heightFitTile(layer.sprite);
      final tileW = t.x * layer.widthMul;

      // How wide this layer needs to be so we can't scroll past empty space
      final requiredW = Vr + layer.parallaxFactor * worldMaxCamX;

      // +2 tiles for safety so there aren't seams at edges
      final tiles = max(3, (requiredW / max(1e-6, tileW)).ceil() + 2);
      layer.buildOrUpdate(Vector2(tileW, t.y), tiles);
    }

    for (final l in _layers.values) {
      buildForLayer(l);
    }

    _repositionSpawnPoints();
  }

  void _recomputeMaxCamBounds() {
    // How much world fits on screen at current zoom
    final inv = 1.0 / (layersRoot.scale.x * cam.viewfinder.zoom);
    final Vr = size.x * inv;
    final Vh = size.y * inv;

    double layerMaxCamX(_FiniteLayer layer, double pf) {
      final exposed = layer.totalWidth - Vr;
      if (pf == 0.0) {
        // Background layers with pf=0 should just never create gaps
        return exposed >= -1e-3 ? double.infinity : 0.0;
      }
      return max(0.0, exposed / pf);
    }

    // All the different parallax layers impose their own horizontal limits.
    // We take whichever is smallest to avoid showing empty.
    final limits = <double>[
      max(0.0, scene.worldWidth - (size.x / cam.viewfinder.zoom)),
    ];

    for (final ld in scene.layers) {
      final fl = _layers[ld.id];
      if (fl == null) continue;
      limits.add(layerMaxCamX(fl, ld.parallaxFactor));
    }

    _maxCamX = limits.isEmpty ? 0.0 : limits.reduce(min);

    // Vertical clamp range is based on total scene "visual" height vs viewport height.
    final contentHeight = (_Vh == 0) ? size.y : _Vh;
    _maxCamY = max(0.0, contentHeight - Vh);
  }

  void _applyCamera() {
    // Convert cameraX/Y (top-left in world coords) into a viewfinder center
    final inv = 1.0 / (layersRoot.scale.x * cam.viewfinder.zoom);
    final vwWorld = size.x * inv;
    final vhWorld = size.y * inv;

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
// WildMonComponent: shows a single creature at a spawn point.
// ------------------------------------------------------------
class WildMonComponent extends PositionComponent
    with TapCallbacks, HasGameRef<SceneGame> {
  final String speciesId;
  final String rarityLabel;
  final VoidCallback onTap;
  final Vector2 desiredSize;

  final Creature? hydrated;
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

    if (hydrated?.spriteData != null) {
      final sheet = sheetFromCreature(hydrated!);
      final visuals = visualsFromInstance(hydrated!, null);

      // 🔧 PRELOAD THE IMAGE BEFORE CREATING THE COMPONENT
      final imagePath = sheet.path; // or however you get the path
      try {
        await gameRef.images.load(imagePath);
      } catch (e) {
        debugPrint('Failed to load sprite: $imagePath - $e');
        // Fall through to fallback blob
        _addFallbackBlob();

        _addTapPulse();
        return;
      }

      add(
        CreatureSpriteComponent(
            sheet: sheet,
            visuals: visuals,
            desiredSize: size,
          )
          ..anchor = Anchor.center
          ..position = size / 2,
      );

      _addTapPulse();
      return;
    }

    // 2) Ask external resolver for a sprite
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

    // 3) Fallback debug blob
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

  void _addFallbackBlob() {
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
// Minimal finite parallax layer helper
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

    // grow
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

    // shrink
    while (_tiles.length > tilesNeeded) {
      _tiles.removeLast().removeFromParent();
    }

    // position horizontally in sequence
    for (var i = 0; i < _tiles.length; i++) {
      final t = _tiles[i];
      if (!sameSize) {
        t.size = tileSize.clone();
      }
      t.position = Vector2(i * tileSize.x, 0);
    }

    totalWidth = _tiles.isEmpty
        ? 0
        : (_tiles.length - 1) * tileSize.x + tileSize.x;

    container.position = Vector2.zero();
  }

  void updateOffsetClamped(double cameraX, double viewportWidthRootSpace) {
    // Parallax scroll. clamp so we never expose beyond the last tile.
    final raw = -(cameraX * parallaxFactor);
    final minX = -(max(0.0, totalWidth - viewportWidthRootSpace));
    final clamped = raw.clamp(minX, 0.0);
    container.position = Vector2(clamped, 0);
  }
}
