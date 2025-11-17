import 'dart:math';
import 'dart:math' as math;
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/encounters/wild_spawn.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:alchemons/services/encounter_service.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/wilderness/creature_sprite_component.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

//KEEP THIS FOR INFO

// The key was understanding that parallax affects BOTH the layer offset AND the camera movement, so the formula is:
// screen_position = world_position - camera_position × (1 + parallax_factor)
// That's why parallax=1.0 creatures were going off-screen - they were being offset twice as much as expected!

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

  bool showSpawnDebug = true; // toggle at runtime
  final Map<String, RectangleComponent> _spawnDebugBoxes = {};

  final SceneDefinition scene;
  final CameraComponent cam = CameraComponent();

  // Injected at runtime by ScenePage
  EncounterService? encounters;
  void attachEncounters(EncounterService svc) => encounters = svc;

  SpeciesSpriteResolver? speciesSpriteResolver;
  WildVisualResolver? wildVisualResolver;
  void Function(String spawnId, String speciesId, Creature? hydrated)?
  onStartEncounter;

  // Internal state
  bool _initialized = false;
  final Random _rng = Random();

  // --- Shake state ---
  double _shakeTime = 0.0; // time remaining (seconds)
  double _shakeDuration = 0.0; // total duration (seconds)
  double _shakeAmplitude = 0.0; // max pixels of jitter at start
  Vector2 _shakeOffset = Vector2.zero();

  final Map<SceneLayer, _FiniteLayer> _layers = {};
  final PositionComponent layersRoot = PositionComponent()..priority = -200;

  // Spawn-point anchors we position creatures at
  final Map<String, PositionComponent> _spawnPointComps = {};

  final Map<String, WildMonComponent> _wildBySpawnId = {};
  String? _currentEncounterSpawnId; // keep this to track which one is engaged

  // Party creature during encounter
  WildMonComponent? _partyCreature;

  // Camera state (in world coords)
  double _cameraX = 0;
  double _cameraY = 0;
  double _maxCamX = 0;
  double _maxCamY = 0;

  // NEW: Hard limit for camera movement in Exploration Mode (based on worldWidth)
  double get _maxCamXExploration =>
      max(0.0, scene.worldWidth - (size.x / cam.viewfinder.zoom));

  // Smooth interpolation targets
  double _targetCameraX = 0;
  double _targetCameraY = 0;

  // Zoom state
  double _targetZoom = 1.0;
  final double minZoom = 1;
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

  double _zoomToFitBox({required double boxW, required double boxH}) {
    final root = layersRoot.scale.x;
    final zx = size.x / (root * boxW);
    final zy = size.y / (root * boxH);
    return math.min(zx, zy);
  }

  Vector2 _sizeForSpecies(Vector2 baseSize, Creature hydrated) {
    // Example: use your own data/model here instead of hardcoding
    const Map<String, double> speciesScale = {
      'let': 0.7,
      'pip': 0.9,
      'mane': 0.9,
      'horn': 1,
      'wing': 1.1,
      'kin': 1,
    };

    final scale =
        speciesScale.containsKey(hydrated.mutationFamily!.toLowerCase())
        ? speciesScale[hydrated.mutationFamily!.toLowerCase()]!
        : 1.0;
    return baseSize * scale;
  }

  /// Trigger a camera shake that eases out over [duration].
  /// [amplitude] is the pixel jitter at the start of the shake.
  void shake({
    Duration duration = const Duration(milliseconds: 700),
    double amplitude = 10,
  }) {
    _shakeDuration = duration.inMilliseconds / 1000.0;
    _shakeTime = _shakeDuration;
    _shakeAmplitude = amplitude;
  }

  // ------------------------------------------------------------
  // Lifecycle / setup
  // ------------------------------------------------------------

  void debugEncounterFrame(String spawnId) {
    final sp = scene.spawnPoints.firstWhere((s) => s.id == spawnId);
    final anchor = _spawnPointComps[spawnId];

    if (anchor == null) {
      debugPrint('⚠️  No anchor for $spawnId');
      return;
    }

    final baseW = scene.worldWidth.toDouble();
    final bp = sp.getBattlePos();

    // Where the creature actually is (accounting for parallax)
    final actualWild = anchor.position.clone();

    // Where we THINK it is
    final calculatedWild = Vector2(
      sp.normalizedPos.dx * baseW,
      sp.normalizedPos.dy * _Vh,
    );

    final calculatedParty = Vector2(bp.dx * baseW, bp.dy * _Vh);

    debugPrint('\n🐛 ENCOUNTER FRAME DEBUG for $spawnId:');
    debugPrint(
      '├─ Layer: ${sp.anchor} (parallax: ${scene.layers.firstWhere((l) => l.id == sp.anchor).parallaxFactor})',
    );
    debugPrint('├─ World size: ${baseW.toInt()} x ${_Vh.toInt()}');
    debugPrint('├─ Viewport: ${size.x.toInt()} x ${size.y.toInt()}');
    debugPrint('├─ Root scale: ${layersRoot.scale.x}');
    debugPrint('│');
    debugPrint(
      '├─ Wild (calculated): (${calculatedWild.x.toStringAsFixed(1)}, ${calculatedWild.y.toStringAsFixed(1)})',
    );
    debugPrint(
      '├─ Wild (actual pos): (${actualWild.x.toStringAsFixed(1)}, ${actualWild.y.toStringAsFixed(1)})',
    );
    debugPrint(
      '├─ Difference: (${(actualWild.x - calculatedWild.x).toStringAsFixed(1)}, ${(actualWild.y - calculatedWild.y).toStringAsFixed(1)})',
    );
    debugPrint('│');
    debugPrint(
      '├─ Party (calculated): (${calculatedParty.x.toStringAsFixed(1)}, ${calculatedParty.y.toStringAsFixed(1)})',
    );
    debugPrint(
      '└─ Distance: ${(calculatedWild - calculatedParty).length.toStringAsFixed(1)}px\n',
    );
  }

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

    await syncWildFromEncounters();
  }

  // ------------------------------------------------------------
  // Spawns
  // ------------------------------------------------------------

  Future<void> syncWildFromEncounters() async {
    final svc = encounters;
    if (svc == null) return;

    // desired spawns by id
    final desired = <String, WildSpawn>{
      for (final s in svc.spawns) s.spawnPointId: s,
    };

    print(svc.spawns);

    // add/update
    for (final entry in desired.entries) {
      final id = entry.key;
      final s = entry.value;
      if (!_wildBySpawnId.containsKey(id)) {
        await _ensureWildAt(id, s.speciesId, s.rarity);
      }
    }

    // remove stale
    final toRemove = _wildBySpawnId.keys
        .where((id) => !desired.containsKey(id))
        .toList();
    for (final id in toRemove) {
      _wildBySpawnId[id]?.removeFromParent();
      _wildBySpawnId.remove(id);
    }
  }

  Future<void> _ensureWildAt(
    String spawnId,
    String speciesId,
    EncounterRarity rarity,
  ) async {
    final sp = scene.spawnPoints.firstWhere(
      (s) => s.id == spawnId,
      orElse: () => throw 'Unknown spawnId $spawnId',
    );
    final anchor = _spawnPointComps[spawnId];
    if (anchor == null) return;

    Creature? hydrated;
    if (wildVisualResolver != null) {
      hydrated = await wildVisualResolver!(speciesId, rarity);
    }

    // 🔍 base logical size from the spawn point
    final baseSize = sp.size;

    // 🧬 adjust based on species (and optionally hydrated)
    final adjustedSize = _sizeForSpecies(baseSize, hydrated!);

    final comp =
        WildMonComponent(
            hydrated: hydrated,
            speciesId: speciesId,
            rarityLabel: rarity.name,
            desiredSize: adjustedSize, // ⬅️ use adjusted size here
            onTap: () => _handleWildTap(spawnId, speciesId, hydrated),
            resolver: speciesSpriteResolver,
          )
          ..anchor = Anchor.center
          ..position = Vector2.zero();

    anchor.add(comp);
    _wildBySpawnId[spawnId] = comp;
  }

  void clearWildAt(String spawnId) {
    _wildBySpawnId.remove(spawnId)?.removeFromParent();
  }

  void _addSpawnPoints() {
    for (final p in scene.spawnPoints) {
      if (!p.enabled) continue;
      final layer = _layers[p.anchor];
      if (layer == null) continue;

      final baseW = scene.worldWidth.toDouble();
      final baseH = scene.worldHeight.toDouble(); // ✅ Use worldHeight, not _Vh

      final x = p.normalizedPos.dx * baseW;
      final y = p.normalizedPos.dy * baseH;

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

  // ------------------------------------------------------------
  // Encounter mode flow
  // ------------------------------------------------------------

  void _handleWildTap(String spawnId, String speciesId, Creature? hydrated) {
    if (_mode == SceneMode.encounter) return; // already in encounter
    _enterEncounterMode(spawnId);

    // 💡 PASS THE spawnId AS THE FIRST ARGUMENT
    onStartEncounter?.call(spawnId, speciesId, hydrated);
  }

  void _enterEncounterMode(String spawnId) {
    debugEncounterFrame(spawnId);
    _mode = SceneMode.encounter;
    _currentEncounterSpawnId = spawnId;

    final sp = scene.spawnPoints.firstWhere((s) => s.id == spawnId);

    for (final e in _wildBySpawnId.entries) {
      if (e.key != spawnId) e.value.scale = Vector2.zero();
    }

    final wildAnchor = _spawnPointComps[spawnId];
    if (wildAnchor == null) {
      debugPrint('⚠️ No anchor found for $spawnId');
      return;
    }

    final wild = wildAnchor.position.clone();
    final layerDef = scene.layers.firstWhere((l) => l.id == sp.anchor);
    final parallaxFactor = layerDef.parallaxFactor;

    debugPrint(
      '🔍 Creature at world: (${wild.x}, ${wild.y}), parallax: $parallaxFactor',
    );

    const encounterZoom = 1.3; // Gentle zoom
    final root = layersRoot.scale.x;
    final worldHeight = scene.worldHeight.toDouble();

    final halfW = size.x / (2 * encounterZoom * root);
    final halfH = size.y / (2 * encounterZoom * root);

    final maxCamX = math.max(0.0, scene.worldWidth.toDouble() - 2 * halfW);
    final maxCamY = math.max(0.0, worldHeight - 2 * halfH);

    double camX, camY;

    if (parallaxFactor == 1.0) {
      // ✅ For parallax=1.0: screen pos = wild.x - 2*camX
      // Want: wild.x - 2*camX = halfW
      // So: camX = (wild.x - halfW) / 2
      camX = ((wild.x - halfW) / 2.0).clamp(0.0, maxCamX);
      camY = ((wild.y - halfH) / 2.0).clamp(0.0, maxCamY);
    } else if (parallaxFactor == 0.0) {
      // Background doesn't move, creature stays at world position
      camX = (wild.x - halfW).clamp(0.0, maxCamX);
      camY = (wild.y - halfH).clamp(0.0, maxCamY);
    } else {
      // General case: screen pos = wild.x - camX*(1 + parallax)
      // Want: wild.x - camX*(1+parallax) = halfW
      // So: camX = (wild.x - halfW) / (1 + parallax)
      camX = ((wild.x - halfW) / (1.0 + parallaxFactor)).clamp(0.0, maxCamX);
      camY = ((wild.y - halfH) / (1.0 + parallaxFactor)).clamp(0.0, maxCamY);
    }

    _targetZoom = encounterZoom;
    _targetCameraX = camX;
    _targetCameraY = camY;

    debugPrint(
      '🎯 Encounter: wild=(${wild.x.toStringAsFixed(0)}, ${wild.y.toStringAsFixed(0)})',
    );
    debugPrint(
      '📐 Zoom: $encounterZoom, Camera: (${camX.toStringAsFixed(1)}, ${camY.toStringAsFixed(1)})',
    );

    // Debug: calculate actual screen position
    final screenX = wild.x - camX * (1.0 + parallaxFactor);
    final screenY = wild.y - camY * (1.0 + parallaxFactor);
    debugPrint(
      '   Expected screen pos: (${screenX.toStringAsFixed(0)}, ${screenY.toStringAsFixed(0)}) vs center: ($halfW, $halfH)',
    );
  }

  void spawnPartyCreature(Creature creature) {
    if (_currentEncounterSpawnId == null) return;

    final sp = scene.spawnPoints.firstWhere(
      (s) => s.id == _currentEncounterSpawnId!,
    );
    final layer = _layers[sp.anchor];
    if (layer == null) return;

    final baseW = scene.worldWidth.toDouble();
    final battlePos = sp.getBattlePos();
    final x = battlePos.dx * baseW;
    final y = battlePos.dy * _Vh; // ✅ Use _Vh, not worldHeight

    debugPrint('🎮 Spawning party at ($x, $y)');

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
            rarityLabel: '',
            desiredSize: _sizeForSpecies(sp.size, creature),
            onTap: () {},
            resolver: speciesSpriteResolver,
          )
          ..anchor = Anchor.center
          ..position = Vector2.zero();

    anchor.add(_partyCreature!);

    _reframeForBattle(sp, anchor.position);
  }

  void _reframeForBattle(SpawnPoint sp, Vector2 partyPos) {
    final wildAnchor = _spawnPointComps[_currentEncounterSpawnId];
    if (wildAnchor == null) return;

    final wild = wildAnchor.position.clone();
    final party = partyPos;

    // ✅ GET PARALLAX FACTOR (both creatures are on same layer)
    final layerDef = scene.layers.firstWhere((l) => l.id == sp.anchor);
    final parallaxFactor = layerDef.parallaxFactor;

    debugPrint(
      '🔄 Reframing: wild=(${wild.x.toStringAsFixed(0)}, ${wild.y.toStringAsFixed(0)}) '
      'party=(${party.x.toStringAsFixed(0)}, ${party.y.toStringAsFixed(0)}) parallax=$parallaxFactor',
    );

    final half = Vector2(sp.size.x * 0.5, sp.size.y * 0.5);

    final left = math.min(wild.x - half.x, party.x - half.x);
    final right = math.max(wild.x + half.x, party.x + half.x);
    final top = math.min(wild.y - half.y, party.y - half.y);
    final bottom = math.max(wild.y + half.y, party.y + half.y);

    const padX = 1.30;
    const padY = 1.35;
    const topPadding = 1.4;

    double boxW = (right - left) * padX;
    double boxH = (bottom - top) * padY * topPadding;

    final minBoxH = math.max(sp.size.y * 2.8, 220.0);
    final minBoxW = math.max(sp.size.x * 2.8, 300.0);
    boxH = math.max(boxH, minBoxH);
    boxW = math.max(boxW, minBoxW);

    final root = layersRoot.scale.x;
    double desiredZoom = _zoomToFitBox(boxW: boxW, boxH: boxH);

    const encounterMaxZoom = 1.55;
    const minEncounterZoom = 1.15;
    desiredZoom = desiredZoom.clamp(minEncounterZoom, encounterMaxZoom);

    debugPrint(
      '📐 Battle zoom: ${desiredZoom.toStringAsFixed(2)} (box: ${boxW.toStringAsFixed(0)}x${boxH.toStringAsFixed(0)})',
    );

    final halfW = size.x / (2 * desiredZoom * root);
    final halfH = size.y / (2 * desiredZoom * root);

    final focusX = (left + right) * 0.5;
    final focusY = (top + bottom) * 0.5;

    const groundBias = 60.0;
    final focusBiased = Vector2(focusX, focusY + groundBias);

    final maxCamX = math.max(0.0, scene.worldWidth.toDouble() - 2 * halfW);
    final maxCamY = math.max(0.0, _Vh - 2 * halfH);

    // ✅ APPLY PARALLAX-AWARE CAMERA CALCULATION
    // We want the FOCUS POINT to be centered on screen
    // screen_pos = world_pos - camera_pos * (1 + parallax)
    // So: focusBiased - camPos * (1 + parallax) = (halfW, halfH)
    // Therefore: camPos = (focusBiased - (halfW, halfH)) / (1 + parallax)

    double camX, camY;

    if (parallaxFactor == 1.0) {
      // screen pos = world - 2*cam
      // Want: focusBiased - 2*cam = (halfW, halfH)
      camX = ((focusBiased.x - halfW) / 2.0).clamp(0.0, maxCamX);
      camY = ((focusBiased.y - halfH) / 2.0).clamp(0.0, maxCamY);
    } else if (parallaxFactor == 0.0) {
      // Background doesn't move
      camX = (focusBiased.x - halfW).clamp(0.0, maxCamX);
      camY = (focusBiased.y - halfH).clamp(0.0, maxCamY);
    } else {
      // General case
      camX = ((focusBiased.x - halfW) / (1.0 + parallaxFactor)).clamp(
        0.0,
        maxCamX,
      );
      camY = ((focusBiased.y - halfH) / (1.0 + parallaxFactor)).clamp(
        0.0,
        maxCamY,
      );
    }

    _targetZoom = desiredZoom;
    _targetCameraX = camX;
    _targetCameraY = camY;

    debugPrint(
      '📷 Camera target: (${camX.toStringAsFixed(1)}, ${camY.toStringAsFixed(1)}) zoom: $desiredZoom',
    );

    // ✅ DEBUG: Verify both creatures will be on screen
    final wildScreenX = wild.x - camX * (1.0 + parallaxFactor);
    final wildScreenY = wild.y - camY * (1.0 + parallaxFactor);
    final partyScreenX = party.x - camX * (1.0 + parallaxFactor);
    final partyScreenY = party.y - camY * (1.0 + parallaxFactor);

    debugPrint(
      '   Wild screen: (${wildScreenX.toStringAsFixed(0)}, ${wildScreenY.toStringAsFixed(0)})',
    );
    debugPrint(
      '   Party screen: (${partyScreenX.toStringAsFixed(0)}, ${partyScreenY.toStringAsFixed(0)})',
    );
    debugPrint(
      '   Viewport: ${(2 * halfW).toStringAsFixed(0)}x${(2 * halfH).toStringAsFixed(0)}',
    );
  }

  void exitEncounterMode() {
    _mode = SceneMode.exploration;

    // Show all creatures again
    for (final mon in _wildBySpawnId.values) {
      mon.scale = Vector2.all(1.0);
    }

    // Zoom back out to exploration view
    _targetZoom = 1.0;
    _targetCameraX = _cameraX;
    _targetCameraY = 0;

    // Remove party creature
    _partyCreature?.removeFromParent();
    _partyCreature = null;
  }

  // Put this inside SceneGame (or a utils file)
  Offset _partyBattlePosFor(SpawnPoint sp) {
    // Wild's normalized position
    final wx = sp.normalizedPos.dx;
    final wy = sp.normalizedPos.dy;

    // Desired horizontal offset in normalized units
    // (roughly sprite width in world, plus breathing room)
    final spriteNormW = (sp.size.x / scene.worldWidth).clamp(0.08, 0.22);
    final desired = (spriteNormW * 1.25).clamp(0.10, 0.30); // 10–30% of width

    // If wild is on the left, put party to the RIGHT; else to the LEFT.
    double px = wx <= 0.5 ? wx + desired : wx - desired;

    // Keep a minimum separation so they never overlap after clamps
    final minSep = (sp.size.x / scene.worldWidth) * 1.1;
    if ((px - wx).abs() < minSep) {
      px = wx + (wx <= 0.5 ? minSep : -minSep);
    }

    // Stay inside safe normalized bounds
    px = px.clamp(0.06, 0.94);
    final py = wy.clamp(0.06, 0.94);

    return Offset(px, py);
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
        _maxCamXExploration, // <-- Use the strict limit here
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

  // ------------------------------------------------------------
  // Fixed: don't over-clamp TARGETS in encounter mode while tweening
  // ------------------------------------------------------------
  @override
  void update(double dt) {
    super.update(dt);

    // 1) Smoothly tween zoom toward target
    final currentZoom = cam.viewfinder.zoom;
    if ((currentZoom - _targetZoom).abs() > 0.0005) {
      final t = 1 - pow(1 / (1 + zoomEase), dt).toDouble();
      cam.viewfinder.zoom = currentZoom + (_targetZoom - currentZoom) * t;
      _recomputeMaxCamBounds(); // bounds grow as zoom increases
    }

    // 2) Choose horizontal limit depending on mode
    final isEncounter = (_mode == SceneMode.encounter);
    final horizontalLimit = isEncounter ? _maxCamX : _maxCamXExploration;

    // Clamp the ACTUAL camera position to current bounds
    _cameraX = _cameraX.clamp(0.0, horizontalLimit);

    // ✅ Do NOT clamp targets in encounter mode (they were computed at target zoom)
    if (!isEncounter) {
      _targetCameraX = _targetCameraX.clamp(0.0, horizontalLimit);
    }

    // 3) Vertical clamping: only clamp targets in exploration
    if (_mode == SceneMode.exploration) {
      _cameraY = _cameraY.clamp(0.0, _maxCamY);
      _targetCameraY = _targetCameraY.clamp(0.0, _maxCamY);
    } else {
      // Encounter: allow target Y to be outside current bounds; only clamp current pos
      _cameraY = _cameraY.clamp(0.0, _maxCamY);
    }

    // 4) Smoothly tween camera toward targets
    const camSpeed = 5.0;
    if ((_cameraX - _targetCameraX).abs() > 0.5) {
      final t = 1 - pow(1 / (1 + camSpeed), dt).toDouble();
      _cameraX += (_targetCameraX - _cameraX) * t;
    }
    if ((_cameraY - _targetCameraY).abs() > 0.5) {
      final t = 1 - pow(1 / (1 + camSpeed), dt).toDouble();
      _cameraY += (_targetCameraY - _cameraY) * t;
    }

    // 5) Shake + apply
    if (_shakeTime > 0) {
      _shakeTime -= dt;
      final t = (_shakeTime / _shakeDuration).clamp(0.0, 1.0);
      final falloff = 1 - (1 - t) * (1 - t) * (1 - t);
      final jx = (_rng.nextDouble() * 2 - 1) * _shakeAmplitude * falloff;
      final jy =
          (_rng.nextDouble() * 2 - 1) * (_shakeAmplitude * 0.6) * falloff;
      _shakeOffset.setValues(jx, jy);
    } else {
      if (!_shakeOffset.isZero()) _shakeOffset.setValues(0, 0);
    }

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
    // We take whichever is smallest (most restrictive) to avoid showing empty.
    final limits = <double>[];

    for (final ld in scene.layers) {
      final fl = _layers[ld.id];
      if (fl == null) continue;
      limits.add(layerMaxCamX(fl, ld.parallaxFactor));
    }

    _maxCamX = limits.isEmpty ? 0.0 : limits.reduce(min);

    // If all layers returned infinity (e.g., all have pf=0), we have no
    // real limit. In that single case, fall back to scene.worldWidth.
    if (_maxCamX == double.infinity) {
      _maxCamX = max(0.0, scene.worldWidth - (size.x / cam.viewfinder.zoom));
    }

    // Vertical clamp range is based on total scene "visual" height vs viewport height.
    final contentHeight = (_Vh == 0) ? size.y : _Vh;
    _maxCamY = max(0.0, contentHeight - Vh);
  }

  void _applyCamera() {
    // Convert cameraX/Y (top-left) into a viewfinder center
    final inv = 1.0 / (layersRoot.scale.x * cam.viewfinder.zoom);
    final vwWorld = size.x * inv;
    final vhWorld = size.y * inv;

    cam.viewfinder.position =
        Vector2(_cameraX + vwWorld / 2, _cameraY + vhWorld / 2) +
        _shakeOffset; // <-- add the shake here
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

      // ✅ Same coordinate system as above
      final baseW = scene.worldWidth.toDouble();
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
