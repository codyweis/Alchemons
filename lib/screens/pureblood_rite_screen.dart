import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/screens/alchemical_encyclopedia_screen.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/pureblood_rite_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/all_specimens_page.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// ─── HK Palette ───────────────────────────────────────────────────────────────
const _kVoid = Color(0xFF080808);
const _kVoidLight = Color(0xFF111111);
const _kIvory = Color(0xFFE8DFC8);
const _kIvoryDim = Color(0xFFB5A98A);
const _kIvoryMuted = Color(0xFF6B6050);
const _kSoulBlue = Color(0xFF5BC8E8);
const _kSoulGold = Color(0xFFC4A35A);
const _kBlood = Color(0xFF8B2020);
const _kSealGreenBr = Color(0xFF6DC88A);

// ─── Typography ───────────────────────────────────────────────────────────────
TextStyle _riteFont(
  BuildContext context,
  double sz,
  Color c, {
  FontWeight w = FontWeight.w400,
  double ls = 0,
  double? h,
  FontStyle style = FontStyle.normal,
}) {
  final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
  return base.copyWith(
    color: c,
    fontSize: sz,
    fontWeight: w,
    letterSpacing: ls,
    height: h,
    fontStyle: style,
  );
}

TextStyle _fell(
  BuildContext context,
  double sz,
  Color c, {
  FontWeight w = FontWeight.w400,
  double ls = 0,
}) => _riteFont(context, sz, c, w: w, ls: ls);

TextStyle _fellItalic(BuildContext context, double sz, Color c) =>
    _riteFont(context, sz, c, style: FontStyle.italic);

TextStyle _mono(
  BuildContext context,
  double sz,
  Color c, {
  FontWeight w = FontWeight.w400,
}) => _riteFont(context, sz, c, w: w);

TextStyle _bask(
  BuildContext context,
  double sz,
  Color c, {
  double h = 1.55,
  FontWeight w = FontWeight.w400,
}) => _riteFont(context, sz, c, h: h, w: w);

class _AutoShrinkText extends StatelessWidget {
  const _AutoShrinkText(
    this.text, {
    required this.style,
    this.maxLines = 1,
    this.minFontSize = 12,
  });

  final String text;
  final TextStyle style;
  final int maxLines;
  final double minFontSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth) {
          return Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: style,
          );
        }

        final baseFontSize = style.fontSize ?? 14;
        final textScaler = MediaQuery.textScalerOf(context);
        var resolvedFontSize = baseFontSize;
        final direction = Directionality.of(context);
        final words = text
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .toList(growable: false);

        while (resolvedFontSize > minFontSize) {
          final painter = TextPainter(
            text: TextSpan(
              text: text,
              style: style.copyWith(fontSize: resolvedFontSize),
            ),
            textDirection: direction,
            maxLines: maxLines,
            textScaler: textScaler,
          )..layout(maxWidth: constraints.maxWidth);

          final hasOversizedWord = words.any((word) {
            final wordPainter = TextPainter(
              text: TextSpan(
                text: word,
                style: style.copyWith(fontSize: resolvedFontSize),
              ),
              textDirection: direction,
              maxLines: 1,
              textScaler: textScaler,
            )..layout(maxWidth: constraints.maxWidth);
            return wordPainter.didExceedMaxLines ||
                wordPainter.width > constraints.maxWidth;
          });

          if (!painter.didExceedMaxLines && !hasOversizedWord) break;
          resolvedFontSize -= 1;
        }

        return Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: style.copyWith(fontSize: resolvedFontSize),
        );
      },
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

Color _sacrificePrimaryColor(Creature species) {
  if (species.types.isEmpty) return _kSoulBlue;
  return BreedConstants.getTypeColor(species.types.first);
}

Color _sacrificeSecondaryColor(Creature species, Color primaryColor) {
  if (species.types.length > 1) {
    return BreedConstants.getTypeColor(species.types[1]);
  }
  return Color.lerp(primaryColor, _kSoulGold, 0.48) ?? _kSoulGold;
}

Color _sacrificeGlowColor(Color primaryColor, Color secondaryColor) {
  return Color.lerp(primaryColor, secondaryColor, 0.35) ?? primaryColor;
}

Offset _ritualShakeOffset({
  required double crackProgress,
  required double dissolveProgress,
}) {
  final crackWave = math.sin(crackProgress * math.pi);
  final dissolveWave = math.sin(dissolveProgress * math.pi * 2.6).abs();
  final amplitude =
      crackWave * 10.0 +
      dissolveWave * (1.0 - dissolveProgress).clamp(0.0, 1.0) * 7.0;
  final phase = crackProgress * 34.0 + dissolveProgress * 52.0;
  return Offset(
    math.sin(phase) * amplitude,
    math.cos(phase * 1.18) * amplitude * 0.34,
  );
}

// ─── Main Screen ──────────────────────────────────────────────────────────────
class PurebloodRiteScreen extends StatefulWidget {
  const PurebloodRiteScreen({super.key});
  @override
  State<PurebloodRiteScreen> createState() => _PurebloodRiteScreenState();
}

