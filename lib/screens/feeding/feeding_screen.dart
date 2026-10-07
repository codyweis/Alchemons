// lib/screens/feeding/feeding_screen.dart
//
// ENHANCE — one place to make one Alchemon stronger.
//
//   Pick an Alchemon, once. It stands on a lit floor, with its level and its
//   four stats under it, and one tray offers everything that can raise them:
//
//     XP     spare Alchemons of the same species, given up for XP and levels
//     ORBS   Power Orbs, dragged onto it, one Enhancement rank each
//     SOULS  Potential Souls, which raise one Potential
//
//   Kin come apart into grains and pour into it; orbs lob in; a soul burns
//   above its head and plunges. Whatever it is, the readouts below show what
//   it will do before you commit, and count it up after.
//
// This replaced a two-door entry (a three-step sacrifice wizard and a
// separate Stat Infusion screen), each with its own picker.

import 'dart:async' show unawaited;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/services/campaign_journal_service.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_instance_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/infusion_discovery.dart';
import 'package:alchemons/services/onboarding_tasks.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/show_quick_instance_dialog.dart';
import 'package:alchemons/widgets/all_instaces_grid.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart'
    show InstanceDetailMode;
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart' show SpecimenGrains;
import 'package:alchemons/widgets/fx/infusion_particles.dart';
import 'package:alchemons/widgets/fx/kin_pour.dart';
import 'package:alchemons/widgets/fx/power_orb.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:alchemons/widgets/potential_soul_sphere.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

part 'enhance_readouts.dart';
part 'enhance_tray.dart';

/// Always the dark chamber, whatever the app theme: like Harvest and the
/// black market, this is a room, not a page.
const _kPalette = BracketPalette.dark;

/// The Enhance violet, as on its dock emblem.
const _kAccent = Color(0xFFC9A6FF);

/// Levels and XP.
const _kGold = Color(0xFFE4C16A);

/// A Potential Soul before it has a stat.
const _kSoul = Color(0xFFCF9BFF);
const _kDanger = Color(0xFFE5735C);

enum _Tray { kin, orbs, souls }

/// What a drag is carrying. Orbs and Souls land on the same sprite but cost
/// different things and take different code paths.
enum _InfusionKind { orb, soul }

@immutable
class _InfusionPayload {
  const _InfusionPayload(this.kind, this.type);

  final _InfusionKind kind;
  final AlchemicalPowerupType type;
}

class FeedingScreen extends StatefulWidget {
  const FeedingScreen({
    super.key,
    this.initialInstanceId,
    this.revealReady,
    this.revealed,
  });

  /// Opens straight onto this Alchemon; back then leaves the screen.
  final String? initialInstanceId;

  /// Coming in through the dock's passage (widgets/dock_passages.dart):
  /// set once the picker has its Alchemons, so the passage opens on them
  /// rather than on an empty grid.
  final ValueNotifier<bool>? revealReady;

  /// Turns true once the passage is half open; the first-visit basics wait
  /// for it rather than showing over the passage.
  final ValueListenable<bool>? revealed;

  @override
  State<FeedingScreen> createState() => _FeedingScreenState();
}

