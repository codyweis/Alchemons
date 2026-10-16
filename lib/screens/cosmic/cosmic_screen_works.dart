part of 'cosmic_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  THE WORKS, as the cosmic screen runs it
//
//  The state lives here (WorksState, saved to prefs) and is caught up to the
//  wall clock every few seconds and whenever space opens: deliveries land in
//  home storage, pressed silver in the wallet, finds in the bay's crates.
//  The game draws the same state (cosmic_game_works.dart); WorksPanel and
//  OutpostPanel read it through [_worksView] and act through
//  [_WorksActionsImpl].
//
//  Teaching, kept short and shown once: coach marks on the home base, then
//  its WORKS button, then OUTPOST at the first found planet without an
//  extractor; one line when the Works first open, and each building's own
//  few pages (works_tutorials.dart) the first time one is built. The ?
//  beside a building's name opens them again.
// ─────────────────────────────────────────────────────────────────────────────

const String _worksPrefsKey = 'cosmic_works_v1';
const String _worksIntroSeenKey = 'cosmic_works_intro_seen_v1';

/// The buildings whose tutorial has been shown, by [WorksBuilding.name].
const String _worksTaughtKey = 'cosmic_works_taught_v1';
const String _worksCoachDoneKey = 'cosmic_works_coach_done_v1';
const String _outpostCoachDoneKey = 'cosmic_outpost_coach_done_v1';

/// How often the works are caught up while space is open.
const Duration _worksTickEvery = Duration(seconds: 4);

/// How often what the works made is written down while space is open.
/// Saving rewrites the whole prefs file, and pressed silver is a database
/// write, so the ticks between only add up; leaving space writes at once.
const int _worksSaveEveryTicks = 8;

const List<StoryBeat> _worksIntroBeats = [
  StoryBeat(
    title: 'THE WORKS',
    message:
        'Buildings your Alchemons run. They keep working while you are away.',
  ),
];

/// [WorksActions] for the panels, answered by the screen.
class _WorksActionsImpl implements WorksActions {
  _WorksActionsImpl(this.s);
  final _CosmicScreenState s;

  @override
  Future<void> build(WorksBuilding b, {String? element}) =>
      s._worksBuild(b, element: element);

  @override
  Future<void> upgrade(WorksBuilding b, {String? element}) =>
      s._worksUpgrade(b, element: element);

  @override
  Future<void> assign(WorkSlotRef slot) => s._worksAssign(slot);

  @override
  Future<void> clear(WorkSlotRef slot) => s._worksClear(slot);

  @override
  void collectCrates() => s._worksCollectCrates();

  @override
  void sendHome(String element) => s._worksSendHome(element);

  @override
  void setReserve(int reserve) => s._worksSetReserve(reserve);

  @override
  void setRecipe(String? recipe) => s._worksSetRecipe(recipe);

  @override
  void openArmory() => s._openArmory();

  @override
  Future<void> openCodex() => s._openCodex();

  @override
  Future<void> dismantle(WorksBuilding b) => s._worksDismantle(b);

  @override
  void setRefineKeep(int keep) => s._worksSetRefineKeep(keep);

  @override
  Future<void> openOutpost(String element) => s._openOutpost(element);
}

extension _CosmicWorks on _CosmicScreenState {
  /// The Works need a home: the bay and the press stand beside it, and
  /// everything they make is stored there.
  bool get _worksAvailable => !widget.memoryTutorial && _homePlanet != null;

  int get _nowMs => DateTime.now().millisecondsSinceEpoch;

  /// A word back from the Works. The Works' panels stand over the space
  /// screen, whose own quote line would be hidden under them, so this goes
  /// on the app's top layer.
  void _worksSay(String message) {
    if (!mounted) return;
    showGameSnack(context, message, accent: CosmicScreenStyles.amberBright);
  }

  // ── load, catch up, save ─────────────────────────────────────────────────

