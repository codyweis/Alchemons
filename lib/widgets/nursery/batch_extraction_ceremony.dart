import 'dart:math' as math;
import 'dart:ui' as ui;

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
/// The cells follow the player's own cinematic quality up to
/// [kBatchFullQualityCells] at once and drop to [CinematicQuality.performance]
/// past that, where it is several times one ceremony's per-frame work. The
/// result cards play one at a time, so they always follow the player's
/// setting. Only the first cell plays the ceremony cue -- seven at once is
/// noise, not sound.
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

class _BatchExtractionCeremonyState extends State<BatchExtractionCeremony> {
  _Phase _phase = _Phase.extracting;
  CinematicQuality _quality = CinematicQuality.cinematic;
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _extractAll());
  }

  /// Movement 0: all the database work, before a single frame of ceremony.
  /// Doing it up front means the grid can start every cell on the same frame
  /// rather than staggering on whatever order the writes happened to finish.
  Future<void> _extractAll() async {
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();
    _quality = await CinematicQualityService().getQuality();
    if (!mounted) return;

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
        cinematicQuality: _quality,
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
      // Plain black, the ceremony's own ground. This used to carry a turning
      // constellation of hairlines behind everything, which repainted every
      // frame for the whole run -- under each result card too, where nothing
      // of it showed.
      child: Material(
        color: Colors.black,
        child: SafeArea(
          child: switch (_phase) {
            _Phase.extracting => _preparing(theme, t),
            _Phase.ceremony => _ceremonyGrid(theme, t),
            // The cards are dialogs above this route; underneath it just
            // holds the dark so nothing flashes between them.
            _Phase.cards => const SizedBox.shrink(),
          },
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
          child: BatchCeremonyGrid(
            ceremonies: [for (final r in _results) r.params],
            keys: [for (final r in _results) ValueKey(r.instance.instanceId)],
            quality: n <= kBatchFullQualityCells
                ? _quality
                : CinematicQuality.performance,
            onCellFinished: _cellFinished,
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

/// Up to this many cells run at the player's own cinematic quality.
const int kBatchFullQualityCells = 4;

/// Every chamber's ceremony at once, two across.
///
/// The cells are not boxed. They used to sit in amber hairline frames with a
/// hard clip at each edge, so every shell that reached its edge was cut off
/// in a visible straight line and the screen read as a spreadsheet of
/// thumbnails. Now each ceremony is inset in its cell, may spill into the
/// margin, and the cell's edges fade to black -- so the grid reads as one dark
/// field with several ceremonies in it.
class BatchCeremonyGrid extends StatelessWidget {
  const BatchCeremonyGrid({
    super.key,
    required this.ceremonies,
    required this.quality,
    required this.onCellFinished,
    this.keys,
  });

  final List<HatchCeremonyParams> ceremonies;
  final List<Key>? keys;
  final CinematicQuality quality;
  final ValueChanged<int> onCellFinished;

  /// The ceremony's share of its cell; the rest is the margin it can spill
  /// into before the edge fade takes it.
  static const double _inset = 0.94;

  @override
  Widget build(BuildContext context) {
    final n = ceremonies.length;
    final screenSpan = MediaQuery.sizeOf(context).shortestSide;
    // Always two across. A ceremony rendered into a third of a phone's width
    // is too small to read as the ceremony -- the shell's whole arc happens
    // inside a thumbnail. Two keeps every cell legible.
    const cross = 2;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, box) {
          // Every ceremony has to be on screen at once -- this is the
          // all-at-once beat, and a cell you have to scroll to has already
          // finished by the time you reach it. Two across is fixed, so the
          // cells take whatever height the rows leave.
          final rows = (n / cross).ceil();
          final cellW = box.maxWidth / cross;
          final cellH = box.maxHeight / rows;
          final ratio = cellH <= 0 ? 1.0 : cellW / cellH;
          final span = math.min(cellW, cellH) * _inset;
          // Thinner tubes, but not in proportion: at a cell's full share they
          // fall under a device pixel and the shell goes grey and sparse. The
          // lift keeps the coverage the full-screen shell has.
          final detail = screenSpan <= 0
              ? 1.0
              : (span / screenSpan * 1.35).clamp(0.5, 1.0);
          return GridView.builder(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: n,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cross,
              childAspectRatio: ratio,
            ),
            itemBuilder: (_, i) {
              final p = ceremonies[i];
              return RepaintBoundary(
                child: ClipRect(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FractionallySizedBox(
                        widthFactor: _inset,
                        heightFactor: _inset,
                        child: HatchingCeremonyView(
                          key: keys?[i] ?? ValueKey(i),
                          parentATypeId: p.parentATypeId,
                          parentBTypeId: p.parentBTypeId,
                          resultTypeId: p.resultTypeId,
                          paletteMain: p.paletteMain,
                          creatureSilhouette: p.silhouette,
                          hintType: p.hintType,
                          variantColor: p.variantColor,
                          pureElementTypeId: p.pureElementTypeId,
                          mutationFamily: p.mutationFamily,
                          mutation: p.mutation,
                          quality: quality,
                          detail: detail,
                          // One cue for the batch, not one per cell.
                          playSound: i == 0,
                          showSkip: false,
                          onComplete: () => onCellFinished(i),
                        ),
                      ),
                      const IgnorePointer(
                        child: RepaintBoundary(
                          child: CustomPaint(painter: _CellEdgeFade()),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Black drawn in from each edge of a cell, so whatever reaches the edge
/// fades out instead of being cut. Static: it is its own layer and never
/// repaints while the ceremony under it does.
class _CellEdgeFade extends CustomPainter {
  const _CellEdgeFade();

  @override
  void paint(Canvas canvas, Size size) {
    final band = size.shortestSide * 0.12;
    const black = Color(0xFF000000);
    const clear = Color(0x00000000);
    void edge(Rect r, Offset from, Offset to) {
      canvas.drawRect(
        r,
        Paint()..shader = ui.Gradient.linear(from, to, const [black, clear]),
      );
    }

    final w = size.width, h = size.height;
    edge(Rect.fromLTWH(0, 0, w, band), Offset.zero, Offset(0, band));
    edge(
      Rect.fromLTWH(0, h - band, w, band),
      Offset(0, h),
      Offset(0, h - band),
    );
    edge(Rect.fromLTWH(0, 0, band, h), Offset.zero, Offset(band, 0));
    edge(
      Rect.fromLTWH(w - band, 0, band, h),
      Offset(w, 0),
      Offset(w - band, 0),
    );
  }

  @override
  bool shouldRepaint(covariant _CellEdgeFade oldDelegate) => false;
}