class _FeedingScreenState extends State<FeedingScreen>
    with TickerProviderStateMixin {
  String? _instanceId;
  _Tray _tray = _Tray.kin;

  /// Kin chosen to give, in the order they were picked.
  final Set<String> _kin = {};
  FeedResult? _preview;
  int _previewToken = 0;
  bool _busy = false;
  String? _message;

  /// One-way: a tray that vanished when its last orb was spent would read as
  /// the feature breaking. See [InfusionDiscovery].
  bool _orbsSeen = false;
  bool _soulsSeen = false;

  // ── the infusion on the stage ──
  late final AnimationController _orbController;
  late final AnimationController _flashController;
  late final AnimationController _pourController;
  late final AnimationController _xpController;
  late final AnimationController _soulSwapController;
  AlchemicalPowerupType? _animatingType;

  /// Set for kin: the power-up is lit gold, not a stat's colour.
  Color? _animatingTint;
  AlchemicalPowerupType? _launchingType;
  String? _deltaLabel;
  String? _rollLabel;
  double _glowBoost = 1.0;
  bool _jackpot = false;
  double _orbitEndProgress = 0.72;
  int? _soulRoll;
  Map<AlchemicalPowerupType, double>? _frozenStats;
  Map<AlchemicalPowerupType, double>? _frozenPotentials;
  InfusionBody? _infusionBody;
  KinPour? _pour;

  /// The level line, as level + the fraction of the way to the next, held
  /// at [_xpFrom] while kin are poured and counted up to [_xpTo] after.
  double? _xpFrom;
  double? _xpTo;
  int _lastLevelShown = 0;

  // ── dragging ──
  AlchemicalPowerupType? _draggingType;
  _InfusionKind? _draggingKind;
  bool _overDropTarget = false;

  // ── souls ──
  // Souls spend Silver, so the commitment comes before the gesture: pick a
  // Potential, confirm the price, and only then is the soul draggable.
  AlchemicalPowerupType? _soulStat;
  bool _soulArmed = false;

  // ── the first-time drag hint ──
  bool _dragHintChecked = false;
  bool _dragHintVisible = false;
  Offset? _hintFrom;
  Offset? _hintTo;

  /// The picker's search: nickname or species.
  final TextEditingController _search = TextEditingController();
  String _query = '';

  final GlobalKey _chamberKey = GlobalKey();

  /// The stage the sprite stands in; the infusion paints in its frame.
  final GlobalKey _stageKey = GlobalKey();

  /// The sprite itself, read into grains when something lands.
  final GlobalKey _bodyKey = GlobalKey();
  final GlobalKey _firstOrbKey = GlobalKey();
  final Map<String, GlobalKey> _kinKeys = {};

  @override
  void initState() {
    super.initState();
    // Arriving earns the task; collecting it happens in the journal.
    OnboardingTaskService.recordArrival(context, 'enhance');
    _instanceId = widget.initialInstanceId;
    _orbController = AnimationController(vsync: this);
    _flashController = AnimationController(vsync: this);
    _pourController = AnimationController(vsync: this);
    _xpController = AnimationController(vsync: this)..addListener(_onXpTick);
    _soulSwapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    unawaited(_refreshDiscovery());
    final revealed = widget.revealed;
    if (revealed == null || revealed.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowBasics());
    } else {
      revealed.addListener(_onRevealed);
    }
  }

  /// The passage is half open: the basics once it has finished.
  void _onRevealed() {
    if (!(widget.revealed?.value ?? true)) return;
    widget.revealed?.removeListener(_onRevealed);
    Future<void>.delayed(const Duration(milliseconds: 900), _maybeShowBasics);
  }

  /// The picker has its Alchemons: the passage may open on them, once
  /// they have been laid out.
  void _signalReady() {
    final ready = widget.revealReady;
    if (ready == null || ready.value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => ready.value = true);
  }

  @override
  void dispose() {
    widget.revealed?.removeListener(_onRevealed);
    _orbController.dispose();
    _flashController.dispose();
    _pourController.dispose();
    _xpController.dispose();
    _soulSwapController.dispose();
    _search.dispose();
    super.dispose();
  }

  /// For the tray pages, which live in an extension.
  void _set(VoidCallback change) => setState(change);

  bool get _canReadPotential =>
      context.read<ConstellationEffectsService>().hasPotentialAnalyzer();

  // ───────────────────────────── discovery ─────────────────────────────

  /// Records anything held right now, so a tray appears on the same visit
  /// its first orb or soul lands.
  Future<void> _refreshDiscovery() async {
    final db = context.read<AlchemonsDatabase>();
    final held = await InfusionDiscovery.readHoldings(db.inventoryDao);
    await InfusionDiscovery.observe(db.settingsDao, held);
    final orbs = await InfusionDiscovery.orbsDiscovered(db.settingsDao);
    final souls = await InfusionDiscovery.soulsDiscovered(db.settingsDao);
    if (!mounted) return;
    if (orbs != _orbsSeen || souls != _soulsSeen) {
      setState(() {
        _orbsSeen = orbs;
        _soulsSeen = souls;
      });
    }
  }

  Future<void> _maybeShowBasics() async {
    if (!mounted) return;
    final settings = context.read<AlchemonsDatabase>().settingsDao;
    if (await settings.hasSeenFeedingTutorial() || !mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => _BasicsDialog(orbs: _orbsSeen, souls: _soulsSeen),
    );
    if (mounted) await settings.setFeedingTutorialSeen();
  }

  // ───────────────────────────── navigation ─────────────────────────────

  void _choose(CreatureInstance inst) {
    HapticFeedback.selectionClick();
    setState(() {
      _instanceId = inst.instanceId;
      _tray = _Tray.kin;
      _kin.clear();
      _preview = null;
      _message = null;
      _soulStat = null;
      _soulArmed = false;
    });
  }

  void _back() {
    if (_busy) return;
    HapticFeedback.lightImpact();
    if (_instanceId == null || widget.initialInstanceId != null) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _instanceId = null;
      _kin.clear();
      _preview = null;
      _message = null;
      _dragHintVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ForcedFactionBrightness(
      brightness: Brightness.dark,
      child: Builder(
        builder: (context) {
          final theme = context.watch<FactionTheme>();
          return PopScope(
            canPop:
                !_busy &&
                (_instanceId == null || widget.initialInstanceId != null),
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _back();
            },
            child: Scaffold(
              backgroundColor: _kPalette.bg0,
              body: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.35),
                          radius: 1.05,
                          colors: [const Color(0xFF15121D), _kPalette.bg0],
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: _instanceId == null
                        ? _buildPicker(theme)
                        : _buildChamber(theme),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ───────────────────────────── the picker ─────────────────────────────

  Widget _buildPicker(FactionTheme theme) {
    final db = context.read<AlchemonsDatabase>();
    return Column(
      children: [
        _EnhanceHeader(subtitle: 'CHOOSE AN ALCHEMON', onBack: _back),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: _SearchField(
            controller: _search,
            onChanged: (q) => setState(() => _query = q),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<CreatureInstance>>(
            stream: db.creatureDao.watchAllInstances(),
            builder: (context, snap) {
              final all = snap.data;
              if (all != null) _signalReady();
              if (all != null && all.isEmpty) {
                return const _QuietNote('No Alchemons yet.');
              }
              // Spare kin per species: the number that decides who is worth
              // opening, shown on each card.
              final spare = <String, int>{};
              for (final inst in all ?? const <CreatureInstance>[]) {
                if (inst.locked) continue;
                spare.update(inst.baseId, (n) => n + 1, ifAbsent: () => 1);
              }
              return AllCreatureInstances(
                theme: theme,
                prefsScopeKey: 'enhance_select',
                searchTextOverride: _query,
                showInternalSearchBar: false,
                allowEnhancementMode: true,
                initialDetailMode: _orbsSeen
                    ? InstanceDetailMode.enhancement
                    : InstanceDetailMode.stats,
                selectedInstanceIds: const [],
                cardBadgeBuilder: (inst, species) {
                  if (inst.level >= AlchemonStatSystem.maxLevel) return null;
                  final n = (spare[inst.baseId] ?? 0) - (inst.locked ? 0 : 1);
                  return n > 0 ? _KinBadge(count: n) : null;
                },
                onTap: _choose,
              );
            },
          ),
        ),
      ],
    );
  }

  // ───────────────────────────── the chamber ─────────────────────────────

  Widget _buildChamber(FactionTheme theme) {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();
    return StreamBuilder<List<CreatureInstance>>(
      stream: db.creatureDao.watchAllInstances(),
      builder: (context, snap) {
        final all = snap.data;
        if (all == null) return const SizedBox.shrink();
        final inst = all.where((i) => i.instanceId == _instanceId).firstOrNull;
        final creature = inst == null
            ? null
            : repo.getCreatureById(inst.baseId);
        if (inst == null || creature == null) {
          return Column(
            children: [
              _EnhanceHeader(subtitle: 'ENHANCE', onBack: _back),
              const Expanded(child: _QuietNote('That Alchemon is gone.')),
            ],
          );
        }
        final kin =
            all
                .where(
                  (i) =>
                      i.baseId == inst.baseId &&
                      i.instanceId != inst.instanceId &&
                      !i.locked,
                )
                .toList()
              ..sort((a, b) {
                // More XP first: a kin's XP follows its level.
                final byLevel = b.level.compareTo(a.level);
                return byLevel != 0
                    ? byLevel
                    : b.createdAtUtcMs.compareTo(a.createdAtUtcMs);
              });
        final lockedKin = all
            .where(
              (i) =>
                  i.baseId == inst.baseId &&
                  i.instanceId != inst.instanceId &&
                  i.locked,
            )
            .length;
        // A kin that left (sold, released) cannot stay chosen.
        if (!_busy) {
          final ids = {for (final k in kin) k.instanceId};
          if (_kin.any((id) => !ids.contains(id))) {
            _kin.removeWhere((id) => !ids.contains(id));
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _updatePreview(),
            );
          }
        }

        return StreamBuilder<List<InventoryItem>>(
          stream: db.inventoryDao.watchItemInventory(),
          builder: (context, invSnap) {
            final inventory = <String, int>{
              for (final item in invSnap.data ?? const <InventoryItem>[])
                item.key: item.qty,
            };
            return StreamBuilder<int>(
              stream: db.currencyDao.watchSilverBalance(),
              builder: (context, silverSnap) {
                final silver = silverSnap.data ?? 0;
                return _buildChamberBody(
                  theme: theme,
                  creature: creature,
                  inst: inst,
                  kin: kin,
                  lockedKin: lockedKin,
                  inventory: inventory,
                  silver: silver,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChamberBody({
    required FactionTheme theme,
    required Creature creature,
    required CreatureInstance inst,
    required List<CreatureInstance> kin,
    required int lockedKin,
    required Map<String, int> inventory,
    required int silver,
  }) {
    final orbQty = InfusionDiscovery.orbCount(inventory);
    final soulQty = inventory[InvKeys.potentialSoul] ?? 0;
    if (orbQty > 0 && !_orbsSeen) _rememberSeen(InfusionDiscovery.orbSeenKey);
    if (soulQty > 0 && !_soulsSeen) {
      _rememberSeen(InfusionDiscovery.soulSeenKey);
    }
    final showOrbs = orbQty > 0 || _orbsSeen;
    // The soul tray waits until it means something: a soul in hand, or the
    // Potential Analyzer that makes Potential a thing you can read.
    final showSouls = soulQty > 0 || _soulsSeen || _canReadPotential;
    final trays = [
      _Tray.kin,
      if (showOrbs) _Tray.orbs,
      if (showSouls) _Tray.souls,
    ];
    final tray = trays.contains(_tray) ? _tray : _Tray.kin;
    if (tray == _Tray.orbs) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowDragHint());
    }

    final rarity = creature.rarity;
    final previewLevel = _preview?.newLevel;
    return Stack(
      key: _chamberKey,
      children: [
        Column(
          children: [
            _EnhanceHeader(
              subtitle: '${creature.name} · ${creature.rarity}'.toUpperCase(),
              onBack: _back,
              silver: silver,
            ),
            Expanded(child: _buildStage(creature, inst, inventory, silver)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: AnimatedBuilder(
                animation: _xpController,
                builder: (context, _) => _LevelLine(
                  coord: _displayCoord(inst, rarity),
                  rarity: rarity,
                  preview: _preview,
                  xpBoost: context
                      .read<ConstellationEffectsService>()
                      .getXpBoostMultiplier(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              // Rebuilt with the level line while it counts, so the stats
              // step up with each level it passes.
              child: AnimatedBuilder(
                animation: _xpController,
                builder: (context, _) => _StatGrid(
                  cells: [
                    for (final type in AlchemicalPowerupType.values)
                      _statCell(inst, type, previewLevel),
                  ],
                ),
              ),
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _message!.toUpperCase(),
                  maxLines: 2,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: _kDanger,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            _TrayPanel(
              trays: trays,
              selected: tray,
              counts: {
                _Tray.kin: kin.length,
                _Tray.orbs: orbQty,
                _Tray.souls: soulQty,
              },
              onSelect: (t) {
                if (_busy) return;
                setState(() {
                  _tray = t;
                  _message = null;
                });
              },
              child: switch (tray) {
                _Tray.kin => _buildKinPage(creature, inst, kin, lockedKin),
                _Tray.orbs => _buildOrbPage(creature, inst, inventory, silver),
                _Tray.souls => _buildSoulPage(inst, soulQty, silver),
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
        if (_pour != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _pourController,
                builder: (context, _) => CustomPaint(
                  painter: KinPourPainter(
                    pour: _pour!,
                    t: _pourController.value,
                    color: _kGold,
                  ),
                ),
              ),
            ),
          ),
        if (_dragHintVisible && _hintFrom != null && _hintTo != null)
          Positioned.fill(
            child: IgnorePointer(
              child: _DragHintOverlay(from: _hintFrom!, to: _hintTo!),
            ),
          ),
      ],
    );
  }

  /// The specimen on its floor: the drop target, and where every infusion
  /// plays.
  Widget _buildStage(
    Creature creature,
    CreatureInstance inst,
    Map<String, int> inventory,
    int silver,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spriteSize = (constraints.maxHeight * 0.74).clamp(96.0, 236.0);
        return DragTarget<_InfusionPayload>(
          onWillAcceptWithDetails: (d) =>
              _acceptsInfusion(inst, inventory, silver, d.data),
          // Crossing onto the specimen is where the drag becomes a
          // commitment — a duller knock when it cannot land.
          onMove: (d) {
            if (_overDropTarget) return;
            _overDropTarget = true;
            if (_acceptsInfusion(inst, inventory, silver, d.data)) {
              HapticFeedback.mediumImpact();
            } else {
              HapticFeedback.lightImpact();
            }
          },
          onLeave: (_) {
            if (!_overDropTarget) return;
            _overDropTarget = false;
            HapticFeedback.selectionClick();
          },
          onAcceptWithDetails: (d) {
            _overDropTarget = false;
            HapticFeedback.mediumImpact();
            switch (d.data.kind) {
              case _InfusionKind.orb:
                _applyOrb(inst, d.data.type);
              case _InfusionKind.soul:
                _applySoul(inst, d.data.type);
            }
          },
          builder: (context, candidate, rejected) {
            final hovering = candidate.isNotEmpty;
            final refusing = rejected.isNotEmpty;
            final armed = _draggingType != null;
            final kinChosen = _kin.isNotEmpty && !_busy;
            // The floor is always lit a little — it is where it stands — and
            // brighter, in the colour of what is coming, when something is.
            final floorColor = hovering
                ? (candidate.first?.type.color ?? _kAccent)
                : refusing
                ? _kDanger
                : armed
                ? (_draggingKind == _InfusionKind.soul
                      ? _kSoul
                      : _draggingType!.color)
                : kinChosen
                ? _kGold
                : _kAccent;
            final floorStrength = hovering
                ? 0.95
                : refusing
                ? 0.6
                : armed || kinChosen
                ? 0.55
                : 0.32;
            return Stack(
              key: _stageKey,
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 64,
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(end: floorColor),
                      duration: const Duration(milliseconds: 220),
                      builder: (context, c, _) => CustomPaint(
                        painter: _FloorLightPainter(
                          color: c ?? floorColor,
                          strength: floorStrength,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 22,
                  // While the power-up has it in grains, the sprite steps
                  // aside for them.
                  child: AnimatedBuilder(
                    animation: _flashController,
                    builder: (context, child) => Opacity(
                      opacity: _infusionBody != null && _animatingType != null
                          ? InfusionPainter.spriteOpacity(
                              _flashController.value,
                            )
                          : 1,
                      child: child,
                    ),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 140),
                      scale: hovering ? 1.05 : 1.0,
                      child: GestureDetector(
                        onLongPress: () => showQuickInstanceDialog(
                          context: context,
                          theme: context.read<FactionTheme>(),
                          creature: creature,
                          instance: inst,
                        ),
                        child: RepaintBoundary(
                          key: _bodyKey,
                          child: InstanceSprite(
                            creature: creature,
                            instance: inst,
                            size: spriteSize,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_animatingType != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _orbController,
                          _flashController,
                        ]),
                        builder: (context, _) {
                          // Kin have no flight of their own: the pour was it.
                          if (_animatingTint != null &&
                              _flashController.value <= 0) {
                            return const SizedBox.shrink();
                          }
                          return CustomPaint(
                            painter: InfusionPainter(
                              progress: _orbController.value,
                              flash: _flashController.value,
                              type: _animatingType!,
                              tint: _animatingTint,
                              body: _infusionBody,
                              rollLabel: _rollLabel,
                              glowBoost: _glowBoost,
                              isJackpot: _jackpot,
                              orbitEndProgress: _orbitEndProgress,
                              soulRoll: _soulRoll,
                              deltaLabel: _deltaLabel,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // ───────────────────────────── readouts ─────────────────────────────

  /// Level + the fraction of the way to the next; 10 is the top.
  double _coordOf(int level, int xp, String rarity) {
    if (level >= AlchemonStatSystem.maxLevel) {
      return AlchemonStatSystem.maxLevel.toDouble();
    }
    final need = CreatureInstanceServiceFeeding.xpNeededForLevel(
      level,
      rarity: rarity,
    );
    return level + (need <= 0 ? 0 : (xp / need).clamp(0.0, 0.999));
  }

  double _displayCoord(CreatureInstance inst, String rarity) {
    final from = _xpFrom;
    if (from == null) return _coordOf(inst.level, inst.xp, rarity);
    final to = _xpTo;
    if (to == null) return from;
    final e = Curves.easeInOutCubic.transform(_xpController.value);
    return from + (to - from) * e;
  }

  /// A level reached while the line counts up: felt, and heard.
  void _onXpTick() {
    final from = _xpFrom, to = _xpTo;
    if (from == null || to == null) return;
    final e = Curves.easeInOutCubic.transform(_xpController.value);
    final level = (from + (to - from) * e).floor();
    if (level > _lastLevelShown) {
      _lastLevelShown = level;
      HapticFeedback.mediumImpact();
      context.sound(
        level >= AlchemonStatSystem.maxLevel
            ? SoundCue.enhanceMaxLevel
            : SoundCue.upgradeComplete,
        owner: this,
      );
    }
  }

  _StatCellData _statCell(
    CreatureInstance inst,
    AlchemicalPowerupType type,
    int? previewLevel,
  ) {
    var value = _frozenStats?[type] ?? _statOf(inst, type);
    final from = _xpFrom, to = _xpTo;
    if (_frozenStats != null && from != null && to != null) {
      // Counting up after kin: the held values, at the level reached so far.
      final e = Curves.easeInOutCubic.transform(_xpController.value);
      value *=
          AlchemonStatSystem.levelMultiplier((from + (to - from) * e).floor()) /
          AlchemonStatSystem.levelMultiplier(from.floor());
    }
    final rank = _rankOf(inst, type);
    // What it will be: kin raise the level, a held orb raises its rank. Only
    // that one factor moves, so the ratio is exact.
    double? after;
    if (previewLevel != null && previewLevel > inst.level && !_busy) {
      after =
          value *
          AlchemonStatSystem.levelMultiplier(previewLevel) /
          AlchemonStatSystem.levelMultiplier(inst.level);
    } else if (_draggingKind == _InfusionKind.orb &&
        _draggingType == type &&
        rank < AlchemonStatSystem.maxEnhancementRank) {
      after =
          value *
          AlchemonStatSystem.enhancementMultiplier(rank + 1) /
          AlchemonStatSystem.enhancementMultiplier(rank);
    }
    return _StatCellData(
      type: type,
      rating: AlchemonStatSystem.displayRating(value),
      after: after == null ? null : AlchemonStatSystem.displayRating(after),
      rank: rank,
      rankAfter: after != null && _draggingKind == _InfusionKind.orb
          ? rank + 1
          : null,
      potential: _canReadPotential
          ? AlchemonStatSystem.normalizePotential(
              _frozenPotentials?[type] ?? _potentialValueOf(inst, type),
            )
          : null,
      lit: _draggingType == null || _draggingType == type,
    );
  }

  static double _statOf(CreatureInstance i, AlchemicalPowerupType t) =>
      switch (t) {
        AlchemicalPowerupType.speed => i.statSpeed,
        AlchemicalPowerupType.intelligence => i.statIntelligence,
        AlchemicalPowerupType.strength => i.statStrength,
        AlchemicalPowerupType.beauty => i.statBeauty,
      };

  static int _rankOf(CreatureInstance i, AlchemicalPowerupType t) =>
      switch (t) {
        AlchemicalPowerupType.speed => i.statSpeedEnhancement,
        AlchemicalPowerupType.intelligence => i.statIntelligenceEnhancement,
        AlchemicalPowerupType.strength => i.statStrengthEnhancement,
        AlchemicalPowerupType.beauty => i.statBeautyEnhancement,
      };

  static double _potentialValueOf(
    CreatureInstance i,
    AlchemicalPowerupType t,
  ) => switch (t) {
    AlchemicalPowerupType.speed => i.statSpeedPotential,
    AlchemicalPowerupType.intelligence => i.statIntelligencePotential,
    AlchemicalPowerupType.strength => i.statStrengthPotential,
    AlchemicalPowerupType.beauty => i.statBeautyPotential,
  };

  int _potentialOf(CreatureInstance i, AlchemicalPowerupType t) =>
      _potentialValueOf(i, t).round();

  Map<AlchemicalPowerupType, double> _snapshotStats(CreatureInstance i) => {
    for (final t in AlchemicalPowerupType.values) t: _statOf(i, t),
  };

  Map<AlchemicalPowerupType, double> _snapshotPotentials(
    CreatureInstance i,
  ) => {
    for (final t in AlchemicalPowerupType.values) t: _potentialValueOf(i, t),
  };

  // ───────────────────────────── kin ─────────────────────────────

  Future<void> _toggleKin(String id) async {
    if (_busy) return;
    final adding = !_kin.contains(id);
    // Past level 10 another kin would only be wasted.
    if (adding &&
        _preview != null &&
        _preview!.newLevel >= AlchemonStatSystem.maxLevel) {
      HapticFeedback.heavyImpact();
      showGameSnack(
        context,
        'Level 10 already — another would be wasted.',
        accent: _kGold,
      );
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      if (adding) {
        _kin.add(id);
      } else {
        _kin.remove(id);
      }
      _message = null;
    });
    await _updatePreview();
  }

  Future<void> _updatePreview() async {
    final token = ++_previewToken;
    if (_kin.isEmpty || _instanceId == null) {
      if (mounted) setState(() => _preview = null);
      return;
    }
    try {
      final result =
          await CreatureInstanceService(
            context.read<AlchemonsDatabase>(),
          ).previewFeed(
            targetInstanceId: _instanceId!,
            fodderInstanceIds: _kin.toList(),
            repo: context.read<CreatureCatalog>(),
            constellationEffects: context.read<ConstellationEffectsService>(),
            maxLevel: AlchemonStatSystem.maxLevel,
            strictSpecies: true,
          );
      if (!mounted || token != _previewToken) return;
      setState(() => _preview = result.ok ? result : null);
    } catch (_) {
      if (mounted && token == _previewToken) setState(() => _preview = null);
    }
  }

  Future<void> _sacrifice(CreatureInstance inst, Creature creature) async {
    if (_busy || _kin.isEmpty) return;
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();
    final effects = context.read<ConstellationEffectsService>();
    final ids = _kin.toList();
    final rarity = creature.rarity;
    final before = _coordOf(inst.level, inst.xp, rarity);

    _orbController.value = 1;
    _flashController.value = 0;
    setState(() {
      _busy = true;
      _message = null;
      _frozenStats = _snapshotStats(inst);
      _xpFrom = before;
      _xpTo = null;
    });
    unawaited(CampaignJournalService.mark(db.settingsDao, 'enhance'));

    // Where each kin card sits and where the specimen stands, on one canvas.
    final body = await _captureBody();
    if (!mounted) return;
    final chamber = _chamberKey.currentContext?.findRenderObject();
    final stage = _stageKey.currentContext?.findRenderObject();
    final sources = <Offset>[];
    if (chamber is RenderBox && stage is RenderBox) {
      for (final id in ids) {
        final box = _kinKeys[id]?.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.attached) continue;
        sources.add(
          chamber.globalToLocal(
            box.localToGlobal(Offset(box.size.width / 2, 30)),
          ),
        );
      }
    }
    if (body != null &&
        chamber is RenderBox &&
        stage is RenderBox &&
        sources.isNotEmpty) {
      setState(
        () => _pour = KinPour(
          sources: sources,
          body: body,
          target: chamber.globalToLocal(stage.localToGlobal(body.centre)),
        ),
      );
      _pourController.duration = Duration(
        milliseconds: (1150 + 170 * (sources.length - 1)).clamp(1150, 1900),
      );
      HapticFeedback.mediumImpact();
      // Scored to this pour's length, which grows with the kin given.
      context.sound(SoundCue.forKinPour(sources.length), owner: this);
      await _pourController.forward(from: 0);
      if (!mounted) return;
    }

    final result = await CreatureInstanceService(db).feedInstances(
      targetInstanceId: inst.instanceId,
      fodderInstanceIds: ids,
      repo: repo,
      constellationEffects: effects,
      maxLevel: AlchemonStatSystem.maxLevel,
      strictSpecies: true,
    );
    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _busy = false;
        _pour = null;
        _frozenStats = null;
        _xpFrom = null;
        _infusionBody = null;
        _message = result.error ?? 'That did not take.';
      });
      HapticFeedback.vibrate();
      return;
    }

    final levels = result.newLevel - inst.level;
    setState(() {
      _pour = null;
      _kin.clear();
      _preview = null;
      _xpTo = _coordOf(result.newLevel, result.newXpRemainder, rarity);
      _lastLevelShown = inst.level;
      _animatingType = AlchemicalPowerupType.strength;
      _animatingTint = _kGold;
      _deltaLabel = '+${result.totalXpGained} XP';
      _rollLabel = levels > 0 ? 'LEVEL ${result.newLevel}' : null;
      _glowBoost = levels > 0 ? 1.3 : 1.0;
      _jackpot = false;
      _soulRoll = null;
    });
    context.sound(SoundCue.rewardCollect, owner: this, speed: 1.08);
    _flashController.duration = Duration(milliseconds: levels > 0 ? 1100 : 860);
    _xpController.duration = Duration(
      milliseconds: (900 + 260 * levels).clamp(900, 1900),
    );
    await Future.wait([
      _flashController.forward(from: 0),
      _xpController.forward(from: 0),
    ]);
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _busy = false;
      _animatingType = null;
      _animatingTint = null;
      _deltaLabel = null;
      _rollLabel = null;
      _glowBoost = 1.0;
      _frozenStats = null;
      _xpFrom = null;
      _xpTo = null;
      _infusionBody = null;
    });
    _xpController.value = 0;
  }

  // ───────────────────────────── orbs ─────────────────────────────

  bool _canApplyOrb(
    CreatureInstance inst,
    Map<String, int> inventory,
    int silver,
    AlchemicalPowerupType type,
  ) {
    final rank = _rankOf(inst, type);
    return !_busy &&
        rank < AlchemonStatSystem.maxEnhancementRank &&
        (inventory[type.inventoryKey] ?? 0) >=
            AlchemonStatSystem.orbCostForNextRank(rank) &&
        silver >= AlchemonStatSystem.enhancementSilverForNextRank(rank);
  }

  bool _canApplySoul(
    CreatureInstance inst,
    Map<String, int> inventory,
    int silver,
    AlchemicalPowerupType type,
  ) =>
      !_busy &&
      _soulArmed &&
      _soulStat == type &&
      (inventory[InvKeys.potentialSoul] ?? 0) > 0 &&
      _potentialOf(inst, type) < AlchemonStatSystem.maxPotential &&
      silver >= _soulCost(inst, type);

  bool _acceptsInfusion(
    CreatureInstance inst,
    Map<String, int> inventory,
    int silver,
    _InfusionPayload p,
  ) => switch (p.kind) {
    _InfusionKind.orb => _canApplyOrb(inst, inventory, silver, p.type),
    _InfusionKind.soul => _canApplySoul(inst, inventory, silver, p.type),
  };

  int _soulCost(CreatureInstance inst, AlchemicalPowerupType type) =>
      AlchemonStatSystem.potentialSoulSilverCost(_potentialOf(inst, type));

  Future<void> _applyOrb(
    CreatureInstance inst,
    AlchemicalPowerupType type,
  ) async {
    if (_busy) return;
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();
    unawaited(CampaignJournalService.mark(db.settingsDao, 'orbUse'));
    _orbController.reset();
    _flashController.reset();
    HapticFeedback.mediumImpact();
    setState(() {
      _busy = true;
      _launchingType = type;
      _animatingType = null;
      _animatingTint = null;
      _frozenStats = _snapshotStats(inst);
      _frozenPotentials = null;
      _message = null;
    });
    // Let the tile lift away first.
    await Future<void>.delayed(const Duration(milliseconds: 190));
    if (!mounted) return;
    // Read the specimen while the orb is in flight.
    unawaited(_captureBody());
    _orbController.duration = const Duration(milliseconds: 520);
    _flashController.duration = const Duration(milliseconds: 560);
    setState(() {
      _launchingType = null;
      _animatingType = type;
      _deltaLabel = '+3%';
      _rollLabel = 'ENHANCING';
      _glowBoost = 1.0;
      _jackpot = false;
      _orbitEndProgress = 0.72;
      _soulRoll = null;
    });
    context.sound(SoundCue.enhanceOrb, owner: this);
    await _orbController.forward(from: 0);
    if (!mounted) return;
    await _flashController.forward(from: 0);
    HapticFeedback.heavyImpact();
    if (!mounted) return;

    final result = await CreatureInstanceService(db).applyAlchemicalPowerup(
      targetInstanceId: inst.instanceId,
      powerup: type,
      repo: repo,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _animatingType = null;
      _launchingType = null;
      _deltaLabel = null;
      _rollLabel = null;
      _frozenStats = null;
      _infusionBody = null;
      if (!result.ok) _message = result.error ?? 'Infusion failed.';
    });
    if (!result.ok) HapticFeedback.vibrate();
  }

  // ───────────────────────────── souls ─────────────────────────────

  Future<void> _applySoul(
    CreatureInstance inst,
    AlchemicalPowerupType type,
  ) async {
    if (_busy) return;
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();
    unawaited(CampaignJournalService.mark(db.settingsDao, 'soulUse'));
    _orbController.reset();
    _flashController.reset();
    HapticFeedback.mediumImpact();
    setState(() {
      _busy = true;
      _animatingType = null;
      _animatingTint = null;
      _rollLabel = 'AWAKENING';
      _soulRoll = null;
      _frozenStats = _snapshotStats(inst);
      _frozenPotentials = _snapshotPotentials(inst);
      _message = null;
    });

    // The transaction resolves first; the old values stay frozen on screen
    // until the reveal finishes, so the real roll drives the celebration.
    final result = await CreatureInstanceService(db).applyPotentialSoul(
      targetInstanceId: inst.instanceId,
      stat: type,
      repo: repo,
    );
    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _busy = false;
        _frozenStats = null;
        _frozenPotentials = null;
        _rollLabel = null;
        _soulArmed = false;
        _message = result.error ?? 'Potential infusion failed.';
      });
      HapticFeedback.vibrate();
      return;
    }

    unawaited(_captureBody());
    final reveal = _soulReveal(result.rolledGain);
    _orbController.duration = reveal.orb;
    _flashController.duration = reveal.flash;
    setState(() {
      _animatingType = type;
      _deltaLabel = '+${result.appliedGain} POTENTIAL';
      _rollLabel = reveal.label;
      _glowBoost = reveal.glow;
      _jackpot = reveal.jackpot;
      _orbitEndProgress = reveal.hangUntil;
      _soulRoll = result.rolledGain;
    });
    // One take per roll: each is scored to that roll's hang and flash.
    context.sound(SoundCue.forSoulRoll(result.rolledGain), owner: this);
    await _orbController.forward(from: 0);
    if (!mounted) return;
    await _flashController.forward(from: 0);
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    if (result.rolledGain >= 4) {
      // A second thump reads as an aftershock rather than a louder tap.
      await Future<void>.delayed(const Duration(milliseconds: 110));
      if (!mounted) return;
      HapticFeedback.heavyImpact();
    }
    setState(() {
      _busy = false;
      _animatingType = null;
      _frozenStats = null;
      _frozenPotentials = null;
      _rollLabel = null;
      _deltaLabel = null;
      _glowBoost = 1.0;
      _jackpot = false;
      _orbitEndProgress = 0.72;
      _soulRoll = null;
      _soulArmed = false;
      _infusionBody = null;
    });
  }

  /// Every roll plays longer and brighter than a routine orb: the weakest
  /// awakening used to be dimmer than one, an anticlimax for an item that
  /// costs tens of thousands of Silver.
  ({
    String label,
    double glow,
    bool jackpot,
    double hangUntil,
    Duration orb,
    Duration flash,
  })
  _soulReveal(int roll) => switch (roll) {
    1 => (
      label: 'SOUL AWAKENED',
      glow: 1.55,
      jackpot: false,
      hangUntil: 0.78,
      orb: const Duration(milliseconds: 2100),
      flash: const Duration(milliseconds: 720),
    ),
    2 => (
      label: 'SOUL STIRRING',
      glow: 1.8,
      jackpot: false,
      hangUntil: 0.80,
      orb: const Duration(milliseconds: 2350),
      flash: const Duration(milliseconds: 840),
    ),
    3 => (
      label: 'SOUL RESONANCE',
      glow: 2.15,
      jackpot: true,
      hangUntil: 0.83,
      orb: const Duration(milliseconds: 2650),
      flash: const Duration(milliseconds: 980),
    ),
    4 => (
      label: 'EXALTED SOUL',
      glow: 2.7,
      jackpot: true,
      hangUntil: 0.86,
      orb: const Duration(milliseconds: 3050),
      flash: const Duration(milliseconds: 1200),
    ),
    _ => (
      label: 'PERFECT AWAKENING',
      glow: 3.4,
      jackpot: true,
      hangUntil: 0.89,
      orb: const Duration(milliseconds: 3600),
      flash: const Duration(milliseconds: 1500),
    ),
  };

  // ───────────────────────────── plumbing ─────────────────────────────

  /// Reads the specimen, as it stands, into grains, centred where it sits on
  /// the stage. Null (and the infusion plays round the sprite) if it fails.
  Future<InfusionBody?> _captureBody() async {
    _infusionBody = null;
    final boundary = _bodyKey.currentContext?.findRenderObject();
    final stage = _stageKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary ||
        stage is! RenderBox ||
        !boundary.attached) {
      return null;
    }
    final ratio = math.min(MediaQuery.devicePixelRatioOf(context), 2.0);
    try {
      final image = await boundary.toImage(pixelRatio: ratio);
      try {
        final data = await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        if (data == null || !mounted) return null;
        final grains = SpecimenGrains.fromRgba(
          data.buffer.asUint8List(),
          image.width,
          image.height,
          pixelRatio: ratio,
          maxGrains: 2600,
          tones: 14,
        );
        if (grains.length < 60 || !boundary.attached || !stage.attached) {
          return null;
        }
        final body = InfusionBody(
          grains,
          stage.globalToLocal(
            boundary.localToGlobal(boundary.size.center(Offset.zero)),
          ),
        );
        if (mounted) setState(() => _infusionBody = body);
        return body;
      } finally {
        image.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  void _rememberSeen(String key) {
    final orb = key == InfusionDiscovery.orbSeenKey;
    if (orb ? _orbsSeen : _soulsSeen) return;
    if (orb) {
      _orbsSeen = true;
    } else {
      _soulsSeen = true;
    }
    final settings = context.read<AlchemonsDatabase>().settingsDao;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(settings.setSetting(key, '1'));
      if (mounted) setState(() {});
    });
  }

  Future<void> _maybeShowDragHint() async {
    if (_dragHintChecked || !mounted) return;
    _dragHintChecked = true;
    final db = context.read<AlchemonsDatabase>();
    if (await db.settingsDao.hasSeenPowerupDragHint() || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chamber = _chamberKey.currentContext?.findRenderObject();
      final orb = _firstOrbKey.currentContext?.findRenderObject();
      final body = _bodyKey.currentContext?.findRenderObject();
      if (chamber is! RenderBox || orb is! RenderBox || body is! RenderBox) {
        return;
      }
      if (!mounted) return;
      setState(() {
        _hintFrom = chamber.globalToLocal(
          orb.localToGlobal(orb.size.center(Offset.zero)),
        );
        _hintTo = chamber.globalToLocal(
          body.localToGlobal(body.size.center(Offset.zero)),
        );
        _dragHintVisible = true;
      });
    });
  }

  void _dismissDragHint() {
    if (!_dragHintVisible) return;
    setState(() => _dragHintVisible = false);
    unawaited(
      context.read<AlchemonsDatabase>().settingsDao.setPowerupDragHintSeen(),
    );
  }
}
