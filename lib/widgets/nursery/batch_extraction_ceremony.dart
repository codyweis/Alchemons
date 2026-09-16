import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:alchemons/services/egg_hatching_service.dart';
import 'package:alchemons/services/new_discovery_reveal_controller.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/animations/hatching_cinematic.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Extract-all, in three movements:
///
///   1. GRID     every chamber's ceremony plays at once, one cell each.
///   2. CARDS    the normal single-extraction result card, per specimen, in
///               order. The card's own CTA is the Next button.
///   3. NEW      anything newly discovered, shown together at the end.
///
/// The ceremonies run at [CinematicQuality.performance] because a full
/// chamber's worth of them is several times the vertex load of one, and only
/// the first cell plays the ceremony cue -- seven at once is noise, not sound.
class BatchExtractionCeremony extends StatefulWidget {
  const BatchExtractionCeremony({
    super.key,
    required this.slots,
    required this.undiscoveredCache,
  });

  final List<IncubatorSlot> slots;
  final Map<String, bool> undiscoveredCache;

  @override
  State<BatchExtractionCeremony> createState() =>
      _BatchExtractionCeremonyState();
}

enum _Phase { extracting, ceremony, cards }

class _Extracted {
  _Extracted({
    required this.instance,
    required this.creature,
    required this.isNewDiscovery,
    required this.params,
  });

  final CreatureInstance instance;
  final Creature creature;
  final bool isNewDiscovery;
  final HatchCeremonyParams params;
}