  Future<void> _initWorks() async {
    if (widget.memoryTutorial) return;
    _worksDb;
    final prefs = await SharedPreferences.getInstance();
    _works = WorksState.deserialise(prefs.getString(_worksPrefsKey));
    _worksCoachDone = prefs.getBool(_worksCoachDoneKey) ?? false;
    _outpostCoachDone = prefs.getBool(_outpostCoachDoneKey) ?? false;
    await _refreshWorkers();
    if (!mounted) return;
    unawaited(_refreshWalletCurrencies());
    unawaited(_refreshKnownRecipes());
    _tickWorks(announce: true);
    _worksTimer?.cancel();
    _worksTimer = Timer.periodic(_worksTickEvery, (_) => _tickWorks());
  }

  /// Reads every Alchemon at work: its profile for the job maths and its
  /// look for space. One that is gone (fused, released) leaves its job.
  Future<void> _refreshWorkers() async {
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();
    final profiles = <String, WorkerProfile>{};
    final members = <String, CosmicPartyMember>{};
    var dropped = false;
    for (final id in _works.workerIds) {
      final inst = await db.creatureDao.getInstance(id);
      if (inst == null) {
        _works.release(id);
        dropped = true;
        continue;
      }
      final base = catalog.getCreatureById(inst.baseId);
      final member = cosmicMemberFromInstance(inst, base, slotIndex: 0);
      members[id] = member;
      profiles[id] = workerProfileOf(inst, member.element);
    }
    if (!mounted) return;
    _workerProfiles = profiles;
    _workerMembers = members;
    _game?.works = _works;
    _game?.setWorksMembers(members);
    if (dropped) unawaited(_saveWorks());
    _publishWorksView();
  }

  /// Brings the works up to now. [announce] says what they did while space
  /// was shut, in one line.
  void _tickWorks({bool announce = false}) {
    if (!mounted || widget.memoryTutorial) return;
    final game = _game;
    if (game == null) return;
    game.works = _works;
    if (_homePlanet == null || _works.isEmpty) {
      _publishWorksView();
      return;
    }
    final report = advanceWorks(
      _works,
      nowMs: _nowMs,
      storage: _elementStorage.stored,
      workers: _workerProfiles,
      distanceHome: game.worksDistanceHome,
      scavengeElements: game.scavengeElements,
    );
    _worksTicks++;
    if (report.silver > 0) {
      // Held until the next save, and shown at once without rebuilding the
      // whole screen for it.
      _worksSilverPending += report.silver;
      _walletCurrencies = {
        ..._walletCurrencies,
        'silver': (_walletCurrencies['silver'] ?? 0) + report.silver,
      };
      if (!announce) game.playSilverPressed();
    }
    _updatePressIntake();
    if (!report.isEmpty) _worksDirty = true;
    if (announce || _worksTicks % _worksSaveEveryTicks == 0) {
      unawaited(_saveWorks());
    }
    if (announce &&
        (report.deliveredUnits >= 1 ||
            report.finds > 0 ||
            report.refinedUnits >= 1 ||
            report.silver > 0)) {
      _showQuote(_awayLine(report));
    }
    _publishWorksView();
  }

  String _awayLine(WorksReport r) {
    final parts = <String>[
      if (r.deliveredUnits >= 1)
        '${r.deliveredUnits.round()} elements came home',
      if (r.finds > 0)
        '${r.finds} ${r.finds == 1 ? 'find' : 'finds'} in the bay',
      if (r.refinedUnits >= 1) '${r.refinedUnits.round()} refined',
      if (r.silver > 0) '${r.silver} silver pressed',
    ];
    return 'While you were away: ${parts.join(', ')}.';
  }

