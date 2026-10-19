// lib/screens/home_biome/home_biome_screen.dart
//
// The home biome: the field under the player's home planet, reached by
// descending from the home base. It is one of the five wild realms, drawn
// by that realm's own field, with the player's own Alchemons standing where
// its wild ones would — the Sky building each an isle, the Swamp a bank, the
// Volcano a shelf.
//
// Looking is the default: the field is the player's to pan, pinch and run a
// finger through, and the residents live in it (home_life.dart). ARRANGE
// opens the few things that can change, along the sky where nothing stands:
// which realm, its weather (each realm only its own), the hour, who lives
// here, the realm's own scenery (its trees, isles, banks, stones — moved,
// sized, put away, or more of them) and the player's keepsakes. Arranging,
// anything there can be taken hold of and carried; tapped, it is chosen.

import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/wilderness/field/field_art.dart';
import 'package:alchemons/games/wilderness/field/home_sand_field.dart';
import 'package:alchemons/games/wilderness/keepsake_component.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/cosmetic_wear.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/home_biome.dart';
import 'package:alchemons/models/home_sand.dart';
import 'package:alchemons/models/home_decor.dart';
import 'package:alchemons/models/home_keepsakes.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/providers/audio_provider.dart' show AudioController;
import 'package:alchemons/screens/home_biome/home_sand_tray.dart';
import 'package:alchemons/services/cosmetic_wear_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/all_specimens_page.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/currency_display_widget.dart';
import 'package:alchemons/widgets/fx/keepsake_art.dart';
import 'package:alchemons/widgets/fx/keepsake_view.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/web_ads.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// The field's HUD sits over a sky — always the dark palette.
const _palette = BracketPalette.dark;
const _amber = Color(0xFFE4C16A);

/// An Alchemon as the field draws it: its species with its own genes, and
/// the instance for what only the instance knows (tint, effect).
Creature? hydrateResident(CreatureInstance inst, CreatureCatalog catalog) {
  final base = catalog.getCreatureById(inst.baseId);
  if (base == null || base.spriteData == null) return null;
  return base.copyWith(
    genetics: decodeGenetics(inst.geneticsJson),
    nature: inst.natureId != null
        ? NatureCatalog.byId(inst.natureId!)
        : base.nature,
    nature2: inst.natureId2 != null
        ? NatureCatalog.byId(inst.natureId2!)
        : base.nature2,
    isPrismaticSkin: inst.isPrismaticSkin || base.isPrismaticSkin,
    wildMutation: inst.mutation,
  );
}

/// The home biome as saved, the realms it may be, and each resident's look
/// by instance id. Residents released, sold or fused away since are dropped,
/// and the save trimmed to match.
Future<
  (HomeBiomeLayout, List<HomeRealm>, Map<String, (Creature, CreatureInstance)>)
>
loadHomeBiome(AlchemonsDatabase db, CreatureCatalog catalog) async {
  final realms = await HomeRealm.openNow(db.settingsDao);
  var layout = (await HomeBiomeLayout.load(db.settingsDao)).within(realms);
  final looks = <String, (Creature, CreatureInstance)>{};
  final kept = <HomeResident>[];
  for (final r in layout.residents) {
    final inst = await db.creatureDao.getInstance(r.instanceId);
    final creature = inst == null ? null : hydrateResident(inst, catalog);
    if (inst == null || creature == null) continue;
    looks[r.instanceId] = (creature, inst);
    kept.add(r);
  }
  if (kept.length != layout.residents.length) {
    layout = layout.copyWith(residents: kept);
    unawaited(layout.save(db.settingsDao));
  }
  return (layout, realms, looks);
}

/// Stands every piece of [layout]'s realm in [game]: each keepsake drawn
/// at its point, each piece of scenery (which the field draws) given room
/// to be taken hold of. For anything that shows the home biome — the screen
/// itself, and the home screen's window onto it.
void standHomePieces(
  SceneGame game,
  HomeBiomeLayout layout,
  CreatureCatalog catalog,
) {
  for (final p in layout.placed) {
    standHomePiece(game, layout, p, catalog);
  }
}

/// Stands [p] of [layout] in [game] (see [standHomePieces]).
void standHomePiece(
  SceneGame game,
  HomeBiomeLayout layout,
  HomePiece p,
  CreatureCatalog catalog,
) {
  final sp = layout.pieceSpawnPoint(p);
  if (sp == null) return;
  if (!p.isKeepsake) {
    game.setPieceBox(p.spawnId, homeSceneryBox(sp));
    return;
  }
  final row = layout.realm.row(p.depth);
  final KeepsakeComponent comp;
  if (p.kind.startsWith('effigy:')) {
    final species = catalog.getCreatureById(p.kind.substring(7));
    if (species == null) return;
    comp = EffigyComponent(
      kind: p.kind,
      creature: species,
      rowSize: row.size,
      flip: p.flip,
      onTap: () => game.callResidentTo(p.spawnId),
    );
  } else {
    final art = KeepsakeArt.of(p.kind, copy: keepsakeCopyOf(p), style: p.style);
    if (art == null) return;
    comp = KeepsakeComponent(
      kind: p.kind,
      art: art,
      rowSize: row.size,
      flip: p.flip,
      // Being tried before it is bought: faint, and nobody visits it.
      ghost: p.trial,
      // Tapped, the nearest resident that can reach it comes to it.
      onTap: () => game.callResidentTo(p.spawnId),
    );
  }
  final b = comp.art.box;
  final k = row.size / 100 * KeepsakeComponent.kKeepsakeScale;
  game.showThing(
    p.spawnId,
    comp,
    Rect.fromLTRB(b.left * k, b.top * k, b.right * k, b.bottom * k),
  );
}

/// Which of a keepsake's copies [p] is (the second portal is orange).
int keepsakeCopyOf(HomePiece p) {
  final hash = p.id.lastIndexOf('#');
  return hash < 0 ? 0 : int.tryParse(p.id.substring(hash + 1)) ?? 0;
}

/// Where a piece of scenery at [sp] can be taken hold of, round its point,
/// at the reference height (see [FieldPiece] for what its size means).
Rect homeSceneryBox(SpawnPoint sp) {
  final w = sp.size.x, h = sp.size.y;
  return switch (sp.piece) {
    FieldPiece.tree => Rect.fromLTRB(-1.0 * w, -2.4 * w, 1.1 * w, 10),
    FieldPiece.boulder => Rect.fromLTRB(-w * 0.6, -h - 8, w * 0.7, 14),
    FieldPiece.grove => Rect.fromLTRB(-w, -w * 1.1, w, w),
    FieldPiece.isle || FieldPiece.falls => Rect.fromLTRB(-w, -22, w, w),
    FieldPiece.cypress => Rect.fromLTRB(-0.6 * w, -4.2 * w, 0.6 * w, 20),
    FieldPiece.stone || FieldPiece.peat => Rect.fromLTRB(-w, -16, w, 42),
    FieldPiece.snag => Rect.fromLTRB(-w, -h * 4.75, w, 40),
    FieldPiece.spire => Rect.fromLTRB(-w * 1.3, -h, w * 1.3, 8),
    FieldPiece.monolith => Rect.fromLTRB(-w * 0.7, -h, w * 0.7, 8),
    // The Geode's pool lies on the floor below its point.
    FieldPiece.tarn => Rect.fromLTRB(-w, 12, w, 78),
    _ => Rect.fromLTRB(-w / 2, -h, w / 2, 8),
  };
}

/// The hours the field can be held at, and the phone's own clock.
const _hours = <(String, double?)>[
  ('LIVE', null),
  ('DAWN', 6.3),
  ('DAY', 12.0),
  ('SUNSET', 18.8),
  ('NIGHT', 23.0),
];

class HomeBiomeScreen extends StatefulWidget {
  const HomeBiomeScreen({super.key, this.revealReady});

  /// Flipped once the field is built, for the portal covering this page
  /// (VoidPortal.pushThroughGlyphs).
  final ValueNotifier<bool>? revealReady;

  @override
  State<HomeBiomeScreen> createState() => _HomeBiomeScreenState();
}

/// Which tray is open along the bottom while arranging: Living Sands has
/// two, its colors and its settings.
enum _Tray { none, scenery, keepsakes, decor, sand, sandSettings }