class _BatchExtractionCeremonyState extends State<BatchExtractionCeremony>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbit;

  _Phase _phase = _Phase.extracting;
  final List<_Extracted> _results = [];
  final Set<int> _finishedCells = {};
  String? _error;
  bool _skipped = false;

  /// Card snapshots for the new discoveries, captured as each card is
  /// dismissed and flown once the whole run has been seen.
  final List<({DiscoveryFlightCapture? capture, String creatureId})>
  _pendingFlights = [];

  int get _completed => _results.length;

  @override
  void initState() {
    super.initState();
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _extractAll());
  }

  @override
  void dispose() {
    _orbit.dispose();
    super.dispose();
  }

  /// Movement 0: all the database work, before a single frame of ceremony.
  /// Doing it up front means the grid can start every cell on the same frame
  /// rather than staggering on whatever order the writes happened to finish.
  Future<void> _extractAll() async {
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();

    for (final slot in widget.slots) {
      if (!mounted) return;
      final result = await EggHatching.performHatching(
        context: context,
        slot: slot,
        undiscoveredCache: widget.undiscoveredCache,
        showPresentation: false,
      );
      if (!mounted) return;
      if (!result.success || result.instanceId == null) {
        _error ??= result.message ?? 'Extraction could not be completed.';
        continue;
      }
      final instance = await db.creatureDao.getInstance(result.instanceId!);
      if (!mounted) return;
      final creature = instance == null
          ? null
          : catalog.getCreatureById(instance.baseId);
      if (instance == null || creature == null) {
        _error ??=
            'A specimen was extracted, but its analysis could not be loaded.';
        continue;
      }
      _results.add(
        _Extracted(
          instance: instance,
          creature: creature,
          isNewDiscovery: result.isNewDiscovery == true,
          params: EggHatching.ceremonyParamsFor(
            instance: instance,
            offspring: creature,
          ),
        ),
      );
    }

    if (!mounted) return;
    if (_results.isEmpty) {
      setState(() {});
      return;
    }
    setState(() => _phase = _Phase.ceremony);
  }

  void _cellFinished(int index) {
    if (_phase != _Phase.ceremony) return;
    _finishedCells.add(index);
    if (_finishedCells.length < _results.length) return;
    _leaveCeremony();
  }

  void _skipCeremony() {
    if (_phase != _Phase.ceremony || _skipped) return;
    _skipped = true;
    _leaveCeremony();
  }

  /// Deferred by a frame on purpose. The last cell reports completion from
  /// inside its own timeline listener, and tearing the grid down there would
  /// dispose that AnimationController while it is still notifying.
  void _leaveCeremony() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _beginCards();
    });
  }

  /// Movement 2: the real result card, one specimen at a time. Each call
  /// awaits its own dialog, so the loop IS the "next" flow.
  ///
  /// New discoveries do NOT file themselves away here. Each card's flight
  /// switches to the catalog, and doing that per card meant the discovery
  /// animation ran before the player had finished going through the batch.
  /// The cards are captured instead and flown together afterwards.
  Future<void> _beginCards() async {
    if (_phase == _Phase.cards) return;
    setState(() => _phase = _Phase.cards);
    for (final r in _results) {
      if (!mounted) return;
      await EggHatching.showExtractionResult(
        context,
        r.instance.instanceId,
        r.isNewDiscovery,
        cinematicQuality: CinematicQuality.performance,
        onDeferDiscoveryFlight: r.isNewDiscovery
            ? (capture) => _pendingFlights.add((
                capture: capture,
                creatureId: r.creature.id,
              ))
            : null,
      );
    }
    if (!mounted) return;
    await _fileAwayDiscoveries();
  }

  /// Movement 3: every new species files itself into the catalog, in turn.
  ///
  /// This is the same flight a single extraction ends with -- card flies to
  /// the species' own tile, catalog scrolls it into view, tile pulses -- just
  /// run once per discovery, so a batch visits each new entry's spot instead
  /// of collapsing them into one.
  Future<void> _fileAwayDiscoveries() async {
    if (_pendingFlights.isEmpty) {
      if (mounted) Navigator.of(context).pop(_completed);
      return;
    }
    final navigator = Navigator.of(context);
    final flights = List.of(_pendingFlights);
    _pendingFlights.clear();
    // Close the ceremony first: the flights land in the catalog, which is
    // behind this route, and a card cannot fly to a tile covered by a
    // full-screen black barrier.
    navigator.pop(_completed);
    await NewDiscoveryReveal.instance.playCapturedSequence(
      context: navigator.context,
      entries: flights,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final t = ForgeTokens(theme);
    // Nothing here is dismissable: the run owns the screen until the last
    // card has been seen and the discoveries have filed themselves away.
    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.black.withValues(alpha: 0.94),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _orbit,
                    builder: (_, __) => CustomPaint(
                      painter: _BatchConstellationPainter(
                        phase: _orbit.value,
                        color: t.amber,
                        remaining: widget.slots.length - _completed,
                      ),
                    ),
                  ),
                ),
              ),
              switch (_phase) {
                _Phase.extracting => _preparing(theme, t),
                _Phase.ceremony => _ceremonyGrid(theme, t),
                // The cards are dialogs above this route; underneath it just
                // holds the field so nothing flashes between them.
                _Phase.cards => const SizedBox.shrink(),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _preparing(FactionTheme theme, ForgeTokens t) {
    final failed = _error != null && _results.isEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (failed) ...[
              Icon(AppIcons.warning_amber_rounded, color: t.danger, size: 34),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.text, height: 1.35),
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: t.amber,
                  foregroundColor: Colors.black,
                ),
                onPressed: () => Navigator.of(context).pop(_completed),
                child: const Text('CLOSE'),
              ),
            ],
            // Nothing while it prepares. A spinner and a status line announce
            // that the app is busy, which breaks the ceremony before it has
            // started; the dark hold reads as the lights going down instead.
            // The failure branch above still speaks up, because a silent
            // failure would just look like a hang.
          ],
        ),
      ),
    );
  }

  Widget _ceremonyGrid(FactionTheme theme, ForgeTokens t) {
    final n = _results.length;
    // Always two across. A ceremony rendered into a third of a phone's width
    // is too small to read as the ceremony -- the shell's whole arc happens
    // inside a thumbnail. Two keeps every cell legible and just scrolls the
    // grid taller as chambers are added.
    const cross = 2;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: Text(
            'CONSTELLATION EXTRACTION  ·  $n CHAMBERS',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: t.amber,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: LayoutBuilder(
              builder: (context, box) {
                // Every ceremony has to be on screen at once -- this is the
                // all-at-once beat, and a cell you have to scroll to has
                // already finished by the time you reach it. Two across is
                // fixed, so the cells take whatever height the rows leave.
                final rows = (n / cross).ceil();
                final cellW = (box.maxWidth - 6 * (cross - 1)) / cross;
                final cellH = (box.maxHeight - 6 * (rows - 1)) / rows;
                final ratio = cellH <= 0 ? 1.0 : cellW / cellH;
                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: n,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    childAspectRatio: ratio,
                  ),
                  itemBuilder: (_, i) {
                    final r = _results[i];
                    return RepaintBoundary(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: t.amber.withValues(alpha: 0.28),
                          ),
                        ),
                        child: ClipRect(
                          child: HatchingCeremonyView(
                            key: ValueKey(r.instance.instanceId),
                            parentATypeId: r.params.parentATypeId,
                            parentBTypeId: r.params.parentBTypeId,
                            resultTypeId: r.params.resultTypeId,
                            paletteMain: r.params.paletteMain,
                            creatureSilhouette: r.params.silhouette,
                            hintType: r.params.hintType,
                            variantColor: r.params.variantColor,
                            pureElementTypeId: r.params.pureElementTypeId,
                            mutationFamily: r.params.mutationFamily,
                            quality: CinematicQuality.performance,
                            // One cue for the batch, not one per cell.
                            playSound: i == 0,
                            showSkip: false,
                            onComplete: () => _cellFinished(i),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
          child: TextButton(
            onPressed: _skipCeremony,
            child: Text(
              'SKIP',
              style: TextStyle(
                color: theme.textMuted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BatchConstellationPainter extends CustomPainter {
  const _BatchConstellationPainter({
    required this.phase,
    required this.color,
    required this.remaining,
  });

  final double phase;
  final Color color;
  final int remaining;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * 0.38;
    final line = Paint()
      ..color = color.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    final dot = Paint()..color = color.withValues(alpha: 0.35);
    const count = 12;
    Offset point(int i) {
      final angle = phase * math.pi * 2 + i * math.pi * 2 / count;
      final wobble = 0.82 + 0.18 * math.sin(phase * math.pi * 2 + i);
      return center +
          Offset(math.cos(angle), math.sin(angle)) * radius * wobble;
    }

    for (var i = 0; i < count; i++) {
      canvas.drawLine(point(i), point((i + 3) % count), line);
    }
    for (var i = 0; i < count; i++) {
      canvas.drawCircle(point(i), i < remaining ? 3.2 : 1.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _BatchConstellationPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.remaining != remaining;
}
