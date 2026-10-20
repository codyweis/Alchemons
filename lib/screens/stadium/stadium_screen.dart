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
import 'package:alchemons/games/stadium/cup_rewards.dart';
import 'package:alchemons/games/stadium/gem_cups.dart';
import 'package:alchemons/games/stadium/race_bodies.dart';
import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:alchemons/games/stadium/race_painter.dart';
import 'package:alchemons/games/stadium/race_room.dart';
import 'package:alchemons/games/stadium/race_rules.dart';
import 'package:alchemons/games/stadium/race_scenes.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/screens/stadium/course_map.dart';
import 'package:alchemons/screens/stadium/cup_won_dialog.dart';
import 'package:alchemons/games/stadium/flight_rules.dart';
import 'package:alchemons/games/stadium/flight_stage.dart';
import 'package:alchemons/games/stadium/island_stage.dart';
import 'package:alchemons/games/stadium/battle_ladder.dart';
import 'package:alchemons/games/stadium/trials_records.dart';
import 'package:alchemons/screens/stadium/bout_screen.dart';
import 'package:alchemons/screens/battle/battle_hub_screen.dart'
    show BattleCase, BattleEmptyCase, loadBattleTeam, pickBattleTeam;
import 'package:alchemons/screens/battle/battle_screen.dart';
import 'package:alchemons/models/battle_arenas.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart' show kBattleTeamSize;
import 'package:alchemons/screens/stadium/cup_shelf.dart';
import 'package:alchemons/screens/stadium/race_lobby_screen.dart';
import 'package:alchemons/screens/stadium/race_screen.dart';
import 'package:alchemons/screens/stadium/racer_gate.dart';
import 'package:alchemons/screens/stadium/route_planner.dart';
import 'package:alchemons/screens/stadium/stadium_passage.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/debug_settings_service.dart';
import 'package:alchemons/services/race_room_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/stadium_trophy.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/friend_service.dart';
import 'package:alchemons/services/shop_service.dart';
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

/// Where the shelf of cups stands on the hub, worked out before the hub is
/// built: the way in from home flies its cup there while the hub is read.
Rect trialsShelfRect(Size size, EdgeInsets pad) => Rect.fromLTWH(
  pad.left + 16,
  pad.top + kTrialsHeaderHeight,
  size.width - pad.horizontal - 32,
  trialsShelfHeight(size),
);