class _HomeBiomeScreenState extends State<HomeBiomeScreen>
    with TickerProviderStateMixin {
  HomeBiomeLayout _layout = const HomeBiomeLayout();

  /// The realms this home can be: the Arcane only once it is unlocked in
  /// the wild.
  List<HomeRealm> _realms = HomeRealm.open(arcane: false);

  /// Each resident's look, by instance id.
  final Map<String, (Creature, CreatureInstance)> _looks = {};

  /// The keepsakes the player has earned.
  KeepsakeLedger _ledger = KeepsakeLedger.empty;

  /// How much of the home decor the player owns.
  DecorLedger _decor = DecorLedger.empty;

  SceneGame? _game;
  int _gameKey = 0;

  /// The first field is built and its residents stand in it.
  bool _ready = false;

  /// Black over the field while a realm is built.
  bool _veiled = true;

  bool _arranging = false;
  _Tray _tray = _Tray.none;

  /// Which of Living Sands' colors the sand tray is picking: one of its
  /// sands, or (at [kSandMaxCount]) the shimmer.
  int _sandSlot = 0;

  /// Living Sands held still, so a finger plays in the sand instead of
  /// panning round it.
  bool _locked = false;

  /// Zoomed out to see the whole field while arranging.
  bool _zoomedOut = false;

  /// What is chosen while arranging, by its point's id: a resident or a
  /// placed piece.
  String? _selected;

  /// The row what is being carried would land on now, lit among the row
  /// chips while it is carried; null when nothing is.
  HomeDepth? _carryingTo;

  /// The tray something chosen was just placed from, closed so it can be
  /// seen where it stands: open again once it is let go (OK, or a tap on
  /// empty ground).
  _Tray? _returnTray;

  /// A line said along the bottom for a moment — why something could not
  /// be done — over whatever is said there otherwise.
  String? _flash;
  Timer? _flashTimer;

  late final RevealWhenReady _reveal;

  /// Sweeps the hour forward to a new one, as the day would.
  late final AnimationController _sweep;
  double _sweepFrom = 0, _sweepBy = 0;
  bool _sweepToLive = false;

  /// Drives the keepsake tray's little living pictures while it is open.
  late final AnimationController _trayClock;

  /// Bumped by every weather change, so a weather waiting for the last one
  /// to clear knows when it has been changed again.
  int _weatherTurn = 0;

  late AlchemonsDatabase _db;
  late CreatureCatalog _catalog;

  @override
  void initState() {
    super.initState();
    _reveal = RevealWhenReady(widget.revealReady, () => mounted && _ready);
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..addListener(_onSweep);
    _trayClock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    );
    _db = context.read<AlchemonsDatabase>();
    _catalog = context.read<CreatureCatalog>();
    unawaited(_load());
  }

  @override
  void dispose() {
    // Browser build only: leaving is a natural pause for an ad.
    WebAds.breakAfter('home_biome');
    _disarm?.cancel();
    _flashTimer?.cancel();
    _reveal.dispose();
    _sweep.dispose();
    _trayClock.dispose();
    super.dispose();
  }

  String _speciesName(String id) => _catalog.getCreatureById(id)?.name ?? id;

  // ── Loading and saving ───────────────────────────────────────────────────

  Future<void> _load() async {
    _realms = await HomeRealm.openNow(_db.settingsDao);
    _ledger = await KeepsakeLedger.load(_db, _speciesName);
    _decor = await DecorLedger.load(_db);
    var layout = await _keepLiving(
      (await HomeBiomeLayout.load(_db.settingsDao)).within(_realms),
    );
    // Keepsakes no longer owned (a save restored from before them) go.
    final owned = _placedOwned(layout);
    if (owned.length != layout.placed.length) layout = layout.withPlaced(owned);
    layout = _settle(layout);
    unawaited(layout.save(_db.settingsDao));
    if (!mounted) return;
    _layout = layout;
    _buildGame();
    unawaited(
      context.read<AudioController?>()?.playWildMusicForScene(
            layout.realm.sceneId,
          ) ??
          Future<void>.value(),
    );
  }

  /// [layout] with its realm's residents given their looks in [_looks], and
  /// without any released, sold or fused away since: they no longer live
  /// there. Each realm keeps its own household, so this is asked of each
  /// realm as it is entered.
  Future<HomeBiomeLayout> _keepLiving(HomeBiomeLayout layout) async {
    final kept = <HomeResident>[];
    for (final r in layout.residents) {
      final inst = await _db.creatureDao.getInstance(r.instanceId);
      final creature = inst == null ? null : hydrateResident(inst, _catalog);
      if (inst == null || creature == null) continue;
      _looks[r.instanceId] = (creature, inst);
      kept.add(r);
    }
    return kept.length == layout.residents.length
        ? layout
        : layout.copyWith(residents: kept);
  }

  /// What stands in [layout]'s realm that the player may have: their own
  /// keepsakes, and the realm's own scenery.
  List<HomePiece> _placedOwned(HomeBiomeLayout layout) {
    final count = <String, int>{};
    final out = <HomePiece>[];
    for (final p in layout.placed) {
      if (p.decor != null) {
        // Decor: as many as are owned, no more, and nothing on trial.
        if (p.trial) continue;
        final n = count[p.kind] = (count[p.kind] ?? 0) + 1;
        if (n <= _decor.allowedOf(p.kind)) out.add(p);
      } else if (!p.isKeepsake || _ledger.owns(p.kind)) {
        out.add(p);
      }
    }
    return out;
  }

  void _commit(HomeBiomeLayout layout) {
    setState(() => _layout = layout);
    unawaited(layout.save(_db.settingsDao));
  }

  bool _floats(String instanceId) =>
      speciesCanFloat(_looks[instanceId]?.$1.id ?? '');

  List<SpawnPoint> get _points => _layout.spawnPoints(_floats);

  /// Keepsakes owned that the player has not been shown yet.
  List<Keepsake> get _unseen => [
    for (final k in _ledger.owned)
      if (!_layout.seen.contains(k.id)) k,
  ];

  // ── The field ────────────────────────────────────────────────────────────

  void _buildGame() {
    final mood = _layout.mood;
    final game = SceneGame(scene: _layout.scene(_floats), showcase: true)
      ..fieldHourOverride = _layout.hour
      ..fieldWeather = mood.weather
      ..fieldAftermath = mood.aftermath
      ..fieldStage = mood.stage
      ..arranging = _arranging
      ..overview = _arranging
      ..viewLocked = _locked
      ..lively = true
      ..ghostTint = _ghostTint(_layout.realm)
      ..canLift = _canLift
      ..onSound = _play
      ..onResidentTap = _onTap
      ..onResidentPicked = _onPicked
      ..onResidentDropped = _onDropped
      ..carryRange = _carryRange
      ..landingOf = _landingOf
      ..onEmptyTap = _onEmptyTap;
    // The Athanor's trails and this realm's ambience, if any are worn.
    final wear = context.read<CosmeticWearService?>();
    if (wear != null) {
      game
        ..trailOf = wear.trailOf
        ..ambience = wear.ambienceIn(_layout.realm.name);
    }
    setState(() {
      _game = game;
      _gameKey++;
    });
    unawaited(_standResidents(game));
  }

  /// The color scenery comes apart into when it is carried: the realm's
  /// own light.
  Color _ghostTint(HomeRealm realm) => switch (realm) {
    HomeRealm.valley => const Color(0xFFD7E8A8),
    HomeRealm.sky => const Color(0xFFE2F0FF),
    HomeRealm.swamp => const Color(0xFFC8D8A0),
    HomeRealm.volcano => const Color(0xFFFFB070),
    HomeRealm.arcane => const Color(0xFFC9B6FF),
    HomeRealm.dunes => const Color(0xFFF0D2A0),
    HomeRealm.geode => const Color(0xFFCDB8FF),
    HomeRealm.tidal => const Color(0xFFA8E4F0),
    HomeRealm.sand => _layout.sandStyle.shimmer,
  };

  bool _canLift(String spawnId) {
    final r = _layout.resident(spawnId);
    if (r != null) return _floats(r.instanceId);
    final p = _layout.piece(spawnId);
    return p != null &&
        (p.hangs || (_layout.realm.sceneryOf(p.kind)?.rises ?? false));
  }

  Future<void> _standResidents(SceneGame game) async {
    await game.loaded;
    if (!mounted || _game != game) return;
    for (final r in _layout.residents) {
      final look = _looks[r.instanceId];
      if (look == null) continue;
      await game.showResident(
        r.spawnId,
        look.$1,
        instance: look.$2,
        flip: r.flip,
      );
    }
    for (final p in _layout.placed) {
      _standPiece(game, p);
    }
    // Revealed with everyone already standing, not popping in.
    await game.residentsLoaded().timeout(
      const Duration(seconds: 3),
      onTimeout: () => const [],
    );
    if (!mounted || _game != game) return;
    setState(() {
      _ready = true;
      _veiled = false;
    });
  }

  /// Stands [p] in [game]: a keepsake drawn, scenery made something to take
  /// hold of (the field draws it).
  void _standPiece(SceneGame game, HomePiece p) =>
      standHomePiece(game, _layout, p, _catalog);

  /// Which of a keepsake's copies [p] is (the second portal is orange).
  int _copyOf(HomePiece p) => keepsakeCopyOf(p);

  /// Counts realm changes, so a slow one does not land after a later one.
  int _realmSwitch = 0;

  Future<void> _setRealm(HomeRealm realm) async {
    if (realm == _layout.realm) return;
    HapticFeedback.selectionClick();
    _select(null);
    _returnTray = null;
    setState(() {
      _veiled = true;
      // Only Living Sands is held still to play in, and has its trays.
      _locked = false;
      if (_tray == _Tray.sand || _tray == _Tray.sandSettings) {
        _tray = _Tray.none;
      }
    });
    // Its own household comes with it, looked up as it is entered.
    final switching = ++_realmSwitch;
    var layout = await _keepLiving(_layout.copyWith(realm: realm));
    if (!mounted || switching != _realmSwitch) return;
    layout = layout.withPlaced(_placedOwned(layout));
    _commit(_settle(layout));
    unawaited(
      context.read<AudioController?>()?.playWildMusicForScene(realm.sceneId) ??
          Future<void>.value(),
    );
    // Under the veil before the old field goes.
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted || _layout.realm != realm) return;
    _buildGame();
  }

  /// [layout] with everything spaced as its realm needs: a realm's rows are
  /// their own lengths, its creatures their own sizes, its isles and banks
  /// where they are. What has no room on its row tries the others; a
  /// keepsake with room on none waits on the shelf.
  HomeBiomeLayout _settle(HomeBiomeLayout layout) {
    // Scenery first, as it stands: the ground the rest is spaced against.
    var out = layout.copyWith(residents: const []).withPlaced([
      for (final p in layout.placed)
        if (!p.isKeepsake) p,
    ]);
    bool beside(String? host) => host != null;
    // What stands on its own ground, then what stands beside it — kept
    // beside it if its host is still there, else spaced on its own.
    for (final pass in const [false, true]) {
      for (final p in layout.placed.where((p) => p.isKeepsake)) {
        if (beside(p.beside) != pass) continue;
        if (pass && out.hostOf(p.spawnId, p.beside, depth: p.depth) != null) {
          out = out.withPlaced([...out.placed, p]);
          continue;
        }
        HomePiece? placed;
        for (final depth in p.depth.byNearness) {
          final q = p.copyWith(depth: depth, beside: () => null);
          final x = out.freeSpotForPiece(q, p.x);
          if (x != null) {
            placed = q.copyWith(x: x);
            break;
          }
        }
        if (placed != null) out = out.withPlaced([...out.placed, placed]);
      }
      for (final r in layout.residents) {
        if (beside(r.beside) != pass) continue;
        if (pass && out.hostOf(r.spawnId, r.beside, depth: r.depth) != null) {
          out = out.copyWith(residents: [...out.residents, r]);
          continue;
        }
        var placed = r.copyWith(beside: () => null);
        for (final depth in r.depth.byNearness) {
          final q = placed.copyWith(depth: depth);
          final x = out.freeSpotNear(q, r.x);
          if (x != null) {
            placed = q.copyWith(x: x);
            break;
          }
        }
        out = out.copyWith(residents: [...out.residents, placed]);
      }
    }
    // Back in the order they were.
    final order = {
      for (final (i, r) in layout.residents.indexed) r.instanceId: i,
    };
    return out.copyWith(
      residents: [...out.residents]
        ..sort((a, b) => order[a.instanceId]!.compareTo(order[b.instanceId]!)),
    );
  }

  /// Living Sands in [style] as the finger moves: the floor dressed again
  /// where it lies, saved only when the finger lifts ([_saveSand]).
  void _previewSand(HomeSandStyle style) {
    setState(() => _layout = _layout.copyWith(sandStyle: style));
    final game = _game;
    if (game == null) return;
    final art = game.fieldArt;
    if (art is HomeSandField) art.style = style;
    game.ghostTint = _ghostTint(_layout.realm);
  }

  void _saveSand() => _commit(_layout);

  /// Living Sands as [style] at once, and saved: a choice made with a tap.
  void _setSand(HomeSandStyle style) {
    HapticFeedback.selectionClick();
    _previewSand(style);
    _saveSand();
  }

  /// Living Sands held still to play in, or let go.
  void _toggleLock() {
    HapticFeedback.selectionClick();
    setState(() => _locked = !_locked);
    _game?.viewLocked = _locked;
  }

  /// Sand that stayed where it was pushed or mixed, all of it back where it
  /// lay.
  void _smoothSand() {
    final art = _game?.fieldArt;
    if (art is! HomeSandField) return;
    HapticFeedback.lightImpact();
    _play(SoundCue.homeSceneryGather);
    art.smooth();
  }

  void _setMood(HomeMood mood) {
    final game = _game;
    final was = _layout.mood;
    if (mood.id == was.id || game == null) return;
    HapticFeedback.selectionClick();
    _commit(_layout.withMood(mood.id));
    game
      ..fieldAftermath = mood.aftermath
      ..fieldStage = mood.stage;
    final turn = ++_weatherTurn;
    if (was.weather != null &&
        mood.weather != null &&
        was.weather != mood.weather &&
        !was.weather!.settled) {
      // One weather clears before the next comes in.
      game.fieldWeather = null;
      Future<void>.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && _game == game && turn == _weatherTurn) {
          game.fieldWeather = mood.weather;
        }
      });
    } else {
      game.fieldWeather = mood.weather;
    }
  }

  /// Lays [ambience] over this realm (the Athanor's), or none.
  void _setAmbience(HomeAmbience? ambience) {
    final wear = context.read<CosmeticWearService?>();
    if (wear == null) return;
    HapticFeedback.selectionClick();
    _game?.ambience = ambience;
    unawaited(
      wear
          .wearAmbience(_layout.realm.name, ambience)
          .then((_) => mounted ? setState(() {}) : null),
    );
  }

  void _setHour(double? hour) {
    final game = _game;
    if (game == null) return;
    if (hour == _layout.hour && !_sweep.isAnimating) return;
    HapticFeedback.selectionClick();
    _commit(_layout.copyWith(hour: () => hour));
    final now = DateTime.now();
    final live = now.hour + now.minute / 60;
    final from = game.fieldHourOverride ?? live;
    final to = hour ?? live;
    // Always forward, as the day goes.
    _sweepFrom = from;
    _sweepBy = (to - from) % 24;
    _sweepToLive = hour == null;
    if (_sweepBy < 0.05) {
      game.fieldHourOverride = hour;
      return;
    }
    _sweep.forward(from: 0);
  }

  void _onSweep() {
    final game = _game;
    if (game == null) return;
    final t = Curves.easeInOutCubic.transform(_sweep.value);
    game.fieldHourOverride = (_sweepFrom + _sweepBy * t) % 24;
    if (_sweep.isCompleted && _sweepToLive) game.fieldHourOverride = null;
  }

  // ── Arranging ────────────────────────────────────────────────────────────

  void _toggleArranging() {
    final on = !_arranging;
    // Previews not bought go when arranging ends: said first, and left only
    // on a second tap.
    if (!on && _armed == 'done') {
      _disarm?.cancel();
      _armed = null;
    } else if (!on && _layout.placed.any((p) => p.trial)) {
      _twice('done', () {});
      _say(
        'Decor you have not bought is removed when you leave. '
        'Tap again to leave.',
      );
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _arranging = on;
      if (!on) {
        _tray = _Tray.none;
        _returnTray = null;
        _zoomedOut = false;
      }
    });
    _game
      ?..arranging = on
      ..overview = on;
    if (!on) {
      _select(null);
      _dropTrials();
    }
    _syncTrayClock();
  }

  /// Whatever was only being tried goes, unbought.
  void _dropTrials() {
    final game = _game;
    final trials = [
      for (final p in _layout.placed)
        if (p.trial) p,
    ];
    if (trials.isEmpty) return;
    var layout = _layout.withPlaced([
      for (final p in _layout.placed)
        if (!p.trial) p,
    ]);
    for (final p in trials) {
      layout = layout.freeBeside(p.spawnId);
    }
    _commit(layout);
    if (game == null) return;
    for (final p in trials) {
      game.removeThing(p.spawnId);
    }
    game.relayout(_points);
  }

  /// Out to see the whole field floating in the dark, or back in.
  void _toggleZoom() {
    final game = _game;
    if (game == null) return;
    HapticFeedback.selectionClick();
    setState(() => _zoomedOut = !_zoomedOut);
    _play(_zoomedOut ? SoundCue.homeOverviewOut : SoundCue.homeOverviewIn);
    game.zoomTo(_zoomedOut ? game.overviewMinZoom : 1);
  }

  void _openTray(_Tray tray) {
    HapticFeedback.selectionClick();
    setState(() => _tray = _tray == tray ? _Tray.none : tray);
    // Opening the keepsakes is being shown them.
    if (_tray == _Tray.keepsakes && _unseen.isNotEmpty) {
      _commit(
        _layout.copyWith(
          seen: {..._layout.seen, for (final k in _ledger.owned) k.id},
        ),
      );
    }
    _syncTrayClock();
  }

  void _syncTrayClock() {
    if (_tray == _Tray.keepsakes) {
      if (!_trayClock.isAnimating) _trayClock.repeat();
    } else {
      _trayClock.stop();
    }
  }

  void _select(String? spawnId) {
    if (_selected == spawnId) return;
    setState(() {
      _selected = spawnId;
      _carryingTo = null;
    });
    _game?.markChosen(spawnId);
  }

  /// Done with what is chosen (OK, or a tap on empty ground): it is let go,
  /// and the tray it was placed from opens again for the next one.
  void _letGo() {
    if (_selected == null) return;
    HapticFeedback.selectionClick();
    _select(null);
    _reopenTray();
  }

  /// The tray what was chosen was placed from, open again.
  void _reopenTray() {
    final back = _returnTray;
    _returnTray = null;
    if (back != null && _tray == _Tray.none) {
      setState(() => _tray = back);
      _syncTrayClock();
    }
  }

  void _onEmptyTap() => _letGo();

  /// Says [text] along the bottom for a few seconds.
  void _say(String text) {
    _flashTimer?.cancel();
    setState(() => _flash = text);
    _flashTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  HomeResident? get _selectedResident =>
      _selected == null ? null : _layout.resident(_selected!);

  HomePiece? get _selectedPiece =>
      _selected == null ? null : _layout.piece(_selected!);

  /// Looking, a tap on a resident plays its essence; arranging, a tap
  /// chooses what it lands on.
  void _onTap(String spawnId) {
    final r = _layout.resident(spawnId);
    if (!_arranging) {
      if (r == null) return;
      HapticFeedback.lightImpact();
      _game?.playEssence(spawnId);
      return;
    }
    if (r == null && _layout.piece(spawnId) == null) return;
    HapticFeedback.selectionClick();
    _select(spawnId);
  }

  /// Plays one of the field's sounds (tool/sounds/home.py).
  void _play(SoundCue cue) {
    if (!mounted) return;
    unawaited(
      context.read<AudioController?>()?.playSound(cue) ?? Future<void>.value(),
    );
  }

  /// Held long enough to be taken hold of: it is chosen, and in the hand.
  void _onPicked(String spawnId) {
    HapticFeedback.mediumImpact();
    _play(SoundCue.homeTake);
    _select(spawnId);
  }

  // ── Clearing ─────────────────────────────────────────────────────────────

  /// Which clearing has been tapped once and waits for a second tap.
  String? _armed;
  Timer? _disarm;

  /// Runs [then] on the second tap of [key] within three seconds.
  void _twice(String key, VoidCallback then) {
    if (_armed == key) {
      _disarm?.cancel();
      setState(() => _armed = null);
      then();
      return;
    }
    HapticFeedback.selectionClick();
    _disarm?.cancel();
    setState(() => _armed = key);
    _disarm = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _armed = null);
    });
  }

  /// Every keepsake in this realm back on the shelf.
  void _putAllAway() {
    final game = _game;
    if (game == null) return;
    HapticFeedback.mediumImpact();
    _play(SoundCue.homeDissolve);
    _select(null);
    final gone = [..._layout.keepsakes];
    _commit(_layout.putKeepsakesAway());
    for (final p in gone) {
      game.removeThing(p.spawnId);
    }
    game.relayout(_points);
  }

  /// This realm's scenery back as the wild has it; keepsakes and residents
  /// stay, spaced again round it.
  Future<void> _resetScenery() async {
    HapticFeedback.mediumImpact();
    _select(null);
    setState(() => _veiled = true);
    _commit(_settle(_layout.resetScenery()));
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    _buildGame();
  }

  /// The chosen decor in its next look.
  void _restyle() {
    final game = _game;
    final p = _selectedPiece;
    final styles = p?.decor?.styles ?? const [];
    if (game == null || p == null || styles.isEmpty) return;
    HapticFeedback.selectionClick();
    _play(SoundCue.homeRestyle);
    final moved = p.copyWith(style: (p.style + 1) % styles.length);
    _commit(_layout.replacePiece(moved));
    _restand(game, moved);
  }

  /// Said on the BUY chip for a moment after a purchase fails.
  String? _buyNote;

  /// Buys the decor [p] being tried, where it stands: it becomes the
  /// player's, in place.
  Future<void> _buy(HomePiece p) async {
    final game = _game;
    final decor = p.decor;
    final shop = context.read<ShopService?>();
    if (game == null || decor == null || shop == null) return;
    final ok = await shop.purchase(decor.offerId);
    if (!mounted) return;
    if (!ok) {
      HapticFeedback.heavyImpact();
      _play(SoundCue.uiDenied);
      setState(
        () =>
            _buyNote = decor.gold > 0 ? 'NOT ENOUGH GOLD' : 'NOT ENOUGH SILVER',
      );
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _buyNote = null);
      });
      return;
    }
    HapticFeedback.mediumImpact();
    _play(SoundCue.purchaseSuccess);
    _decor = await DecorLedger.load(_db);
    if (!mounted) return;
    final used = {
      for (final o in _layout.placed)
        if (o.kind == p.kind && !o.trial) _copyOf(o),
    };
    final copy = [
      for (var i = 0; i < decor.max; i++)
        if (!used.contains(i)) i,
    ].firstOrNull;
    final current = _layout.piece(p.spawnId);
    if (_game != game || current == null || !current.trial || copy == null) {
      setState(() {});
      return;
    }
    final bought = current.copyWith(id: '${p.kind}#$copy');
    final layout = _layout.renamePiece(current, bought.id);
    _select(null);
    _commit(layout);
    game.removeThing(p.spawnId);
    game.relayout(_points);
    _standPiece(game, bought);
    _restandBeside(game, bought.spawnId);
    _select(bought.spawnId);
  }

  /// Which row [spawnId] is on.
  HomeDepth? _depthOf(String spawnId) =>
      _layout.resident(spawnId)?.depth ?? _layout.piece(spawnId)?.depth;

  /// How high [spawnId]'s anchor rests on [depth]'s row, as a share of the
  /// field's height, as near as can be said without the field: a
  /// resident's middle, a keepsake's feet, scenery's own point.
  double _restOn(String spawnId, HomeDepth depth) {
    final row = _layout.realm.row(depth);
    final p = _layout.piece(spawnId);
    if (p == null) return row.height;
    if (p.isKeepsake) {
      return row.height + 0.42 * row.size / (_game?.fieldHeight ?? 475);
    }
    final k = _layout.realm.sceneryOf(p.kind);
    return (depth == HomeDepth.back ? k?.farY : k?.y) ?? row.height;
  }

  /// The rows [spawnId] can be put down on, and how high its anchor would
  /// rest on each — going by [rest], where it really rests on its own.
  List<(HomeDepth, double)> _restsFor(String spawnId, double rest) {
    final own = _depthOf(spawnId);
    if (own == null) return const [];
    // In the air, it rests where it hovers: the rows are where they are.
    final aloft = _layout.resident(spawnId)?.lift != null;
    final off = aloft ? 0.0 : rest - _restOn(spawnId, own);
    return [
      for (final d in _layout.depthsFor(spawnId))
        (d, _restOn(spawnId, d) + off),
    ];
  }

  /// The row whose ground is nearest [height] — its [own] row a little
  /// favoured, so a hand that drifts while carrying something along does
  /// not send it to another.
  HomeDepth _nearestRow(
    List<(HomeDepth, double)> rests,
    double height,
    HomeDepth own,
  ) {
    double off((HomeDepth, double) r) =>
        (height - r.$2).abs() * (r.$1 == own ? 0.6 : 1);
    var best = rests.first;
    for (final r in rests) {
      if (off(r) < off(best)) best = r;
    }
    return best.$1;
  }

  /// How high what is carried may be carried, from the far row's ground to
  /// the near row's: up and down the field it goes from row to row. Null
  /// for what stands on only one row.
  ({double lo, double hi})? _carryRange(String spawnId, double rest) {
    final rests = _restsFor(spawnId, rest);
    if (rests.length < 2) return null;
    final ys = [for (final (_, y) in rests) y];
    final lo = ys.reduce(math.min), hi = ys.reduce(math.max);
    final pad = (hi - lo) * 0.2;
    return (lo: lo - pad, hi: hi + pad);
  }

  /// Where [spawnId] lands if let go [at]: on the row nearest where it is
  /// held, as near where it is held as there is room (see
  /// [HomeBiomeLayout.dropResident]) — and which row it was let go over.
  (HomeDrop, HomeDepth)? _resolveDrop(String spawnId, FieldDrop at) {
    final game = _game;
    final own = _depthOf(spawnId);
    if (game == null || own == null) return null;
    final realm = _layout.realm;
    // Along its own layer, where it was let go on it; along another, under
    // the same spot on the screen.
    double xAt(HomeDepth d) => realm.row(d).layer == realm.row(own).layer
        ? at.share
        : game.shareAtScreen(realm.row(d).layer, at.screenX);
    final rests = _restsFor(spawnId, at.rest);
    final r = _layout.resident(spawnId);
    if (r != null) {
      // Something that can float, let go well above the far row's ground —
      // more than half its own height, so a hand that drifts up a little
      // while carrying it along still sets it down — stays up there, over
      // its own row.
      final far = realm.row(HomeDepth.back);
      final farRest = rests.where((e) => e.$1 == HomeDepth.back).first.$2;
      final aloft =
          _floats(r.instanceId) && at.height < farRest - far.size / 475 * 0.55;
      final depth = aloft ? own : _nearestRow(rests, at.height, own);
      final row = realm.row(own);
      final drop = _layout.dropResident(
        r,
        depth,
        xAt,
        lift: aloft ? at.height.clamp(0.12, row.height - 0.07) : null,
      );
      return drop == null ? null : (drop, depth);
    }
    final p = _layout.piece(spawnId);
    if (p == null) return null;
    // An isle, or what hangs, is set at whatever height it is let go, on
    // its own row.
    final rises = (realm.sceneryOf(p.kind)?.rises ?? false) || p.hangs;
    final depth = rises ? own : _nearestRow(rests, at.height, own);
    final drop = _layout.dropPiece(
      p,
      depth,
      xAt,
      y: rises ? () => at.height.clamp(0.14, p.back ? 0.62 : 0.8) : null,
      stay: rises,
    );
    return drop == null ? null : (drop, depth);
  }

  /// Where what is carried lands if let go [at] now, shown under it on the
  /// ground: nothing for what is held in the air.
  FieldLanding? _landingOf(String spawnId, FieldDrop at) {
    final resolved = _resolveDrop(spawnId, at);
    final own = _depthOf(spawnId);
    if (resolved == null || own == null) return null;
    final (drop, _) = resolved;
    if (_carryingTo != drop.depth && mounted) {
      setState(() => _carryingTo = drop.depth);
    }
    if (drop.layout.resident(spawnId)?.lift != null) return null;
    final p = drop.layout.piece(spawnId);
    final kind = p == null ? null : _layout.realm.sceneryOf(p.kind);
    if (p != null && (p.hangs || (kind?.rises ?? false))) return null;
    final rest = _restsFor(
      spawnId,
      at.rest,
    ).where((e) => e.$1 == drop.depth).firstOrNull?.$2;
    if (rest == null) return null;
    final scale = kind != null
        ? kind.width(back: drop.depth == HomeDepth.back) /
              kind.width(back: own == HomeDepth.back)
        : _layout.realm.row(drop.depth).size / _layout.realm.row(own).size;
    return (
      layer: _layout.realm.row(drop.depth).layer,
      share: drop.x,
      height: rest,
      scale: scale,
    );
  }

  void _onDropped(String spawnId, FieldDrop at) {
    final game = _game;
    if (_carryingTo != null) setState(() => _carryingTo = null);
    if (game == null) return;
    // Taken hold of and let go where it was: it stays.
    final was = _layout.resident(spawnId)?.x ?? _layout.piece(spawnId)?.x;
    if (was == null) return;
    if (((at.share - was + 0.5) % 1.0 - 0.5).abs() < 0.002 &&
        (at.height - at.rest).abs() < 0.015) {
      return;
    }
    final resolved = _resolveDrop(spawnId, at);
    if (resolved == null) {
      HapticFeedback.heavyImpact();
      _say('No room for it anywhere. Move something and try again.');
      return;
    }
    final (drop, asked) = resolved;
    _land(game, drop, asked);
    final scenery = _layout.piece(spawnId)?.isKeepsake == false;
    // Scenery carried in grains sets back into its piece; anything else is
    // set down on its ground.
    _play(scenery ? SoundCue.homeSceneryGather : SoundCue.homeSet);
  }

  /// Puts [drop] in place, and says why when it is not where it was asked
  /// for — on [asked]'s row.
  void _land(SceneGame game, HomeDrop drop, HomeDepth asked) {
    final before = _layout;
    _commit(drop.layout);
    game.relayout(_points);
    _restandMoved(game, before);
    HapticFeedback.lightImpact();
    switch (drop.how) {
      case HomeLanding.otherRow:
        _say(
          'No room there in the ${asked.label.toLowerCase()} row, '
          'so it went to the ${drop.depth.label.toLowerCase()} row.',
        );
      case HomeLanding.along:
        _say('No room there, so it went to the nearest open spot.');
      case HomeLanding.asked || HomeLanding.beside:
        break;
    }
  }

  /// Stands again whatever placed piece moved since [before]: a keepsake
  /// seated on its new ground, scenery made something to take hold of
  /// where it now is.
  void _restandMoved(SceneGame game, HomeBiomeLayout before) {
    for (final p in _layout.placed) {
      final was = before.piece(p.spawnId);
      if (was == null ||
          was.x != p.x ||
          was.depth != p.depth ||
          was.y != p.y ||
          was.scale != p.scale ||
          was.beside != p.beside) {
        _restand(game, p);
      }
    }
  }

  /// Stands again the keepsakes beside [hostId], which went where it went.
  void _restandBeside(SceneGame game, String hostId) {
    for (final p in _layout.placed) {
      if (p.beside == hostId && p.isKeepsake) _restand(game, p);
    }
  }

  /// Stands [p] again after its point changed, seated on its new ground.
  void _restand(SceneGame game, HomePiece p) {
    if (p.isKeepsake) game.removeThing(p.spawnId);
    _standPiece(game, p);
  }

  /// Sends the chosen resident or piece to [depth]'s row, where it stood
  /// on screen.
  void _setDepth(HomeDepth depth) {
    final game = _game;
    final id = _selected;
    if (game == null || id == null || _depthOf(id) == depth) return;
    final screenX = game.screenXOf(id) ?? game.size.x / 2;
    double xAt(HomeDepth d) =>
        game.shareAtScreen(_layout.realm.row(d).layer, screenX);
    final r = _selectedResident;
    final p = _selectedPiece;
    final row = _layout.realm.row(depth);
    final drop = r != null
        ? _layout.dropResident(
            r,
            depth,
            xAt,
            lift: r.lift?.clamp(0.12, row.height - 0.07),
            stay: true,
          )
        : p != null
        // Its height goes back to where its kind sits on that row.
        ? _layout.dropPiece(p, depth, xAt, y: () => null, stay: true)
        : null;
    if (drop == null) {
      HapticFeedback.heavyImpact();
      _say('No room in the ${depth.label.toLowerCase()} row. Move something first.');
      return;
    }
    HapticFeedback.selectionClick();
    _land(game, drop, depth);
    _play(p != null && !p.isKeepsake ? SoundCue.homeSceneryGather : SoundCue.homeSet);
  }

  void _turn() {
    final game = _game;
    if (game == null) return;
    final r = _selectedResident;
    if (r != null) {
      HapticFeedback.selectionClick();
      _commit(_layout.replace(r.copyWith(flip: !r.flip)));
      game.turnResident(r.spawnId);
      return;
    }
    final p = _selectedPiece;
    if (p == null || !p.isKeepsake) return;
    HapticFeedback.selectionClick();
    final moved = p.copyWith(flip: !p.flip);
    _commit(_layout.replacePiece(moved));
    _restand(game, moved);
  }

  /// The chosen piece of scenery the next size up, round to the smallest.
  void _resize() {
    final game = _game;
    final p = _selectedPiece;
    if (game == null || p == null || p.isKeepsake) return;
    const scales = HomeScenery.scales;
    final next = scales.firstWhere(
      (s) => s > p.scale + 0.01,
      orElse: () => scales.first,
    );
    var moved = p.copyWith(scale: next);
    final x = _layout.freeSpotForPiece(moved, p.x);
    if (x == null) {
      // No room to grow here: back to the smallest.
      moved = p.copyWith(scale: scales.first);
    } else {
      moved = moved.copyWith(x: x);
    }
    HapticFeedback.selectionClick();
    _commit(_layout.replacePiece(moved));
    game.relayout(_points);
    _restand(game, moved);
  }

  /// Lifts the chosen resident into the air, or sets it down.
  void _flyOrLand() {
    final game = _game;
    final r = _selectedResident;
    if (game == null || r == null || !_floats(r.instanceId)) return;
    final row = _layout.realm.row(r.depth);
    var moved = r.copyWith(
      lift: () => r.lift == null
          ? (row.height - 0.26).clamp(0.14, row.height - 0.07)
          : null,
    );
    final x = _layout.freeSpotNear(moved, r.x);
    if (x == null) {
      HapticFeedback.heavyImpact();
      return;
    }
    moved = moved.copyWith(x: x, beside: () => null);
    HapticFeedback.selectionClick();
    _commit(_closeUp(_layout.replace(moved).freeBeside(r.spawnId), r.beside));
    game.relayout(_points);
    _restandBeside(game, r.spawnId);
    if (r.beside != null) _restandBeside(game, r.beside!);
  }

  /// [layout] with the group [host] stands at the head of closed up, after
  /// one of its own left it; [layout] as it is for none.
  HomeBiomeLayout _closeUp(HomeBiomeLayout layout, String? host) =>
      host == null ? layout : layout.packBeside(host);

  void _sendAway() {
    final r = _selectedResident;
    if (r != null) {
      HapticFeedback.mediumImpact();
      _select(null);
      _apply(
        _closeUp(
          _layout
              .copyWith(
                residents: [
                  for (final o in _layout.residents)
                    if (o.instanceId != r.instanceId) o,
                ],
              )
              .freeBeside(r.spawnId),
          r.beside,
        ),
        gone: [r],
      );
      final game = _game;
      if (game != null && r.beside != null) _restandBeside(game, r.beside!);
      return;
    }
    final p = _selectedPiece;
    final game = _game;
    if (p == null || game == null) return;
    HapticFeedback.mediumImpact();
    _select(null);
    _commit(
      _closeUp(
        _layout
            .withPlaced([
              for (final o in _layout.placed)
                if (o.id != p.id) o,
            ])
            .freeBeside(p.spawnId),
        p.beside,
      ),
    );
    game
      ..removeThing(p.spawnId)
      ..relayout(_points);
    _restandBeside(game, p.spawnId);
    if (p.beside != null) _restandBeside(game, p.beside!);
    _play(SoundCue.homeDissolve);
    _reopenTray();
  }

  /// Places a new [kind] — a piece of the realm's scenery, or one of the
  /// player's keepsakes — as near the middle of the screen as there is
  /// room, in front, in the middle or at the back.
  void _place(String kind, {required bool keepsake}) {
    final game = _game;
    if (game == null) return;
    String id;
    final decor = HomeDecor.byId(kind);
    if (decor != null) {
      final placedReal = _layout.placed
          .where((p) => p.kind == kind && !p.trial)
          .length;
      final trying = _layout.placed.where((p) => p.kind == kind && p.trial);
      if (placedReal < _decor.allowedOf(kind)) {
        // Owned: a real one, under the next copy number free.
        final used = {
          for (final p in _layout.placed)
            if (p.kind == kind && !p.trial) _copyOf(p),
        };
        final copy = [
          for (var i = 0; i < decor.max; i++)
            if (!used.contains(i)) i,
        ].first;
        id = '$kind#$copy';
      } else if (trying.isNotEmpty) {
        // Already being tried: choose that one, and show it.
        _showChosen(game, trying.first.spawnId);
        return;
      } else if (!decor.athanorOnly && _decor.ownedOf(kind) < decor.max) {
        // Not owned (or not enough): stood in faint, to be tried and
        // bought where it stands. (The Athanor's pieces are never sold, so
        // never tried.)
        id = 'try:$kind#0';
      } else {
        // All of it is out: choose the one there.
        final there = _layout.placed.where((p) => p.kind == kind).firstOrNull;
        if (there != null) _showChosen(game, there.spawnId);
        _say('${decor.name}: every one you own is placed here.');
        return;
      }
    } else if (keepsake) {
      final k = _ledger.byId(kind);
      if (k == null) return;
      final used = {
        for (final p in _layout.placed)
          if (p.kind == kind) _copyOf(p),
      };
      final copy = [
        for (var i = 0; i < k.copies; i++)
          if (!used.contains(i)) i,
      ].firstOrNull;
      if (copy == null) {
        // All of it is out: choose the one there instead.
        final there = _layout.placed.where((p) => p.kind == kind).first;
        _showChosen(game, there.spawnId);
        _say('${k.title} is already placed.');
        return;
      }
      id = '$kind#$copy';
    } else {
      if (_layout.scenery.length >= kHomeBiomeMaxScenery) {
        HapticFeedback.heavyImpact();
        _say(
          'Scenery is full ($kHomeBiomeMaxScenery of '
          '$kHomeBiomeMaxScenery). Put a piece away to add another.',
        );
        return;
      }
      id = '${kind}_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    }
    final mid = game.size.x / 2;
    // As near the middle of the screen as there is room: in front, else in
    // the middle row, else at the back.
    final drop = _layout.dropPiece(
      HomePiece(
        id: id,
        kind: kind,
        // What hangs in the air is put up above the ground.
        y: (decor?.aloft ?? false) ? _layout.realm.near.height - 0.32 : null,
      ),
      HomeDepth.front,
      (d) => game.shareAtScreen(_layout.realm.row(d).layer, mid),
      nest: false,
    );
    final placed = drop?.layout.piece('PIECE_$id');
    if (drop == null || placed == null) {
      HapticFeedback.heavyImpact();
      _say('No free ground for it. Move something and try again.');
      return;
    }
    HapticFeedback.lightImpact();
    _play(SoundCue.homeAppear);
    _commit(drop.layout);
    game.relayout(_points);
    _standPiece(game, placed);
    _showChosen(game, placed.spawnId);
  }

  /// Chooses [spawnId] from a tray and brings it on screen. A tall tray
  /// goes, so it can be seen where it stands — to be moved, or bought —
  /// and comes back once it is let go; the scenery's is one short row and
  /// stays, for the next piece.
  void _showChosen(SceneGame game, String spawnId) {
    if (_tray != _Tray.scenery && _tray != _Tray.none) {
      _returnTray = _tray;
      setState(() => _tray = _Tray.none);
      _syncTrayClock();
    }
    _select(spawnId);
    game.lookAt(spawnId);
  }

  /// Puts [layout] in place: the newcomers in [added] gather out of
  /// grains, those [gone] come apart, and only then does the ground they
  /// stood on go.
  void _apply(
    HomeBiomeLayout layout, {
    List<HomeResident> added = const [],
    List<HomeResident> gone = const [],
  }) {
    final game = _game;
    final before = _layout;
    _commit(layout);
    if (game == null) return;
    game.relayout([
      ...layout.spawnPoints(_floats),
      for (final r in gone)
        before.spawnPointFor(r, floats: _floats(r.instanceId)),
    ]);
    for (final r in gone) {
      game.removeResident(r.spawnId);
    }
    for (final r in added) {
      final look = _looks[r.instanceId];
      if (look == null) continue;
      game.showResident(
        r.spawnId,
        look.$1,
        instance: look.$2,
        flip: r.flip,
        gather: true,
      );
    }
    if (gone.isEmpty) return;
    Future<void>.delayed(const Duration(milliseconds: 850), () {
      if (!mounted || _game != game) return;
      game.relayout(_points);
    });
    for (final r in gone) {
      _looks.remove(r.instanceId);
    }
  }

  Future<void> _chooseResidents() async {
    final game = _game;
    if (game == null) return;
    final theme = context.read<FactionTheme>();
    final picked = await Navigator.of(context).push<List<CreatureInstance>>(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) =>
            AllSpecimensPage(
              theme: theme,
              instancePrefsScopeKey: 'home_biome_residents',
              title: 'WHO LIVES HERE',
              selectionMode: true,
              maxSelections: kHomeBiomeMaxResidents,
              selectedInstanceIds: [
                for (final r in _layout.residents) r.instanceId,
              ],
              onConfirmSelection: (selected) =>
                  Navigator.of(context).pop(selected),
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
    if (picked == null || !mounted || _game != game) return;

    final ids = {for (final i in picked) i.instanceId};
    final gone = [
      for (final r in _layout.residents)
        if (!ids.contains(r.instanceId)) r,
    ];
    var layout = _layout.copyWith(
      residents: [
        for (final r in _layout.residents)
          if (ids.contains(r.instanceId)) r,
      ],
    );
    if (gone.any((r) => r.spawnId == _selected)) _select(null);

    // Newcomers stand as near the middle of the screen as there is room:
    // in front, else in the middle row, else at the back — and only then
    // further along.
    final added = <HomeResident>[];
    final mid = game.size.x / 2;
    for (final inst in picked) {
      if (_looks.containsKey(inst.instanceId) &&
          layout.residents.any((r) => r.instanceId == inst.instanceId)) {
        continue;
      }
      final creature = hydrateResident(inst, _catalog);
      if (creature == null) continue;
      HomeResident? placed;
      for (final within in [layout.gap(HomeDepth.front), 0.5]) {
        for (final depth in HomeDepth.values) {
          final row = layout.realm.row(depth);
          final r = HomeResident(instanceId: inst.instanceId, depth: depth);
          final x = layout.freeSpotNear(
            r,
            game.shareAtScreen(row.layer, mid),
            within: within,
          );
          if (x != null) {
            placed = r.copyWith(x: x);
            break;
          }
        }
        if (placed != null) break;
      }
      if (placed == null) continue;
      _looks[inst.instanceId] = (creature, inst);
      layout = layout.copyWith(residents: [...layout.residents, placed]);
      added.add(placed);
    }
    _apply(layout, added: added, gone: gone);
  }

  // ── The page ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final game = _game;
    final unseen = _unseen;
    if (game != null) {
      // Zoomed out, the field floats in the room the HUD leaves it.
      final pad = MediaQuery.paddingOf(context);
      game
        ..overviewTop =
            pad.top + 8 + 54 + 8 + 32 + (_selected != null ? 40 : 0) + 14
        ..overviewBottom =
            pad.bottom +
            (_tray == _Tray.keepsakes || _tray == _Tray.decor
                ? 168
                : _tray == _Tray.sand
                ? 148
                : _tray == _Tray.sandSettings
                ? 124
                : 56);
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (game != null)
            Positioned.fill(
              child: GameWidget(key: ValueKey(_gameKey), game: game),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _veiled ? 1 : 0,
                duration: Duration(milliseconds: _veiled ? 240 : 520),
                child: const ColoredBox(color: Colors.black),
              ),
            ),
          ),
          if (_arranging)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 170,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xB3000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _topRow(context),
                  if (_arranging) ...[
                    const SizedBox(height: 8),
                    _settingsRow(context),
                    if (_selected != null) ...[
                      const SizedBox(height: 8),
                      _selectionRow(context),
                    ],
                  ],
                  const Spacer(),
                  if (_arranging && _tray != _Tray.none) ...[
                    if (_flash != null) ...[
                      _note(context, _flash!),
                      const SizedBox(height: 6),
                    ],
                    _trayRow(context),
                  ] else if (_flash != null)
                    _note(context, _flash!)
                  else if (_arranging && (_selectedPiece?.trial ?? false))
                    _note(context, 'This is a preview. Buy it to keep it here.')
                  else if (_arranging && _selected != null)
                    _note(
                      context,
                      'Hold it to move it. Up or down changes its row. '
                      'Tap OK when it is in place.',
                    )
                  else if (_arranging)
                    _note(
                      context,
                      'Hold something to move it. Tap to choose it.',
                    )
                  else if (!_arranging && _ready && unseen.isNotEmpty)
                    _note(
                      context,
                      unseen.length == 1
                          ? 'New keepsake: ${unseen.first.title}. '
                                'Arrange, then Keepsakes, to place it.'
                          : '${unseen.length} new keepsakes. '
                                'Arrange, then Keepsakes, to place them.',
                    )
                  else if (!_arranging && _ready && _layout.residents.isEmpty)
                    _note(
                      context,
                      'No Alchemons live here yet. Tap Arrange to bring them home.',
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A line along the bottom, on a slip of the HUD's dark so it reads
  /// over a bright sky.
  Widget _note(BuildContext context, String text) => Center(
    child: CustomPaint(
      foregroundPainter: BracketFramePainter(
        color: _palette.line.withValues(alpha: 0.8),
        bracketSize: 7,
        strokeWidth: 1,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        color: _palette.surfaceFill(),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: bracketText(
            context,
            12,
            _palette.ink.withValues(alpha: 0.9),
            weight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
    ),
  );

  Widget _topRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HudButton(
          label: 'Exit',
          icon: AppIcons.exit_to_app_rounded,
          accent: const Color(0xFFC0392B),
          // Back up through the window it came down, as sand.
          onTap: () => VoidPortal.leaveThroughSand<void>(context),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _arranging ? _realmRow(context) : const SizedBox.shrink(),
        ),
        const SizedBox(width: 10),
        // Living Sands, looked at: held still to play in, and smoothed.
        if (!_arranging && _ready && _layout.realm == HomeRealm.sand) ...[
          if (_layout.sandStyle.stays) ...[
            _HudButton(
              label: 'Smooth',
              icon: AppIcons.waves_rounded,
              accent: _amber,
              onTap: _smoothSand,
            ),
            const SizedBox(width: 10),
          ],
          _HudButton(
            label: _locked ? 'Locked' : 'Lock',
            icon: _locked ? AppIcons.lock_rounded : AppIcons.lock_open_rounded,
            accent: _amber,
            active: _locked,
            onTap: _toggleLock,
          ),
          const SizedBox(width: 10),
        ],
        _HudButton(
          label: _arranging
              ? (_armed == 'done' ? 'Leave?' : 'Done')
              : 'Arrange',
          icon: _arranging ? AppIcons.check_rounded : AppIcons.tune_rounded,
          accent: _amber,
          active: _arranging,
          onTap: _ready ? _toggleArranging : null,
        ),
      ],
    );
  }

  Widget _realmRow(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final realm in _realms) ...[
            if (realm != _realms.first) const SizedBox(width: 6),
            _Chip(
              label: realm.name.toUpperCase(),
              selected: realm == _layout.realm,
              onTap: () => _setRealm(realm),
              height: 54,
            ),
          ],
        ],
      ),
    );
  }

  Widget _settingsRow(BuildContext context) {
    final mood = _layout.mood;
    final hour = _layout.hour;
    final wear = context.watch<CosmeticWearService?>();
    final owned = wear?.ownedAmbiences ?? const <HomeAmbience>[];
    final worn = wear?.ambienceIn(_layout.realm.name);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(
            label:
                'ALCHEMONS ${_layout.residents.length}/$kHomeBiomeMaxResidents',
            icon: AppIcons.add_rounded,
            selected: false,
            accent: _amber,
            onTap: _chooseResidents,
          ),
          const SizedBox(width: 6),
          _Chip(
            label: 'OVERVIEW',
            icon: _zoomedOut
                ? AppIcons.zoom_in_map_rounded
                : AppIcons.zoom_out_map_rounded,
            selected: _zoomedOut,
            accent: _amber,
            onTap: _toggleZoom,
          ),
          const SizedBox(width: 6),
          _Chip(
            label: 'SCENERY',
            icon: AppIcons.layers_rounded,
            selected: _tray == _Tray.scenery,
            accent: _amber,
            onTap: () => _openTray(_Tray.scenery),
          ),
          const SizedBox(width: 6),
          _Chip(
            label: 'KEEPSAKES',
            icon: AppIcons.add_rounded,
            selected: _tray == _Tray.keepsakes,
            accent: _amber,
            dot: _unseen.isNotEmpty,
            onTap: () => _openTray(_Tray.keepsakes),
          ),
          const SizedBox(width: 6),
          _Chip(
            label: 'DECOR',
            icon: AppIcons.home_rounded,
            selected: _tray == _Tray.decor,
            accent: _amber,
            onTap: () => _openTray(_Tray.decor),
          ),
          const SizedBox(width: 16),
          // Living Sands has no weather and no hour: only its colors and
          // how it lies.
          if (_layout.realm == HomeRealm.sand) ...[
            _Chip(
              label: 'COLORS',
              selected: _tray == _Tray.sand,
              accent: _amber,
              onTap: () => _openTray(_Tray.sand),
            ),
            const SizedBox(width: 6),
            _Chip(
              label: 'SETTINGS',
              selected: _tray == _Tray.sandSettings,
              accent: _amber,
              onTap: () => _openTray(_Tray.sandSettings),
            ),
          ] else ...[
            for (final m in _layout.realm.moods) ...[
              _Chip(
                label: m.label,
                selected: m.id == mood.id,
                onTap: () => _setMood(m),
              ),
              const SizedBox(width: 6),
            ],
            const SizedBox(width: 10),
            for (final (label, h) in _hours) ...[
              _Chip(
                label: label,
                selected: h == hour,
                onTap: () => _setHour(h),
              ),
              const SizedBox(width: 6),
            ],
          ],
          // The ambiences owned (the Athanor's), and none.
          if (owned.isNotEmpty) ...[
            const SizedBox(width: 10),
            _Chip(
              label: 'NO AMBIENCE',
              selected: worn == null,
              onTap: () => _setAmbience(null),
            ),
            for (final a in owned) ...[
              const SizedBox(width: 6),
              _Chip(
                label: a.title.toUpperCase(),
                selected: a == worn,
                onTap: () => _setAmbience(a),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// What can be done to the chosen resident or piece.
  Widget _selectionRow(BuildContext context) {
    final r = _selectedResident;
    final p = _selectedPiece;
    String name;
    final chips = <Widget>[];
    void chip(
      String label,
      IconData icon,
      VoidCallback onTap, {
      Color? accent,
    }) {
      chips
        ..add(const SizedBox(width: 6))
        ..add(
          _Chip(
            label: label,
            icon: icon,
            selected: false,
            accent: accent ?? _amber,
            onTap: onTap,
          ),
        );
    }

    // Which row it stands on, the one it is on lit: tapped, it goes to
    // another where it stands on screen.
    void depths(List<HomeDepth> rows, HomeDepth now) {
      if (rows.length < 2) return;
      chips.add(const SizedBox(width: 6));
      for (final d in rows) {
        if (d != rows.first) chips.add(const SizedBox(width: 2));
        chips.add(
          _Chip(
            label: d.label,
            icon: d == rows.first ? AppIcons.layers_rounded : null,
            selected: d == now,
            accent: _amber,
            onTap: () => _setDepth(d),
          ),
        );
      }
    }

    if (r != null) {
      final look = _looks[r.instanceId];
      name = look?.$2.nickname?.isNotEmpty == true
          ? look!.$2.nickname!
          : (look?.$1.name ?? '');
      depths(HomeDepth.values, _carryingTo ?? r.depth);
      chip('TURN', AppIcons.swap_horiz_rounded, _turn);
      if (_floats(r.instanceId)) {
        chip(
          r.lift == null ? 'FLY' : 'LAND',
          AppIcons.flight_takeoff_rounded,
          _flyOrLand,
        );
      }
      chip(
        'SEND AWAY',
        AppIcons.close_rounded,
        _sendAway,
        accent: const Color(0xFFC0392B),
      );
    } else if (p != null) {
      final scenery = _layout.realm.sceneryOf(p.kind);
      name = p.decor != null
          ? '${p.decor!.name}${p.trial ? ' · PREVIEW' : ''}'
          : p.isKeepsake
          ? (_ledger.byId(p.kind)?.title ?? '')
          : (scenery?.label ?? '');
      depths(_layout.depthsFor(p.spawnId), _carryingTo ?? p.depth);
      if (p.isKeepsake) {
        chip('TURN', AppIcons.swap_horiz_rounded, _turn);
      } else {
        chip('SIZE', AppIcons.tune_rounded, _resize);
      }
      final decor = p.decor;
      if (decor != null && decor.styles.isNotEmpty) {
        chip(
          decor.styles[p.style.clamp(0, decor.styles.length - 1)],
          AppIcons.auto_awesome_rounded,
          _restyle,
        );
      }
      if (decor != null && p.trial) {
        final price = decor.gold > 0
            ? '${decor.gold} GOLD'
            : '${decor.silver} SILVER';
        chips
          ..add(const SizedBox(width: 6))
          ..add(
            _Chip(
              label: _armed == 'buy'
                  ? 'TAP AGAIN TO BUY · $price'
                  : (_buyNote ?? 'BUY · $price'),
              icon: AppIcons.add_rounded,
              selected: _armed == 'buy',
              accent: _amber,
              onTap: () => _twice('buy', () => _buy(p)),
            ),
          )
          // What the player holds of the coin it costs, beside the price:
          // the tray's purse is put away while a piece is being tried.
          ..add(const SizedBox(width: 6))
          ..add(
            _HeldCoins(kind: decor.gold > 0 ? CoinKind.gold : CoinKind.silver),
          );
      }
      chip(
        'PUT AWAY',
        AppIcons.close_rounded,
        _sendAway,
        accent: const Color(0xFFC0392B),
      );
    } else {
      return const SizedBox.shrink();
    }
    // Let go of it, for the next thing. A preview is kept only by buying
    // it, so it has no OK.
    if (p == null || !p.trial) {
      chips.insertAll(0, [
        const SizedBox(width: 6),
        _Chip(
          label: 'OK',
          icon: AppIcons.check_rounded,
          selected: true,
          accent: _amber,
          onTap: _letGo,
        ),
      ]);
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Container(
              height: 32,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              color: _palette.chromeFill(),
              child: Text(
                name.toUpperCase(),
                style: bracketText(
                  context,
                  11,
                  _amber,
                  weight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 2),
            ...chips,
          ],
        ),
      ),
    );
  }

  /// The decor tray: every piece by tier — how many of it stand here of
  /// how many owned, or its price to try and buy.
  Widget _decorTray(BuildContext context) {
    final placedDecor = _layout.decor.where((p) => !p.trial).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (placedDecor.isNotEmpty) ...[
          _Chip(
            label: _armed == 'decor'
                ? 'TAP AGAIN TO PUT ALL AWAY'
                : 'PUT ALL DECOR AWAY',
            icon: AppIcons.close_rounded,
            selected: _armed == 'decor',
            accent: const Color(0xFFC0392B),
            onTap: () => _twice('decor', _putAllDecorAway),
          ),
          const SizedBox(height: 6),
        ],
        SizedBox(
          height: 112,
          child: Row(
            children: [
              // What the player holds, beside what is for sale: the decor
              // is bought here, and the purse was nowhere on screen.
              CurrencyDisplayWidget(
                palette: _palette,
                fill: Color.alphaBlend(
                  _palette.surfaceFill(),
                  const Color(0xFF05060B),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _decorShelf()),
            ],
          ),
        ),
      ],
    );
  }

  /// Every piece of decor by tier, scrolling along the tray.
  Widget _decorShelf() {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (final tier in DecorTier.values) ...[
          _TrayLabel(tier.label),
          const SizedBox(width: 6),
          // The Athanor's pieces only once one is drawn: they are never
          // for sale here.
          for (final d in HomeDecor.ofTier(tier))
            if (!d.athanorOnly || _decor.ownedOf(d.id) > 0) ...[
              _DecorTile(
                decor: d,
                owned: _decor.allowedOf(d.id),
                placed: _layout.placed
                    .where((p) => p.kind == d.id && !p.trial)
                    .length,
                canBuy: !d.athanorOnly && _decor.ownedOf(d.id) < d.max,
                onTap: () => _place(d.id, keepsake: true),
              ),
              const SizedBox(width: 6),
            ],
          const SizedBox(width: 10),
        ],
      ],
    );
  }

  /// The solid ground of Living Sands' trays: the field must not show
  /// through.
  Widget _sandPanel({required List<Widget> children}) => Container(
    color: Color.alphaBlend(_palette.surfaceFill(), const Color(0xFF05060B)),
    padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  TextStyle _stripLabel(BuildContext context) => bracketText(
    context,
    9.5,
    _palette.muted,
    weight: FontWeight.w800,
    letterSpacing: 1.2,
  );

  /// Living Sands' colors: how many sands, each one's color and the
  /// shimmer's, and strips to pick the chosen one's.
  Widget _sandTray(BuildContext context) {
    final style = _layout.sandStyle;
    final count = style.count;
    // Fewer sands than the one being picked: the last that is left.
    final slot = _sandSlot == kSandMaxCount
        ? _sandSlot
        : math.min(_sandSlot, count - 1);
    final picked = slot == kSandMaxCount ? style.shimmer : style.colors[slot];
    return _sandPanel(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _Chip(
                label: '−',
                selected: false,
                onTap: count > 1
                    ? () => _setSand(style.copyWith(count: count - 1))
                    : () {},
              ),
              _TrayLabel(count == 1 ? '1 SAND' : '$count SANDS'),
              _Chip(
                label: '+',
                selected: false,
                onTap: count < kSandMaxCount
                    ? () => _setSand(style.copyWith(count: count + 1))
                    : () {},
              ),
              const SizedBox(width: 14),
              for (var i = 0; i < count; i++) ...[
                _Chip(
                  label: 'SAND ${i + 1}',
                  selected: i == slot,
                  accent: style.colors[i],
                  dot: true,
                  onTap: () => setState(() => _sandSlot = i),
                ),
                const SizedBox(width: 6),
              ],
              _Chip(
                label: 'SHIMMER',
                selected: slot == kSandMaxCount,
                accent: style.shimmer,
                dot: true,
                onTap: () => setState(() => _sandSlot = kSandMaxCount),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SandColorStrips(
          color: picked,
          labelStyle: _stripLabel(context),
          onChanged: (c) => _previewSand(
            slot == kSandMaxCount
                ? style.copyWith(shimmer: c)
                : style.withColor(slot, c),
          ),
          onDone: _saveSand,
        ),
      ],
    );
  }

  /// How Living Sands lies and moves: its pattern, whether pushed sand
  /// springs back, stays or mixes, and its amounts.
  Widget _sandSettingsTray(BuildContext context) {
    final style = _layout.sandStyle;
    Widget amount(
      String label,
      SandAmount kind,
      double value,
      HomeSandStyle Function(double v) set,
    ) => Expanded(
      child: SandAmountStrip(
        label: label,
        kind: kind,
        value: value,
        sand: style.colors.first,
        shimmer: style.shimmer,
        labelStyle: _stripLabel(context),
        onChanged: (v) => _previewSand(set(v)),
        onDone: _saveSand,
      ),
    );
    return _sandPanel(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final p in SandPattern.values) ...[
                _Chip(
                  label: p.label,
                  selected: p == style.pattern,
                  onTap: () => _setSand(style.copyWith(pattern: p)),
                ),
                const SizedBox(width: 6),
              ],
              const SizedBox(width: 14),
              for (final m in SandMotion.values) ...[
                if (m != SandMotion.values.first) const SizedBox(width: 6),
                _Chip(
                  label: m.label,
                  selected: m == style.motion,
                  onTap: () => _setSand(style.copyWith(motion: m)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            amount(
              'DENSITY',
              SandAmount.density,
              style.density,
              (v) => style.copyWith(density: v),
            ),
            const SizedBox(width: 18),
            amount(
              'GRAIN',
              SandAmount.grain,
              style.grain,
              (v) => style.copyWith(grain: v),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            amount(
              'SHIMMER',
              SandAmount.sparkle,
              style.sparkle,
              (v) => style.copyWith(sparkle: v),
            ),
            const SizedBox(width: 18),
            const Spacer(),
          ],
        ),
      ],
    );
  }

  /// Every piece of decor in this realm back on the shelf.
  void _putAllDecorAway() {
    final game = _game;
    if (game == null) return;
    HapticFeedback.mediumImpact();
    _play(SoundCue.homeDissolve);
    _select(null);
    final gone = [..._layout.decor];
    var layout = _layout.withPlaced([
      for (final p in _layout.placed)
        if (p.decor == null) p,
    ]);
    for (final p in gone) {
      layout = layout.freeBeside(p.spawnId);
    }
    _commit(layout);
    for (final p in gone) {
      game.removeThing(p.spawnId);
    }
    game.relayout(_points);
  }

  /// The tray along the bottom: the realm's own scenery, or the player's
  /// keepsakes, to place.
  Widget _trayRow(BuildContext context) {
    if (_tray == _Tray.decor) return _decorTray(context);
    if (_tray == _Tray.sand) return _sandTray(context);
    if (_tray == _Tray.sandSettings) return _sandSettingsTray(context);
    if (_tray == _Tray.scenery) {
      final count = _layout.scenery.length;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _TrayLabel(
              '${_layout.realm.title.toUpperCase()}  $count/$kHomeBiomeMaxScenery',
            ),
            const SizedBox(width: 6),
            _Chip(
              label: _armed == 'scenery'
                  ? 'TAP AGAIN TO RESET'
                  : 'RESET SCENERY',
              icon: AppIcons.close_rounded,
              selected: _armed == 'scenery',
              accent: const Color(0xFFC0392B),
              onTap: () => _twice('scenery', _resetScenery),
            ),
            for (final s in _layout.realm.scenery) ...[
              const SizedBox(width: 6),
              _Chip(
                label: s.label,
                icon: AppIcons.add_rounded,
                selected: false,
                onTap: () => _place(s.piece, keepsake: false),
              ),
            ],
          ],
        ),
      );
    }
    final owned = _ledger.owned;
    if (owned.isEmpty) {
      return _note(
        context,
        'No keepsakes yet. Lost maxims, cups won in the Trials and a hundred '
        'of a species bred each earn one.',
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_layout.keepsakes.isNotEmpty) ...[
          _Chip(
            label: _armed == 'keepsakes'
                ? 'TAP AGAIN TO PUT ALL AWAY'
                : 'PUT ALL AWAY',
            icon: AppIcons.close_rounded,
            selected: _armed == 'keepsakes',
            accent: const Color(0xFFC0392B),
            onTap: () => _twice('keepsakes', _putAllAway),
          ),
          const SizedBox(height: 6),
        ],
        _keepsakeList(owned),
      ],
    );
  }

  Widget _keepsakeList(List<Keepsake> owned) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: owned.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final k = owned[i];
          final out = _layout.placed.where((p) => p.kind == k.id).length;
          return _KeepsakeTile(
            keepsake: k,
            clock: _trayClock,
            placed: out,
            onTap: () => _place(k.id, keepsake: true),
          );
        },
      ),
    );
  }
}

