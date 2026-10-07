// lib/screens/pureblood_rite_screen.dart
//
// THE PUREBLOOD RITE: twenty offerings of an unbroken bloodline, each asked
// for by name, then one a week. Everything is given to a pool of blood
// (pureblood_rite/rite_pool.dart) that the screen stands over — the one
// home's RITE emblem falls into on the way in, in the same place.
//
// Top to bottom: the pool with the vessel over it (the specimen asked for, a
// ghost, until one is placed in the chamber; the pool brightens for a worthy
// one), the rite asked for and the ladder of twenty, what the altar asks, how
// many you have, the chamber, and the rite after this one. Performing it is
// held, as every rite at the Mystic Altar is; what it does is
// pureblood_rite/rite_offering.dart.
//
// The altar's own words and buttons (altar_chrome.dart): dark, monospace
// labels, plain panels.

import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/screens/alchemical_encyclopedia_screen.dart';
import 'package:alchemons/screens/mystic_altar/altar_chrome.dart';
import 'package:alchemons/screens/mystic_altar/altar_grains.dart';
import 'package:alchemons/screens/pureblood_rite/rite_offering.dart';
import 'package:alchemons/screens/pureblood_rite/rite_pool.dart';
import 'package:alchemons/screens/pureblood_rite/rite_stage.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/pureblood_rite_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/all_specimens_page.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:alchemons/widgets/story_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

const BracketPalette _palette = altarPalette;

/// The rite's accents: blood for what it asks, gold for what it gives, the
/// souls' blue for what you have that it would take.
final Color _blood = RitePool.blood[3];
const Color _gold = AltarTone.gold;
const Color _soul = RitePool.soulBlue;

class PurebloodRiteScreen extends StatefulWidget {
  const PurebloodRiteScreen({super.key});

  @override
  State<PurebloodRiteScreen> createState() => _PurebloodRiteScreenState();
}

class _PurebloodRiteScreenState extends State<PurebloodRiteScreen> {
  static const _introStorySeenKey = 'pureblood_rite_story_intro_seen_v1';
  static const _completionStorySeenKey =
      'pureblood_rite_story_completion_seen_v1';

  int? _stageIndex;
  String? _selectedInstanceId;
  String? _busyInstanceId;
  bool _checkedIntroStory = false;

  // The weekly offering, once the twenty are given.
  bool? _weeklyCompleted;
  String? _weeklySelectedInstanceId;
  String? _weeklyBusyInstanceId;

  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadStageProgress();
    _loadWeeklyStatus();
    _maybeShowIntroStory();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  PurebloodRiteService get _rite => PurebloodRiteService(
    context.read<AlchemonsDatabase>(),
    context.read<CreatureCatalog>(),
  );

  Future<void> _loadStageProgress() async {
    final idx = await _rite.getStageIndex();
    if (mounted) setState(() => _stageIndex = idx);
  }

  Future<void> _loadWeeklyStatus() async {
    final completed = await _rite.isWeeklyComplete();
    if (mounted) setState(() => _weeklyCompleted = completed);
  }

