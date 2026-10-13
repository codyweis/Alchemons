// lib/screens/stadium/stadium_screen.dart
//
// THE TRIALS (the stadium, in the code): the race ladder, upright like the
// rest of the game's menus (the author, 2026-10-12: "would it be better if
// the race hub was portrait?" — yes: no turn of the phone on the way in).
// Top to bottom: the crowd over the three cups standing on their ledge
// (cup_shelf.dart) — the chosen one taller, in a spotlight — the chosen
// cup's three races, the chosen race (its course leg by leg), the start
// line with the racer and its rivals (racer_gate.dart), and RACE, which
// turns the phone for the race itself. Stats are shown, never how a racer
// would fare: that is the player's to work out (lightning is quick, horns
// are strong, a Fire racer makes Steam at a Water station).
//
// Entered from home's cup (stadium_passage.dart), the way in ends on the
// cup racing for now, and leaving goes back the same way.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/stadium/race_bodies.dart';
import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:alchemons/games/stadium/race_painter.dart';
import 'package:alchemons/games/stadium/race_room.dart';
import 'package:alchemons/games/stadium/race_rules.dart';
import 'package:alchemons/games/stadium/race_scenes.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/screens/stadium/course_map.dart';
import 'package:alchemons/screens/stadium/cup_shelf.dart';
import 'package:alchemons/screens/stadium/race_lobby_screen.dart';
import 'package:alchemons/screens/stadium/race_screen.dart';
import 'package:alchemons/screens/stadium/racer_gate.dart';
import 'package:alchemons/screens/stadium/stadium_passage.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/race_room_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/stadium_trophy.dart';
import 'package:flame/flame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _ink = Color(0xFFE6E2DA);
const Color _muted = Color(0xFF8E8C88);
const Color _brass = Color(0xFFCDB07A);
const Color _brassHot = Color(0xFFE2C98F);
const Color _bg = Color(0xFF09090B);
const Color _bg1 = Color(0xFF131316);

/// Where the stadium keeps the racer last chosen, by instance id.
const String kStadiumRacerKey = 'stadium_racer_v1';

/// [inst] as the stadium races it: its stats with the constellation's
/// bonuses, its stamina bars (one boost each), its sprite and looks — built
/// the way the cosmic screen builds its party.
CosmicPartyMember stadiumMemberOf(
  BuildContext context,
  CreatureInstance inst, {
  int slot = 0,
}) {
  final db = context.read<AlchemonsDatabase>();
  final catalog = context.read<CreatureCatalog>();
  final bonuses = context.read<ConstellationEffectsService>();
  final base = catalog.getCreatureById(inst.baseId);
  final stamina = StaminaService(db).computeState(inst);
  return CosmicPartyMember(
    instanceId: inst.instanceId,
    baseId: inst.baseId,
    displayName: inst.nickname ?? base?.name ?? inst.baseId,
    element: (base?.types.isNotEmpty ?? false) ? base!.types.first : 'Earth',
    family: base?.mutationFamily ?? 'kin',
    level: inst.level,
    statSpeed: bonuses.applyCombatStatBonus('speed', inst.statSpeed),
    statIntelligence: bonuses.applyCombatStatBonus(
      'intelligence',
      inst.statIntelligence,
    ),
    statStrength: bonuses.applyCombatStatBonus('strength', inst.statStrength),
    statBeauty: bonuses.applyCombatStatBonus('beauty', inst.statBeauty),
    slotIndex: slot,
    staminaBars: stamina.bars,
    staminaMax: stamina.max,
    spriteSheet: base?.spriteData != null ? sheetFromCreature(base!) : null,
    spriteVisuals: visualsFromInstance(base, inst),
  );
}

/// The party as it flies in space, for opening the stadium from outside
/// space (home's trophy, the developer tools): the saved slots. A save with
/// no party yet gets its four fastest Alchemons, so a new account can race
/// too. The stadium offers the first as its racer until one is chosen.
Future<List<CosmicPartyMember>> stadiumPartyFromSave(
  BuildContext context,
) async {
  final db = context.read<AlchemonsDatabase>();
  final rows = <CreatureInstance>[];
  for (final id in await db.settingsDao.getCosmicPartySlots()) {
    if (id == null) continue;
    final inst = await db.creatureDao.getInstance(id);
    if (inst != null) rows.add(inst);
  }
  if (rows.isEmpty) {
    final all = await db.creatureDao.getAllInstances()
      ..sort((a, b) => b.statSpeed.compareTo(a.statSpeed));
    rows.addAll(all.take(4));
  }
  if (!context.mounted) return const [];
  return [
    for (var i = 0; i < rows.length; i++)
      stadiumMemberOf(context, rows[i], slot: i),
  ];
}

