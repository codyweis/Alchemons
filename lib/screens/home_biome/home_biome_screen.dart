// lib/screens/home_biome/home_biome_screen.dart
//
// The home biome: the field under the player's home planet, reached by
// descending from the home base. It is one of the five wild realms, drawn
// by that realm's own field, with the player's own Alchemons standing where
// its wild ones would — the Sky building each an isle, the Swamp a bank, the
// Volcano a shelf.
//
// Looking is the default: the field is the player's to pan, pinch and run a
// finger through. ARRANGE opens the few things that can change, along the
// sky where nothing stands: which realm, its weather (each realm only its
// own), the hour, and who lives here. Arranging, a resident can be taken
// hold of and carried; tapped, it can be sent to the other row, turned,
// lifted into the air (what can float), or sent away.

import 'dart:async';

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/home_biome.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/providers/audio_provider.dart' show AudioController;
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/all_specimens_page.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
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

class _HomeBiomeScreenState extends State<HomeBiomeScreen>
    with SingleTickerProviderStateMixin {
  HomeBiomeLayout _layout = const HomeBiomeLayout();

  /// Each resident's look, by instance id.
  final Map<String, (Creature, CreatureInstance)> _looks = {};

  SceneGame? _game;
  int _gameKey = 0;

  /// The first field is built and its residents stand in it.
  bool _ready = false;

  /// Black over the field while a realm is built.
  bool _veiled = true;

  bool _arranging = false;

  /// The resident chosen while arranging, by instance id.
  String? _selected;

  late final RevealWhenReady _reveal;

  /// Sweeps the hour forward to a new one, as the day would.
  late final AnimationController _sweep;
  double _sweepFrom = 0, _sweepBy = 0;
  bool _sweepToLive = false;

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
    _db = context.read<AlchemonsDatabase>();
    _catalog = context.read<CreatureCatalog>();
    unawaited(_load());
  }

  @override
  void dispose() {
    _reveal.dispose();
    _sweep.dispose();
    super.dispose();
  }

  // ── Loading and saving ───────────────────────────────────────────────────

  Future<void> _load() async {
    var layout = await HomeBiomeLayout.load(_db.settingsDao);
    final kept = <HomeResident>[];
    for (final r in layout.residents) {
      final inst = await _db.creatureDao.getInstance(r.instanceId);
      final creature = inst == null ? null : hydrateResident(inst, _catalog);
      // Released, sold or fused away since: it no longer lives here.
      if (inst == null || creature == null) continue;
      _looks[r.instanceId] = (creature, inst);
      kept.add(r);
    }
    if (kept.length != layout.residents.length) {
      layout = layout.copyWith(residents: kept);
      unawaited(layout.save(_db.settingsDao));
    }
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

  void _commit(HomeBiomeLayout layout) {
    setState(() => _layout = layout);
    unawaited(layout.save(_db.settingsDao));
  }

  bool _floats(String instanceId) =>
      speciesCanFloat(_looks[instanceId]?.$1.id ?? '');

  List<SpawnPoint> get _points => _layout.spawnPoints(_floats);

  // ── The field ────────────────────────────────────────────────────────────

  void _buildGame() {
    final mood = _layout.mood;
    final game = SceneGame(scene: _layout.scene(_floats), showcase: true)
      ..fieldHourOverride = _layout.hour
      ..fieldWeather = mood.weather
      ..fieldAftermath = mood.aftermath
      ..fieldStage = mood.stage
      ..arranging = _arranging
      ..onResidentTap = _onResidentTap
      ..onResidentPicked = _onResidentTap
      ..onResidentDropped = _onResidentDropped;
    setState(() {
      _game = game;
      _gameKey++;
    });
    unawaited(_standResidents(game));
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

  Future<void> _setRealm(HomeRealm realm) async {
    if (realm == _layout.realm) return;
    HapticFeedback.selectionClick();
    _select(null);
    setState(() => _veiled = true);
    _commit(_settle(_layout.copyWith(realm: realm)));
    unawaited(
      context.read<AudioController?>()?.playWildMusicForScene(realm.sceneId) ??
          Future<void>.value(),
    );
    // Under the veil before the old field goes.
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted || _layout.realm != realm) return;
    _buildGame();
  }

  /// [layout] with every resident spaced as its realm needs: a realm's
  /// rows are their own lengths, its creatures their own sizes.
  HomeBiomeLayout _settle(HomeBiomeLayout layout) {
    var out = layout.copyWith(residents: const []);
    for (final r in layout.residents) {
      var placed = r;
      final x = out.freeSpotNear(r, r.x);
      if (x != null) {
        placed = r.copyWith(x: x);
      } else {
        final other = r.copyWith(back: !r.back);
        final y = out.freeSpotNear(other, r.x);
        if (y != null) placed = other.copyWith(x: y);
      }
      out = out.copyWith(residents: [...out.residents, placed]);
    }
    return out;
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
    HapticFeedback.selectionClick();
    final on = !_arranging;
    setState(() => _arranging = on);
    _game?.arranging = on;
    if (!on) _select(null);
  }

  void _select(String? instanceId) {
    if (_selected == instanceId) return;
    setState(() => _selected = instanceId);
    _game?.markResident(instanceId == null ? null : 'HOME_$instanceId');
  }

  HomeResident? get _selectedResident => _selected == null
      ? null
      : _layout.residents.where((r) => r.instanceId == _selected).firstOrNull;

  void _onResidentTap(String spawnId) {
    if (!_arranging) return;
    final r = _layout.resident(spawnId);
    if (r == null) return;
    HapticFeedback.selectionClick();
    _select(r.instanceId);
  }

  void _onResidentDropped(String spawnId, double share, double height) {
    final game = _game;
    final r = _layout.resident(spawnId);
    if (game == null || r == null) return;
    final row = _layout.realm.row(back: r.back);
    // Something that can float, let go well above where it would stand,
    // stays up there.
    final lift = _floats(r.instanceId) && height < row.height - 0.07
        ? height.clamp(0.12, row.height - 0.07)
        : null;
    var moved = r.copyWith(x: share, lift: () => lift);
    final x = _layout.freeSpotNear(moved, share);
    if (x == null) return;
    moved = moved.copyWith(x: x);
    _commit(_layout.replace(moved));
    game.relayout(_points);
    HapticFeedback.lightImpact();
  }

  /// Sends the chosen resident to the other row, where it stood on screen.
  void _swapRow() {
    final game = _game;
    final r = _selectedResident;
    if (game == null || r == null) return;
    final back = !r.back;
    final row = _layout.realm.row(back: back);
    final screenX = game.screenXOf(r.spawnId) ?? game.size.x / 2;
    var moved = r.copyWith(
      back: back,
      x: game.shareAtScreen(row.layer, screenX),
      lift: () => r.lift?.clamp(0.12, row.height - 0.07),
    );
    final x = _layout.freeSpotNear(moved, moved.x);
    if (x == null) {
      HapticFeedback.heavyImpact();
      return;
    }
    moved = moved.copyWith(x: x);
    HapticFeedback.selectionClick();
    _commit(_layout.replace(moved));
    game.relayout(_points);
  }

  void _turn() {
    final game = _game;
    final r = _selectedResident;
    if (game == null || r == null) return;
    HapticFeedback.selectionClick();
    _commit(_layout.replace(r.copyWith(flip: !r.flip)));
    game.turnResident(r.spawnId);
  }

  /// Lifts the chosen resident into the air, or sets it down.
  void _flyOrLand() {
    final game = _game;
    final r = _selectedResident;
    if (game == null || r == null || !_floats(r.instanceId)) return;
    final row = _layout.realm.row(back: r.back);
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
    moved = moved.copyWith(x: x);
    HapticFeedback.selectionClick();
    _commit(_layout.replace(moved));
    game.relayout(_points);
  }

  void _sendAway() {
    final r = _selectedResident;
    if (r == null) return;
    HapticFeedback.mediumImpact();
    _select(null);
    _apply(
      _layout.copyWith(
        residents: [
          for (final o in _layout.residents)
            if (o.instanceId != r.instanceId) o,
        ],
      ),
      gone: [r],
    );
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
              searchHint: 'WHO LIVES HERE',
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
    if (gone.any((r) => r.instanceId == _selected)) _select(null);

    // Newcomers stand as near the middle of the screen as there is room:
    // on the near row, or the far one once that is full.
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
      for (final back in const [false, true]) {
        final row = layout.realm.row(back: back);
        final r = HomeResident(instanceId: inst.instanceId, back: back);
        final x = layout.freeSpotNear(r, game.shareAtScreen(row.layer, mid));
        if (x != null) {
          placed = r.copyWith(x: x);
          break;
        }
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
                    if (_selectedResident != null) ...[
                      const SizedBox(height: 8),
                      _residentRow(context, _selectedResident!),
                    ],
                  ],
                  const Spacer(),
                  if (!_arranging && _ready && _layout.residents.isEmpty)
                    Center(
                      child: Text(
                        'No Alchemons live here yet. Tap Arrange to bring them home.',
                        textAlign: TextAlign.center,
                        style: bracketText(
                          context,
                          12.5,
                          _palette.ink.withValues(alpha: 0.85),
                          weight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HudButton(
          label: 'Exit',
          icon: AppIcons.exit_to_app_rounded,
          accent: const Color(0xFFC0392B),
          onTap: () => VoidPortal.pop(context),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _arranging ? _realmRow(context) : const SizedBox.shrink(),
        ),
        const SizedBox(width: 10),
        _HudButton(
          label: _arranging ? 'Done' : 'Arrange',
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
          for (final realm in HomeRealm.values) ...[
            if (realm != HomeRealm.values.first) const SizedBox(width: 6),
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
          const SizedBox(width: 16),
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
            _Chip(label: label, selected: h == hour, onTap: () => _setHour(h)),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _residentRow(BuildContext context, HomeResident r) {
    final look = _looks[r.instanceId];
    final name = look?.$2.nickname?.isNotEmpty == true
        ? look!.$2.nickname!
        : (look?.$1.name ?? '');
    final floats = _floats(r.instanceId);
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
            const SizedBox(width: 8),
            _Chip(
              label: r.back ? 'TO FRONT' : 'TO BACK',
              icon: AppIcons.layers_rounded,
              selected: false,
              onTap: _swapRow,
            ),
            const SizedBox(width: 6),
            _Chip(
              label: 'TURN',
              icon: AppIcons.swap_horiz_rounded,
              selected: false,
              onTap: _turn,
            ),
            if (floats) ...[
              const SizedBox(width: 6),
              _Chip(
                label: r.lift == null ? 'FLY' : 'LAND',
                icon: AppIcons.flight_takeoff_rounded,
                selected: false,
                onTap: _flyOrLand,
              ),
            ],
            const SizedBox(width: 6),
            _Chip(
              label: 'SEND AWAY',
              icon: AppIcons.close_rounded,
              selected: false,
              accent: const Color(0xFFC0392B),
              onTap: _sendAway,
            ),
          ],
        ),
      ),
    );
  }
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
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.accent = _amber,
    this.height = 32,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color accent;
  final double height;

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
            ],
          ),
        ),
      ),
    );
  }
}