/// A piece of decor on the tray: its picture, its name, how many are owned,
/// and what a tap does — places one of those owned, or stands a preview of
/// one more to be bought where it stands.
class _DecorTile extends StatelessWidget {
  const _DecorTile({
    required this.decor,
    required this.owned,
    required this.placed,
    required this.canBuy,
    required this.onTap,
  });

  final HomeDecor decor;
  final int owned, placed;

  /// Whether one more can be bought (fewer owned than a realm can stand).
  final bool canBuy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final left = owned - placed;
    final price = decor.gold > 0 ? '${decor.gold} G' : '${decor.silver} S';
    final (status, lit) = left > 0
        ? ('PLACE · $left LEFT', true)
        : canBuy
        ? ('PREVIEW · $price', false)
        : ('ALL PLACED', false);
    final own = owned == 0
        ? 'NOT OWNED'
        : canBuy
        ? 'OWN $owned OF ${decor.max}'
        : 'OWN $owned';
    TextStyle line(Color color) => TextStyle(
      fontFamily: 'monospace',
      color: color,
      fontSize: 8,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: lit
              ? _amber.withValues(alpha: 0.9)
              : _palette.line.withValues(alpha: 0.9),
          bracketSize: 7,
          strokeWidth: 1,
        ),
        child: Container(
          width: 96,
          // Solid: the field must not show through.
          color: Color.alphaBlend(
            _palette.surfaceFill(),
            const Color(0xFF05060B),
          ),
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 5),
          child: Column(
            children: [
              Expanded(
                child: Opacity(
                  opacity: owned > 0 ? 1 : 0.7,
                  child: KeepsakeView(decor.id),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                decor.name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: _palette.ink,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              Text(own, maxLines: 1, style: line(_palette.muted)),
              Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: line(lit ? _amber : _palette.ink.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrayLabel extends StatelessWidget {
  const _TrayLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    height: 32,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    color: _palette.chromeFill(),
    child: Text(
      text,
      style: bracketText(
        context,
        10.5,
        _amber,
        weight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    ),
  );
}

/// A keepsake on the tray: its own living picture, its name, and how many
/// of it are out.
class _KeepsakeTile extends StatefulWidget {
  const _KeepsakeTile({
    required this.keepsake,
    required this.clock,
    required this.placed,
    required this.onTap,
  });

  final Keepsake keepsake;
  final Animation<double> clock;
  final int placed;
  final VoidCallback onTap;

  @override
  State<_KeepsakeTile> createState() => _KeepsakeTileState();
}

class _KeepsakeTileState extends State<_KeepsakeTile> {
  late final KeepsakeArt? _art = KeepsakeArt.of(widget.keepsake.id);

  @override
  void dispose() {
    _art?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.keepsake;
    final left = k.copies - widget.placed;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(widget.onTap),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: left > 0
              ? _amber.withValues(alpha: 0.9)
              : _palette.line.withValues(alpha: 0.9),
          bracketSize: 7,
          strokeWidth: 1,
        ),
        child: Container(
          width: 96,
          // Solid: the field must not show through.
          color: Color.alphaBlend(
            _palette.surfaceFill(),
            const Color(0xFF05060B),
          ),
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 5),
          child: Column(
            children: [
              Expanded(
                child: _art == null
                    ? const SizedBox.shrink()
                    : CustomPaint(
                        size: Size.infinite,
                        painter: _KeepsakePainter(_art, widget.clock),
                      ),
              ),
              const SizedBox(height: 3),
              Text(
                k.title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: _palette.ink,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              Text(
                left <= 0
                    ? 'PLACED'
                    : k.copies > 1
                    ? 'PLACE · $left LEFT'
                    : 'PLACE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: left > 0 ? _amber : _palette.muted,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A keepsake drawn to fit its tile, alive.
class _KeepsakePainter extends CustomPainter {
  _KeepsakePainter(this.art, this.clock) : super(repaint: clock);

  final KeepsakeArt art;
  final Animation<double> clock;
  final KeepsakeTime _time = KeepsakeTime(night: 0.6, daylight: 0.6);

  @override
  void paint(Canvas canvas, Size size) {
    final b = art.box;
    final k = math.min(size.width / b.width, size.height / b.height) * 0.92;
    _time.t = clock.value * 60;
    canvas
      ..save()
      ..translate(size.width / 2 - b.center.dx * k, size.height - b.bottom * k)
      ..scale(k);
    art.paint(canvas, _time);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_KeepsakePainter old) => old.art != art;
}

/// A corner button in the wilderness HUD's language.
class _HudButton extends StatelessWidget {
  const _HudButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: GestureDetector(
        onTap: context.soundTap(onTap ?? () {}),
        behavior: HitTestBehavior.opaque,
        child: CustomPaint(
          painter: BracketFramePainter(
            color: accent.withValues(alpha: 0.8),
            bracketSize: 8,
            strokeWidth: 1.1,
          ),
          child: Container(
            constraints: const BoxConstraints(minWidth: 66, minHeight: 54),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: active
                ? _palette.accentWash(accent, darkAlpha: 0.22)
                : _palette.surfaceFill(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: accent, size: 20),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: bracketText(
                    context,
                    10.5,
                    _palette.ink,
                    weight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One choice: brackets in the accent when chosen.
/// How much of one coin the player holds, live, in a slip the height of a
/// chip — set beside a BUY chip.
class _HeldCoins extends StatefulWidget {
  const _HeldCoins({required this.kind});

  final CoinKind kind;

  @override
  State<_HeldCoins> createState() => _HeldCoinsState();
}

class _HeldCoinsState extends State<_HeldCoins> {
  // Held, so a rebuild of the row does not open a new query.
  late final Stream<Map<String, int>> _wallet = context
      .read<AlchemonsDatabase>()
      .currencyDao
      .watchAllCurrencies();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, int>>(
      stream: _wallet,
      builder: (context, snap) {
        final held =
            snap.data?[widget.kind == CoinKind.gold ? 'gold' : 'silver'] ?? 0;
        return CustomPaint(
          foregroundPainter: BracketFramePainter(
            color: _palette.line.withValues(alpha: 0.9),
            bracketSize: 7,
            strokeWidth: 1,
          ),
          child: Container(
            height: 32,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            color: _palette.chromeMutedFill(darkAlpha: 0.62),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'HAVE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: _palette.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(width: 6),
                CoinAmount(
                  kind: widget.kind,
                  amount: held,
                  size: 11,
                  color: coinColor(widget.kind, _palette),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.accent = _amber,
    this.height = 32,
    this.dot = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color accent;
  final double height;

  /// Something new behind it.
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: selected ? accent : _palette.line.withValues(alpha: 0.9),
          bracketSize: 7,
          strokeWidth: selected ? 1.3 : 1,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          color: selected
              ? _palette.accentWash(accent, darkAlpha: 0.24)
              : _palette.chromeMutedFill(darkAlpha: 0.62),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: accent),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: selected ? _palette.ink : _palette.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
              if (dot) ...[
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