/// The hub's header, and how tall the shelf of cups stands under it.
const double kTrialsHeaderHeight = 46;
double trialsShelfHeight(Size size) =>
    (size.height * .26).clamp(150.0, 250.0).toDouble();

/// Where the crowd stands on the hub: a band across the top, from the
/// header to about halfway down the shelf, behind the cups' spotlight.
/// The way in from home sweeps its stands' ring up into exactly this.
Rect trialsStandsBand(Size size, EdgeInsets pad) => Rect.fromLTWH(
  0,
  pad.top + 2,
  size.width,
  kTrialsHeaderHeight + trialsShelfHeight(size) * .5,
);

/// What the Trials open on: the ladder as won so far, and the racer at
/// the line — the one last chosen, else [party]'s first, else the fastest
/// Alchemon. Read while the way in plays, so the screen opens on it.
Future<(RaceProgress, CosmicPartyMember?)> loadTrialsStart(
  BuildContext context, {
  List<CosmicPartyMember> party = const [],
}) async {
  final db = context.read<AlchemonsDatabase?>();
  final prefs = await SharedPreferences.getInstance();
  final progress = RaceProgress.deserialise(
    prefs.getString(RaceProgress.prefsKey),
  );
  final saved = prefs.getString(kStadiumRacerKey);
  CosmicPartyMember? racer;
  try {
    if (db != null && saved != null) {
      final inst = await db.creatureDao.getInstance(saved);
      if (inst != null && context.mounted) {
        racer = stadiumMemberOf(context, inst);
      }
    }
    if (racer == null && party.isNotEmpty) racer = party.first;
    if (racer == null && db != null) {
      final all = await db.creatureDao.getAllInstances();
      if (all.isNotEmpty && context.mounted) {
        all.sort((a, b) => b.statSpeed.compareTo(a.statSpeed));
        racer = stadiumMemberOf(context, all.first);
      }
    }
  } catch (_) {
    racer ??= party.isEmpty ? null : party.first;
  }
  return (progress, racer);
}

class StadiumScreen extends StatefulWidget {
  const StadiumScreen({
    super.key,
    this.party = const [],
    this.passage,
    this.preload,
  });

  /// The party in space (its living members): the first is offered as the
  /// racer until the player has chosen one in the stadium.
  final List<CosmicPartyMember> party;

  /// The way in from home's trophy, when it came that way.
  final StadiumPassage? passage;

  /// [loadTrialsStart], begun before the screen was (while the way in
  /// played).
  final Future<(RaceProgress, CosmicPartyMember?)>? preload;

  @override
  State<StadiumScreen> createState() => _StadiumScreenState();
}