  /// The colours going under the press: what storage holds over its reserve.
  void _updatePressIntake() {
    final press = _works.press;
    final presser = press.presser;
    final intake = <Color>[];
    if (press.built && presser != null && _workerProfiles[presser] != null) {
      final over =
          _elementStorage.stored.entries
              .where((e) => e.value > press.reserve + 0.5)
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));
      intake.addAll(over.take(4).map((e) => elementColor(e.key)));
    }
    _game?.worksPressIntake = intake;

    // The Refinery works while it has a refiner and both inputs to spare.
    final r = _works.refinery;
    final parts = r.parts;
    _game?.worksRefining =
        r.built &&
        parts != null &&
        r.refiner != null &&
        _workerProfiles[r.refiner] != null &&
        (_elementStorage.stored[parts.$1] ?? 0) > r.keep + 0.5 &&
        (_elementStorage.stored[parts.$2] ?? 0) > r.keep + 0.5;
  }

  /// Saves the works with what they made since the last save: the silver
  /// pressed and, when deliveries or the refinery changed it, storage. All
  /// at once, so a game killed between saves catches up again from the last
  /// one rather than losing or doubling anything.
  Future<void> _saveWorks() async {
    if (widget.memoryTutorial) return;
    final silver = _worksSilverPending;
    _worksSilverPending = 0;
    final dirty = _worksDirty;
    _worksDirty = false;
    if (silver > 0) await _worksDb.currencyDao.addSilver(silver);
    final prefs = await SharedPreferences.getInstance();
    if (dirty) {
      await prefs.setString(
        _elementStoragePrefsKey,
        _elementStorage.serialise(),
      );
    }
    await prefs.setString(_worksPrefsKey, _works.serialise());
  }

  /// The found planet the ship is at, if any: its extractor is built and
  /// sent home from anywhere in its field, not only beside the rig.
  String? get _worksPlanetHere {
    final near = _nearPlanet;
    return near != null && near.discovered ? near.element : null;
  }

  WorksView _makeWorksView() {
    final game = _game;
    final here = _worksPlanetHere;
    return WorksView(
      works: _works,
      profiles: _workerProfiles,
      members: _workerMembers,
      storage: Map.of(_elementStorage.stored),
      hold: Map.of(game?.meter.breakdown ?? const {}),
      silver: _walletCurrencies['silver'] ?? 0,
      planetsFound: game?.scavengeElements ?? const [],
      distanceHome: (e) => game?.worksDistanceHome(e) ?? 8000,
      nowMs: _nowMs,
      nearRig: here != null && _works.extractors.containsKey(here)
          ? here
          : null,
      atPlanet: here,
      berthCount: _berthCount,
      knownRecipes: _knownRecipes,
      shipSkin: _customizationState.activeShipSkin,
    );
  }

  void _publishWorksView() {
    if (!mounted) return;
    _worksView.value = _makeWorksView();
  }

  // ── opening the panels ───────────────────────────────────────────────────

  Future<void> _openWorks() async {
    if (!_worksAvailable) return;
    if (_worksCoachButton) _finishWorksCoach();
    await _refreshWalletCurrencies();
    await _refreshKnownRecipes();
    _tickWorks();
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final introSeen = prefs.getBool(_worksIntroSeenKey) ?? false;
    if (!mounted) return;
    final open = showStationPanel<void>(
      context,
      WorksPanel(view: _worksView, actions: _worksActions),
    );
    if (!introSeen) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      await _showWorksIntro();
      await prefs.setBool(_worksIntroSeenKey, true);
    }
    await open;
  }

  Future<void> _showWorksIntro() async {
    await showStoryDialog(context, beats: _worksIntroBeats, primaryLabel: 'OK');
  }

  Future<void> _openOutpost(String element) async {
    if (!_worksAvailable) return;
    if (_outpostCoach) _finishOutpostCoach();
    await _refreshWalletCurrencies();
    _tickWorks();
    if (!mounted) return;
    await showStationPanel<void>(
      context,
      OutpostPanel(element: element, view: _worksView, actions: _worksActions),
    );
  }

  // ── building ─────────────────────────────────────────────────────────────

  /// Berths round home, by the largest size unlocked.
  int get _berthCount => homeBerthsForTier(_homePlanet?.sizeTierLevel ?? 0);

  Future<void> _worksBuild(WorksBuilding b, {String? element}) async {
    if (b == WorksBuilding.extractor) {
      if (element != null) await _buildExtractor(element);
      return;
    }
    if (_works.berths.containsKey(b)) return;
    final berth = _works.freeBerth(_berthCount);
    if (berth == null) {
      _worksSay('No free slots. A bigger planet has more.');
      return;
    }
    final name = _worksName(b);
    final ok = await _payWorksCost(worksCost(b, 1), title: 'BUILD THE $name?');
    if (!ok || !mounted) return;
    _tickWorks();
    switch (b) {
      case WorksBuilding.scavengerBay:
        _works.bay
          ..tier = 1
          ..fitSlots();
      case WorksBuilding.silverPress:
        _works.press
          ..tier = 1
          ..updatedMs = _nowMs;
      case WorksBuilding.refinery:
        _works.refinery
          ..tier = 1
          ..updatedMs = _nowMs;
      case WorksBuilding.armory:
        _works.armory.tier = 1;
      case WorksBuilding.extractor:
        return;
    }
    _works.setBerth(b, berth);
    HapticFeedback.heavyImpact();
    _worksSay('${_worksTitle(b)} built.');
    await _saveWorks();
    _publishWorksView();
    await _teachWorksBuilding(b);
  }

  /// [b]'s tutorial, the first time one is built.
  Future<void> _teachWorksBuilding(WorksBuilding b, {String? element}) async {
    final prefs = await SharedPreferences.getInstance();
    final taught = prefs.getStringList(_worksTaughtKey) ?? const <String>[];
    if (taught.contains(b.name) || !mounted) return;
    await prefs.setStringList(_worksTaughtKey, [...taught, b.name]);
    if (!mounted) return;
    await showWorksTutorial(context, b, element: element);
  }

  /// [b]'s name as a sentence says it.
  String _worksTitle(WorksBuilding b) => switch (b) {
    WorksBuilding.scavengerBay => 'Scavenger Bay',
    WorksBuilding.silverPress => 'Silver Press',
    WorksBuilding.refinery => 'Refinery',
    WorksBuilding.armory => 'Armory',
    WorksBuilding.extractor => 'Extractor',
  };

  String _worksName(WorksBuilding b) => switch (b) {
    WorksBuilding.scavengerBay => 'SCAVENGER BAY',
    WorksBuilding.silverPress => 'SILVER PRESS',
    WorksBuilding.refinery => 'REFINERY',
    WorksBuilding.armory => 'ARMORY',
    WorksBuilding.extractor => 'EXTRACTOR',
  };

  /// The Codex, over the Works: the recipes found are the Refinery's.
  Future<void> _openCodex() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AlchemicalEncyclopediaScreen(),
      ),
    );
    if (mounted) await _refreshKnownRecipes();
  }

  /// Opens the Armory: the Works panel gives way to it, and BACK returns to
  /// the home base window.
  void _openArmory() {
    if (!_works.armory.built) return;
    Navigator.of(context).maybePop();
    _labMode = LabMode.armory;
    _openSubPanel(_CosmicPanel.home, () {
      _showHomeMenu = false;
      _showCustomizationMenu = true;
    });
  }

  /// Takes a home building down to free its berth, after asking.
  Future<void> _worksDismantle(WorksBuilding b) async {
    if (!_works.berths.containsKey(b)) return;
    final ok = await showBracketConfirm(
      context,
      palette: panelPalette,
      accent: CosmicScreenStyles.danger,
      title: 'TAKE DOWN THE ${_worksName(b)}?',
      message: b == WorksBuilding.armory
          ? 'Frees its slot. The ship keeps its upgrades.'
          : 'Frees its slot. Nothing is refunded.',
      confirmLabel: 'TAKE DOWN',
    );
    if (!ok || !mounted) return;
    _tickWorks();
    if (b == WorksBuilding.scavengerBay && _works.bay.crates.isNotEmpty) {
      _worksCollectCrates();
    }
    _works.dismantle(b);
    HapticFeedback.heavyImpact();
    _worksSay('${_worksTitle(b)} taken down.');
    await _refreshWorkers();
    await _saveWorks();
    _updatePressIntake();
    _publishWorksView();
    _rebuild();
  }

  Future<void> _buildExtractor(String element) async {
    final game = _game;
    if (game == null || _works.extractors.containsKey(element)) return;
    if (_worksPlanetHere != element) {
      _worksSay('Fly to ${planetName(element)} to build its extractor.');
      return;
    }
    const need = WorkRules.extractorBuildUnits;
    final have = game.meter.breakdown[element] ?? 0;
    if (have + 1e-6 < need) {
      _worksSay('Your cargo needs $need $element to build here.');
      return;
    }
    final ok = await showBracketConfirm(
      context,
      palette: panelPalette,
      accent: elementInk(element),
      title: 'BUILD AN EXTRACTOR?',
      message: 'It takes $need $element from your cargo.',
      confirmLabel: 'BUILD',
    );
    if (!ok || !mounted) return;
    game.meter.take(element, need.toDouble());
    game.onMeterChanged();
    _works.extractors[element] = ExtractorState(
      element: element,
      updatedMs: _nowMs,
    );
    game.works = _works;
    game.playHoldToRig(element);
    HapticFeedback.heavyImpact();
    await _saveWorks();
    _publishWorksView();
    if (_outpostCoach) _finishOutpostCoach();
    _rebuild();
    await _teachWorksBuilding(WorksBuilding.extractor, element: element);
  }

  Future<void> _worksUpgrade(WorksBuilding b, {String? element}) async {
    final int tier;
    switch (b) {
      case WorksBuilding.extractor:
        final x = element == null ? null : _works.extractors[element];
        if (x == null) return;
        tier = x.tier;
      case WorksBuilding.scavengerBay:
        tier = _works.bay.tier;
      case WorksBuilding.silverPress:
        tier = _works.press.tier;
      case WorksBuilding.refinery:
        tier = _works.refinery.tier;
      case WorksBuilding.armory:
        tier = _works.armory.tier;
    }
    if (tier <= 0 || tier >= WorkRules.maxTier) return;
    final ok = await _payWorksCost(
      worksCost(b, tier + 1, element: element),
      title: 'UPGRADE TO TIER ${tier + 1}?',
    );
    if (!ok || !mounted) return;
    _tickWorks();
    switch (b) {
      case WorksBuilding.extractor:
        _works.extractors[element]!
          ..tier = tier + 1
          ..fitSlots();
      case WorksBuilding.scavengerBay:
        _works.bay
          ..tier = tier + 1
          ..fitSlots();
      case WorksBuilding.silverPress:
        _works.press.tier = tier + 1;
      case WorksBuilding.refinery:
        _works.refinery.tier = tier + 1;
      case WorksBuilding.armory:
        _works.armory.tier = tier + 1;
    }
    HapticFeedback.heavyImpact();
    _worksSay('Upgraded to tier ${tier + 1}.');
    _tickWorks();
    await _saveWorks();
    _publishWorksView();
  }

  /// Asks, then takes [cost] from storage and the wallet. False when it
  /// cannot be paid or the player says no.
  Future<bool> _payWorksCost(WorksCost cost, {required String title}) async {
    final db = context.read<AlchemonsDatabase>();
    final plan = elementsForCost(cost, _elementStorage.stored);
    if (plan == null) {
      _worksSay('Not enough in storage.');
      return false;
    }
    // Pressed silver not yet saved is banked first, so it can be spent.
    if (cost.silver > 0) await _saveWorks();
    final silver = await db.currencyDao.getSilverBalance();
    if (silver < cost.silver) {
      _worksSay('Not enough silver.');
      return false;
    }
    if (!mounted) return false;
    final takes = plan.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final ok = await showBracketConfirm(
      context,
      palette: panelPalette,
      accent: CosmicScreenStyles.amberBright,
      title: title,
      message: takes.isEmpty
          ? 'Paid in silver.'
          : 'Takes ${takes.map((e) => '${e.value} ${e.key}').join(', ')} '
                'from storage.',
      amounts: cost.silver > 0 ? [(CoinKind.silver, cost.silver)] : const [],
      amountsLabel: 'YOU PAY',
      confirmLabel: 'BUILD',
    );
    if (!ok || !mounted) return false;
    if (cost.silver > 0 && !await db.currencyDao.spendSilver(cost.silver)) {
      _worksSay('Not enough silver.');
      return false;
    }
    for (final e in plan.entries) {
      _elementStorage.stored[e.key] =
          (_elementStorage.stored[e.key] ?? 0) - e.value;
    }
    _elementStorage.stored.removeWhere((_, v) => v <= 0.01);
    _saveElementStorage();
    await _refreshWalletCurrencies();
    return true;
  }

  // ── workers ──────────────────────────────────────────────────────────────

  String? _occupant(WorkSlotRef slot) {
    switch (slot.job) {
      case WorkJob.miner:
        final x = _works.extractors[slot.element];
        if (x == null || slot.index >= x.miners.length) return null;
        return x.miners[slot.index];
      case WorkJob.courier:
        return _works.extractors[slot.element]?.courier;
      case WorkJob.scavenger:
        final slots = _works.bay.slots;
        return slot.index < slots.length ? slots[slot.index].instanceId : null;
      case WorkJob.presser:
        return _works.press.presser;
      case WorkJob.refiner:
        return _works.refinery.refiner;
    }
  }

  Future<void> _worksAssign(WorkSlotRef slot) async {
    final game = _game;
    if (game == null) return;
    final blocked = <String, String>{
      for (final m in _partyMembers.whereType<CosmicPartyMember>())
        m.instanceId: 'IN PARTY',
      for (final m in _garrisonMembers.whereType<CosmicPartyMember>())
        m.instanceId: 'GARRISON',
    };
    final atWork = <String, String>{
      for (final id in _works.workerIds)
        id: () {
          final j = _works.jobOf(id);
          if (j == null) return 'AT WORK';
          return j.$2 == null
              ? j.$1.label
              : '${j.$1.label} · ${j.$2!.toUpperCase()}';
        }(),
    };
    final id = await showStationPanel<String>(
      context,
      WorkerPicker(
        job: slot.job,
        element: slot.job == WorkJob.miner ? slot.element : null,
        distance: slot.element == null
            ? 0
            : game.worksDistanceHome(slot.element!),
        pressTier: _works.press.tier,
        refineTier: _works.refinery.tier,
        blocked: blocked,
        atWork: atWork,
        current: _occupant(slot),
      ),
    );
    if (id == null || !mounted) return;
    await _assignWorker(slot, id);
  }

  Future<void> _assignWorker(WorkSlotRef slot, String id) async {
    if (_partyMembers.any((m) => m?.instanceId == id) ||
        _garrisonMembers.any((m) => m?.instanceId == id)) {
      _worksSay('That Alchemon is with your ship or garrison.');
      return;
    }
    _tickWorks();
    final storage = _elementStorage.stored;
    // Off its old job; a courier mid-run lands what it carries.
    final was = _works.jobOf(id);
    if (was != null && was.$1 == WorkJob.courier) {
      final x = _works.extractors[was.$2];
      if (x != null) endCourierRun(x, storage);
    }
    _works.release(id);
    switch (slot.job) {
      case WorkJob.miner:
        final x = _works.extractors[slot.element];
        if (x == null || slot.index >= x.miners.length) return;
        x.miners[slot.index] = id;
      case WorkJob.courier:
        final x = _works.extractors[slot.element];
        if (x == null || !WorkRules.hasCourier(x.tier)) return;
        endCourierRun(x, storage);
        x.courier = id;
      case WorkJob.scavenger:
        final slots = _works.bay.slots;
        if (slot.index >= slots.length) return;
        slots[slot.index]
          ..instanceId = id
          ..tripStartMs = 0;
      case WorkJob.presser:
        _works.press
          ..presser = id
          ..updatedMs = _nowMs;
      case WorkJob.refiner:
        _works.refinery
          ..refiner = id
          ..updatedMs = _nowMs;
    }
    HapticFeedback.mediumImpact();
    await _refreshWorkers();
    if (!mounted) return;
    _tickWorks();
    _saveElementStorage();
    await _saveWorks();
    _rebuild();
  }

  Future<void> _worksClear(WorkSlotRef slot) async {
    final id = _occupant(slot);
    if (id == null) return;
    _tickWorks();
    if (slot.job == WorkJob.courier) {
      final x = _works.extractors[slot.element];
      if (x != null) endCourierRun(x, _elementStorage.stored);
    }
    _works.release(id);
    HapticFeedback.selectionClick();
    await _refreshWorkers();
    if (!mounted) return;
    _saveElementStorage();
    await _saveWorks();
    _rebuild();
  }

  // ── collecting ───────────────────────────────────────────────────────────

  void _worksCollectCrates() {
    _tickWorks();
    final bay = _works.bay;
    if (bay.crates.isEmpty) return;
    final colors = <Color>{
      for (final c in bay.crates)
        for (final e in c.elements.keys) elementColor(e),
    }.toList();
    final (got, shards) = collectCrates(
      bay,
      _elementStorage.stored,
      nowMs: _nowMs,
      workers: _workerProfiles,
    );
    if (shards > 0 && _homePlanet != null) {
      _homePlanet!.astralBank += shards;
      unawaited(_saveHomePlanet());
    }
    _saveElementStorage();
    unawaited(_saveWorks());
    _game?.playCratesEmptied(colors);
    HapticFeedback.mediumImpact();
    final units = got.values.fold(0, (s, v) => s + v);
    _worksSay(
      'Collected $units elements'
      '${shards > 0 ? ' and $shards astral shards' : ''}.',
    );
    _publishWorksView();
    _rebuild();
  }

  void _worksSendHome(String element) {
    final game = _game;
    if (game == null || _worksPlanetHere != element) {
      _worksSay('Fly to ${planetName(element)} to send its hopper home.');
      return;
    }
    _tickWorks();
    final x = _works.extractors[element];
    if (x == null || x.hopper < 1) return;
    final units = x.hopper;
    _elementStorage.stored[element] =
        (_elementStorage.stored[element] ?? 0) + units;
    x.hopper = 0;
    _saveElementStorage();
    unawaited(_saveWorks());
    game.playHopperSentHome(element);
    HapticFeedback.mediumImpact();
    _worksSay('Sent ${units.floor()} $element home.');
    _publishWorksView();
  }

  void _worksSetReserve(int reserve) {
    if (_works.press.reserve == reserve) return;
    _tickWorks();
    _works.press.reserve = reserve;
    HapticFeedback.selectionClick();
    unawaited(_saveWorks());
    _updatePressIntake();
    _publishWorksView();
  }

  void _worksSetRecipe(String? recipe) {
    final r = _works.refinery;
    if (r.recipe == recipe) return;
    if (recipe != null && !_knownRecipes.contains(recipe)) return;
    _tickWorks();
    r.recipe = recipe;
    HapticFeedback.selectionClick();
    unawaited(_saveWorks());
    _updatePressIntake();
    _publishWorksView();
  }

  void _worksSetRefineKeep(int keep) {
    if (_works.refinery.keep == keep) return;
    _tickWorks();
    _works.refinery.keep = keep;
    HapticFeedback.selectionClick();
    unawaited(_saveWorks());
    _updatePressIntake();
    _publishWorksView();
  }

  /// Which Refinery recipes the Codex has found: an outcome made by fusing,
  /// in either order of its pair.
  Future<void> _refreshKnownRecipes() async {
    final db = context.read<AlchemonsDatabase>();
    final found = await AlchemicalEncyclopediaService.loadFoundElementOutcomes(
      db,
    );
    if (!mounted) return;
    _knownRecipes = {
      for (final e in WorkRules.refineRecipes.entries)
        if (() {
          final ab = e.key.split('+');
          return found.contains('${ab[0]}+${ab[1]}::${e.value}') ||
              found.contains('${ab[1]}+${ab[0]}::${e.value}');
        }())
          e.key,
    };
    _publishWorksView();
  }

  // ── teaching ─────────────────────────────────────────────────────────────

  /// The home base is showing and nothing else is teaching: point at it once
  /// so the Works are found. Called from build; lands next frame.
  void _maybeStartWorksCoach({required bool homeActionsShowing}) {
    if (_worksCoachDone || _worksCoachHome || _worksCoachButton) return;
    if (!homeActionsShowing || !_worksAvailable) return;
    if (!_homeTourDone || _homeTourStep != null) return;
    if (_runningCosmicIntro ||
        _awaitingShipMenuTap ||
        _awaitingBuildHomeTap ||
        _awaitingSurvivalMapTap ||
        _survivalSignalTutorialActive ||
        _anyOverlayOpen) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _worksCoachDone || _worksCoachHome) return;
      _worksCoachHome = true;
      _rebuild();
    });
  }

  /// The home base button was tapped while the coach pointed at it: now
  /// point at WORKS inside.
  void _advanceWorksCoach() {
    if (!_worksCoachHome) return;
    _worksCoachHome = false;
    _worksCoachButton = true;
  }

  void _finishWorksCoach() {
    _worksCoachHome = false;
    _worksCoachButton = false;
    _worksCoachDone = true;
    unawaited(
      SharedPreferences.getInstance().then(
        (p) => p.setBool(_worksCoachDoneKey, true),
      ),
    );
  }

  /// The OUTPOST button is showing at a found planet with nothing built:
  /// point at it once.
  void _maybeStartOutpostCoach({required bool outpostShowing}) {
    if (_outpostCoachDone || _outpostCoach || !outpostShowing) return;
    if (!_worksCoachDone || _anyOverlayOpen) return;
    final near = _nearPlanet;
    if (near == null || _works.extractors.containsKey(near.element)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _outpostCoachDone || _outpostCoach) return;
      _outpostCoach = true;
      _rebuild();
    });
  }

  void _finishOutpostCoach() {
    _outpostCoach = false;
    _outpostCoachDone = true;
    unawaited(
      SharedPreferences.getInstance().then(
        (p) => p.setBool(_outpostCoachDoneKey, true),
      ),
    );
  }
}

