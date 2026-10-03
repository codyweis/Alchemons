import 'package:alchemons/audio/audio.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/egg/egg_payload_helpers.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:alchemons/services/cold_storage_service.dart';
import 'package:alchemons/services/egg_hatching_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:alchemons/widgets/nursery/cultivation_stage.dart';
import 'package:alchemons/widgets/nursery/hatch_curtain.dart';
import 'package:alchemons/widgets/fx/cultivation_sphere.dart';
import 'package:alchemons/widgets/perf/viewport_ticker_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/widgets/app_icons.dart';

/// Cold storage's ice: the same frost as the upgrade glyph, so the rack and
/// the thing that buys it more cells read as one.
const Color _kFrost = Color(0xFFDFF6FF);
const Color _kIce = Color(0xFF5CC4F2);
const Color _kIceDeep = Color(0xFF1E5B85);
const Color _kSocket = Color(0xFF3D566B);
const Color _kReadyGold = Color(0xFFFFD700);

/// Grains in storage turn at the pace they cultivate at.
const double _kStoredSpin = 1 / ColdStorageService.slowdownFactor;

/// Shows a dialog built by [builder]: how a stasis cell opens its details.
typedef StoragePresentDialog = Future<void> Function(WidgetBuilder builder);

/// Extracts a stored cultivation; called with the curtain already up.
typedef StorageExtract = Future<void> Function(Egg egg);

/// A stored cultivation's clock, read once for a cell and its dialog alike.
class _StoredTimes {
  const _StoredTimes(this.active, this.display, this.progress);

  /// What would be left in a chamber.
  final Duration active;

  /// What is left here, at a fifth of the pace.
  final Duration display;

  /// 0..1 through its time in storage, when that can be known.
  final double? progress;

  bool get ready => active <= Duration.zero;

  static _StoredTimes of(
    Egg egg,
    Map<String, dynamic> payload,
    Map<String, dynamic> coldPayload, [
    DateTime? nowUtc,
  ]) {
    final now = nowUtc ?? DateTime.now().toUtc();
    final fallback = Duration(milliseconds: egg.remainingMs);
    final active = ColdStorageService.activeRemainingFromPayload(
      coldPayload,
      fallbackActiveRemaining: fallback,
      nowUtc: now,
    );
    final display = ColdStorageService.coldStorageRemainingFromPayload(
      coldPayload,
      fallbackActiveRemaining: fallback,
      nowUtc: now,
    );
    final rarityHatch =
        BreedConstants.rarityHatchTimes[egg.rarity.toLowerCase()];
    final factor = ColdStorageService.slowdownFactorFromPayload(payload);
    final totalMs =
        ColdStorageService.totalDisplayDurationMsFromPayload(coldPayload) ??
        (rarityHatch == null ? null : rarityHatch.inMilliseconds * factor);
    final progress = (totalMs != null && totalMs > 0)
        ? (1 - display.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : null;
    return _StoredTimes(active, display, progress);
  }
}

/// How far up its cell the frost has grown. It thaws as the vial cultivates;
/// there is always a little while it is still in here, and none once ready.
double _frostFor(_StoredTimes t) =>
    t.ready ? 0 : 0.18 + 0.82 * (1 - (t.progress ?? 0));

class StorageSection extends StatefulWidget {
  final Color primaryColor;
  final CinematicQuality quality;
  final Widget Function(
    String title,
    IconData icon,
    Color color, {
    Widget? trailing,
  })
  buildSectionHeader;

  /// Offers the "move to empty chambers" bulk button (unlocked together
  /// with batch extraction).
  final bool canAutoMove;

  /// Shows a vial's dialog. The nursery passes its own, which pauses the
  /// chambers behind it as their dialogs do; without one it is a plain
  /// [showDialog].
  final StoragePresentDialog? presentDialog;

  /// Runs an extraction behind the dialog's curtain. The nursery passes its
  /// own, the one its chambers use — background paused, curtain held, the
  /// cultivation carried into the ceremony; without one the dialog runs the
  /// hatch itself.
  final StorageExtract? onExtract;

  const StorageSection({
    super.key,
    required this.primaryColor,
    required this.quality,
    required this.buildSectionHeader,
    this.canAutoMove = false,
    this.presentDialog,
    this.onExtract,
  });