/// Where the crowd stands on the hub: a band across the top, from the
/// header to about halfway down the shelf, behind the cups' spotlight.
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
  var progress = RaceProgress.deserialise(
    prefs.getString(RaceProgress.prefsKey),
  );
  // The developer tools open every cup, race and bout.
  if (await DebugSettingsService().isEnabled()) progress = progress.opened();
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

  /// The player's bests at every race and bout.
  TrialsRecords _records = const TrialsRecords();
  bool _loaded = false;
  int _cup = 0, _race = 0;
  bool _starting = false, _leaving = false;

  /// Showing the gem cups (Ruby, Sapphire, Emerald) rather than the races;
  /// the gem cup and bout chosen there.
  bool _gems = false;
  int _gem = 0, _bout = 0;

  /// The four the Emerald Cup's battle ladder is fought with (the battle
  /// hub's), and each round's set team, built once.
  List<CosmicPartyMember> _battleTeam = const [];
  final Map<String, List<CosmicPartyMember>> _ladderTeams = {};

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

  GemCup get _gemDef => kGemCups[_gem];
  bool get _boutOpen =>
      _progress.gemOpen(_gem) && _progress.boutOpen(_gemDef, _bout);

  int _firstOpenBout(int gem) => _progress
      .wonInGem(kGemCups[gem])
      .clamp(0, kGemCups[gem].bouts.length - 1);

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
    final records = await TrialsRecords.load();
    if (!mounted) return;
    final battleTeam = await loadBattleTeam(context);
    if (!mounted) return;
    // A cup won before cups gave anything gives it now.
    final db = context.read<AlchemonsDatabase?>();
    if (db != null) _toAnnounce.addAll(await giveCupRewards(db, p));
    if (!mounted) return;
    // The stat effects the cups give now (the space contests' once).
    final shop = context.read<ShopService?>();
    if (shop != null) await unlockCupStatEffects(shop, p);
    if (!mounted) return;
    setState(() {
      _progress = p;
      _records = records;
      _racer = racer;
      _battleTeam = battleTeam;
      _loaded = true;
      // Open on the cup racing for now (the one home's trophy shows), at
      // its first race not yet won.
      _cup = TrophyLook.currentCup(p);
      _race = _firstOpenRace(_cup);
      // The gem cup being fought for: the first open one not yet done (all
      // three open together, each with its own five).
      _gem = 0;
      for (var g = kGemCups.length - 1; g >= 0; g--) {
        if (p.gemOpen(g) && !p.gemDone(kGemCups[g])) _gem = g;
      }
      _bout = _firstOpenBout(_gem);
    });
    // Laid out with it: the way in may settle onto the shelf now.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.passage?.ready.value = true;
    });
    if (_toAnnounce.isNotEmpty) unawaited(_announceOnceSettled());
  }

  /// Cups won and not yet shown off.
  final List<CupReward> _toAnnounce = [];

  /// Shows the cups won, once the way in has landed on the shelf.
  Future<void> _announceOnceSettled() async {
    final held = widget.passage?.held;
    if (held != null && held.value) {
      final landed = Completer<void>();
      void on() {
        if (!held.value && !landed.isCompleted) landed.complete();
      }

      held.addListener(on);
      await landed.future.timeout(const Duration(seconds: 6), onTimeout: () {});
      held.removeListener(on);
    }
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await _announce();
  }

  Future<void> _announce() async {
    if (!mounted || _toAnnounce.isEmpty) return;
    final rewards = [..._toAnnounce];
    _toAnnounce.clear();
    await showCupsWon(context, rewards, racer: _racer);
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
      // Home's cup is one of the races': back to their shelf to leave.
      if (_gems) {
        setState(() => _gems = false);
        await Future<void>.delayed(const Duration(milliseconds: 380));
        if (!mounted) return;
      }
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
        onFinished: (finish) => _pay(cup, race, finish),
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
    // on the shelf: be on it — after showing off the cup, if it was won.
    if (!mounted) return;
    await _announce();
    if (!mounted || !frontier || _progress.wonIn(cup) <= race) return;
    setState(() {
      if (_progress.cupDone(cup) && cupIndex + 1 < kRaceCups.length) {
        _cup = cupIndex + 1;
      }
      _race = _firstOpenRace(_cup);
    });
  }

  /// A race's end: any finish can set the course's record; a win opens
  /// the next race, and the first win of each pays its gold, shards and
  /// tincture.
  Future<TrialsPayout> _pay(RaceCup cup, int race, TrialsFinish finish) async {
    final record = await _keepRecord(cup.courses[race].id, finish.mark);
    if (finish.place != 1) return TrialsPayout(record: record);
    final (next, first) = _progress.afterWin(cup, race);
    if (!first || !mounted) return TrialsPayout(record: record);
    final gold = cup.gold[race];
    final db = context.read<AlchemonsDatabase>();
    await db.currencyDao.addGold(gold);
    await _payFirstWin(db, cup.id, race);
    if (!mounted) return TrialsPayout(gold: gold, record: record);
    setState(() => _progress = next);
    await _save();
    // The cup's last race: what the cup gives, shown back on the shelf.
    _toAnnounce.addAll(await giveCupRewards(db, next));
    if (mounted) {
      final shop = context.read<ShopService?>();
      if (shop != null) await unlockCupStatEffects(shop, next);
    }
    _publish();
    return TrialsPayout(gold: gold, record: record);
  }

  /// What a first win pays besides its gold: shards for the home bank
  /// (space banks them; see [addPendingTrialsShards]) and tincture for the
  /// Athanor — what the space contests used to pay.
  Future<void> _payFirstWin(AlchemonsDatabase db, String cupId, int i) async {
    final shards = kTrialsFirstWinShards[cupId];
    if (shards != null && i < shards.length) {
      await addPendingTrialsShards(shards[i]);
    }
    final tincture = kTrialsFirstWinTincture[cupId] ?? 0;
    if (tincture > 0) {
      await db.inventoryDao.addItemQty(InvKeys.athanorTincture, tincture);
    }
  }

  /// Keeps [mark] as the record at [id] if it beats the one kept, set by
  /// the racer that ran it; whether it did.
  Future<bool> _keepRecord(
    String id,
    double? mark, {
    CosmicPartyMember? by,
  }) async {
    final event = trialsEvent(id);
    final me = by ?? _racer;
    if (event == null || mark == null || me == null) return false;
    final value = (mark * 1000).round();
    if (value <= 0 || !_records.beats(id, value)) return false;
    final next = _records.withRecord(
      id,
      TrialsRecord(
        value: value,
        by: me.displayName,
        baseId: me.baseId,
        at: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await next.save();
    if (mounted) setState(() => _records = next);
    _publish();
    return true;
  }

  /// Friends see the cups and records (on their planet pages).
  void _publish() {
    if (!mounted) return;
    context.read<FriendService?>()?.publishSoon();
  }

  /// The record kept at [id] as a short line (BEST 37.86s), or null.
  String? _best(String id) {
    final r = _records.best[id];
    final e = trialsEvent(id);
    if (r == null || e == null) return null;
    return 'BEST ${e.show(r.value)}';
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
                      child: !_loaded
                          ? const SizedBox.shrink()
                          : AnimatedSwitcher(
                              duration: const Duration(milliseconds: 360),
                              child: _gems
                                  ? CupShelf(
                                      key: const ValueKey('gems'),
                                      cups: ShelfCup.gems(_progress),
                                      selected: _gem,
                                      onSelect: (g) => setState(() {
                                        _chosen = true;
                                        _gem = g;
                                        _bout = _firstOpenBout(g);
                                      }),
                                    )
                                  : CupShelf(
                                      key: const ValueKey('races'),
                                      cups: ShelfCup.races(_progress),
                                      selected: _cup,
                                      passage: widget.passage,
                                      onSelect: (c) => setState(() {
                                        _chosen = true;
                                        _cup = c;
                                        _race = _firstOpenRace(c);
                                      }),
                                    ),
                            ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 46,
                      // Another cup's races come up as the light reaches
                      // it on the shelf.
                      child: _changing(
                        _gems ? 'gem$_gem' : 'race$_cup',
                        Row(
                          children: [
                            for (
                              var r = 0;
                              r <
                                  (_gems
                                      ? _gemDef.bouts.length
                                      : _cupDef.courses.length);
                              r++
                            ) ...[
                              if (r > 0) const SizedBox(width: 6),
                              Expanded(
                                child: _gems
                                    ? _boutTile(context, r)
                                    : _raceTile(context, r),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: _gems ? _gemDetail(context) : _detail(context),
                    ),
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
          const Spacer(),
          if (_loaded) _ladderSwitch(context),
        ],
      ),
    );
  }

  /// RACES · GEMS: which cups the shelf shows.
  Widget _ladderSwitch(BuildContext context) {
    Widget side(String label, bool gems) {
      final on = _gems == gems;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (on || _starting) return;
          HapticFeedback.selectionClick();
          setState(() {
            _chosen = true;
            _gems = gems;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: bracketText(
                  context,
                  11,
                  on ? _brassHot : _muted,
                  weight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                width: on ? 18 : 0,
                height: 2,
                color: _brass,
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [side('RACES', false), side('GEMS', true)],
    );
  }

  /// One of the gem cup's bouts: its name, and WON, its first-win gold, or
  /// LOCKED.
  Widget _boutTile(BuildContext context, int r) {
    final cup = _gemDef;
    final open = _progress.gemOpen(_gem) && _progress.boutOpen(cup, r);
    final won = r < _progress.wonInGem(cup);
    final selected = r == _bout;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (selected) return;
        HapticFeedback.selectionClick();
        setState(() {
          _chosen = true;
          _bout = r;
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
              // Five to a row: a name of two words takes two lines rather
              // than shrinking out of reading.
              Text(
                cup.bouts[r].name.toUpperCase(),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: bracketText(
                  context,
                  9,
                  !open
                      ? _muted.withValues(alpha: .5)
                      : (selected ? _brassHot : _ink),
                  weight: FontWeight.w800,
                  letterSpacing: 1.0,
                ).copyWith(height: 1.05),
              ),
              const SizedBox(height: 2),
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

  /// The chosen bout: its name and pay, the event and what it asks, the
  /// two rivals at the line, and START.
  Widget _gemDetail(BuildContext context) {
    final rooms = context.watch<RaceRoomService?>();
    final cup = _gemDef;
    final bout = cup.bouts[_bout];
    final open = _boutOpen;
    final won = _bout < _progress.wonInGem(cup);
    final shut = !_progress.gemOpen(_gem);
    final battle = cup.event == GemEvent.battle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _changing(
          'gem$_gem/$_bout',
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
                        bout.name.toUpperCase(),
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
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: won
                        ? Text(
                            _best(bout.id) ?? 'WON',
                            style: bracketText(
                              context,
                              11,
                              _brass,
                              weight: FontWeight.w800,
                              letterSpacing: 1.6,
                            ),
                          )
                        : CoinAmount(
                            kind: CoinKind.gold,
                            amount: cup.gold[_bout],
                            size: 12,
                          ),
                  ),
                ],
              ),
              Text(
                '${cup.name.toUpperCase()} · ${battle ? 'ROUND' : 'BOUT'} '
                '${_bout + 1} OF ${cup.bouts.length} · ${cup.event.title}',
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
              const SizedBox(height: 8),
              Text(
                shut
                    ? 'Win the Silver Cup to open the gem cups.'
                    : (bout.line.isNotEmpty ? bout.line : cup.event.line),
                style: bracketText(context, 12.5, _ink.withValues(alpha: .8)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: battle
              ? _changing('gem$_gem/$_bout', _ladderGate(context, bout))
              : RacerGate(
                  racer: _racer,
                  rivals: cup.rivalsOf(_bout),
                  onChoose: _chooseRacer,
                  flying: _flying,
                  landings: _landings,
                ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // The bout with friends, for a player who can (not the battle
            // ladder yet).
            if (!battle && rooms != null && rooms.available) ...[
              Expanded(
                child: BracketButton(
                  label: 'WITH FRIENDS',
                  palette: BracketPalette.dark,
                  accent: _brass,
                  primary: false,
                  height: 42,
                  enabled: open && !_starting,
                  onTap: _fightFriends,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: BracketButton(
                label: !open
                    ? 'LOCKED'
                    : (_starting ? 'STEPPING OUT…' : 'START'),
                palette: BracketPalette.dark,
                accent: _brass,
                height: 42,
                enabled:
                    open &&
                    !_starting &&
                    (battle ? _battleTeam.isNotEmpty : _racer != null),
                onTap: _startGem,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// A ladder round's two fours: the player's (tap to change them) and
  /// the round's set team, with the arena it is fought in.
  Widget _ladderGate(BuildContext context, GemBout bout) {
    final rival = _ladderTeam(bout);
    Widget label(String text, String trailing, {VoidCallback? onTap}) {
      final style = bracketText(
        context,
        10,
        _muted,
        weight: FontWeight.w800,
        letterSpacing: 1.6,
      );
      return Row(
        children: [
          Text(text, style: style),
          const Spacer(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                trailing,
                style: style.copyWith(color: onTap == null ? _muted : _brass),
              ),
            ),
          ),
        ],
      );
    }

    Widget row(
      List<CosmicPartyMember> team,
      double height, {
      bool rival = false,
    }) => Row(
      children: [
        for (var i = 0; i < kBattleTeamSize; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: rival ? null : _changeBattleTeam,
              child: i < team.length
                  ? BattleCase(member: team[i], height: height, rival: rival)
                  : BattleEmptyCase(height: height),
            ),
          ),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, box) {
        // Two rows of cases and their labels, the player's a little taller.
        final h = ((box.maxHeight - 66) / 1.9).clamp(64.0, 118.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            label('YOUR FOUR', 'CHANGE', onTap: _changeBattleTeam),
            const SizedBox(height: 4),
            row(_battleTeam, h),
            const Spacer(),
            label(
              'THEIR FOUR',
              battleArenaOf(bout.place).title.toUpperCase(),
            ),
            const SizedBox(height: 4),
            row(rival, h * 0.9, rival: true),
          ],
        );
      },
    );
  }

  /// [bout]'s set team, as it fights.
  List<CosmicPartyMember> _ladderTeam(GemBout bout) => _ladderTeams
      .putIfAbsent(
        bout.id,
        () => ladderTeamFor(context.read<CreatureCatalog>(), bout),
      );

  Future<void> _changeBattleTeam() async {
    if (_starting) return;
    HapticFeedback.selectionClick();
    final team = await pickBattleTeam(context, _battleTeam);
    if (team == null || !mounted) return;
    setState(() => _battleTeam = team);
  }

  /// A room for the bout on show, to ask friends into.
  Future<void> _fightFriends() async {
    if (_starting || _leaving || !_boutOpen) return;
    if (_gemDef.event == GemEvent.battle) return;
    HapticFeedback.selectionClick();
    await RaceLobbyScreen.host(context, cup: _gem, race: _bout, gem: true);
  }

  /// A gem cup's bout: the three set down on the island, or flown up the
  /// space course on the route the player plans; or a round of the battle
  /// ladder.
  Future<void> _startGem() async {
    if (_gemDef.event == GemEvent.battle) return _startLadder();
    final member = _racer;
    if (_starting || member == null || !_boutOpen) return;
    final cup = _gemDef;
    setState(() => _starting = true);
    HapticFeedback.mediumImpact();
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();
    final inst = await db.creatureDao.getInstance(member.instanceId);
    final gemIndex = _gem, bout = _bout;
    final frontier = bout == _progress.wonInGem(cup);
    final form = bout < cup.rivalForm.length ? cup.rivalForm[bout] : 1.0;
    final rivals = cup.rivalsOf(bout);
    final fighters = [
      racerFromMember(member, inst),
      for (final r in rivals) gemRivalRacer(r, form),
    ];
    final bodies = [
      RaceBody(member),
      for (final r in rivals) rivalBody(catalog, r),
    ];
    for (final b in bodies) {
      if (b.ticker == null) await b.load(Flame.images);
    }
    if (!mounted) return;
    // The space course: the player plans a way through first; the rivals
    // fly the ways that suit them.
    List<List<int>>? routes;
    if (cup.event == GemEvent.flight) {
      final course = flightCourseOf(cup.bouts[bout]);
      final mine = await planFlightRoute(
        context,
        title: cup.bouts[bout].name,
        subtitle:
            '${cup.name.toUpperCase()} · BOUT ${bout + 1} OF '
            '${cup.bouts.length} · PLAN YOUR ROUTE',
        course: course,
        racer: fighters.first,
      );
      if (!mounted) return;
      if (mine == null) {
        setState(() => _starting = false);
        return;
      }
      routes = [
        mine,
        for (final r in fighters.skip(1)) bestFlightRoute(r, course),
      ];
    }
    // What the element gates make of each flyer on its route, to fly on
    // as once it is through.
    final forms = routes == null
        ? null
        : flightForms(
            catalog,
            fighters,
            bodies,
            flightCourseOf(cup.bouts[bout]),
            routes,
          );
    for (final m in forms ?? const <Map<String, RaceBody>>[]) {
      for (final b in m.values) {
        if (b.ticker == null) await b.load(Flame.images);
      }
    }
    if (!mounted) return;
    setState(() => _starting = false);
    await Navigator.of(context).push<RaceOutcome>(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) => BoutSeries(
          cup: cup,
          bout: bout,
          fighters: fighters,
          bodies: bodies,
          stage: () => switch (cup.event) {
            GemEvent.flight => FlightStage(
              course: flightCourseOf(cup.bouts[bout]),
              fighters: fighters,
              bodies: bodies,
              player: 0,
              choices: routes!,
              forms: forms,
            ),
            _ => IslandStage(
              bout: islandBoutOf(cup.bouts[bout]),
              fighters: fighters,
              bodies: bodies,
              player: 0,
            ),
          },
          onFinished: (finish) => _payGem(cup, bout, finish),
        ),
        transitionsBuilder: (_, a, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
          child: child,
        ),
      ),
    );
    if (!mounted) return;
    await _afterGem(gemIndex, bout, frontier);
  }

  /// Back from a gem bout: the cups won shown, and a first win moves on to
  /// the cup's next bout (each cup keeps its own five).
  Future<void> _afterGem(int gemIndex, int bout, bool frontier) async {
    await _announce();
    if (!mounted || !frontier || _gem != gemIndex) return;
    if (_progress.wonInGem(kGemCups[gemIndex]) <= bout) return;
    setState(() => _bout = _firstOpenBout(gemIndex));
  }

  /// A round of the Emerald Cup's battle ladder: the player's four against
  /// the round's set team, in the round's own arena. Each fight's end is
  /// paid like any bout's: a win opens the next round, and its first pays.
  Future<void> _startLadder() async {
    if (_starting || _battleTeam.isEmpty || !_boutOpen) return;
    final cup = _gemDef;
    final gemIndex = _gem, bout = _bout;
    final frontier = bout == _progress.wonInGem(cup);
    final round = cup.bouts[bout];
    HapticFeedback.mediumImpact();
    await Navigator.of(context).push(
      BattleScreen.route(
        BattleScreen(
          team: _battleTeam,
          rival: _ladderTeam(round),
          rivalName: round.name.toUpperCase(),
          arena: round.place,
          leaveLabel: 'BACK TO THE TRIALS',
          onFinished: (winner, at) async {
            await _payGem(
              cup,
              bout,
              TrialsFinish(winner == 0 ? 1 : 2, winner == 0 ? at : null),
              by: _battleTeam.first,
            );
          },
        ),
      ),
    );
    if (!mounted) return;
    // The battle played its own music.
    unawaited(context.read<AudioController?>()?.playStadiumMusic());
    await _afterGem(gemIndex, bout, frontier);
  }

  /// A gem bout's end: any can set its record; a win opens the next, and
  /// its first win pays its gold, shards and tincture.
  Future<TrialsPayout> _payGem(
    GemCup cup,
    int bout,
    TrialsFinish finish, {
    CosmicPartyMember? by,
  }) async {
    final record = await _keepRecord(cup.bouts[bout].id, finish.mark, by: by);
    if (finish.place != 1) return TrialsPayout(record: record);
    final (next, first) = _progress.afterGemWin(cup, bout);
    if (!first || !mounted) return TrialsPayout(record: record);
    final gold = cup.gold[bout];
    final db = context.read<AlchemonsDatabase>();
    await db.currencyDao.addGold(gold);
    await _payFirstWin(db, cup.id, bout);
    if (!mounted) return TrialsPayout(gold: gold, record: record);
    setState(() => _progress = next);
    await _save();
    // The cup's last bout: what the cup gives, shown back on the shelf.
    _toAnnounce.addAll(await giveCupRewards(db, next));
    if (mounted) {
      final shop = context.read<ShopService?>();
      if (shop != null) await unlockCupStatEffects(shop, next);
    }
    _publish();
    return TrialsPayout(gold: gold, record: record);
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
                            _best(course.id) ?? 'WON',
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

  /// A friend's invitation waiting: who, which course, DECLINE and JOIN.
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
                  '${room.placeName.toUpperCase()}',
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
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.read<RaceRoomService>().decline(room);
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                  child: Text(
                    'DECLINE',
                    style: bracketText(
                      context,
                      10.5,
                      _muted,
                      weight: FontWeight.w800,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
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