class _StadiumScreenState extends State<StadiumScreen>
    with SingleTickerProviderStateMixin {
  /// Seconds since the screen opened: the stands and the course map move
  /// by it.
  final ValueNotifier<double> _clock = ValueNotifier(0);
  late final Ticker _ticker;
  RaceProgress _progress = const RaceProgress();
  bool _loaded = false;
  int _cup = 0, _race = 0;
  bool _starting = false, _leaving = false;

  /// Whether a change of cup or race comes up gently: only once the
  /// player has chosen one (the screen opens straight on its own).
  bool _chosen = false;

  /// The one at the line; null until read (or with nothing to race).
  CosmicPartyMember? _racer;

  /// A picked racer is flying from the picker to the line.
  final ValueNotifier<bool> _flying = ValueNotifier(false);
  int _landings = 0;

  RaceCup get _cupDef => kRaceCups[_cup];
  RaceCourse get _course => _cupDef.courses[_race];
  bool get _raceOpen =>
      _progress.cupOpen(_cup) && _progress.raceOpen(_cupDef, _race);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) => _clock.value = e.inMicroseconds / 1e6)
      ..start();
    _load();
    unawaited(context.read<AudioController?>()?.playStadiumMusic());
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    _flying.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final (p, racer) =
        await (widget.preload ?? loadTrialsStart(context, party: widget.party));
    if (!mounted) return;
    setState(() {
      _progress = p;
      _racer = racer;
      _loaded = true;
      // Open on the cup racing for now (the one home's trophy shows), at
      // its first race not yet won.
      _cup = TrophyLook.currentCup(p);
      _race = _firstOpenRace(_cup);
    });
    // Laid out with it: the way in may settle onto the shelf now.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.passage?.ready.value = true;
    });
  }

  /// The usual slide-up picker; the one picked flies to the line.
  Future<void> _chooseRacer() async {
    if (_starting || _leaving) return;
    _flying.value = false;
    final picked = await pickRacer(
      context,
      current: _racer?.instanceId,
      flying: _flying,
      onPick: (inst) async {
        if (!mounted) return null;
        final m = stadiumMemberOf(context, inst);
        setState(() => _racer = m);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(kStadiumRacerKey, inst.instanceId);
        return m;
      },
    );
    if (picked != null && mounted) {
      HapticFeedback.lightImpact();
      setState(() => _landings++);
    }
  }

  int _firstOpenRace(int cup) => _progress
      .wonIn(kRaceCups[cup])
      .clamp(0, kRaceCups[cup].courses.length - 1);

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(RaceProgress.prefsKey, _progress.serialise());
  }

  /// Back the way it came: to home's trophy, or out through sand.
  Future<void> _leave() async {
    final passage = widget.passage;
    // Not while the way in is still settling onto the shelf.
    if (_leaving || _starting || (passage?.held.value ?? false)) return;
    _leaving = true;
    HapticFeedback.selectionClick();
    if (passage != null) {
      final cup = TrophyLook.currentCup(_progress);
      await passage.leave(
        context,
        cup: cup,
        look: TrophyLook.ofCup(cup, _progress),
      );
      return;
    }
    await VoidPortal.leaveThroughSand<void>(context);
  }

  Future<void> _start() async {
    final member = _racer;
    if (_starting || member == null || !_raceOpen) return;
    setState(() => _starting = true);
    HapticFeedback.mediumImpact();
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();
    final inst = await db.creatureDao.getInstance(member.instanceId);
    final cupIndex = _cup, cup = _cupDef, race = _race;
    // Racing the newest open race: a win moves the ladder on.
    final frontier = race == _progress.wonIn(cup);
    final (racers, bodies) = raceSix(catalog, cup, race, member, inst);
    // And what each becomes at the fusion stations.
    final forms = raceForms(catalog, racers, bodies, cup.courses[race]);
    for (final f in forms) {
      for (final b in f.values) {
        if (b.ticker == null) await b.load(Flame.images);
      }
    }
    if (!mounted) return;
    setState(() => _starting = false);
    // The lights go down, the phone turns for the race, and the race comes
    // up out of the black; RACE AGAIN stays sideways, leaving turns back.
    await VoidPortal.pushThroughTurn<RaceOutcome>(
      context,
      page: RaceSeries(
        cup: cup,
        race: race,
        racers: racers,
        bodies: bodies,
        forms: forms,
        onFinished: (place) => _pay(cup, race, place),
      ),
      scene: const RaceLightsScene(),
      from: null,
      to: () => null,
      orientation: const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      returnOrientation: const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ],
    );
    // A win opened the next race, or finished the cup and lit the next one
    // on the shelf: be on it.
    if (!mounted || !frontier || _progress.wonIn(cup) <= race) return;
    setState(() {
      if (_progress.cupDone(cup) && cupIndex + 1 < kRaceCups.length) {
        _cup = cupIndex + 1;
      }
      _race = _firstOpenRace(_cup);
    });
  }

  /// A win opens the next race; the first win of each race pays its gold.
  Future<int> _pay(RaceCup cup, int race, int place) async {
    if (place != 1) return 0;
    final (next, first) = _progress.afterWin(cup, race);
    if (!first) return 0;
    final gold = cup.gold[race];
    await context.read<AlchemonsDatabase>().currencyDao.addGold(gold);
    if (!mounted) return gold;
    setState(() => _progress = next);
    await _save();
    return gold;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _Backdrop(_clock, MediaQuery.paddingOf(context)),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(context),
                    SizedBox(
                      height: trialsShelfHeight(size),
                      child: _loaded
                          ? CupShelf(
                              progress: _progress,
                              selected: _cup,
                              passage: widget.passage,
                              onSelect: (c) => setState(() {
                                _chosen = true;
                                _cup = c;
                                _race = _firstOpenRace(c);
                              }),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 46,
                      // Another cup's races come up as the light reaches
                      // it on the shelf.
                      child: _changing(
                        _cup,
                        Row(
                          children: [
                            for (
                              var r = 0;
                              r < _cupDef.courses.length;
                              r++
                            ) ...[
                              if (r > 0) const SizedBox(width: 6),
                              Expanded(child: _raceTile(context, r)),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(child: _detail(context)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return SizedBox(
      height: kTrialsHeaderHeight,
      child: Row(
        children: [
          BracketIconButton(
            icon: AppIcons.arrow_back_rounded,
            onTap: _leave,
            palette: BracketPalette.dark,
            size: 34,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'THE TRIALS',
                style: bracketText(
                  context,
                  15,
                  _ink,
                  weight: FontWeight.w800,
                  letterSpacing: 2.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One of the chosen cup's races: its name, and WON, its first-win
  /// gold, or LOCKED.
  Widget _raceTile(BuildContext context, int r) {
    final cup = _cupDef;
    final open = _progress.cupOpen(_cup) && _progress.raceOpen(cup, r);
    final won = r < _progress.wonIn(cup);
    final selected = r == _race;
    final name = cup.courses[r].name.replaceAll(' Track', '').toUpperCase();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (selected) return;
        HapticFeedback.selectionClick();
        setState(() {
          _chosen = true;
          _race = r;
        });
      },
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: selected
              ? (open ? _brass : _muted)
              : BracketPalette.dark.lineSoft,
          strokeWidth: 1.2,
        ),
        child: Container(
          color: selected ? _bg1 : _bg1.withValues(alpha: .45),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  name,
                  maxLines: 1,
                  style: bracketText(
                    context,
                    11,
                    !open
                        ? _muted.withValues(alpha: .5)
                        : (selected ? _brassHot : _ink),
                    weight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              if (won)
                Text(
                  'WON',
                  style: bracketText(
                    context,
                    9,
                    _brass,
                    weight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                )
              else if (open)
                CoinAmount(kind: CoinKind.gold, amount: cup.gold[r], size: 10)
              else
                Text(
                  'LOCKED',
                  style: bracketText(
                    context,
                    9,
                    _muted.withValues(alpha: .5),
                    weight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// [child], which comes up in place of the last as [key] changes: the
  /// old one going quickly, the new rising into its place a moment after —
  /// as the light reaches the new cup on the shelf.
  Widget _changing(Object key, Widget child) => AnimatedSwitcher(
    duration: Duration(milliseconds: _chosen ? 640 : 0),
    switchInCurve: const Interval(.4, 1, curve: Curves.easeOutCubic),
    switchOutCurve: const Interval(.7, 1, curve: Curves.easeIn),
    layoutBuilder: (current, previous) => Stack(
      alignment: Alignment.topCenter,
      children: [...previous, ?current],
    ),
    transitionBuilder: (child, a) => FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, .12),
          end: Offset.zero,
        ).animate(a),
        child: child,
      ),
    ),
    child: KeyedSubtree(key: ValueKey(key), child: child),
  );

  // ── the chosen race ───────────────────────────────────────────────────────

  Widget _detail(BuildContext context) {
    final rooms = context.watch<RaceRoomService?>();
    final course = _course;
    final open = _raceOpen;
    final won = _race < _progress.wonIn(_cupDef);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The race's name, what it pays, and its course: another race's
        // come up in their place.
        _changing(
          '$_cup/$_race',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        course.name.toUpperCase(),
                        style: bracketText(
                          context,
                          19,
                          open ? _brassHot : _muted,
                          weight: FontWeight.w800,
                          letterSpacing: 2.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: won
                        ? Text(
                            'WON',
                            style: bracketText(
                              context,
                              11,
                              _brass,
                              weight: FontWeight.w800,
                              letterSpacing: 1.6,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'FIRST WIN',
                                style: bracketText(
                                  context,
                                  9,
                                  _muted,
                                  weight: FontWeight.w700,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(width: 6),
                              CoinAmount(
                                kind: CoinKind.gold,
                                amount: _cupDef.gold[_race],
                                size: 12,
                              ),
                            ],
                          ),
                  ),
                ],
              ),
              // The cup, which race of it, and where it runs.
              Text(
                '${_cupDef.name.toUpperCase()} · RACE ${_race + 1} OF '
                '${_cupDef.courses.length} · ${raceSceneName(course.scene)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: bracketText(
                  context,
                  9.5,
                  _muted,
                  weight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              // The course, leg by leg, where each falls.
              SizedBox(
                height: 60,
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: CourseMapPainter(
                      course: course,
                      clock: _clock,
                      textStyle:
                          Theme.of(context).textTheme.bodyMedium ??
                          const TextStyle(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // The racer at the line, the rivals down the lane.
        Expanded(
          child: RacerGate(
            racer: _racer,
            rivals: _cupDef.rivals,
            onChoose: _chooseRacer,
            flying: _flying,
            landings: _landings,
          ),
        ),
        const SizedBox(height: 8),
        // A friend asking to race, if one is.
        if (rooms != null && rooms.invites.isNotEmpty) ...[
          _inviteSlip(context, rooms.invites.first),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            // Racing friends, for a player who can.
            if (rooms != null && rooms.available) ...[
              Expanded(
                child: BracketButton(
                  label: 'RACE FRIENDS',
                  palette: BracketPalette.dark,
                  accent: _brass,
                  primary: false,
                  height: 42,
                  enabled: open && !_starting,
                  onTap: _raceFriends,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: BracketButton(
                label: !open ? 'LOCKED' : (_starting ? 'LINING UP…' : 'RACE'),
                palette: BracketPalette.dark,
                accent: _brass,
                height: 42,
                enabled: open && !_starting && _racer != null,
                onTap: _start,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// A room for the race on show, to ask friends into.
  Future<void> _raceFriends() async {
    if (_starting || _leaving || !_raceOpen) return;
    HapticFeedback.selectionClick();
    await RaceLobbyScreen.host(context, cup: _cup, race: _race);
  }

  /// A friend's invitation waiting: who, which course, and JOIN.
  Widget _inviteSlip(BuildContext context, RaceRoom room) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        RaceLobbyScreen.open(context, room.id);
      },
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: _brass.withValues(alpha: .7),
          strokeWidth: 1.1,
        ),
        child: Container(
          height: 36,
          color: _bg1,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${room.nameOf(room.host).toUpperCase()} ASKS YOU TO RACE · '
                  '${room.course.name.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bracketText(
                    context,
                    10,
                    _ink,
                    weight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'JOIN',
                style: bracketText(
                  context,
                  10.5,
                  _brassHot,
                  weight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Trials behind the screen: the crowd in a band across the top
/// (the race's own stands, drifting), falling away into the dark.
class _Backdrop extends CustomPainter {
  _Backdrop(this.clock, this.pad) : super(repaint: clock);

  final ValueListenable<double> clock;
  final EdgeInsets pad;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    canvas.drawRect(Offset.zero & size, Paint()..color = _bg);
    // The stands draw themselves in a band 0.1–0.335 of the height they
    // are given: given a height that puts that band where it belongs.
    final band = trialsStandsBand(size, pad);
    final virtual = band.height / 0.235;
    canvas.save();
    canvas.translate(0, band.top - virtual * 0.1);
    paintStadiumStands(
      canvas,
      Size(size.width, virtual),
      t: t,
      camX: t * 9,
      cheer: 0.3,
    );
    canvas.restore();
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, band.top),
          Offset(0, size.height),
          [
            _bg.withValues(alpha: 0.1),
            _bg.withValues(alpha: 0.8),
            _bg.withValues(alpha: 0.95),
          ],
          [
            0,
            ((band.bottom - band.top + 40) / (size.height - band.top)).clamp(
              0.1,
              0.9,
            ),
            1,
          ],
        ),
    );
  }

  @override
  bool shouldRepaint(_Backdrop old) => old.pad != pad;
}