class _PurebloodRiteScreenState extends State<PurebloodRiteScreen>
    with TickerProviderStateMixin {
  static const _introStorySeenKey = 'pureblood_rite_story_intro_seen_v1';
  static const _completionStorySeenKey =
      'pureblood_rite_story_completion_seen_v1';

  late final AnimationController _wispCtrl;
  late final AnimationController _entryCtrl;
  String? _busyInstanceId;
  int? _stageIndex;
  String? _selectedInstanceId;
  bool _checkedIntroStory = false;

  // Weekly challenge state
  bool? _weeklyCompleted;
  String? _weeklySelectedInstanceId;
  String? _weeklyBusyInstanceId;

  @override
  void initState() {
    super.initState();
    _wispCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _loadStageProgress();
    _loadWeeklyStatus();
    _maybeShowIntroStory();
  }

  @override
  void dispose() {
    _wispCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStageProgress() async {
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();
    final rite = PurebloodRiteService(db, catalog);
    final idx = await rite.getStageIndex();
    if (!mounted) return;
    setState(() => _stageIndex = idx);
  }

  Future<void> _loadWeeklyStatus() async {
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();
    final rite = PurebloodRiteService(db, catalog);
    final completed = await rite.isWeeklyComplete();
    if (!mounted) return;
    setState(() => _weeklyCompleted = completed);
  }

  Future<void> _maybeShowIntroStory() async {
    if (_checkedIntroStory) return;
    _checkedIntroStory = true;
    final db = context.read<AlchemonsDatabase>();
    final seen = await db.settingsDao.getSetting(_introStorySeenKey) == '1';
    if (seen || !mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _showStoryDialog(
      body:
          '"Humankind cannot gain anything without first giving something in return. '
          'To obtain, something of equal value must be lost"',
    );
    if (!mounted) return;
    await db.settingsDao.setSetting(_introStorySeenKey, '1');
  }

  Future<void> _maybeShowCompletionStory() async {
    final db = context.read<AlchemonsDatabase>();
    final seen =
        await db.settingsDao.getSetting(_completionStorySeenKey) == '1';
    if (seen || !mounted) return;
    await _showStoryDialog(
      title: 'no one can rewrite the stars',
      body: 'but what if we created them',
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$unlockedName unlocked in the shop to buy.')),
    );
  }

  Future<void> _showStoryDialog({String? title, required String body}) {
    return showGeneralDialog<void>(
      context: context,
      barrierLabel: 'story',
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.90),
      pageBuilder: (_, __, ___) => Material(
        color: Colors.transparent,
        child: _RiteStoryDialog(title: title, body: body),
      ),
    );
  }

  Future<void> _showRecipeDialog(PurebloodChallenge challenge) {
    HapticFeedback.selectionClick();
    return showGeneralDialog<void>(
      context: context,
      barrierLabel: 'recipe',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      pageBuilder: (_, __, ___) => Material(
        color: Colors.transparent,
        child: _RiteRecipeDialog(challenge: challenge),
      ),
    );
  }

  Future<void> _showSpecimenDialog({
    required String title,
    required String emptyMessage,
    required List<CreatureInstance> instances,
    required CreatureCatalog catalog,
    required PurebloodRiteService rite,
    required PurebloodChallenge challenge,
  }) async {
    HapticFeedback.selectionClick();
    final entries =
        instances
            .map((instance) {
              final species = catalog.getCreatureById(instance.baseId);
              if (species == null) return null;
              return _RiteSpecimenEntry(
                instance: instance,
                species: species,
                check: rite.evaluate(instance, challenge: challenge),
              );
            })
            .whereType<_RiteSpecimenEntry>()
            .toList(growable: false)
          ..sort((a, b) {
            final eligibleCmp = (b.check.isEligible ? 1 : 0).compareTo(
              a.check.isEligible ? 1 : 0,
            );
            if (eligibleCmp != 0) return eligibleCmp;
            final nameCmp = a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            );
            if (nameCmp != 0) return nameCmp;
            return b.instance.level.compareTo(a.instance.level);
          });

    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'specimens',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      pageBuilder: (_, __, ___) => Material(
        color: Colors.transparent,
        child: _RiteSpecimenDialog(
          title: title,
          emptyMessage: emptyMessage,
          entries: entries,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLineageAnalyzer = context
        .watch<ConstellationEffectsService>()
        .hasLineageAnalyzer();
    if (!hasLineageAnalyzer) {
      return Scaffold(
        backgroundColor: _kVoid,
        body: Stack(
          children: [
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _wispCtrl,
                builder: (_, __) => CustomPaint(
                  painter: _WispBgPainter(_wispCtrl.value),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            SafeArea(
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _entryCtrl,
                  curve: Curves.easeOut,
                ),
                child: Column(
                  children: [
                    _buildHeader(context),
                    Expanded(child: _buildLockedContent(context)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();
    final rite = PurebloodRiteService(db, catalog);
    final stageIndex = _stageIndex;
    final challenge = stageIndex == null
        ? null
        : rite.currentChallenge(stageIndex: stageIndex);
    final nextChallenge = stageIndex == null
        ? null
        : rite.nextChallengeAfter(stageIndex);

    return Scaffold(
      backgroundColor: _kVoid,
      body: Stack(
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _wispCtrl,
              builder: (_, __) => CustomPaint(
                painter: _WispBgPainter(_wispCtrl.value),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _entryCtrl,
                curve: Curves.easeOut,
              ),
              child: Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: stageIndex == null
                        ? _buildLoading(context)
                        : challenge == null
                        ? _buildCompletedContent(
                            context: context,
                            db: db,
                            catalog: catalog,
                            rite: rite,
                          )
                        : _buildContent(
                            context: context,
                            db: db,
                            catalog: catalog,
                            rite: rite,
                            challenge: challenge,
                            nextChallenge: nextChallenge,
                            stageIndex: stageIndex,
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

  Widget _buildLockedContent(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SoulOrb(
              size: 68,
              color: _kBlood,
              child: const Icon(
                Icons.lock_outline_rounded,
                color: _kIvory,
                size: 28,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Rite Sealed',
              textAlign: TextAlign.center,
              style: _fell(context, 28, _kIvory, ls: 0.7),
            ),
            const SizedBox(height: 10),
            Text(
              'The altar remains hidden until the Constellation '
              'Lineage Analyzer is awakened.',
              textAlign: TextAlign.center,
              style: _bask(context, 13, _kIvoryDim),
            ),
            const SizedBox(height: 22),
            _HkPanel(
              accentColor: _kIvoryMuted,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HkTag(label: 'REQUIREMENT', color: _kSoulBlue),
                  const SizedBox(height: 12),
                  Text(
                    'Unlock Lineage Analyzer in the breeder constellation tree '
                    'to reveal the Rite on the home screen.',
                    style: _bask(context, 13, _kIvoryDim),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 220,
              child: _HkBtn(
                label: 'Return',
                onTap: () => Navigator.of(context).maybePop(),
                primary: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Row(
        children: [
          _HkBackButton(onTap: () => Navigator.of(context).maybePop()),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alchemical Rite',
                  style: _fell(context, 24, _kIvory, ls: 0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  'Offer only the unbroken bloodline.',
                  style: _fellItalic(context, 13, _kIvoryMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _RiteHeaderAction(
            icon: Icons.menu_book_rounded,
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AlchemicalEncyclopediaScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _AltarLoader(size: 72),
          const SizedBox(height: 20),
          Text(
            'Consulting the altar...',
            style: _fellItalic(context, 15, _kIvoryMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedContent({
    required BuildContext context,
    required AlchemonsDatabase db,
    required CreatureCatalog catalog,
    required PurebloodRiteService rite,
  }) {
    final weeklyChallenge = rite.weeklyChallenge();
    final resetIn = PurebloodRiteService.timeUntilWeeklyReset();
    final resetDays = resetIn.inDays;
    final resetHours = resetIn.inHours % 24;

    return StreamBuilder<List<CreatureInstance>>(
      stream: db.creatureDao.watchAllInstances(),
      builder: (context, snapshot) {
        final allInstances = snapshot.data ?? const <CreatureInstance>[];
        final weeklySelected = _weeklySelectedInstanceId == null
            ? null
            : allInstances.firstWhereOrNull(
                (i) => i.instanceId == _weeklySelectedInstanceId,
              );
        if (_weeklySelectedInstanceId != null && weeklySelected == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _weeklySelectedInstanceId = null);
          });
        }
        final weeklySelectedSpecies = weeklySelected == null
            ? null
            : catalog.getCreatureById(weeklySelected.baseId);
        final weeklyCheck = weeklySelected == null
            ? null
            : rite.evaluate(weeklySelected, challenge: weeklyChallenge);

        final familyInstances = allInstances
            .where(
              (i) => rite.speciesMatchesChallenge(
                catalog.getCreatureById(i.baseId),
                challenge: weeklyChallenge,
              ),
            )
            .toList(growable: false);
        final eligibleInstances = familyInstances
            .where((i) => rite.evaluate(i, challenge: weeklyChallenge).isEligible)
            .toList(growable: false);

        final isCompleted = _weeklyCompleted ?? false;

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Rite complete banner ──────────────────────────────────────
            _s(
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.workspace_premium_rounded,
                      color: _kSoulGold,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rite Complete',
                            style: _fell(context, 22, _kSoulGold, ls: 0.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'All 20 offerings sealed. The altar endures.',
                            style: _bask(context, 12, _kIvoryMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Weekly Challenge header ───────────────────────────────────
            _s(
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: _HkSectionHead(
                  title: 'Weekly Altar Challenge',
                  sub: isCompleted
                      ? 'Completed this week. Resets in '
                            '${resetDays}d ${resetHours}h.'
                      : 'A new offering demanded each week. Resets in '
                            '${resetDays}d ${resetHours}h.',
                ),
              ),
            ),
            if (_weeklyCompleted == null)
              _s(
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: _AltarLoader(size: 52)),
                ),
              )
            else ...[
              // ── Weekly challenge info card ────────────────────────────
              _s(
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: _WeeklyChallengePanel(
                    challenge: weeklyChallenge,
                    isCompleted: isCompleted,
                    onTap: () => _showRecipeDialog(weeklyChallenge),
                  ),
                ),
              ),
              if (!isCompleted) ...[
                // ── Stat row ─────────────────────────────────────────────
                _s(
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: _TriStatRow(
                      ownedCount: familyInstances.length,
                      eligibleCount: eligibleInstances.length,
                      stageStep: weeklyChallenge.goldReward,
                      stageLabel: 'REWARD',
                      challenge: weeklyChallenge,
                      onOwnedTap: () => _showSpecimenDialog(
                        title: 'Owned Specimens',
                        emptyMessage:
                            'No ${weeklyChallenge.requiredFamily} specimens available.',
                        instances: familyInstances,
                        catalog: catalog,
                        rite: rite,
                        challenge: weeklyChallenge,
                      ),
                      onEligibleTap: () => _showSpecimenDialog(
                        title: 'Eligible Specimens',
                        emptyMessage:
                            'No specimens satisfy every weekly condition.',
                        instances: eligibleInstances,
                        catalog: catalog,
                        rite: rite,
                        challenge: weeklyChallenge,
                      ),
                    ),
                  ),
                ),
                // ── Chamber ──────────────────────────────────────────────
                _s(
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                    child: _HkSectionHead(
                      title: 'Ritual Chamber',
                      sub:
                          'Place any specimen in the chamber. The altar will judge it.',
                    ),
                  ),
                ),
                _s(
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: _SacrificeChamberCard(
                      challenge: weeklyChallenge,
                      selectedInstance: weeklySelected,
                      selectedSpecies: weeklySelectedSpecies,
                      selectedCheck: weeklyCheck,
                      isBusy: weeklySelected != null &&
                          _weeklyBusyInstanceId == weeklySelected.instanceId,
                      onTap: () => _openWeeklyChamberSelection(
                        rite: rite,
                        challenge: weeklyChallenge,
                      ),
                      onSacrifice: weeklySelected != null &&
                              weeklySelectedSpecies != null &&
                              weeklyCheck?.isEligible == true &&
                              _weeklyBusyInstanceId != weeklySelected.instanceId
                          ? () => _handleWeeklySacrifice(
                              rite: rite,
                              challenge: weeklyChallenge,
                              species: weeklySelectedSpecies,
                              instance: weeklySelected,
                            )
                          : null,
                    ),
                  ),
                ),
              ] else ...[
                // ── Already completed card ────────────────────────────────
                _s(
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: _WeeklyCompleteCard(
                      resetDays: resetDays,
                      resetHours: resetHours,
                    ),
                  ),
                ),
              ],
            ],
            _s(const SizedBox(height: 24)),
            _s(
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
                child: SizedBox(
                  width: 220,
                  child: _HkBtn(
                    label: 'Return',
                    onTap: () => Navigator.of(context).maybePop(),
                    primary: false,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openWeeklyChamberSelection({
    required PurebloodRiteService rite,
    required PurebloodChallenge challenge,
  }) async {
    final theme = context.read<FactionTheme>();
    if (!mounted) return;

    final selected = await Navigator.of(context).push<CreatureInstance>(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) =>
            AllSpecimensPage(
              theme: theme,
              instancePrefsScopeKey: 'pureblood_rite_specimens',
              popOnSelect: true,
              searchHint: 'PLACE SPECIMEN',
              selectedInstanceIds: _weeklySelectedInstanceId == null
                  ? const []
                  : [_weeklySelectedInstanceId!],
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
    if (selected == null || !mounted) return;

    final check = rite.evaluate(selected, challenge: challenge);
    setState(() => _weeklySelectedInstanceId = selected.instanceId);

    if (!check.isEligible) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(check.message)));
    }
  }

  Future<void> _handleWeeklySacrifice({
    required PurebloodRiteService rite,
    required PurebloodChallenge challenge,
    required Creature species,
    required CreatureInstance instance,
  }) async {
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierLabel: 'confirm',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      pageBuilder: (_, __, ___) => Material(
        color: Colors.transparent,
        child: _HkConfirmDialog(species: species, instance: instance),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _weeklyBusyInstanceId = instance.instanceId);
    try {
      HapticFeedback.heavyImpact();
      final result = await rite.sacrificeWeekly(
        instanceId: instance.instanceId,
        challenge: challenge,
      );
      if (mounted) {
        setState(() {
          _weeklyCompleted = true;
          _weeklySelectedInstanceId = null;
        });
      }
      if (!mounted) return;
      await showGeneralDialog<void>(
        context: context,
        barrierLabel: 'echo',
        barrierDismissible: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => Material(
          color: Colors.transparent,
          child: _RitualEchoOverlay(
            species: species,
            instance: instance,
            reward: result.goldEarned,
            nextChallengeTitle: null,
            completedRite: false,
            completionBonusGold: 0,
          ),
        ),
      );
    } on PurebloodRiteException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _weeklyBusyInstanceId = null);
    }
  }

  Widget _buildContent({
    required BuildContext context,
    required AlchemonsDatabase db,
    required CreatureCatalog catalog,
    required PurebloodRiteService rite,
    required PurebloodChallenge challenge,
    required PurebloodChallenge? nextChallenge,
    required int stageIndex,
  }) {
    return StreamBuilder<List<CreatureInstance>>(
      stream: db.creatureDao.watchAllInstances(),
      builder: (context, snapshot) {
        final allInstances = snapshot.data ?? const <CreatureInstance>[];
        final selectedInstance = _selectedInstanceId == null
            ? null
            : allInstances.firstWhereOrNull(
                (instance) => instance.instanceId == _selectedInstanceId,
              );
        if (_selectedInstanceId != null && selectedInstance == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _selectedInstanceId = null);
          });
        }
        final selectedSpecies = selectedInstance == null
            ? null
            : catalog.getCreatureById(selectedInstance.baseId);
        final selectedCheck = selectedInstance == null
            ? null
            : rite.evaluate(selectedInstance, challenge: challenge);
        final instances = allInstances
            .where(
              (instance) => rite.speciesMatchesChallenge(
                catalog.getCreatureById(instance.baseId),
                challenge: challenge,
              ),
            )
            .toList(growable: false);
        final eligibleInstances = instances
            .where((i) => rite.evaluate(i, challenge: challenge).isEligible)
            .toList(growable: false);
        final eligibleCount = eligibleInstances.length;

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _s(
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: _PathProgressBar(
                  currentStageIndex: stageIndex,
                  currentChallenge: challenge,
                  nextChallenge: nextChallenge,
                  challengeLadder: rite.challengeLadder,
                  onCompletedChallengeTap: _showRecipeDialog,
                ),
              ),
            ),
            _s(
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                child: _ChallengePanel(
                  challenge: challenge,
                  currentStageIndex: stageIndex,
                  onTap: () => _showRecipeDialog(challenge),
                ),
              ),
            ),
            _s(
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: _TriStatRow(
                  ownedCount: instances.length,
                  eligibleCount: eligibleCount,
                  stageStep: stageIndex + 1,
                  challenge: challenge,
                  onOwnedTap: () => _showSpecimenDialog(
                    title: 'Owned Specimens',
                    emptyMessage:
                        'No ${challenge.requiredFamily} specimens are available for this rite.',
                    instances: instances,
                    catalog: catalog,
                    rite: rite,
                    challenge: challenge,
                  ),
                  onEligibleTap: () => _showSpecimenDialog(
                    title: 'Eligible Specimens',
                    emptyMessage:
                        'No specimens currently satisfy every condition for this rite.',
                    instances: eligibleInstances,
                    catalog: catalog,
                    rite: rite,
                    challenge: challenge,
                  ),
                ),
              ),
            ),
            _s(
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: _HkSectionHead(
                  title: 'Ritual Chamber',
                  sub:
                      'Place any specimen in the chamber. The altar will judge it before the rite can proceed.',
                ),
              ),
            ),
            _s(
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _SacrificeChamberCard(
                  challenge: challenge,
                  selectedInstance: selectedInstance,
                  selectedSpecies: selectedSpecies,
                  selectedCheck: selectedCheck,
                  isBusy:
                      selectedInstance != null &&
                      _busyInstanceId == selectedInstance.instanceId,
                  onTap: () =>
                      _openChamberSelection(rite: rite, challenge: challenge),
                  onSacrifice:
                      selectedInstance != null &&
                          selectedSpecies != null &&
                          selectedCheck?.isEligible == true &&
                          _busyInstanceId != selectedInstance.instanceId
                      ? () => _handleSacrifice(
                          rite: rite,
                          challenge: challenge,
                          species: selectedSpecies,
                          instance: selectedInstance,
                        )
                      : null,
                ),
              ),
            ),
            _s(
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
                child: _HkSectionHead(
                  title: 'Next Unlock',
                  sub: nextChallenge == null
                      ? 'One final perfect offering will complete the rite.'
                      : 'Complete ${challenge.shortTitle} to unlock '
                            '${nextChallenge.shortTitle}.',
                ),
              ),
            ),
            _s(
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 48),
                child: nextChallenge == null
                    ? const _PathEndCard()
                    : _NextRiteCard(
                        challenge: nextChallenge,
                        onTap: () => _showRecipeDialog(nextChallenge),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  SliverToBoxAdapter _s(Widget w) => SliverToBoxAdapter(child: w);

  Future<void> _openChamberSelection({
    required PurebloodRiteService rite,
    required PurebloodChallenge challenge,
  }) async {
    final theme = context.read<FactionTheme>();
    if (!mounted) return;

    final selected = await Navigator.of(context).push<CreatureInstance>(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) =>
            AllSpecimensPage(
              theme: theme,
              instancePrefsScopeKey: 'pureblood_rite_specimens',
              popOnSelect: true,
              searchHint: 'PLACE SPECIMEN',
              selectedInstanceIds: _selectedInstanceId == null
                  ? const []
                  : [_selectedInstanceId!],
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
    if (selected == null || !mounted) return;

    final check = rite.evaluate(selected, challenge: challenge);
    setState(() => _selectedInstanceId = selected.instanceId);

    if (!check.isEligible) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(check.message)));
    }
  }

  Future<void> _handleSacrifice({
    required PurebloodRiteService rite,
    required PurebloodChallenge challenge,
    required Creature species,
    required CreatureInstance instance,
  }) async {
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierLabel: 'confirm',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      pageBuilder: (_, __, ___) => Material(
        color: Colors.transparent,
        child: _HkConfirmDialog(species: species, instance: instance),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyInstanceId = instance.instanceId);
    try {
      HapticFeedback.heavyImpact();
      final result = await rite.sacrifice(
        instanceId: instance.instanceId,
        challenge: challenge,
        currentStageIndex: _stageIndex ?? 0,
      );
      if (mounted) {
        setState(() {
          _stageIndex = result.newStageIndex;
          _selectedInstanceId = null;
        });
      }
      if (!mounted) return;
      await showGeneralDialog<void>(
        context: context,
        barrierLabel: 'echo',
        barrierDismissible: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => Material(
          color: Colors.transparent,
          child: _RitualEchoOverlay(
            species: species,
            instance: instance,
            reward: result.goldEarned,
            nextChallengeTitle: result.nextChallenge?.shortTitle,
            completedRite: result.completedRite,
            completionBonusGold: result.completionBonusGold,
          ),
        ),
      );
      if (!mounted) return;
      if (result.completedRite) {
        await _maybeShowCompletionStory();
        if (!mounted) return;
        await _unlockCompletionShopEffect();
      }
    } on PurebloodRiteException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busyInstanceId = null);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PATH PROGRESS BAR
// ═══════════════════════════════════════════════════════════════════════════════
class _PathProgressBar extends StatelessWidget {
  const _PathProgressBar({
    required this.currentStageIndex,
    required this.currentChallenge,
    required this.nextChallenge,
    required this.challengeLadder,
    required this.onCompletedChallengeTap,
  });
  final int currentStageIndex;
  final PurebloodChallenge currentChallenge;
  final PurebloodChallenge? nextChallenge;
  final List<PurebloodChallenge> challengeLadder;
  final ValueChanged<PurebloodChallenge> onCompletedChallengeTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Rite Ladder', style: _fell(context, 15, _kIvoryDim, ls: 0.8)),
            const Spacer(),
            Text(
              '${currentStageIndex + 1} / ${PurebloodRiteService.totalChallenges}',
              style: _mono(context, 13, _kSoulBlue),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          currentChallenge.shortTitle,
          style: _fellItalic(context, 12, _kIvoryMuted),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 76,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: PurebloodRiteService.totalChallenges,
            itemBuilder: (context, i) {
              final status = i < currentStageIndex
                  ? _HkNodeStatus.done
                  : i == currentStageIndex
                  ? _HkNodeStatus.active
                  : _HkNodeStatus.sealed;
              final challenge = challengeLadder[i];
              return Row(
                children: [
                  _HkPathNode(
                    status: status,
                    index: i,
                    challenge: challenge,
                    onTap: status == _HkNodeStatus.done
                        ? () => onCompletedChallengeTap(challenge)
                        : null,
                  ),
                  if (i < PurebloodRiteService.totalChallenges - 1)
                    _HkConnector(lit: i < currentStageIndex),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

enum _HkNodeStatus { done, active, sealed }

class _HkPathNode extends StatelessWidget {
  const _HkPathNode({
    required this.status,
    required this.index,
    required this.challenge,
    this.onTap,
  });
  final _HkNodeStatus status;
  final int index;
  final PurebloodChallenge challenge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = status == _HkNodeStatus.active;
    final isDone = status == _HkNodeStatus.done;

    final node = SizedBox(
      width: 58,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          isActive
              ? _SoulOrb(
                  size: 46,
                  color: _kSoulBlue,
                  child: Text(
                    '${index + 1}',
                    style: _mono(context, 14, _kVoid, w: FontWeight.w700),
                  ),
                )
              : _HkCircleNode(
                  status: status,
                  index: index,
                  challenge: challenge,
                ),
          const SizedBox(height: 6),
          Text(
            '${index + 1}',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _mono(
              context,
              9,
              isActive
                  ? _kSoulBlue
                  : isDone
                  ? _kIvoryDim
                  : _kIvoryMuted,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return node;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: node,
    );
  }
}

class _HkCircleNode extends StatelessWidget {
  const _HkCircleNode({
    required this.status,
    required this.index,
    required this.challenge,
  });
  final _HkNodeStatus status;
  final int index;
  final PurebloodChallenge challenge;

  @override
  Widget build(BuildContext context) {
    final isDone = status == _HkNodeStatus.done;

    return SizedBox(
      width: 46,
      height: 46,
      child: CustomPaint(
        painter: _ScribbleCirclePainter(
          lit: isDone,
          color: isDone ? _kSoulGold : _kIvoryMuted,
        ),
        child: Center(
          child: isDone
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: ClipOval(
                        child: Container(
                          color: _kVoidLight,
                          child: _HkCreatureFrame(
                            species: challenge.previewSpecies,
                            size: 34,
                            previewSizeGene: challenge.requiredSize,
                            previewTintGene: challenge.requiredTint,
                            preferStaticImage: true,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _kSoulGold,
                          shape: BoxShape.circle,
                          border: Border.all(color: _kVoid, width: 1),
                        ),
                        child: const Icon(Icons.check, size: 10, color: _kVoid),
                      ),
                    ),
                  ],
                )
              : Text(
                  '${index + 1}',
                  style: _mono(
                    context,
                    12,
                    _kIvoryMuted.withValues(alpha: 0.55),
                    w: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

class _HkConnector extends StatelessWidget {
  const _HkConnector({required this.lit});
  final bool lit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 2,
      child: CustomPaint(painter: _DashConnectorPainter(lit: lit)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHALLENGE PANEL
// ═══════════════════════════════════════════════════════════════════════════════
class _ChallengePanel extends StatelessWidget {
  const _ChallengePanel({
    required this.challenge,
    required this.currentStageIndex,
    required this.onTap,
  });
  final PurebloodChallenge challenge;
  final int currentStageIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: _HkPanel(
        accentColor: _kBlood,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [_HkTag(label: 'CURRENT RITE', color: _kBlood)],
                  ),
                  const SizedBox(height: 12),
                  _AutoShrinkText(
                    challenge.shortTitle,
                    maxLines: 2,
                    minFontSize: 20,
                    style: _fell(context, 34, _kIvory, ls: 1.1),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Stage ${currentStageIndex + 1} of ${PurebloodRiteService.totalChallenges}',
                    style: _mono(context, 12, _kSoulBlue),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    challenge.vesselDescription,
                    style: _bask(context, 13, _kIvoryDim),
                  ),
                  const SizedBox(height: 14),
                  if (challenge.requireElementalPurity) ...[
                    _HkReqLine(
                      icon: Icons.opacity,
                      label: challenge.requiredElement == null
                          ? 'Elemental lineage — PURE'
                          : '${challenge.requiredElement} element line — PURE',
                      met: true,
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (challenge.requireSpeciesPurity) ...[
                    _HkReqLine(
                      icon: Icons.account_tree_outlined,
                      label: '${challenge.requiredFamily} species line — PURE',
                      met: true,
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (challenge.requiredTint != null) ...[
                    _HkReqLine(
                      icon:
                          tintIcons[challenge.requiredTint] ??
                          Icons.brightness_high_outlined,
                      label:
                          'Tinting — ${_traitLabel(challenge.requiredTint!)}',
                      met: true,
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (challenge.requiredSize != null) ...[
                    _HkReqLine(
                      icon: sizeIcons[challenge.requiredSize] ?? Icons.circle,
                      label: 'Size — ${_traitLabel(challenge.requiredSize!)}',
                      met: true,
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (challenge.requiredNature != null) ...[
                    _HkReqLine(
                      icon: Icons.psychology_alt_outlined,
                      label:
                          'Nature — ${_titleCaseLabel(challenge.requiredNature!)}',
                      met: true,
                    ),
                  ],
                  if (challenge.requiredVariantFaction != null) ...[
                    const SizedBox(height: 6),
                    _HkReqLine(
                      icon: Icons.scatter_plot_outlined,
                      label:
                          'Variant — ${_titleCaseLabel(challenge.requiredVariantFaction!)}',
                      met: true,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            _HkCreatureFrame(
              species: challenge.previewSpecies,
              size: 120,
              previewSizeGene: challenge.requiredSize,
              previewTintGene: challenge.requiredTint,
            ),
          ],
        ),
      ),
    );
  }
}

class _HkReqLine extends StatelessWidget {
  const _HkReqLine({
    required this.icon,
    required this.label,
    required this.met,
  });
  final IconData icon;
  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start, // Aligns icon with multi-line text
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: 2.0,
          ), // Nudges icon down to match text baseline
          child: Icon(icon, size: 13, color: met ? _kSoulBlue : _kIvoryMuted),
        ),
        const SizedBox(width: 8),
        Expanded(
          // <--- THIS PREVENTS THE OVERFLOW
          child: Text(
            label,
            style: _bask(context, 12.5, met ? _kIvoryDim : _kIvoryMuted),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRI-STAT ROW
// ═══════════════════════════════════════════════════════════════════════════════
class _TriStatRow extends StatelessWidget {
  const _TriStatRow({
    required this.ownedCount,
    required this.eligibleCount,
    required this.stageStep,
    required this.challenge,
    required this.onOwnedTap,
    required this.onEligibleTap,
    this.stageLabel = 'STAGE',
  });
  final int ownedCount, eligibleCount, stageStep;
  final PurebloodChallenge challenge;
  final VoidCallback onOwnedTap;
  final VoidCallback onEligibleTap;
  final String stageLabel;

  @override
  Widget build(BuildContext context) {
    final elColor = BreedConstants.getTypeColor(challenge.accentElement);
    return Row(
      children: [
        Expanded(
          child: _HkStat(
            label: 'OWNED',
            value: '$ownedCount',
            color: _kIvoryDim,
            onTap: onOwnedTap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _HkStat(
            label: 'ELIGIBLE',
            value: '$eligibleCount',
            color: _kSealGreenBr,
            onTap: onEligibleTap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _HkStat(label: stageLabel, value: '$stageStep', color: elColor),
        ),
      ],
    );
  }
}

class _HkStat extends StatelessWidget {
  const _HkStat({
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });
  final String label, value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 70,
        child: CustomPaint(
          painter: _CornerBracketPainter(
            color: _kIvoryMuted.withValues(alpha: 0.28),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(label, style: _mono(context, 9, _kIvoryMuted)),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value, style: _fell(context, 26, color)),
                    ),
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

// ═══════════════════════════════════════════════════════════════════════════════
// SACRIFICIAL CHAMBER
// ═══════════════════════════════════════════════════════════════════════════════
class _SacrificeChamberCard extends StatelessWidget {
  const _SacrificeChamberCard({
    required this.challenge,
    required this.selectedInstance,
    required this.selectedSpecies,
    required this.selectedCheck,
    required this.isBusy,
    required this.onTap,
    required this.onSacrifice,
  });

  final PurebloodChallenge challenge;
  final CreatureInstance? selectedInstance;
  final Creature? selectedSpecies;
  final PurebloodSacrificeCheck? selectedCheck;
  final bool isBusy;
  final VoidCallback onTap;
  final VoidCallback? onSacrifice;

  @override
  Widget build(BuildContext context) {
    final species = selectedSpecies;
    final check = selectedCheck;
    final hasSelection = selectedInstance != null && species != null;
    final canSacrifice = onSacrifice != null;
    final nickname = selectedInstance?.nickname?.trim();
    final title = nickname != null && nickname.isNotEmpty
        ? nickname
        : species?.name ?? 'Empty Chamber';
    final borderColor = check == null
        ? _kIvoryMuted.withValues(alpha: 0.30)
        : check.isEligible
        ? _kSealGreenBr.withValues(alpha: 0.55)
        : _kBlood.withValues(alpha: 0.50);

    return CustomPaint(
      painter: _CornerBracketPainter(
        color: borderColor,
        strokeWidth: 1.4,
        bracketSize: 18,
      ),
      child: Container(
        color: _kVoidLight,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _HkTag(label: 'CHAMBER', color: _kSoulBlue, small: true),
                const Spacer(),
                if (selectedInstance != null)
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        'PLACED VESSEL',
                        style: _mono(context, 10, _kIvoryMuted),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: selectedInstance == null || species == null
                  ? const _EmptyChamberPreview()
                  : Row(
                      key: ValueKey(selectedInstance!.instanceId),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HkCreatureFrame(
                          species: species,
                          instance: selectedInstance,
                          size: 90,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: _fell(context, 18, _kIvory),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Lv ${selectedInstance!.level}  ·  ${species.rarity.toUpperCase()}',
                                style: _mono(context, 11, _kIvoryMuted),
                              ),
                              const SizedBox(height: 10),
                              if (challenge.requireElementalPurity) ...[
                                _LineageRow(
                                  label: _elementLineLabel(challenge),
                                  pure: check?.pureElement ?? false,
                                ),
                                const SizedBox(height: 4),
                              ],
                              if (challenge.requireSpeciesPurity) ...[
                                _LineageRow(
                                  label:
                                      '${challenge.requiredFamily} species line',
                                  pure: check?.pureFamily ?? false,
                                ),
                                const SizedBox(height: 4),
                              ],
                              if (challenge.requiredTint != null) ...[
                                _LineageRow(
                                  label:
                                      'Tinting: ${_traitLabel(challenge.requiredTint!)}',
                                  pure: check?.matchesTint ?? false,
                                  successLabel: 'met',
                                ),
                                const SizedBox(height: 4),
                              ],
                              if (challenge.requiredSize != null) ...[
                                _LineageRow(
                                  label:
                                      'Size: ${_traitLabel(challenge.requiredSize!)}',
                                  pure: check?.matchesSize ?? false,
                                  successLabel: 'met',
                                ),
                                const SizedBox(height: 4),
                              ],
                              if (challenge.requiredNature != null) ...[
                                _LineageRow(
                                  label:
                                      'Nature: ${_titleCaseLabel(challenge.requiredNature!)}',
                                  pure: check?.matchesNature ?? false,
                                  successLabel: 'met',
                                ),
                              ],
                              if (challenge.requiredVariantFaction != null) ...[
                                const SizedBox(height: 4),
                                _LineageRow(
                                  label:
                                      'Variant: ${_titleCaseLabel(challenge.requiredVariantFaction!)}',
                                  pure: check?.matchesVariant ?? false,
                                  successLabel: 'met',
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: _HkTag(
                label: canSacrifice ? 'READY' : 'JUDGEMENT',
                color: canSacrifice ? _kSealGreenBr : _kBlood,
                small: true,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                !hasSelection
                    ? 'No specimen placed.'
                    : check?.isEligible == true
                    ? 'The altar accepts this vessel.'
                    : 'This vessel is not worthy.',
                style: _fell(context, 18, _kIvory),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                !hasSelection
                    ? 'Choose any specimen. The altar will judge whether it is worthy.'
                    : check?.message ?? 'Awaiting judgement.',
                style: _bask(context, 13, _kIvoryDim),
              ),
            ),
            const SizedBox(height: 16),
            _ChamberActionButton(
              label: selectedInstance == null
                  ? 'Place Specimen'
                  : 'Change Specimen',
              onTap: isBusy ? null : onTap,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _WideSacrificeButton(
                enabled: canSacrifice,
                busy: isBusy,
                label: 'Perform Ritual',
                onTap: onSacrifice,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChamberPreview extends StatelessWidget {
  const _EmptyChamberPreview();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final orbSize = math.min(52.0, constraints.maxWidth * 0.18);
        return Padding(
          key: const ValueKey('empty-chamber'),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * 0.82,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _AltarLoader(size: orbSize, compact: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose any specimen. The altar will judge whether it is worthy.',
                          softWrap: true,
                          style: _bask(context, 12, _kIvoryMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WideSacrificeButton extends StatelessWidget {
  const _WideSacrificeButton({
    required this.enabled,
    required this.busy,
    required this.label,
    required this.onTap,
  });

  final bool enabled;
  final bool busy;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = enabled
        ? _kBlood.withValues(alpha: 0.80)
        : _kIvoryMuted.withValues(alpha: 0.28);
    final textColor = enabled ? _kIvory : _kIvoryMuted;

    return GestureDetector(
      onTap: enabled && !busy ? onTap : null,
      child: CustomPaint(
        painter: _CornerBracketPainter(
          color: borderColor,
          bracketSize: 12,
          strokeWidth: 1.2,
        ),
        child: Container(
          color: enabled ? _kBlood.withValues(alpha: 0.10) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Center(
            child: busy
                ? _AltarLoader(
                    size: 26,
                    accent: textColor,
                    secondary: borderColor,
                    compact: true,
                  )
                : Text(label, style: _fell(context, 15, textColor)),
          ),
        ),
      ),
    );
  }
}

class _ChamberActionButton extends StatelessWidget {
  const _ChamberActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: _kIvory,
          side: BorderSide(
            color: (onTap == null ? _kIvoryMuted : _kSoulBlue).withValues(
              alpha: 0.65,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          backgroundColor: (onTap == null ? _kVoid : _kSoulBlue).withValues(
            alpha: onTap == null ? 0.08 : 0.08,
          ),
        ),
        child: Text(
          label,
          style: _fell(context, 15, onTap == null ? _kIvoryMuted : _kIvory),
        ),
      ),
    );
  }
}

class _AltarLoader extends StatefulWidget {
  const _AltarLoader({
    required this.size,
    this.accent = _kSoulBlue,
    this.secondary = _kSoulGold,
    this.compact = false,
  });

  final double size;
  final Color accent;
  final Color secondary;
  final bool compact;

  @override
  State<_AltarLoader> createState() => _AltarLoaderState();
}

class _AltarLoaderState extends State<_AltarLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.compact ? 1200 : 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          final orbitRadius = widget.size * (widget.compact ? 0.28 : 0.32);
          final coreSize = widget.size * (widget.compact ? 0.34 : 0.42);

          Widget orbitDot({
            required double angle,
            required Color color,
            required double scale,
          }) {
            final x = math.cos(angle) * orbitRadius;
            final y = math.sin(angle) * orbitRadius;
            return Transform.translate(
              offset: Offset(x, y),
              child: Container(
                width: widget.size * scale,
                height: widget.size * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.92),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: widget.size * 0.12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            );
          }

          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: math.pi * 2 * t,
                child: Container(
                  width: widget.size * 0.92,
                  height: widget.size * 0.92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.accent.withValues(alpha: 0.18),
                      width: widget.compact ? 1.0 : 1.2,
                    ),
                  ),
                ),
              ),
              orbitDot(
                angle: math.pi * 2 * t,
                color: widget.accent,
                scale: widget.compact ? 0.11 : 0.10,
              ),
              orbitDot(
                angle: math.pi * 2 * t + (math.pi * 2 / 3),
                color: widget.secondary,
                scale: widget.compact ? 0.09 : 0.085,
              ),
              orbitDot(
                angle: math.pi * 2 * t + (math.pi * 4 / 3),
                color: _kBlood,
                scale: widget.compact ? 0.08 : 0.075,
              ),
              Container(
                width: coreSize,
                height: coreSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.secondary.withValues(alpha: 0.28),
                      widget.accent.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                  border: Border.all(
                    color: widget.secondary.withValues(alpha: 0.55),
                    width: widget.compact ? 1.0 : 1.2,
                  ),
                ),
                child: Center(
                  child: Transform.rotate(
                    angle: -math.pi * 2 * t * 0.8,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: widget.size * (widget.compact ? 0.22 : 0.24),
                      color: widget.secondary,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LineageRow extends StatelessWidget {
  const _LineageRow({
    required this.label,
    required this.pure,
    this.successLabel = 'PURE',
  });
  final String label;
  final bool pure;
  final String successLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CustomPaint(painter: _ScratchMarkPainter(checked: pure)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                label,
                style: _bask(context, 12.5, pure ? _kIvoryDim : _kIvoryMuted),
              ),
              if (pure)
                Text(
                  '— $successLabel',
                  style: _fellItalic(context, 11, _kSoulBlue),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NEXT RITE CARD
// ═══════════════════════════════════════════════════════════════════════════════
class _NextRiteCard extends StatelessWidget {
  const _NextRiteCard({required this.challenge, required this.onTap});
  final PurebloodChallenge challenge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: _CornerBracketPainter(
          color: _kIvoryMuted.withValues(alpha: 0.22),
          bracketSize: 16,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _HkCreatureFrame(
                species: challenge.previewSpecies,
                size: 72,
                dimmed: true,
                previewSizeGene: challenge.requiredSize,
                previewTintGene: challenge.requiredTint,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _HkTag(
                          label: 'SEALED',
                          color: _kIvoryMuted,
                          small: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _AutoShrinkText(
                      challenge.shortTitle,
                      maxLines: 2,
                      minFontSize: 13,
                      style: _fell(context, 17, _kIvoryDim),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      challenge.vesselDescription,
                      style: _mono(context, 11, _kIvoryMuted),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.lock_outline,
                color: _kIvoryMuted.withValues(alpha: 0.40),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiteRecipeDialog extends StatefulWidget {
  const _RiteRecipeDialog({required this.challenge});

  final PurebloodChallenge challenge;

  @override
  State<_RiteRecipeDialog> createState() => _RiteRecipeDialogState();
}

class _RiteRecipeDialogState extends State<_RiteRecipeDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    return Center(
      child: FadeTransition(
        opacity: _ctrl,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.05),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)),
          child: Container(
            width: 360,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: CustomPaint(
              painter: _CornerBracketPainter(
                color: _kSoulBlue.withValues(alpha: 0.60),
                strokeWidth: 1.4,
                bracketSize: 20,
              ),
              child: Container(
                color: _kVoidLight,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _AutoShrinkText(
                                challenge.shortTitle,
                                maxLines: 2,
                                minFontSize: 18,
                                style: _fell(context, 24, _kIvory, ls: 0.7),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '1x ${challenge.shortTitle}',
                                style: _mono(context, 12, _kSoulBlue),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        _HkCreatureFrame(
                          species: challenge.previewSpecies,
                          size: 84,
                          previewSizeGene: challenge.requiredSize,
                          previewTintGene: challenge.requiredTint,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    for (final requirement in challenge.requirementLines) ...[
                      _RecipeDetailLine(label: requirement),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 180,
                      child: _HkBtn(
                        label: 'Close',
                        onTap: () => Navigator.of(context).pop(),
                        primary: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipeDetailLine extends StatelessWidget {
  const _RecipeDetailLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: _kSoulBlue,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: _bask(context, 13, _kIvoryDim))),
      ],
    );
  }
}

class _RiteSpecimenEntry {
  const _RiteSpecimenEntry({
    required this.instance,
    required this.species,
    required this.check,
  });

  final CreatureInstance instance;
  final Creature species;
  final PurebloodSacrificeCheck check;

  String get displayName {
    final nickname = instance.nickname?.trim();
    if (nickname != null && nickname.isNotEmpty) return nickname;
    return species.name;
  }
}

class _RiteSpecimenDialog extends StatefulWidget {
  const _RiteSpecimenDialog({
    required this.title,
    required this.emptyMessage,
    required this.entries,
  });

  final String title;
  final String emptyMessage;
  final List<_RiteSpecimenEntry> entries;

  @override
  State<_RiteSpecimenDialog> createState() => _RiteSpecimenDialogState();
}

class _RiteSpecimenDialogState extends State<_RiteSpecimenDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeTransition(
        opacity: _ctrl,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.05),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)),
          child: Container(
            width: 380,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: CustomPaint(
              painter: _CornerBracketPainter(
                color: _kSoulBlue.withValues(alpha: 0.60),
                strokeWidth: 1.4,
                bracketSize: 20,
              ),
              child: Container(
                color: _kVoidLight,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HkTag(label: 'SPECIMENS', color: _kSoulBlue),
                    const SizedBox(height: 12),
                    Text(
                      widget.title,
                      style: _fell(context, 24, _kIvory, ls: 0.6),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.entries.length} shown',
                      style: _mono(context, 12, _kIvoryMuted),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: widget.entries.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Text(
                                widget.emptyMessage,
                                style: _bask(context, 13, _kIvoryDim),
                              ),
                            )
                          : Scrollbar(
                              thumbVisibility: true,
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: widget.entries.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final entry = widget.entries[index];
                                  final statusLabel = entry.check.isEligible
                                      ? 'READY'
                                      : entry.check.isProtected
                                      ? 'LOCKED'
                                      : 'MISSING';
                                  final statusColor = entry.check.isEligible
                                      ? _kSealGreenBr
                                      : entry.check.isProtected
                                      ? _kBlood
                                      : _kIvoryMuted;

                                  return CustomPaint(
                                    painter: _CornerBracketPainter(
                                      color: statusColor.withValues(
                                        alpha: 0.35,
                                      ),
                                      bracketSize: 12,
                                      strokeWidth: 1.1,
                                    ),
                                    child: Container(
                                      color: _kVoid.withValues(alpha: 0.18),
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _HkCreatureFrame(
                                            species: entry.species,
                                            instance: entry.instance,
                                            size: 56,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  entry.displayName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: _fell(
                                                    context,
                                                    16,
                                                    _kIvory,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Lv ${entry.instance.level}  ·  ${entry.species.rarity.toUpperCase()}',
                                                  style: _mono(
                                                    context,
                                                    11,
                                                    _kIvoryMuted,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  entry.check.message,
                                                  style: _bask(
                                                    context,
                                                    12,
                                                    _kIvoryDim,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            statusLabel,
                                            style: _mono(
                                              context,
                                              10,
                                              statusColor,
                                              w: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 180,
                      child: _HkBtn(
                        label: 'Close',
                        onTap: () => Navigator.of(context).pop(),
                        primary: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WEEKLY CHALLENGE WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════
class _WeeklyChallengePanel extends StatelessWidget {
  const _WeeklyChallengePanel({
    required this.challenge,
    required this.isCompleted,
    required this.onTap,
  });
  final PurebloodChallenge challenge;
  final bool isCompleted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accentColor = isCompleted ? _kSoulGold : _kSoulBlue;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: _HkPanel(
        accentColor: accentColor,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _HkTag(
                        label: isCompleted ? 'COMPLETED' : 'WEEKLY OFFER',
                        color: accentColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _AutoShrinkText(
                    challenge.shortTitle,
                    maxLines: 2,
                    minFontSize: 18,
                    style: _fell(context, 30, _kIvory, ls: 0.8),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '+${challenge.goldReward} Gold Reward',
                    style: _mono(context, 12, _kSoulGold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    challenge.vesselDescription,
                    style: _bask(context, 13, _kIvoryDim),
                  ),
                  const SizedBox(height: 14),
                  if (challenge.requireElementalPurity) ...[
                    _HkReqLine(
                      icon: Icons.opacity,
                      label: challenge.requiredElement == null
                          ? 'Elemental lineage — PURE'
                          : '${challenge.requiredElement} element line — PURE',
                      met: true,
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (challenge.requireSpeciesPurity) ...[
                    _HkReqLine(
                      icon: Icons.account_tree_outlined,
                      label: '${challenge.requiredFamily} species line — PURE',
                      met: true,
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (challenge.requiredSize != null) ...[
                    _HkReqLine(
                      icon: sizeIcons[challenge.requiredSize] ?? Icons.circle,
                      label: 'Size — ${_traitLabel(challenge.requiredSize!)}',
                      met: true,
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (challenge.requiredTint != null) ...[
                    _HkReqLine(
                      icon: tintIcons[challenge.requiredTint] ??
                          Icons.brightness_high_outlined,
                      label: 'Pigmentation — ${_traitLabel(challenge.requiredTint!)}',
                      met: true,
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (challenge.requiredNature != null) ...[
                    _HkReqLine(
                      icon: Icons.psychology_alt_outlined,
                      label:
                          'Nature — ${_titleCaseLabel(challenge.requiredNature!)}',
                      met: true,
                    ),
                  ],
                  if (challenge.requiredVariantFaction != null) ...[
                    const SizedBox(height: 6),
                    _HkReqLine(
                      icon: Icons.scatter_plot_outlined,
                      label:
                          'Variant — ${_titleCaseLabel(challenge.requiredVariantFaction!)}',
                      met: true,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            _HkCreatureFrame(
              species: challenge.previewSpecies,
              size: 110,
              previewSizeGene: challenge.requiredSize,
              previewTintGene: challenge.requiredTint,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyCompleteCard extends StatelessWidget {
  const _WeeklyCompleteCard({
    required this.resetDays,
    required this.resetHours,
  });
  final int resetDays;
  final int resetHours;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CornerBracketPainter(
        color: _kSoulGold.withValues(alpha: 0.45),
        bracketSize: 16,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              color: _kSoulGold,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly offering accepted.',
                    style: _fell(context, 15, _kSoulGold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Return when the altar resets in '
                    '${resetDays}d ${resetHours}h.',
                    style: _bask(context, 13, _kIvoryDim),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PathEndCard extends StatelessWidget {
  const _PathEndCard();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CornerBracketPainter(
        color: _kSoulGold.withValues(alpha: 0.45),
        bracketSize: 16,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              color: _kSoulGold,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The Final Rite Awaits',
                    style: _fell(context, 16, _kSoulGold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Complete the current offering to finish the altar forever.',
                    style: _bask(context, 13, _kIvoryDim),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIRM DIALOG
// ═══════════════════════════════════════════════════════════════════════════════
class _HkConfirmDialog extends StatefulWidget {
  const _HkConfirmDialog({required this.species, required this.instance});
  final Creature species;
  final CreatureInstance instance;

  @override
  State<_HkConfirmDialog> createState() => _HkConfirmDialogState();
}

class _HkConfirmDialogState extends State<_HkConfirmDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeTransition(
        opacity: _ctrl,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)),
          child: Container(
            width: 320,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: CustomPaint(
              painter: _CornerBracketPainter(
                color: _kBlood.withValues(alpha: 0.70),
                strokeWidth: 1.5,
                bracketSize: 20,
              ),
              child: Container(
                color: _kVoidLight,
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Perform this ritual?',
                      style: _fell(context, 22, _kIvory),
                    ),
                    const SizedBox(height: 6),
                    _HkDivider(),
                    const SizedBox(height: 14),
                    _HkCreatureFrame(
                      species: widget.species,
                      instance: widget.instance,
                      size: 88,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.species.name,
                      style: _fell(context, 18, _kIvoryDim),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The creature will be consumed by the altar. This cannot be undone.',
                      style: _bask(context, 13, _kIvoryMuted),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: _HkBtn(
                            label: 'Turn Back',
                            onTap: () => Navigator.of(context).pop(false),
                            primary: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _HkBtn(
                            label: 'Perform Ritual',
                            onTap: () => Navigator.of(context).pop(true),
                            primary: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RiteStoryDialog extends StatefulWidget {
  const _RiteStoryDialog({this.title, required this.body});

  final String? title;
  final String body;

  @override
  State<_RiteStoryDialog> createState() => _RiteStoryDialogState();
}

class _RiteStoryDialogState extends State<_RiteStoryDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeTransition(
        opacity: _ctrl,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.05),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)),
          child: Container(
            width: 360,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: CustomPaint(
              painter: _CornerBracketPainter(
                color: _kSoulGold.withValues(alpha: 0.55),
                strokeWidth: 1.4,
                bracketSize: 20,
              ),
              child: Container(
                color: _kVoidLight,
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HkTag(label: 'STORY', color: _kSoulGold),
                    const SizedBox(height: 14),
                    if (widget.title != null) ...[
                      Text(
                        widget.title!,
                        style: _fell(context, 24, _kIvory, ls: 0.6),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      widget.body,
                      style: _bask(
                        context,
                        widget.title == null ? 18 : 15,
                        _kIvoryDim,
                        h: 1.7,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 180,
                      child: _HkBtn(
                        label: 'Continue',
                        onTap: () => Navigator.of(context).pop(),
                        primary: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RITUAL ECHO OVERLAY
// ═══════════════════════════════════════════════════════════════════════════════
class _RitualEchoOverlay extends StatefulWidget {
  const _RitualEchoOverlay({
    required this.species,
    required this.instance,
    required this.reward,
    this.nextChallengeTitle,
    required this.completedRite,
    required this.completionBonusGold,
  });
  final Creature species;
  final CreatureInstance instance;
  final int reward;
  final String? nextChallengeTitle;
  final bool completedRite;
  final int completionBonusGold;

  @override
  State<_RitualEchoOverlay> createState() => _RitualEchoOverlayState();
}

class _RitualEchoOverlayState extends State<_RitualEchoOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _crackCtrl;
  late final AnimationController _dissolveCtrl;
  late final AnimationController _particleCtrl;
  late final AnimationController _wispCtrl;
  late final AnimationController _exitCtrl;

  final List<String> _lines = [];
  int _visibleChars = 0;
  Timer? _typeTimer;
  int _displayedGold = 0;
  Timer? _goldTimer;

  @override
  void initState() {
    super.initState();
    _lines.addAll([
      'The altar accepts the offering.',
      '${widget.species.name} dissolves into the void.',
      if (widget.completionBonusGold > 0)
        'Completion reward: +${widget.completionBonusGold} gold.',
      if (widget.completedRite)
        'The rite stands complete.'
      else if (widget.nextChallengeTitle != null)
        '${widget.nextChallengeTitle} — unsealed.',
    ]);

    _crackCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _dissolveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4300),
    );
    _wispCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    )..repeat();
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _dissolveCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 380), () {
      if (mounted) _particleCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 1020), _startTypewriter);
    Future.delayed(const Duration(milliseconds: 1380), _startGoldCounter);
  }

  void _startTypewriter() {
    final full = _lines.join('\n');
    _typeTimer = Timer.periodic(const Duration(milliseconds: 30), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_visibleChars < full.length) {
        setState(() => _visibleChars++);
      } else {
        t.cancel();
      }
    });
  }

  Future<void> _closeOverlay() async {
    if (_exitCtrl.isAnimating || _exitCtrl.isCompleted || !mounted) return;
    await _exitCtrl.forward();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _startGoldCounter() {
    final target = widget.reward;
    var step = 0;
    const steps = 28;
    _goldTimer = Timer.periodic(const Duration(milliseconds: 42), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      step++;
      setState(
        () =>
            _displayedGold = ((step / steps) * target).round().clamp(0, target),
      );
      if (step >= steps) t.cancel();
    });
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _goldTimer?.cancel();
    _crackCtrl.dispose();
    _dissolveCtrl.dispose();
    _particleCtrl.dispose();
    _wispCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final fullText = _lines.join('\n');
    final visText = fullText.substring(
      0,
      _visibleChars.clamp(0, fullText.length),
    );
    final primaryColor = _sacrificePrimaryColor(widget.species);
    final secondaryColor = _sacrificeSecondaryColor(
      widget.species,
      primaryColor,
    );
    final glowColor = _sacrificeGlowColor(primaryColor, secondaryColor);

    return AnimatedBuilder(
      animation: Listenable.merge([
        _crackCtrl,
        _dissolveCtrl,
        _particleCtrl,
        _wispCtrl,
        _exitCtrl,
      ]),
      builder: (context, _) {
        final exitT = Curves.easeIn.transform(_exitCtrl.value);
        final crackT = Curves.easeOut.transform(_crackCtrl.value);
        final dissolveT = Curves.easeIn.transform(_dissolveCtrl.value);
        final particleT = Curves.easeInCubic.transform(_particleCtrl.value);
        final shakeOffset = _ritualShakeOffset(
          crackProgress: crackT,
          dissolveProgress: dissolveT,
        );
        return Opacity(
          opacity: (1.0 - exitT).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: shakeOffset,
            child: Stack(
              children: [
                Container(color: _kVoid),
                // Crack lines
                CustomPaint(
                  size: size,
                  painter: _AltarCrackPainter(
                    progress: crackT,
                    center: Offset(size.width * 0.5, size.height * 0.36),
                  ),
                ),
                // Rising wisps
                RepaintBoundary(
                  child: CustomPaint(
                    size: size,
                    painter: _WispFgPainter(
                      _wispCtrl.value,
                      primaryColor: primaryColor,
                      secondaryColor: secondaryColor,
                      glowColor: glowColor,
                    ),
                  ),
                ),
                // Dissolving creature
                Positioned(
                  top: size.height * 0.14,
                  left: size.width * 0.5 - 90,
                  child: _DissolvingCreature(
                    species: widget.species,
                    instance: widget.instance,
                    size: 180,
                    progress: dissolveT,
                    streamProgress: particleT,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    glowColor: glowColor,
                  ),
                ),
                // Text + gold bottom panel
                Positioned(
                  left: 32,
                  right: 32,
                  bottom: size.height * 0.10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '+$_displayedGold',
                        style: _fell(context, 52, _kSoulGold, ls: 2),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'gold received',
                        style: _fellItalic(context, 14, _kSoulGold),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        visText,
                        style: _bask(context, 14, _kIvoryDim, h: 1.8),
                      ),
                      const SizedBox(height: 22),
                      if (_dissolveCtrl.value > 0.7)
                        SizedBox(
                          width: 180,
                          child: _HkBtn(
                            label: 'Continue',
                            onTap: _closeOverlay,
                            primary: true,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Creature dissolving upward
class _DissolvingCreature extends StatelessWidget {
  const _DissolvingCreature({
    required this.species,
    required this.instance,
    required this.size,
    required this.progress,
    required this.streamProgress,
    required this.primaryColor,
    required this.secondaryColor,
    required this.glowColor,
  });
  final Creature species;
  final CreatureInstance instance;
  final double size;
  final double progress;
  final double streamProgress;
  final Color primaryColor;
  final Color secondaryColor;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    final spriteOpacity = (1.0 - progress * 1.08).clamp(0.0, 1.0);
    final emberOpacity = (progress * 2.0 - 0.08).clamp(0.0, 1.0);
    final emberFade =
        (1.0 - progress * 0.34).clamp(0.0, 1.0) *
        (1.0 - streamProgress * 0.92).clamp(0.0, 1.0);
    final palette = <Color>[
      primaryColor,
      secondaryColor,
      glowColor,
      Color.lerp(primaryColor, Colors.white, 0.36) ?? primaryColor,
    ];

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            child: Container(
              width: size * (0.62 + progress * 0.28),
              height: size * (0.62 + progress * 0.28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    glowColor.withValues(alpha: 0.28 * (1.0 - progress * 0.35)),
                    primaryColor.withValues(
                      alpha: 0.12 * (1.0 - progress * 0.25),
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Opacity(
            opacity: spriteOpacity,
            child: Transform.scale(
              scale: 1.0 - progress * 0.08,
              child: Transform.translate(
                offset: Offset(0, -40 * progress),
                child: _HkCreatureFrame(
                  species: species,
                  instance: instance,
                  size: size,
                ),
              ),
            ),
          ),
          for (var i = 0; i < 28; i++)
            Positioned(
              left:
                  size * 0.5 +
                  math.sin(
                        i * 0.74 +
                            progress * (5.8 + (i % 4) * 0.3) +
                            streamProgress * (3.5 + (i % 3) * 0.6),
                      ) *
                      size *
                      (0.06 + (i % 5) * 0.02 + streamProgress * 0.06) -
                  (3.0 + (i % 4) * 1.5),
              top:
                  size * 0.64 -
                  size *
                      (progress * (0.22 + (i % 7) * 0.03) +
                          streamProgress * (0.90 + (i % 5) * 0.08)) +
                  math.cos(
                        i * 0.58 +
                            progress * 4.2 +
                            streamProgress * (5.0 + (i % 4) * 0.5),
                      ) *
                      size *
                      0.03,
              child: Opacity(
                opacity:
                    emberOpacity *
                    emberFade *
                    (0.60 + (i % 4) * 0.08).clamp(0.0, 1.0),
                child: Container(
                  width: 3.0 + (i % 4) * 1.5,
                  height: 6.0 + (i % 5) * 2.0,
                  decoration: BoxDecoration(
                    color: palette[i % palette.length].withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: palette[i % palette.length].withValues(
                          alpha: 0.25,
                        ),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          for (var i = 0; i < 18; i++)
            Positioned(
              left:
                  size * 0.5 +
                  math.cos(
                        i * 0.62 +
                            progress * (7.5 + (i % 3) * 0.6) +
                            streamProgress * (4.8 + (i % 4) * 0.7),
                      ) *
                      size *
                      (0.12 + progress * 0.18 + streamProgress * 0.12) -
                  (2.5 + (i % 3) * 1.2),
              top:
                  size * 0.56 -
                  size *
                      (progress * (0.12 + (i % 5) * 0.05) +
                          streamProgress * (1.0 + (i % 4) * 0.10)) +
                  math.sin(
                        i * 0.91 +
                            progress * 6.0 +
                            streamProgress * (6.2 + (i % 3) * 0.4),
                      ) *
                      size *
                      0.05,
              child: Transform.rotate(
                angle:
                    i * 0.48 +
                    progress * 8.0 +
                    streamProgress * (6.0 + i * 0.02),
                child: Opacity(
                  opacity:
                      (progress * 1.9).clamp(0.0, 1.0) *
                      (1.0 - progress * 0.20).clamp(0.0, 1.0) *
                      (1.0 - streamProgress * 0.95).clamp(0.0, 1.0),
                  child: Container(
                    width: 2.5 + (i % 3) * 1.2,
                    height: 12.0 + (i % 4) * 2.5,
                    decoration: BoxDecoration(
                      color: palette[(i + 1) % palette.length].withValues(
                        alpha: 0.78,
                      ),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: palette[(i + 1) % palette.length].withValues(
                            alpha: 0.24,
                          ),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════
class _SoulOrb extends StatefulWidget {
  const _SoulOrb({required this.size, required this.color, this.child});
  final double size;
  final Color color;
  final Widget? child;

  @override
  State<_SoulOrb> createState() => _SoulOrbState();
}

class _SoulOrbState extends State<_SoulOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) {
          final t = _ctrl.value;
          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  widget.color.withValues(alpha: 0.28 + t * 0.18),
                  widget.color.withValues(alpha: 0.06 + t * 0.06),
                  Colors.transparent,
                ],
              ),
              border: Border.all(
                color: widget.color.withValues(alpha: 0.55 + t * 0.30),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.14 + t * 0.16),
                  blurRadius: 10 + t * 8,
                  spreadRadius: t * 2,
                ),
              ],
            ),
            child: Center(child: child),
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _HkPanel extends StatelessWidget {
  const _HkPanel({required this.child, this.accentColor = _kIvoryMuted});
  final Widget child;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CornerBracketPainter(
        color: accentColor.withValues(alpha: 0.55),
        strokeWidth: 1.4,
        bracketSize: 22,
      ),
      child: Container(
        color: _kVoidLight,
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _HkCreatureFrame extends StatelessWidget {
  const _HkCreatureFrame({
    required this.species,
    required this.size,
    this.instance,
    this.previewSizeGene,
    this.previewTintGene,
    this.dimmed = false,
    this.preferStaticImage = false,
  });
  final Creature species;
  final double size;
  final CreatureInstance? instance;
  final String? previewSizeGene;
  final String? previewTintGene;
  final bool dimmed;
  final bool preferStaticImage;

  @override
  Widget build(BuildContext context) {
    final sprite = species.spriteData;
    final previewGenetics =
        instance == null && (previewSizeGene != null || previewTintGene != null)
        ? Genetics({
            ...?species.genetics?.variants,
            if (previewSizeGene != null) 'size': previewSizeGene!,
            if (previewTintGene != null) 'tinting': previewTintGene!,
          })
        : species.genetics;
    final scale = scaleFromGenes(previewGenetics);
    final saturation = satFromGenes(previewGenetics);
    final brightness = briFromGenes(previewGenetics);
    final hueShift = hueFromGenes(previewGenetics);
    final staticImage = Transform.scale(
      scale: scale,
      child: Image.asset(
        _creatureAssetPath(species),
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Image.asset(
          species.image,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.bug_report_rounded,
            color: _kIvoryMuted,
            size: size * 0.5,
          ),
        ),
      ),
    );
    return Opacity(
      opacity: dimmed ? 0.45 : 1.0,
      child: SizedBox(
        width: size,
        height: size,
        child: instance != null && !preferStaticImage
            ? InstanceSprite(creature: species, instance: instance!, size: size)
            : preferStaticImage
            ? staticImage
            : sprite != null
            ? RepaintBoundary(
                child: CreatureSprite(
                  spritePath: sprite.spriteSheetPath,
                  totalFrames: sprite.totalFrames,
                  rows: sprite.rows,
                  frameSize: Vector2(
                    sprite.frameWidth.toDouble(),
                    sprite.frameHeight.toDouble(),
                  ),
                  stepTime: sprite.frameDurationMs / 1000.0,
                  scale: scale,
                  saturation: saturation,
                  brightness: brightness,
                  hueShift: hueShift,
                  isPrismatic: species.isPrismaticSkin,
                  alchemyEffect: species.alchemyEffect,
                  variantFaction: species.variantFaction,
                  effectSlotSize: size,
                ),
              )
            : staticImage,
      ),
    );
  }
}

String _creatureAssetPath(Creature c) =>
    c.image.startsWith('assets/') ? c.image : 'assets/images/${c.image}';

class _HkTag extends StatelessWidget {
  const _HkTag({required this.label, required this.color, this.small = false});
  final String label;
  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 2,
          height: small ? 12 : 16,
          color: color.withValues(alpha: 0.80),
        ),
        const SizedBox(width: 6),
        Text(label, style: _mono(context, small ? 9 : 11, color)),
      ],
    );
  }
}

class _HkSectionHead extends StatelessWidget {
  const _HkSectionHead({required this.title, required this.sub});
  final String title, sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: _fell(context, 17, _kIvory, ls: 0.6)),
            const SizedBox(width: 12),
            Expanded(child: _HkDivider()),
          ],
        ),
        const SizedBox(height: 5),
        Text(sub, style: _bask(context, 12.5, _kIvoryMuted)),
      ],
    );
  }
}

class _HkDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: CustomPaint(painter: _ScribbleLinePainter()),
    );
  }
}

class _HkBackButton extends StatelessWidget {
  const _HkBackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: CustomPaint(
          painter: _CornerBracketPainter(
            color: _kIvoryMuted.withValues(alpha: 0.40),
            bracketSize: 8,
            strokeWidth: 1.0,
          ),
          child: const Icon(
            Icons.chevron_left_rounded,
            color: _kIvoryDim,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _RiteHeaderAction extends StatelessWidget {
  const _RiteHeaderAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints.tightFor(width: 58, height: 58),
        child: CustomPaint(
          painter: _CornerBracketPainter(
            color: _kSoulBlue.withValues(alpha: 0.52),
            bracketSize: 12,
            strokeWidth: 1.2,
          ),
          child: Container(
            color: _kVoidLight,
            child: Center(child: Icon(icon, color: _kSoulBlue, size: 28)),
          ),
        ),
      ),
    );
  }
}

class _HkBtn extends StatelessWidget {
  const _HkBtn({
    required this.label,
    required this.onTap,
    required this.primary,
  });
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _CornerBracketPainter(
          color: primary
              ? _kBlood.withValues(alpha: 0.80)
              : _kIvoryMuted.withValues(alpha: 0.30),
          bracketSize: 10,
          strokeWidth: 1.2,
        ),
        child: Container(
          color: primary ? _kBlood.withValues(alpha: 0.10) : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(
              label,
              style: _fell(context, 15, primary ? _kIvory : _kIvoryMuted),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CUSTOM PAINTERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Corner-bracket frame — the defining HK UI motif
class _CornerBracketPainter extends CustomPainter {
  const _CornerBracketPainter({
    this.color = _kIvoryMuted,
    this.strokeWidth = 1.2,
    this.bracketSize = 14,
  });
  final Color color;
  final double strokeWidth, bracketSize;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;
    final b = bracketSize;
    final w = size.width;
    final h = size.height;
    canvas.drawLine(Offset(0, b), Offset.zero, p);
    canvas.drawLine(Offset.zero, Offset(b, 0), p);
    canvas.drawLine(Offset(w - b, 0), Offset(w, 0), p);
    canvas.drawLine(Offset(w, 0), Offset(w, b), p);
    canvas.drawLine(Offset(0, h - b), Offset(0, h), p);
    canvas.drawLine(Offset(0, h), Offset(b, h), p);
    canvas.drawLine(Offset(w - b, h), Offset(w, h), p);
    canvas.drawLine(Offset(w, h), Offset(w, h - b), p);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

/// Imperfect hand-drawn circle
class _ScribbleCirclePainter extends CustomPainter {
  const _ScribbleCirclePainter({required this.lit, required this.color});
  final bool lit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) - 2;
    final p = Paint()
      ..color = color
      ..strokeWidth = lit ? 1.4 : 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    final wobble = lit ? 0.0 : 1.6;
    final rng = math.Random(42);
    const pts = 32;
    for (var i = 0; i <= pts; i++) {
      final angle = (math.pi * 2 / pts) * i;
      final w = wobble * (rng.nextDouble() - 0.5);
      final x = cx + math.cos(angle) * (r + w);
      final y = cy + math.sin(angle) * (r + w);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _ScribbleCirclePainter old) =>
      old.lit != lit || old.color != color;
}

/// Dashed path connector
class _DashConnectorPainter extends CustomPainter {
  const _DashConnectorPainter({required this.lit});
  final bool lit;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = lit
          ? _kSoulGold.withValues(alpha: 0.70)
          : _kIvoryMuted.withValues(alpha: 0.25)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final dashW = lit ? 4.0 : 2.5;
    final gapW = lit ? 2.0 : 3.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + dashW).clamp(0, size.width), size.height / 2),
        p,
      );
      x += dashW + gapW;
    }
  }

  @override
  bool shouldRepaint(covariant _DashConnectorPainter old) => old.lit != lit;
}

/// Checkmark or empty square scratch mark
class _ScratchMarkPainter extends CustomPainter {
  const _ScratchMarkPainter({required this.checked});
  final bool checked;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = checked ? _kSoulBlue : _kIvoryMuted.withValues(alpha: 0.40)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (checked) {
      canvas.drawPath(
        Path()
          ..moveTo(size.width * 0.10, size.height * 0.55)
          ..lineTo(size.width * 0.42, size.height * 0.82)
          ..lineTo(size.width * 0.90, size.height * 0.20),
        p,
      );
    } else {
      canvas.drawRect(Rect.fromLTWH(2, 2, size.width - 4, size.height - 4), p);
    }
  }

  @override
  bool shouldRepaint(covariant _ScratchMarkPainter old) =>
      old.checked != checked;
}

/// Slightly wobbly horizontal rule
class _ScribbleLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _kIvoryMuted.withValues(alpha: 0.22)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    final path = Path();
    final rng = math.Random(7);
    path.moveTo(0, size.height / 2);
    var x = 0.0;
    while (x < size.width) {
      x += 6.0;
      path.lineTo(x, size.height / 2 + (rng.nextDouble() - 0.5) * 1.5);
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Background soul wisps
class _WispBgPainter extends CustomPainter {
  const _WispBgPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 14; i++) {
      final phase = (t + i * 0.072) % 1.0;
      final x =
          size.width *
          (0.08 + (math.sin(i * 1.618 + phase * 2) * 0.5 + 0.5) * 0.84);
      final y = size.height * (1.05 - phase * 1.1);
      final alpha = math.sin(phase * math.pi) * 0.16;
      final r = 3.0 + (i % 4);
      if (y < -r || y > size.height + r) continue;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: r * 1.1, height: r * 1.9),
        Paint()..color = _kSoulBlue.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WispBgPainter old) => old.t != t;
}

/// Foreground wisps during sacrifice
class _WispFgPainter extends CustomPainter {
  const _WispFgPainter(
    this.t, {
    required this.primaryColor,
    required this.secondaryColor,
    required this.glowColor,
  });
  final double t;
  final Color primaryColor;
  final Color secondaryColor;
  final Color glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final palette = <Color>[
      primaryColor,
      secondaryColor,
      glowColor,
      _kSoulGold,
    ];
    for (var i = 0; i < 42; i++) {
      final phase = (t * (0.68 + i * 0.022) + i * 0.037) % 1.0;
      final sway =
          math.sin(phase * math.pi * 3.4 + i * 0.9) * (18 + (i % 4) * 6);
      final x = size.width * (0.10 + (i / 42.0) * 0.80) + sway;
      final y = size.height * (1.05 - phase * 1.2);
      final alpha = math.sin(phase * math.pi) * (0.07 + (i % 6) * 0.035);
      final r = 2.0 + (i % 6) * 0.9;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: r, height: r * 1.8),
        Paint()..color = palette[i % palette.length].withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WispFgPainter old) =>
      old.t != t ||
      old.primaryColor != primaryColor ||
      old.secondaryColor != secondaryColor ||
      old.glowColor != glowColor;
}

/// Crack lines radiating from center — sacrifice crack effect
class _AltarCrackPainter extends CustomPainter {
  const _AltarCrackPainter({required this.progress, required this.center});
  final double progress;
  final Offset center;

  static final List<List<Offset>> _cracks = _buildCracks();

  static List<List<Offset>> _buildCracks() {
    final rng = math.Random(1337);
    final cracks = <List<Offset>>[];
    for (var i = 0; i < 9; i++) {
      final baseAngle = (math.pi * 2 / 9) * i + rng.nextDouble() * 0.4;
      final pts = <Offset>[Offset.zero];
      var cur = Offset.zero;
      var angle = baseAngle;
      final segs = 3 + rng.nextInt(3);
      for (var s = 0; s < segs; s++) {
        angle += (rng.nextDouble() - 0.5) * 0.5;
        final len = 30.0 + rng.nextDouble() * 70;
        cur = Offset(
          cur.dx + math.cos(angle) * len,
          cur.dy + math.sin(angle) * len,
        );
        pts.add(cur);
      }
      cracks.add(pts);
    }
    return cracks;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _kBlood.withValues(alpha: 0.28 * progress)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    for (final crack in _cracks) {
      final path = Path();
      for (var i = 0; i < crack.length - 1; i++) {
        final sp = (progress * (crack.length - 1) - i).clamp(0.0, 1.0);
        if (sp <= 0) break;
        final start = crack[i];
        final end = Offset.lerp(crack[i], crack[i + 1], sp)!;
        if (i == 0) path.moveTo(start.dx, start.dy);
        path.lineTo(end.dx, end.dy);
      }
      canvas.drawPath(path, p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AltarCrackPainter old) =>
      old.progress != progress;
}