  Future<void> _maybeShowIntroStory() async {
    if (_checkedIntroStory) return;
    _checkedIntroStory = true;
    final db = context.read<AlchemonsDatabase>();
    final seen = await db.settingsDao.getSetting(_introStorySeenKey) == '1';
    if (seen || !mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await showStoryDialog(
      context,
      beats: const [
        StoryBeat(
          title: 'THE PUREBLOOD RITE',
          message: '',
          voice:
              '"Humankind cannot gain anything without first giving something '
              'in return. To obtain, something of equal value must be lost."',
        ),
      ],
    );
    if (!mounted) return;
    await db.settingsDao.setSetting(_introStorySeenKey, '1');
  }

  Future<void> _maybeShowCompletionStory() async {
    final db = context.read<AlchemonsDatabase>();
    final seen =
        await db.settingsDao.getSetting(_completionStorySeenKey) == '1';
    if (seen || !mounted) return;
    await showStoryDialog(
      context,
      beats: const [
        StoryBeat(
          title: 'no one can rewrite the stars',
          message: '',
          voice: 'but what if we created them',
        ),
      ],
    );
    if (!mounted) return;
    await db.settingsDao.setSetting(_completionStorySeenKey, '1');
  }

  Future<void> _unlockCompletionShopEffect() async {
    final shop = context.read<ShopService>();
    final unlockedName = await shop.unlockContestEffectOffer(
      ShopService.ritualGoldEffectOfferId,
      freeQty: 0,
    );
    if (!mounted || unlockedName == null) return;
    showGameSnack(
      context,
      '$unlockedName unlocked in the shop to buy.',
      accent: _gold,
    );
  }

  void _openEncyclopedia() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AlchemicalEncyclopediaScreen()),
    );
  }

  /// Plays the offering, and while it covers the screen puts the page back
  /// at the top, so it closes on the pool and what the rite asks for next.
  Future<void> _offer(Future<void> offering) async {
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
    });
    await offering;
    if (mounted && _scroll.hasClients && _scroll.offset > 0) {
      await _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  // ── choosing and giving ───────────────────────────────────────────────────

  Future<CreatureInstance?> _pick(String? current) {
    final theme = context.read<FactionTheme>();
    return Navigator.of(context).push<CreatureInstance>(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, _, _) => AllSpecimensPage(
          theme: theme,
          instancePrefsScopeKey: 'pureblood_rite_specimens',
          popOnSelect: true,
          title: 'PLACE SPECIMEN',
          selectedInstanceIds: current == null ? const [] : [current],
        ),
        transitionsBuilder: (context, animation, _, child) => SlideTransition(
          position: animation.drive(
            Tween(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic)),
          ),
          child: child,
        ),
      ),
    );
  }

  Future<void> _place({
    required PurebloodChallenge challenge,
    required bool weekly,
  }) async {
    final selected = await _pick(
      weekly ? _weeklySelectedInstanceId : _selectedInstanceId,
    );
    if (selected == null || !mounted) return;
    final check = _rite.evaluate(selected, challenge: challenge);
    setState(() {
      if (weekly) {
        _weeklySelectedInstanceId = selected.instanceId;
      } else {
        _selectedInstanceId = selected.instanceId;
      }
    });
    if (!check.isEligible) {
      showGameSnack(context, check.message, accent: _blood);
    }
  }

  Future<void> _perform({
    required PurebloodChallenge challenge,
    required Creature species,
    required CreatureInstance instance,
    required bool weekly,
  }) async {
    if (_busyInstanceId != null || _weeklyBusyInstanceId != null) return;
    setState(() {
      if (weekly) {
        _weeklyBusyInstanceId = instance.instanceId;
      } else {
        _busyInstanceId = instance.instanceId;
      }
    });
    // Read into grains while the altar takes it.
    final grains = AltarGrains.creature(
      species,
      width: kRiteVesselSize.round(),
      maxGrains: 1800,
      tones: 12,
    );
    final rite = _rite;
    try {
      if (weekly) {
        final result = await rite.sacrificeWeekly(
          instanceId: instance.instanceId,
          challenge: challenge,
        );
        if (!mounted) return;
        setState(() {
          _weeklyCompleted = true;
          _weeklySelectedInstanceId = null;
        });
        await _offer(
          showRiteOffering(
            context,
            species: species,
            instance: instance,
            grains: grains,
            gold: result.goldEarned,
            lines: [
              'The altar accepts the offering.',
              '${species.name} is given to the pool.',
              'It will ask again when the week turns.',
            ],
          ),
        );
        return;
      }
      final result = await rite.sacrifice(
        instanceId: instance.instanceId,
        challenge: challenge,
        currentStageIndex: _stageIndex ?? 0,
      );
      if (!mounted) return;
      setState(() {
        _stageIndex = result.newStageIndex;
        _selectedInstanceId = null;
      });
      final next = result.nextChallenge;
      await _offer(
        showRiteOffering(
          context,
          species: species,
          instance: instance,
          grains: grains,
          gold: result.goldEarned,
          lines: [
            'The altar accepts the offering.',
            '${species.name} is given to the pool.',
            if (result.completionBonusGold > 0)
              'Completion reward: +${result.completionBonusGold} gold.',
            if (result.completedRite)
              'The rite stands complete.'
            else if (next != null)
              '${next.shortTitle}. Unsealed.',
          ],
        ),
      );
      if (!mounted) return;
      if (result.completedRite) {
        await _maybeShowCompletionStory();
        if (!mounted) return;
        await _unlockCompletionShopEffect();
      }
    } on PurebloodRiteException catch (e) {
      if (mounted) showGameSnack(context, e.message, accent: _blood);
    } finally {
      if (mounted) {
        setState(() {
          _busyInstanceId = null;
          _weeklyBusyInstanceId = null;
        });
      }
    }
  }

  // ── the screen ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final effects = context.watch<ConstellationEffectsService>();
    if (!effects.hasLineageAnalyzer()) return _sealed();
    final stage = _stageIndex;
    if (stage == null) {
      return _page(
        stage: const RiteStage(),
        body: [
          Text(
            'Consulting the altar…',
            style: altarBody(context, color: AltarTone.muted),
          ),
        ],
      );
    }
    final rite = _rite;
    if (stage == 10 && !effects.hasPotentialAnalyzer()) {
      return _potentialLocked(rite.currentChallenge(stageIndex: stage));
    }
    final challenge = rite.currentChallenge(stageIndex: stage);
    if (challenge == null) return _completed(rite);
    return _riteOf(
      rite: rite,
      challenge: challenge,
      next: rite.nextChallengeAfter(stage),
      stage: stage,
    );
  }

  /// The top bar, the stage, and the words under it, scrolling together;
  /// the stage is the pool home's RITE emblem floods into, so it sits just
  /// under the bar where [ritePoolFor] puts it.
  Widget _page({
    required Widget stage,
    required List<Widget> body,
    String? count,
  }) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: kRiteVoid,
      body: Column(
        children: [
          SizedBox(height: pad.top),
          SizedBox(
            height: kRiteHeaderHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  BracketIconButton(
                    icon: AppIcons.chevron_left_rounded,
                    palette: _palette,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'THE PUREBLOOD RITE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: altarMono(
                        11.5,
                        AltarTone.parchmentDim,
                        spacing: 2.8,
                      ),
                    ),
                  ),
                  if (count != null) ...[
                    Text(count, style: altarMono(11, AltarTone.muted)),
                    const SizedBox(width: 12),
                  ],
                  BracketIconButton(
                    icon: AppIcons.menu_book_rounded,
                    palette: _palette,
                    onTap: _openEncyclopedia,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: CustomScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: stage),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(24, 6, 24, 40 + pad.bottom),
                  sliver: SliverList.list(children: body),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The pool with [challenge]'s vessel over it: the specimen placed for
  /// it, or a ghost of what it asks for.
  Widget _stageFor(
    PurebloodChallenge? challenge, {
    CreatureInstance? placed,
    Creature? species,
    PurebloodSacrificeCheck? check,
    bool still = false,
  }) {
    final worthy = check?.isEligible ?? false;
    Widget? vessel;
    if (placed != null && species != null) {
      vessel = AnimatedOpacity(
        key: ValueKey(placed.instanceId),
        opacity: worthy ? 1 : 0.75,
        duration: const Duration(milliseconds: 400),
        child: RiteVessel(
          species: species,
          instance: placed,
          size: kRiteVesselSize,
        ),
      );
    } else if (challenge != null) {
      vessel = Opacity(
        key: ValueKey('ghost-${challenge.shortTitle}'),
        opacity: 0.3,
        child: RiteVessel(
          species: challenge.previewSpecies,
          size: kRiteVesselSize,
          previewSizeGene: challenge.requiredSize,
          previewTintGene: challenge.requiredTint,
        ),
      );
    }
    return RiteStage(vessel: vessel, lit: worthy ? 1 : 0, still: still);
  }

  // ── the twenty ────────────────────────────────────────────────────────────

  Widget _riteOf({
    required PurebloodRiteService rite,
    required PurebloodChallenge challenge,
    required PurebloodChallenge? next,
    required int stage,
  }) {
    final catalog = context.read<CreatureCatalog>();
    final db = context.read<AlchemonsDatabase>();
    return StreamBuilder<List<CreatureInstance>>(
      stream: db.creatureDao.watchAllInstances(),
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <CreatureInstance>[];
        final placed = _placed(
          all,
          _selectedInstanceId,
          loaded: snapshot.hasData,
          clear: () => _selectedInstanceId = null,
        );
        final species = placed == null
            ? null
            : catalog.getCreatureById(placed.baseId);
        final check = placed == null
            ? null
            : rite.evaluate(placed, challenge: challenge);
        final family = [
          for (final i in all)
            if (rite.speciesMatchesChallenge(
              catalog.getCreatureById(i.baseId),
              challenge: challenge,
            ))
              i,
        ];
        final eligible = [
          for (final i in family)
            if (rite.evaluate(i, challenge: challenge).isEligible) i,
        ];
        final total = PurebloodRiteService.totalChallenges;
        return _page(
          count: '${stage + 1} / $total',
          stage: _stageFor(
            challenge,
            placed: placed,
            species: species,
            check: check,
          ),
          body: [
            ..._heading(
              challenge,
              overline: 'RITE ${stage + 1} OF $total',
              onTap: () => _showRecipe(challenge),
            ),
            const SizedBox(height: 20),
            RiteLadder(
              done: stage,
              total: total,
              onDoneTap: (i) => _showRecipe(rite.challengeLadder[i]),
            ),
            const SizedBox(height: 24),
            _asks(challenge),
            const SizedBox(height: 20),
            _readouts(
              rite: rite,
              challenge: challenge,
              family: family,
              eligible: eligible,
            ),
            _rule(),
            _chamber(
              challenge: challenge,
              placed: placed,
              species: species,
              check: check,
              busy: placed != null && _busyInstanceId == placed.instanceId,
              weekly: false,
            ),
            _rule(),
            _next(challenge, next),
          ],
        );
      },
    );
  }

  // ── once the twenty are given: the weekly offering ────────────────────────

  Widget _completed(PurebloodRiteService rite) {
    final weekly = rite.weeklyChallenge();
    final resetIn = PurebloodRiteService.timeUntilWeeklyReset();
    final resets = '${resetIn.inDays}D ${resetIn.inHours % 24}H';
    final catalog = context.read<CreatureCatalog>();
    final db = context.read<AlchemonsDatabase>();
    return StreamBuilder<List<CreatureInstance>>(
      stream: db.creatureDao.watchAllInstances(),
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <CreatureInstance>[];
        final given = _weeklyCompleted ?? false;
        final placed = given
            ? null
            : _placed(
                all,
                _weeklySelectedInstanceId,
                loaded: snapshot.hasData,
                clear: () => _weeklySelectedInstanceId = null,
              );
        final species = placed == null
            ? null
            : catalog.getCreatureById(placed.baseId);
        final check = placed == null
            ? null
            : rite.evaluate(placed, challenge: weekly);
        final family = [
          for (final i in all)
            if (rite.speciesMatchesChallenge(
              catalog.getCreatureById(i.baseId),
              challenge: weekly,
            ))
              i,
        ];
        final eligible = [
          for (final i in family)
            if (rite.evaluate(i, challenge: weekly).isEligible) i,
        ];
        return _page(
          count: 'COMPLETE',
          stage: _stageFor(
            given ? null : weekly,
            placed: placed,
            species: species,
            check: check,
          ),
          body: [
            Text(
              'THE RITE STANDS COMPLETE',
              style: altarMono(10.5, _gold, spacing: 2.2),
            ),
            const SizedBox(height: 6),
            Text(
              'All twenty offerings given. The pool endures, and asks one '
              'more each week.',
              style: altarBody(context),
            ),
            _rule(),
            ..._heading(
              weekly,
              overline: given
                  ? 'THIS WEEK\'S OFFERING  ·  GIVEN'
                  : 'THIS WEEK\'S OFFERING',
              detail: given
                  ? 'IT ASKS AGAIN IN $resets'
                  : '+${weekly.goldReward} GOLD  ·  RESETS IN $resets',
              onTap: () => _showRecipe(weekly),
            ),
            if (_weeklyCompleted == null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  'Consulting the altar…',
                  style: altarBody(context, color: AltarTone.muted),
                ),
              )
            else if (!given) ...[
              const SizedBox(height: 24),
              _asks(weekly),
              const SizedBox(height: 20),
              _readouts(
                rite: rite,
                challenge: weekly,
                family: family,
                eligible: eligible,
              ),
              _rule(),
              _chamber(
                challenge: weekly,
                placed: placed,
                species: species,
                check: check,
                busy:
                    placed != null &&
                    _weeklyBusyInstanceId == placed.instanceId,
                weekly: true,
              ),
            ],
          ],
        );
      },
    );
  }

  /// [id]'s instance among [all], or null — clearing the choice (after this
  /// frame) once the instances have loaded and it is gone.
  CreatureInstance? _placed(
    List<CreatureInstance> all,
    String? id, {
    required bool loaded,
    required VoidCallback clear,
  }) {
    if (id == null) return null;
    for (final i in all) {
      if (i.instanceId == id) return i;
    }
    if (loaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(clear);
      });
    }
    return null;
  }

  // ── sealed ────────────────────────────────────────────────────────────────

  Widget _sealed() => _page(
    stage: _stageFor(null, still: true),
    body: [
      Text('SEALED', style: altarMono(10.5, AltarTone.muted, spacing: 2.2)),
      const SizedBox(height: 6),
      Text('The rite is sealed', style: altarName(context, 28)),
      const SizedBox(height: 10),
      Text(
        'The pool stays still until the Lineage Analyzer is awakened in '
        'the breeder constellation.',
        style: altarBody(context),
      ),
      const SizedBox(height: 24),
      BracketButton(
        label: 'RETURN',
        palette: _palette,
        accent: _blood,
        primary: false,
        onTap: () => Navigator.of(context).maybePop(),
      ),
    ],
  );

  Widget _potentialLocked(PurebloodChallenge? challenge) => _page(
    count: '11 / ${PurebloodRiteService.totalChallenges}',
    stage: _stageFor(challenge),
    body: [
      Text(
        'THE ELEVENTH RITE WAITS',
        style: altarMono(10.5, _soul, spacing: 2.2),
      ),
      const SizedBox(height: 6),
      Text('What it may become', style: altarName(context, 28)),
      const SizedBox(height: 10),
      Text(
        'From here the altar judges what a specimen may become, not only '
        'the bloodline it carries. Unlock the Potential Analyzer in the '
        'breeder constellation; the next offering asks for Beauty '
        'Potential 76+.',
        style: altarBody(context),
      ),
      const SizedBox(height: 20),
      RiteLadder(
        done: 10,
        total: PurebloodRiteService.totalChallenges,
        onDoneTap: (i) => _showRecipe(_rite.challengeLadder[i]),
      ),
    ],
  );

  // ── pieces ────────────────────────────────────────────────────────────────

  List<Widget> _heading(
    PurebloodChallenge challenge, {
    required String overline,
    String? detail,
    VoidCallback? onTap,
  }) => [
    GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(overline, style: altarMono(10.5, _blood, spacing: 2.2)),
          const SizedBox(height: 6),
          Text(
            challenge.shortTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: altarName(context, 27),
          ),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(detail, style: altarMono(10.5, _gold, spacing: 1.6)),
          ],
          const SizedBox(height: 8),
          Text(challenge.vesselDescription, style: altarBody(context)),
        ],
      ),
    ),
  ];

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: altarMono(10.5, AltarTone.muted, spacing: 2.4)),
  );

  Widget _rule() => Container(
    height: 1,
    margin: const EdgeInsets.symmetric(vertical: 24),
    color: _palette.lineSoft,
  );

  Widget _asks(PurebloodChallenge challenge) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label('THE ALTAR ASKS'),
      for (final line in challenge.requirementLines)
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7, right: 12),
                child: _Diamond(color: _blood, size: 5),
              ),
              Expanded(
                child: Text(
                  line,
                  style: altarBody(context, color: AltarTone.parchment),
                ),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _readouts({
    required PurebloodRiteService rite,
    required PurebloodChallenge challenge,
    required List<CreatureInstance> family,
    required List<CreatureInstance> eligible,
  }) {
    Widget rule() => Container(width: 1, height: 34, color: _palette.lineSoft);
    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: _Readout(
              label: 'OWNED',
              value: '${family.length}',
              onTap: () => _showSpecimens(
                title: 'Owned',
                empty: 'No ${challenge.requiredFamily} specimens to offer.',
                instances: family,
                challenge: challenge,
              ),
            ),
          ),
          rule(),
          Expanded(
            child: _Readout(
              label: 'WORTHY',
              value: '${eligible.length}',
              color: eligible.isEmpty ? null : _soul,
              onTap: () => _showSpecimens(
                title: 'Worthy',
                empty: 'None you own satisfies every condition yet.',
                instances: eligible,
                challenge: challenge,
              ),
            ),
          ),
          rule(),
          Expanded(
            child: _Readout(
              label: 'REWARD',
              value: '+${challenge.goldReward}',
              color: _gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chamber({
    required PurebloodChallenge challenge,
    required CreatureInstance? placed,
    required Creature? species,
    required PurebloodSacrificeCheck? check,
    required bool busy,
    required bool weekly,
  }) {
    final worthy = check?.isEligible ?? false;
    final nickname = placed?.nickname?.trim();
    final name = nickname != null && nickname.isNotEmpty
        ? nickname
        : species?.name ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('THE CHAMBER'),
        if (placed == null || species == null)
          Text(
            'Nothing is placed. Choose any specimen; the altar judges whether '
            'it is worthy.',
            style: altarBody(context),
          )
        else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                color: _palette.bg1,
                child: RiteVessel(
                  species: species,
                  instance: placed,
                  size: 72,
                  still: true,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: altarName(context, 20),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'LV ${placed.level}  ·  ${species.rarity.toUpperCase()}',
                      style: altarMono(10, AltarTone.muted, spacing: 1.4),
                    ),
                    const SizedBox(height: 10),
                    for (final (label, met, word) in _checks(challenge, check))
                      _CheckRow(label: label, met: met, word: word),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            worthy
                ? 'The altar accepts this vessel.'
                : 'This vessel is not worthy.',
            style: altarName(
              context,
              17,
            ).copyWith(color: worthy ? _gold : AltarTone.parchmentDim),
          ),
          const SizedBox(height: 4),
          Text(check?.message ?? '', style: altarBody(context)),
        ],
        const SizedBox(height: 18),
        BracketButton(
          label: placed == null ? 'PLACE A SPECIMEN' : 'CHANGE SPECIMEN',
          palette: _palette,
          accent: _soul,
          primary: placed == null,
          enabled: !busy,
          onTap: () => _place(challenge: challenge, weekly: weekly),
        ),
        if (placed != null && species != null) ...[
          const SizedBox(height: 10),
          AltarHoldButton(
            key: ValueKey('perform-${placed.instanceId}'),
            label: 'HOLD TO PERFORM THE RITE',
            holdingLabel: 'GIVING IT TO THE POOL',
            accent: _blood,
            seconds: 1.4,
            enabled: worthy && !busy,
            onComplete: () => _perform(
              challenge: challenge,
              species: species,
              instance: placed,
              weekly: weekly,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The vessel is given to the pool. This cannot be undone.',
            style: altarBody(context, size: 12, color: AltarTone.muted),
          ),
        ],
      ],
    );
  }

  List<(String, bool, String)> _checks(
    PurebloodChallenge c,
    PurebloodSacrificeCheck? k,
  ) => [
    if (c.requireElementalPurity)
      (_elementLineLabel(c), k?.pureElement ?? false, 'PURE'),
    if (c.requireSpeciesPurity)
      ('${c.requiredFamily} species line', k?.pureFamily ?? false, 'PURE'),
    if (c.requiredTint != null)
      (
        'Tinting: ${_traitLabel(c.requiredTint!)}',
        k?.matchesTint ?? false,
        'MET',
      ),
    if (c.requiredSize != null)
      ('Size: ${_traitLabel(c.requiredSize!)}', k?.matchesSize ?? false, 'MET'),
    if (c.requiredNature != null)
      (
        'Nature: ${_titleCaseLabel(c.requiredNature!)}',
        k?.matchesNature ?? false,
        'MET',
      ),
    if (c.requiredVariantFaction != null)
      (
        'Variant: ${_titleCaseLabel(c.requiredVariantFaction!)}',
        k?.matchesVariant ?? false,
        'MET',
      ),
  ];

  Widget _next(PurebloodChallenge current, PurebloodChallenge? next) {
    if (next == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('THE LAST RITE'),
          Text(
            'Give this offering and the rite is complete.',
            style: altarBody(context),
          ),
        ],
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showRecipe(next),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('NEXT  ·  SEALED'),
          Row(
            children: [
              Opacity(
                opacity: 0.4,
                child: RiteVessel(
                  species: next.previewSpecies,
                  size: 60,
                  previewSizeGene: next.requiredSize,
                  previewTintGene: next.requiredTint,
                  still: true,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      next.shortTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: altarName(
                        context,
                        17,
                      ).copyWith(color: AltarTone.parchmentDim),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Give ${current.shortTitle} to unseal it.',
                      style: altarBody(
                        context,
                        size: 12,
                        color: AltarTone.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── dialogs ───────────────────────────────────────────────────────────────

  Future<void> _dialog({
    required Color accent,
    required List<Widget> children,
  }) {
    HapticFeedback.selectionClick();
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: CustomPaint(
          foregroundPainter: BracketFramePainter(
            color: accent.withValues(alpha: 0.9),
            bracketSize: 14,
            strokeWidth: 1.3,
          ),
          child: Container(
            color: _palette.bg1,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...children,
                const SizedBox(height: 18),
                BracketButton(
                  label: 'CLOSE',
                  palette: _palette,
                  accent: accent,
                  primary: false,
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showRecipe(PurebloodChallenge challenge) => _dialog(
    accent: _blood,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('THE RITE OF', style: altarMono(10, _blood)),
                const SizedBox(height: 6),
                Text(challenge.shortTitle, style: altarName(context, 22)),
                const SizedBox(height: 6),
                Text(
                  '+${challenge.goldReward} GOLD',
                  style: altarMono(10.5, _gold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          RiteVessel(
            species: challenge.previewSpecies,
            size: 76,
            previewSizeGene: challenge.requiredSize,
            previewTintGene: challenge.requiredTint,
          ),
        ],
      ),
      const SizedBox(height: 14),
      for (final line in challenge.requirementLines)
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7, right: 12),
                child: _Diamond(color: _blood, size: 5),
              ),
              Expanded(child: Text(line, style: altarBody(context))),
            ],
          ),
        ),
    ],
  );

  Future<void> _showSpecimens({
    required String title,
    required String empty,
    required List<CreatureInstance> instances,
    required PurebloodChallenge challenge,
  }) {
    final catalog = context.read<CreatureCatalog>();
    final rite = _rite;
    final entries =
        [
          for (final i in instances)
            if (catalog.getCreatureById(i.baseId) case final species?)
              (i, species, rite.evaluate(i, challenge: challenge)),
        ]..sort((a, b) {
          final worthy = (b.$3.isEligible ? 1 : 0).compareTo(
            a.$3.isEligible ? 1 : 0,
          );
          if (worthy != 0) return worthy;
          return b.$1.level.compareTo(a.$1.level);
        });
    return _dialog(
      accent: _soul,
      children: [
        Text(
          '${title.toUpperCase()}  ·  ${entries.length}',
          style: altarMono(11, _soul),
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Text(empty, style: altarBody(context))
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: entries.length,
              separatorBuilder: (_, _) =>
                  Container(height: 1, color: _palette.lineSoft),
              itemBuilder: (context, index) {
                final (instance, species, check) = entries[index];
                final nickname = instance.nickname?.trim();
                final status = check.isEligible
                    ? ('WORTHY', _soul)
                    : check.isProtected
                    ? ('LOCKED', _blood)
                    : ('NOT YET', AltarTone.muted);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RiteVessel(
                        species: species,
                        instance: instance,
                        size: 44,
                        still: true,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nickname != null && nickname.isNotEmpty
                                  ? nickname
                                  : species.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: altarName(context, 15),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'LV ${instance.level}  ·  '
                              '${species.rarity.toUpperCase()}',
                              style: altarMono(9.5, AltarTone.muted),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              check.message,
                              style: altarBody(context, size: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(status.$1, style: altarMono(9.5, status.$2)),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ── small parts ─────────────────────────────────────────────────────────────

class _Diamond extends StatelessWidget {
  const _Diamond({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: math.pi / 4,
    child: Container(width: size, height: size, color: color),
  );
}

class _Readout extends StatelessWidget {
  const _Readout({
    required this.label,
    required this.value,
    this.color,
    this.onTap,
  });

  final String label, value;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Text(
              value,
              style: altarName(
                context,
                24,
              ).copyWith(color: color ?? AltarTone.parchment),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: altarMono(
                9.5,
                onTap == null ? AltarTone.muted : AltarTone.parchmentDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.met, required this.word});

  final String label, word;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 10),
            child: met
                ? const _Diamond(color: _gold, size: 5)
                : Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AltarTone.ash.withValues(alpha: 0.6),
                    ),
                  ),
          ),
          Expanded(
            child: Text(
              label,
              style: altarBody(
                context,
                size: 12.5,
                color: met ? AltarTone.parchment : AltarTone.muted,
              ),
            ),
          ),
          if (met)
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 8),
              child: Text(word, style: altarMono(9, _gold)),
            ),
        ],
      ),
    );
  }
}

String _traitLabel(String id) {
  switch (id.trim().toLowerCase()) {
    case 'vibrant':
      return 'Radiant';
    default:
      return tintLabels[id] ?? sizeLabels[id] ?? _titleCaseLabel(id);
  }
}

String _titleCaseLabel(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
}

String _elementLineLabel(PurebloodChallenge challenge) {
  if (challenge.requiredElement == null) return 'Elemental line';
  return '${challenge.requiredElement} line';
}