  @override
  State<StorageSection> createState() => _StorageSectionState();
}

class _StorageSectionState extends State<StorageSection> {
  ElementalGroup? _selectedFaction;
  Timer? _clock;
  DateTime _nowUtc = DateTime.now().toUtc();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      // Hidden (another tab, or a screen pushed over this one): no one sees
      // the countdowns, and rebuilding every vial each second costs a frame.
      if (!mounted || !TickerMode.valuesOf(context).enabled) return;
      setState(() {
        _nowUtc = DateTime.now().toUtc();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Shown again: catch the countdowns up at once.
    if (TickerMode.valuesOf(context).enabled) {
      _nowUtc = DateTime.now().toUtc();
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final palette = BracketPalette.fromTheme(theme);
    final db = context.read<AlchemonsDatabase>();

    return StreamBuilder<String?>(
      stream: db.settingsDao.watchSetting(
        ColdStorageService.capacitySettingKey,
      ),
      builder: (context, capSnap) {
        final capacity = ColdStorageService.normalizeCapacity(
          int.tryParse(capSnap.data ?? '') ?? ColdStorageService.baseCapacity,
        );
        return StreamBuilder<List<Egg>>(
          stream: db.incubatorDao.watchInventory(),
          builder: (context, snap) {
            final items = snap.data ?? const <Egg>[];
            final groups = [
              for (final egg in items)
                getElementalGroupFromPayload(parseEggPayload(egg)),
            ];
            final present = {...groups};
            // A filter that no longer matches anything (its last vial left)
            // falls back to showing them all.
            final selected = present.contains(_selectedFaction)
                ? _selectedFaction
                : null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                widget.buildSectionHeader(
                  'COLD STORAGE',
                  AppIcons.ac_unit_rounded,
                  widget.primaryColor,
                  trailing: _CapacityReadout(
                    used: items.length,
                    capacity: capacity,
                    palette: palette,
                  ),
                ),
                if (present.length > 1) ...[
                  const SizedBox(height: 10),
                  _buildFactionFilter(
                    theme: theme,
                    palette: palette,
                    present: present,
                    selected: selected,
                  ),
                ],
                const SizedBox(height: 12),
                ViewportTickerGate(
                  child: _StasisRack(
                    items: items,
                    groups: groups,
                    capacity: capacity,
                    highlight: selected,
                    quality: widget.quality,
                    nowUtc: _nowUtc,
                    presentDialog: widget.presentDialog,
                    onExtract: widget.onExtract,
                  ),
                ),
                const SizedBox(height: 10),
                _buildFooter(palette: palette, theme: theme, items: items),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFooter({
    required BracketPalette palette,
    required FactionTheme theme,
    required List<Egg> items,
  }) {
    final caption = Text(
      items.isEmpty
          ? 'Empty. Vials kept here cultivate at a fifth of the pace.'
          : 'Cultivating at a fifth of the pace.',
      style: bracketText(
        context,
        12,
        palette.muted,
        weight: FontWeight.w500,
        fontStyle: FontStyle.italic,
      ),
    );

    if (!widget.canAutoMove || items.isEmpty) return caption;

    return StreamBuilder<List<IncubatorSlot>>(
      stream: context.read<AlchemonsDatabase>().incubatorDao.watchSlots(),
      builder: (context, snap) {
        final emptyChambers = (snap.data ?? const <IncubatorSlot>[])
            .where((s) => s.unlocked && s.eggId == null)
            .length;
        final moveCount = math.min(emptyChambers, items.length);
        if (moveCount == 0) return caption;
        return Row(
          children: [
            Expanded(child: caption),
            const SizedBox(width: 10),
            BracketButton(
              label: 'TO CHAMBERS',
              height: 34,
              palette: palette,
              accent: bracketReadableAccent(theme, color: _kIce),
              icon: AppIcons.bubble_chart_rounded,
              trailing: Text(
                '$moveCount',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: bracketReadableAccent(theme, color: _kIce),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              onTap: () => _autoMoveToChambers(items),
            ),
          ],
        );
      },
    );
  }

  Future<void> _autoMoveToChambers(List<Egg> items) async {
    final db = context.read<AlchemonsDatabase>();
    int moved = 0;
    for (final egg in items) {
      if (await placeStoredEggInChamber(db, egg) == null) break;
      moved++;
    }
    if (!mounted || moved == 0) return;
    HapticFeedback.lightImpact();
    showGameSnack(
      context,
      '$moved specimen${moved == 1 ? '' : 's'} moved to chambers',
      icon: AppIcons.bubble_chart_rounded,
      accent: _kIce,
      duration: const Duration(seconds: 2),
    );
  }

  Widget _buildFactionFilter({
    required FactionTheme theme,
    required BracketPalette palette,
    required Set<ElementalGroup> present,
    required ElementalGroup? selected,
  }) {
    Widget chip(ElementalGroup? group, String label) => BracketControlChip(
      label: label,
      accentColor: group?.color ?? theme.accentSoft,
      selected: selected == group,
      showBracketWhenSelected: true,
      theme: theme,
      labelFontSize: 11.5,
      leading: group == null
          ? null
          : Container(
              width: 5,
              height: 5,
              color: bracketReadableAccent(theme, color: group.color),
            ),
      onTap: () => setState(() => _selectedFaction = group),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(null, 'All'),
          for (final group in ElementalGroup.values)
            if (present.contains(group)) ...[
              const SizedBox(width: 6),
              chip(group, group.displayName),
            ],
        ],
      ),
    );
  }
}

/// "7 / 10" beside the heading: how full the rack is.
class _CapacityReadout extends StatelessWidget {
  const _CapacityReadout({
    required this.used,
    required this.capacity,
    required this.palette,
  });

  final int used;
  final int capacity;
  final BracketPalette palette;

  @override
  Widget build(BuildContext context) {
    final full = used >= capacity;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(AppIcons.ac_unit_rounded, size: 12, color: palette.muted),
        const SizedBox(width: 5),
        Text(
          '$used / $capacity',
          style: TextStyle(
            fontFamily: 'monospace',
            color: full ? palette.ink : palette.muted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Moves one stored vial into the first free chamber, resuming cultivation
/// from where cold storage left it. Returns the chamber id, or null when
/// every unlocked chamber is occupied.
Future<int?> placeStoredEggInChamber(AlchemonsDatabase db, Egg egg) async {
  final freeSlot = await db.incubatorDao.firstFreeSlot();
  if (freeSlot == null) return null;

  final activeRemaining = ColdStorageService.activeRemainingFromEgg(egg);
  final hatchAt = DateTime.now().toUtc().add(activeRemaining);

  await db.incubatorDao.placeEgg(
    slotId: freeSlot.id,
    eggId: egg.eggId,
    resultCreatureId: egg.resultCreatureId,
    bonusVariantId: egg.bonusVariantId,
    rarity: egg.rarity,
    hatchAtUtc: hatchAt,
    payloadJson: ColdStorageService.clearColdStoragePayload(egg.payloadJson),
  );
  await db.incubatorDao.removeFromInventory(egg.eggId);
  return freeSlot.id;
}

// ─────────────────────────────────────────────────────────────────────────────
// THE STASIS RACK
// ─────────────────────────────────────────────────────────────────────────────

/// Cold storage as a honeycomb of stasis cells — the upgrade glyph's cells,
/// at full size. One cell per unit of capacity: the stored vials fill them in
/// order and the rest stay as empty sockets, so how much room is left is
/// something you can see rather than a number. It used to be a strip of
/// small cards scrolling sideways, each with its own brackets and bar.
class _StasisRack extends StatefulWidget {
  const _StasisRack({
    required this.items,
    required this.groups,
    required this.capacity,
    required this.highlight,
    required this.quality,
    required this.nowUtc,
    this.presentDialog,
    this.onExtract,
  });

  final List<Egg> items;

  /// [items]' elemental groups, in the same order.
  final List<ElementalGroup> groups;
  final int capacity;

  /// When set, the cells of other groups go dark.
  final ElementalGroup? highlight;
  final CinematicQuality quality;
  final DateTime nowUtc;
  final StoragePresentDialog? presentDialog;
  final StorageExtract? onExtract;

  /// A cell's width, aimed for: the column count follows from it.
  static const double targetCellWidth = 84;

  @override
  State<_StasisRack> createState() => _StasisRackState();
}

class _StasisRackState extends State<_StasisRack>
    with SingleTickerProviderStateMixin {
  // The cold coming off the rack. One controller for all of it.
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cells = math.max(widget.capacity, widget.items.length);
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        // Flat-topped hexes: each column steps three quarters of a cell
        // across, and every other column sits half a cell lower.
        final columns = math.max(
          1,
          math.min(
            cells,
            ((width / _StasisRack.targetCellWidth - 1) / 0.75 + 1).floor(),
          ),
        );
        final w = math.min(96.0, width / (1 + 0.75 * (columns - 1)));
        final h = w * math.sqrt(3) / 2;
        final rows = (cells / columns).ceil();
        final rackWidth = w * (1 + 0.75 * (columns - 1));
        final left = (width - rackWidth) / 2;
        final height = rows * h + (columns > 1 ? h / 2 : 0);

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              for (var i = 0; i < cells; i++)
                Positioned(
                  left: left + (i % columns) * w * 0.75,
                  top: (i ~/ columns) * h + ((i % columns).isOdd ? h / 2 : 0),
                  width: w,
                  height: h,
                  child: i < widget.items.length
                      ? StasisCell(
                          key: ValueKey(widget.items[i].eggId),
                          egg: widget.items[i],
                          quality: widget.quality,
                          nowUtc: widget.nowUtc,
                          presentDialog: widget.presentDialog,
                          onExtract: widget.onExtract,
                          dimmed:
                              widget.highlight != null &&
                              widget.groups[i] != widget.highlight,
                        )
                      : const StasisCell.socket(),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: _FrostDriftPainter(_drift)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One cell of the rack: a stored cultivation, or with no [egg] an empty
/// socket waiting for one.
class StasisCell extends StatefulWidget {
  const StasisCell({
    super.key,
    required Egg this.egg,
    required this.quality,
    required this.nowUtc,
    this.dimmed = false,
    this.presentDialog,
    this.onExtract,
  });

  const StasisCell.socket({super.key})
    : egg = null,
      quality = CinematicQuality.performance,
      nowUtc = null,
      dimmed = false,
      presentDialog = null,
      onExtract = null;

  final Egg? egg;
  final CinematicQuality quality;
  final DateTime? nowUtc;

  /// Filtered out: the cell goes dark and its grains are put away.
  final bool dimmed;

  /// Shows the cell's dialog; see [StorageSection.presentDialog].
  final StoragePresentDialog? presentDialog;

  /// Extracts it; see [StorageSection.onExtract].
  final StorageExtract? onExtract;

  @override
  State<StasisCell> createState() => _StasisCellState();
}

class _StasisCellState extends State<StasisCell> {
  // The egg's payload, decoded once per payload rather than several times
  // a build: the countdown rebuilds every cell every second.
  bool _decoded = false;
  String? _payloadJson;
  Map<String, dynamic> _payload = const {};
  Map<String, dynamic> _coldPayload = const {};

  void _decode(Egg egg) {
    final json = egg.payloadJson;
    if (_decoded && json == _payloadJson) return;
    _decoded = true;
    _payloadJson = json;
    _payload = parseEggPayload(egg);
    _coldPayload = ColdStorageService.decodePayload(json);
  }

  @override
  Widget build(BuildContext context) {
    final egg = widget.egg;
    if (egg == null) {
      return CustomPaint(
        painter: _StasisCellPainter(
          state: _CellState.socket,
          onParchment: !BracketPalette.of(context).isDark,
        ),
      );
    }

    _decode(egg);
    final payload = _payload;
    final nowUtc = widget.nowUtc ?? DateTime.now().toUtc();
    final elementGroup = getElementalGroupFromPayload(payload);
    final times = _StoredTimes.of(egg, payload, _coldPayload, nowUtc);
    final displayRemaining = times.display;
    final isReady = times.ready;
    final progress = times.progress;

    // Neither the viewport gate's TickerMode nor a fling's deferred-loading
    // hint may change these: either one rebuilt every sphere from nothing,
    // so the grains popped in as the rack scrolled into view and again when
    // a fling settled. A muted ticker already stops the sphere by itself.
    final showGrains =
        !widget.dimmed && !MediaQuery.of(context).disableAnimations;
    final grains = switch (widget.quality) {
      CinematicQuality.cinematic => 220,
      CinematicQuality.performance => 140,
    };

    final isBloodborn = isBloodbornPayload(payload);
    final light = isBloodborn ? kBloodbornSecondary : elementGroup.color;

    return _HexHitBox(
      child: GestureDetector(
        onTap: context.soundAction(() => _showEggDetails(context, payload)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Its own layer, so the grains turning over it do not repaint the
            // cell's gradients and frost every frame (they share the rack's
            // layer otherwise, and every cell in it went with them).
            RepaintBoundary(
              child: CustomPaint(
                painter: _StasisCellPainter(
                  onParchment: !BracketPalette.of(context).isDark,
                  state: widget.dimmed
                      ? _CellState.dimmed
                      : (isReady ? _CellState.ready : _CellState.held),
                  light: light,
                  frost: _frostFor(times),
                  seed: egg.eggId.hashCode,
                ),
              ),
            ),
            if (showGrains)
              LayoutBuilder(
                builder: (context, box) {
                  final side = box.maxHeight * 0.66;
                  return Align(
                    alignment: const Alignment(0, -0.35),
                    child: SizedBox.square(
                      dimension: side,
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          child: CultivationSphere(
                            payload: payload,
                            types: isBloodborn
                                ? const ['blood', 'dark']
                                : _sphereTypes(payload, elementGroup),
                            progress: progress,
                            isReady: isReady,
                            grains: grains,
                            interactive: false,
                            spinScale: _kStoredSpin,
                            radiusFactor: 0.36,
                            pureElement: pureElementFromPayload(payload),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            Align(
              alignment: const Alignment(0, 0.8),
              child: Text(
                isReady ? 'READY' : _fmtShort(displayRemaining),
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: (isReady ? _kReadyGold : Colors.white).withValues(
                    alpha: widget.dimmed ? 0.35 : (isReady ? 1 : 0.88),
                  ),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEggDetails(BuildContext context, Map<String, dynamic> payload) {
    Widget dialog(BuildContext _) => StoredCultivationDialog(
      hostContext: this.context,
      egg: widget.egg!,
      onExtract: widget.onExtract,
    );
    final present = widget.presentDialog;
    if (present != null) {
      present(dialog);
    } else {
      showDialog<void>(context: context, builder: dialog);
    }
  }
}

String _fmtShort(Duration d) {
  // Cold storage multiplies waits by five; "349h 59m" is too wide for a cell
  // and reads worse than "14d 13h".
  if (d.inHours >= 24) return '${d.inDays}d ${d.inHours.remainder(24)}h';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m';
  return '${s}s';
}

/// The two element types a stored cultivation's sphere is coloured by.
List<String> _sphereTypes(
  Map<String, dynamic> payload,
  ElementalGroup elementGroup,
) {
  final types = extractParticleTypeIdsFromPayload(payload);
  if (types.isNotEmpty) return types;
  final (a, b) = elementGroup.particleTypes;
  return [a, ?b];
}

enum _CellState { socket, held, ready, dimmed }

/// A flat-topped hexagon filling [size], inset by [inset].
Path _hexPath(Size size, double inset) {
  final c = size.center(Offset.zero);
  final r = size.width / 2 - inset;
  final path = Path();
  for (var i = 0; i < 6; i++) {
    final a = i * math.pi / 3;
    final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  return path..close();
}

/// A stasis cell in material, not line: an ice bevel (a filled hex, lit from
/// above) holding a well of dark glass, with the vial's colour pooled in it
/// and frost grown up from the floor in tapered crystals.
class _StasisCellPainter extends CustomPainter {
  const _StasisCellPainter({
    required this.state,
    this.onParchment = false,
    this.light = _kIce,
    this.frost = 0,
    this.seed = 0,
  });

  final _CellState state;

  /// The light theme. Only an empty socket changes: a recess in the
  /// parchment rather than a black hole in it. A cell holding something is
  /// dark glass on either theme, as every vial is.
  final bool onParchment;
  final Color light;

  /// 0..1, how far up the cell the frost has grown.
  final double frost;
  final int seed;

  /// The seam left round the cell, and its bevel's width: fixed at rack size,
  /// growing for the dialog's large cell so its ice does not go thin.
  static double _seam(Size s) => math.max(2.2, s.width * 0.01);
  static double _bevel(Size s) => math.max(2.4, s.width * 0.028);

  @override
  void paint(Canvas canvas, Size size) {
    final outer = _hexPath(size, _seam(size));
    final inner = _hexPath(size, _seam(size) + _bevel(size));
    final rect = Offset.zero & size;
    final p = Paint();

    final socket = state == _CellState.socket;
    if (socket && onParchment) {
      _paintParchmentSocket(canvas, size, outer, inner, rect, p);
      return;
    }

    // The bevel.
    final bevel = switch (state) {
      _CellState.ready => const [
        Color(0xFFFFEDB0),
        Color(0xFFC9962E),
        Color(0xFF3A2A10),
      ],
      _CellState.held => [
        _kFrost.withValues(alpha: 0.85),
        _kIceDeep,
        const Color(0xFF0C1C2A),
      ],
      _ => const [Color(0xFF4A6275), Color(0xFF243443), Color(0xFF0E151D)],
    };
    canvas.drawPath(
      outer,
      p
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: bevel,
          stops: const [0.0, 0.45, 1.0],
        ).createShader(rect),
    );

    // The well of glass.
    canvas.drawPath(
      inner,
      p
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: socket || state == _CellState.dimmed
              ? const [Color(0xFF06080B), Color(0xFF0B1016)]
              : const [Color(0xFF0E1620), Color(0xFF06080C)],
        ).createShader(rect),
    );

    if (socket) {
      // An empty socket: a faint bead of cold at its heart, nothing more.
      final c = size.center(Offset.zero);
      canvas.drawCircle(
        c,
        size.height * 0.07,
        p
          ..shader =
              RadialGradient(
                colors: [
                  _kSocket.withValues(alpha: 0.9),
                  _kSocket.withValues(alpha: 0),
                ],
              ).createShader(
                Rect.fromCircle(center: c, radius: size.height * 0.07),
              ),
      );
      p.shader = null;
      return;
    }

    canvas.save();
    canvas.clipPath(inner);

    // The vial's light, pooled behind its grains.
    if (state != _CellState.dimmed) {
      final c = Offset(size.width / 2, size.height * 0.42);
      final r = size.height * 0.52;
      final glow = state == _CellState.ready
          ? Color.lerp(light, _kReadyGold, 0.45)!
          : light;
      canvas.drawCircle(
        c,
        r,
        p
          ..shader = RadialGradient(
            colors: [
              glow.withValues(alpha: state == _CellState.ready ? 0.3 : 0.2),
              glow.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    // Frost, grown up from the floor of the cell: tapered crystals whose
    // edge catches the light, over a soft body of rime.
    if (frost > 0.01) {
      final floor = size.height - _seam(size) - _bevel(size);
      final top = floor - frost * size.height * 0.4;
      final a = state == _CellState.dimmed ? 0.1 : 0.26;
      // Crystals keep their rack size in a larger cell — more of them, no
      // taller — or the dialog's cell grows a mountain range.
      final grain = (73 / size.height).clamp(0.3, 1.0);
      final crystals = Path()..moveTo(0, floor);
      final teeth = math.max(21, (size.width / 4).round()) | 1;
      for (var k = 0; k <= teeth; k++) {
        final x = size.width * k / teeth;
        final jag = ((seed * 31 + k * 17) % 13) / 13.0;
        final y = k.isEven
            ? top - size.height * grain * (0.015 + 0.045 * jag)
            : top + size.height * grain * (0.004 + 0.01 * jag);
        crystals.lineTo(x, y);
      }
      crystals
        ..lineTo(size.width, floor)
        ..close();
      final reach = top - size.height * grain * 0.07;
      canvas.drawPath(
        crystals,
        p
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _kFrost.withValues(alpha: a * 0.2),
              _kFrost.withValues(alpha: a),
              _kIce.withValues(alpha: a * 0.3),
              _kFrost.withValues(alpha: a * 0.5),
            ],
            // The bright rime sits at the crystals' edge, wherever that is.
            stops: [
              0.0,
              ((top - reach) / (floor - reach)).clamp(0.0, 1.0) * 0.9,
              0.75,
              1.0,
            ],
          ).createShader(Rect.fromLTRB(0, reach, 0, floor)),
      );
    }

    // Light off the glass's upper face.
    canvas.drawRect(
      Rect.fromLTRB(0, 0, size.width, size.height * 0.3),
      p
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.07),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTRB(0, 0, 0, size.height * 0.3)),
    );

    canvas.restore();
    p.shader = null;
  }

  void _paintParchmentSocket(
    Canvas canvas,
    Size size,
    Path outer,
    Path inner,
    Rect rect,
    Paint p,
  ) {
    // Lit from above like the cells, so the lower lip is the bright one.
    canvas.drawPath(
      outer,
      p
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB3A285), Color(0xFFD2C5AD), Color(0xFFF4EDE0)],
        ).createShader(rect),
    );
    // The recess, shadowed under its upper lip.
    canvas.drawPath(
      inner,
      p
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD5C8B1), Color(0xFFE6DCCA), Color(0xFFEDE4D4)],
          stops: [0.0, 0.35, 1.0],
        ).createShader(rect),
    );
    final c = size.center(Offset.zero);
    final r = size.height * 0.08;
    canvas.drawCircle(
      c,
      r,
      p
        ..shader = RadialGradient(
          colors: [
            _kIceDeep.withValues(alpha: 0.28),
            _kIceDeep.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    p.shader = null;
  }

  @override
  bool shouldRepaint(_StasisCellPainter old) =>
      old.state != state ||
      old.onParchment != onParchment ||
      old.light != light ||
      (old.frost - frost).abs() > 0.002 ||
      old.seed != seed;
}

/// Takes taps on its hexagon only: neighbouring cells' boxes overlap by a
/// quarter of their width, and the corner of one would steal the other's.
class _HexHitBox extends SingleChildRenderObjectWidget {
  const _HexHitBox({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHexHitBox();
}

class _RenderHexHitBox extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!_hexPath(size, 0).contains(position)) return false;
    return super.hitTest(result, position: position);
  }
}

/// Cold coming off the rack: a few motes of frost rising slowly across it.
/// One painter and one controller for the whole rack, and few enough motes
/// to cost nothing.
class _FrostDriftPainter extends CustomPainter {
  _FrostDriftPainter(this.t) : super(repaint: t);

  final Animation<double> t;

  static const int _motes = 14;
  static final Paint _p = Paint();

  static double _seed(int i, int salt) => ((i * 47 + salt * 23) % 100) / 100.0;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _motes; i++) {
      final phase = (t.value + _seed(i, 1)) % 1.0;
      final fade =
          (phase < 0.2 ? phase / 0.2 : 1.0) *
          (phase > 0.7 ? (1 - phase) / 0.3 : 1.0);
      if (fade <= 0.02) continue;
      final sway = math.sin((phase + _seed(i, 2)) * math.pi * 2) * 6;
      final x = _seed(i, 3) * size.width + sway;
      final y = size.height * (1.0 - phase);
      canvas.drawCircle(
        Offset(x, y),
        0.9 + _seed(i, 4) * 0.9,
        _p..color = _kFrost.withValues(alpha: 0.42 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(_FrostDriftPainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// A STORED CULTIVATION, UP CLOSE
// ─────────────────────────────────────────────────────────────────────────────

/// What tapping a stasis cell opens: that cell, large, on the same dark stage
/// as a chamber's own dialog, with the same controls — the thing to do written
/// on the vessel (and the vessel itself the target), delete and close in the
/// corners, the countdown between them. It used to be a bottom sheet with a
/// boxed vial, a solid green button and a countdown that never moved.
class StoredCultivationDialog extends StatefulWidget {
  const StoredCultivationDialog({
    super.key,
    required this.hostContext,
    required this.egg,
    this.onExtract,
  });

  /// The cell's context, which outlives this dialog for the extraction.
  final BuildContext hostContext;
  final Egg egg;
  final StorageExtract? onExtract;

  @override
  State<StoredCultivationDialog> createState() =>
      _StoredCultivationDialogState();
}

class _StoredCultivationDialogState extends State<StoredCultivationDialog> {
  late final Map<String, dynamic> _payload = parseEggPayload(widget.egg);
  late final Map<String, dynamic> _coldPayload =
      ColdStorageService.decodePayload(widget.egg.payloadJson);
  Timer? _clock;
  bool _busy = false;

  /// The sphere on the stage, handed on to the hatching ceremony so it opens
  /// on this cultivation instead of on black — as a chamber's does.
  final GlobalKey _sphereKey = GlobalKey();

  /// The vessel's width; flat-topped, so its height is √3/2 of this.
  static const double _cellWidth = 272;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);
    const ink = Color(0xFFE8DCC8);
    const muted = Color(0xFF9A8D7C);

    final egg = widget.egg;
    final payload = _payload;
    final times = _StoredTimes.of(egg, payload, _coldPayload);
    final elementGroup = getElementalGroupFromPayload(payload);
    final isBloodborn = isBloodbornPayload(payload);
    final light = isBloodborn ? kBloodbornSecondary : elementGroup.color;
    final media = MediaQuery.of(context);
    final showGrains =
        TickerMode.valuesOf(context).enabled && !media.disableAnimations;
    final ready = times.ready;
    final act = ready ? _extract : _toChamber;

    final source = _formatSource(payload['source'] as String?);
    final parents = _parentNames(payload);
    final lineage = [
      elementGroup.displayName,
      ?source,
      if (parents.isNotEmpty) parents.join(' × '),
    ].join('  ·  ');

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: ColoredBox(
            color: kCultivationStage,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 44 + _cellWidth * math.sqrt(3) / 2 + 46,
                  child: Stack(
                    children: [
                      // The cell, large, under its label. Tapping it does
                      // what its word says.
                      Positioned(
                        top: 44,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: SizedBox(
                            width: _cellWidth,
                            height: _cellWidth * math.sqrt(3) / 2,
                            child: _HexHitBox(
                              child: GestureDetector(
                                onTap: context.soundTap(act),
                                behavior: HitTestBehavior.opaque,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CustomPaint(
                                      painter: _StasisCellPainter(
                                        state: ready
                                            ? _CellState.ready
                                            : _CellState.held,
                                        light: light,
                                        frost: _frostFor(times),
                                        seed: egg.eggId.hashCode,
                                      ),
                                    ),
                                    if (showGrains)
                                      Align(
                                        alignment: const Alignment(0, -0.3),
                                        child: SizedBox.square(
                                          dimension: _cellWidth * 0.6,
                                          // Its parents' grains, which a held
                                          // finger can part.
                                          child: CultivationSphere(
                                            key: _sphereKey,
                                            payload: payload,
                                            types: isBloodborn
                                                ? const ['blood', 'dark']
                                                : _sphereTypes(
                                                    payload,
                                                    elementGroup,
                                                  ),
                                            progress: times.progress,
                                            isReady: ready,
                                            grains: 1100,
                                            spinScale: _kStoredSpin,
                                            radiusFactor: 0.36,
                                            pureElement: pureElementFromPayload(
                                              payload,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 14,
                        child: CultivationChamberPill(
                          label: 'COLD STORAGE',
                          color: ready ? _kReadyGold : _kIce,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: VialActionButton(
                            label: ready ? 'EXTRACT' : 'TO CHAMBER',
                            onTap: act,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
                  child: Row(
                    children: [
                      StageIconButton(
                        icon: AppIcons.delete_outline_rounded,
                        tooltip: 'Delete specimen',
                        color: t.danger,
                        heavy: true,
                        onTap: _confirmDelete,
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ready ? 'READY' : _fmtShort(times.display),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: ready ? _kReadyGold : _kIce,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              ready
                                  ? 'Cultivation complete'
                                  : '${_fmtShort(times.active)} in a chamber',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StageIconButton(
                        icon: AppIcons.close_rounded,
                        tooltip: 'Close',
                        // The stage is dark on both themes; the theme's own
                        // secondary text is dark on the light one.
                        color: muted,
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                  child: Column(
                    children: [
                      Text(
                        getEggLabel(payload),
                        textAlign: TextAlign.center,
                        style: bracketText(
                          context,
                          14,
                          ink,
                          weight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        lineage,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: bracketText(
                          context,
                          12,
                          muted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toChamber() async {
    if (_busy) return;
    _busy = true;
    final t = ForgeTokens(context.read<FactionTheme>());
    final db = context.read<AlchemonsDatabase>();
    final chamber = await placeStoredEggInChamber(db, widget.egg);
    if (!mounted) return;
    _busy = false;

    // Told before the dialog closes: once it has, its context is gone.
    if (chamber == null) {
      HapticFeedback.heavyImpact();
      showGameSnack(
        context,
        'All chambers are full',
        icon: AppIcons.lock_rounded,
        accent: t.danger,
        duration: const Duration(seconds: 2),
      );
      return;
    }
    HapticFeedback.lightImpact();
    showGameSnack(
      context,
      'Added to chamber ${chamber + 1}',
      icon: AppIcons.bubble_chart_rounded,
      accent: t.amberBright,
      duration: const Duration(seconds: 2),
    );
    Navigator.pop(context);
  }

  Future<void> _extract() async {
    if (_busy) return;
    _busy = true;
    HapticFeedback.heavyImpact();
    final host = widget.hostContext;
    final t = ForgeTokens(context.read<FactionTheme>());

    // The chamber's order: carry the grains, go dark, and only then close
    // the dialog underneath, so the nursery never flashes back up between
    // the dialog and the ceremony.
    CultivationHandoff.stage(CultivationSphere.handoffFrom(_sphereKey));
    await HatchCurtain.raise(context);
    if (!mounted) {
      HatchCurtain.lower();
      return;
    }
    Navigator.pop(context);

    final onExtract = widget.onExtract;
    if (onExtract != null) {
      await onExtract(widget.egg);
      return;
    }
    if (!host.mounted) {
      HatchCurtain.lower();
      return;
    }
    late final HatchingResult result;
    try {
      result = await EggHatching.performStorageHatching(
        context: host,
        egg: widget.egg,
      );
    } finally {
      HatchCurtain.lower();
    }
    if (!host.mounted || result.success || result.message == null) return;
    showGameSnack(
      host,
      result.message!,
      icon: result.icon ?? AppIcons.error_rounded,
      accent: result.color ?? t.danger,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _confirmDelete() async {
    final t = ForgeTokens(context.read<FactionTheme>());
    final confirmed = await showBracketConfirm(
      context,
      palette: BracketPalette.of(context),
      accent: t.danger,
      title: 'DELETE SPECIMEN?',
      message: 'This is permanent and cannot be undone.',
      confirmLabel: 'DELETE',
      icon: AppIcons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;

    await context.read<AlchemonsDatabase>().incubatorDao.removeFromInventory(
      widget.egg.eggId,
    );
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    showGameSnack(
      context,
      'Specimen deleted',
      icon: AppIcons.delete_outline_rounded,
      accent: t.danger,
      duration: const Duration(seconds: 2),
    );
    Navigator.pop(context);
  }

  /// Where it came from, in words; null when the record does not say.
  static String? _formatSource(String? source) {
    return switch (source) {
      null || '' || 'unknown' => null,
      'wild_capture' || 'wild' => 'Wild Capture',
      'wild_fusion' || 'wild_breeding' => 'Wild Fusion',
      'standard_fusion' || 'breeding' => 'Standard Fusion',
      'rift_portal' => 'Rift Portal',
      'planet_summon' => 'Planet Summon',
      'boss_summon' => 'Altar Summon',
      'vial' => 'Extraction Vial',
      'bloodborn' => 'Bloodborn Rite',
      'starter' => 'Starter Selection',
      _ =>
        source
            .split('_')
            .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
            .join(' '),
    };
  }

  /// Its parents' names, when it has any on record.
  static List<String> _parentNames(Map<String, dynamic> payload) {
    final parentage = payload['parentage'];
    if (parentage is! Map) return const [];
    final names = <String>[];
    for (final key in const ['parentA', 'parentB']) {
      final raw = parentage[key];
      if (raw is! Map) continue;
      String name;
      try {
        name = ParentSnapshot.fromJson(Map<String, dynamic>.from(raw)).name;
      } catch (_) {
        name = raw['name'] as String? ?? '';
      }
      name = name.trim();
      if (name.isNotEmpty) names.add(name);
    }
    return names;
  }
}