/// [inst] as the space screen describes an Alchemon: its look, its element
/// and family, its stats as stored.
CosmicPartyMember cosmicMemberFromInstance(
  CreatureInstance inst,
  Creature? base, {
  required int slotIndex,
  double Function(String stat, double value)? bonus,
  int staminaBars = 3,
}) {
  double stat(String name, double v) => bonus == null ? v : bonus(name, v);
  return CosmicPartyMember(
    instanceId: inst.instanceId,
    baseId: inst.baseId,
    displayName: inst.nickname ?? base?.name ?? inst.baseId,
    imagePath: base?.image != null ? 'assets/images/${base!.image}' : null,
    element: (base?.types.isNotEmpty ?? false) ? base!.types.first : 'Earth',
    family: base?.mutationFamily ?? 'kin',
    level: inst.level,
    statSpeed: stat('speed', inst.statSpeed),
    statIntelligence: stat('intelligence', inst.statIntelligence),
    statStrength: stat('strength', inst.statStrength),
    statBeauty: stat('beauty', inst.statBeauty),
    statSpeedPotential: inst.statSpeedPotential,
    statIntelligencePotential: inst.statIntelligencePotential,
    statStrengthPotential: inst.statStrengthPotential,
    statBeautyPotential: inst.statBeautyPotential,
    slotIndex: slotIndex,
    staminaBars: staminaBars,
    staminaMax: inst.staminaMax,
    spriteSheet: base?.spriteData != null ? sheetFromCreature(base!) : null,
    spriteVisuals: visualsFromInstance(base, inst),
  );
}
