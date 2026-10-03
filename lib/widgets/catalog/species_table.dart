// lib/widgets/catalog/species_table.dart
//
// The species catalog, in either of two layouts the player toggles between:
//
//   SHELVES  one shelf per family, six across in element order.
//   TABLE    elements down (grouped by realm), families across — split into
//            two tables of four families, so the cells stay big on a phone.
//
// A found species is a glass cell with its portrait and a thin rarity edge;
// an unknown one is the Codex's still grain shadow. Progress is the catalog
// filling in.
//
// Everything is still: portraits are stills, the shadows paint once. The only
// thing that moves is a reveal, when a new species files itself away.

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/services/new_discovery_reveal_controller.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/fx/codex_stage.dart';
import 'package:alchemons/widgets/instance_widgets/specimen_case.dart';
import 'package:flutter/material.dart';

enum CatalogLayout { shelves, table }

class SpeciesTable extends StatelessWidget {
  const SpeciesTable({
    super.key,
    required this.entries,
    required this.counts,
    required this.palette,
    required this.accent,
    required this.onTap,
    this.layout = CatalogLayout.shelves,
    this.onLayoutChanged,
    this.query = '',
    this.revealCreatureId,
    this.controller,
    this.onOpenMilestones,
  });

  final List<CreatureEntry> entries;

  /// Specimens owned, by species id.
  final Map<String, int> counts;
  final BracketPalette palette;
  final Color accent;
  final void Function(Creature species, bool discovered) onTap;
  final CatalogLayout layout;
  final ValueChanged<CatalogLayout>? onLayoutChanged;

  /// Found species that do not match fade back; unknowns never match.
  final String query;
  final String? revealCreatureId;
  final ScrollController? controller;
  final VoidCallback? onOpenMilestones;

  static const double _rowHead = 62;
  static const int _shelfColumns = 6;

  /// Wider screens get a centred catalog rather than huge cells.
  static const double _maxWidth = 620;

  static const List<String> _elementOrder = [
    'Fire', 'Lava', 'Lightning', //
    'Water', 'Ice', 'Steam', //
    'Earth', 'Mud', 'Dust', 'Crystal', //
    'Air', 'Plant', 'Poison', //
    'Spirit', 'Light', 'Dark', 'Blood',
  ];

  @override
  Widget build(BuildContext context) {
    final found = entries.where((e) => e.player.discovered).length;
    final q = query.trim().toLowerCase();

    bool matches(CreatureEntry e) {
      if (q.isEmpty) return true;
      if (!e.player.discovered) return false;
      final c = e.creature;
      return c.name.toLowerCase().contains(q) ||
          c.id.toLowerCase().contains(q) ||
          c.rarity.toLowerCase().contains(q) ||
          c.types.any((t) => t.toLowerCase().contains(q));
    }

    Widget cell(CreatureEntry entry, {bool showElement = false}) {
      final c = entry.creature;
      final built = _Cell(
        key: ValueKey('species:${c.id}'),
        entry: entry,
        count: counts[c.id] ?? 0,
        palette: palette,
        faded: !matches(entry),
        showElement: showElement,
        onTap: () => onTap(c, entry.player.discovered),
      );
      if (c.id != revealCreatureId) return built;
      // Keyed so the filing-away card lands on this exact cell.
      final key = NewDiscoveryReveal.instance.revealTileKey ??= GlobalKey(
        debugLabel: 'reveal-tile-${c.id}',
      );
      return _RevealPulse(key: key, child: built);
    }

    final body = layout == CatalogLayout.shelves
        ? _shelves(cell)
        : _table(cell);

    return SingleChildScrollView(
      controller: controller,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Tally(
                palette: palette,
                accent: accent,
                found: found,
                total: entries.length,
                layout: layout,
                onLayoutChanged: onLayoutChanged,
                onOpenMilestones: onOpenMilestones,
              ),
              ...body,
            ],
          ),
        ),
      ),
    );
  }

  // ── SHELVES ────────────────────────────────────────────────────────────────

  List<Widget> _shelves(
    Widget Function(CreatureEntry, {bool showElement}) cell,
  ) {
    final out = <Widget>[];
    for (final family in CreatureFamily.values) {
      final list =
          entries.where((e) => _familyOf(e.creature) == family).toList()
            ..sort((a, b) {
              final byElement = _elementRank(
                a.creature,
              ).compareTo(_elementRank(b.creature));
              return byElement != 0
                  ? byElement
                  : a.creature.id.compareTo(b.creature.id);
            });
      if (list.isEmpty) continue;
      out
        ..add(const SizedBox(height: 14))
        ..add(
          _GroupHead(
            palette: palette,
            title: family.displayName.toUpperCase(),
            color: family.color,
            have: list.where((e) => e.player.discovered).length,
            total: list.length,
          ),
        )
        ..add(const SizedBox(height: 6));
      for (var i = 0; i < list.length; i += _shelfColumns) {
        out.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                for (var j = 0; j < _shelfColumns; j++) ...[
                  if (j > 0) const SizedBox(width: 4),
                  Expanded(
                    child: i + j < list.length
                        ? cell(list[i + j], showElement: true)
                        : const SizedBox(),
                  ),
                ],
              ],
            ),
          ),
        );
      }
    }
    return out;
  }

  // ── TABLE ──────────────────────────────────────────────────────────────────

  List<Widget> _table(Widget Function(CreatureEntry, {bool showElement}) cell) {
    // Slot every species by (element, family). A slot holding more than one
    // (the Mask family's second Bloodmask) spills into an extra row beneath
    // its element.
    final slots = <String, Map<CreatureFamily, List<CreatureEntry>>>{};
    for (final e in entries) {
      final c = e.creature;
      if (c.types.isEmpty) continue;
      final family = _familyOf(c);
      if (family == null) continue;
      ((slots[c.types.first] ??= {})[family] ??= []).add(e);
    }

    final out = <Widget>[];
    const families = CreatureFamily.values;
    for (final half in [families.sublist(0, 4), families.sublist(4)]) {
      out
        ..add(const SizedBox(height: 14))
        ..add(
          Row(
            children: [
              const SizedBox(width: _rowHead),
              for (final f in half)
                Expanded(
                  child: Center(
                    child: Text(
                      f.displayName.toUpperCase(),
                      style: caseMono(9.5, palette.muted, spacing: 0.8),
                    ),
                  ),
                ),
            ],
          ),
        );
      for (final group in ElementalGroup.values) {
        final inGroup = entries
            .where(
              (e) =>
                  half.contains(_familyOf(e.creature)) &&
                  e.creature.types.isNotEmpty &&
                  group.elementTypes.contains(e.creature.types.first),
            )
            .toList();
        out
          ..add(const SizedBox(height: 8))
          ..add(
            _GroupHead(
              palette: palette,
              title: group.displayName.toUpperCase(),
              color: group.color,
              have: inGroup.where((e) => e.player.discovered).length,
              total: inGroup.length,
            ),
          );
        for (final element in group.elementTypes) {
          final bySlot = slots[element] ?? const {};
          var depth = 1;
          for (final f in half) {
            final n = bySlot[f]?.length ?? 0;
            if (n > depth) depth = n;
          }
          for (var layer = 0; layer < depth; layer++) {
            out.add(
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: _rowHead,
                      child: layer == 0
                          ? _ElementHead(element: element, palette: palette)
                          : const SizedBox(),
                    ),
                    for (final f in half)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: () {
                            final list = bySlot[f];
                            if (list == null || layer >= list.length) {
                              return const AspectRatio(aspectRatio: 0.92);
                            }
                            return cell(list[layer]);
                          }(),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }
        }
      }
    }
    return out;
  }

  static int _elementRank(Creature c) {
    final i = c.types.isEmpty ? -1 : _elementOrder.indexOf(c.types.first);
    return i < 0 ? _elementOrder.length : i;
  }

  static CreatureFamily? _familyOf(Creature c) {
    for (final f in CreatureFamily.values) {
      if (c.id.startsWith(f.code)) return f;
    }
    return null;
  }
}

class _Tally extends StatelessWidget {
  const _Tally({
    required this.palette,
    required this.accent,
    required this.found,
    required this.total,
    required this.layout,
    this.onLayoutChanged,
    this.onOpenMilestones,
  });

  final BracketPalette palette;
  final Color accent;
  final int found, total;
  final CatalogLayout layout;
  final ValueChanged<CatalogLayout>? onLayoutChanged;
  final VoidCallback? onOpenMilestones;

  @override
  Widget build(BuildContext context) {
    Widget word(String label, bool on, VoidCallback? onTap) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null ? null : context.soundAction(onTap),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text(
          label,
          style: caseMono(10, on ? accent : palette.muted, spacing: 1.2),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '$found',
              style: caseMono(
                15,
                palette.ink,
                weight: FontWeight.w900,
                spacing: 0.5,
              ),
            ),
            Text(
              ' / $total  SPECIES',
              style: caseMono(10.5, palette.muted, weight: FontWeight.w700),
            ),
            const Spacer(),
            if (onOpenMilestones != null)
              word('MILESTONES ›', false, onOpenMilestones),
          ],
        ),
        if (onLayoutChanged != null)
          Row(
            children: [
              word(
                'SHELVES',
                layout == CatalogLayout.shelves,
                () => onLayoutChanged!(CatalogLayout.shelves),
              ),
              Text('·', style: caseMono(10, palette.muted)),
              word(
                'TABLE',
                layout == CatalogLayout.table,
                () => onLayoutChanged!(CatalogLayout.table),
              ),
            ],
          ),
      ],
    );
  }
}

class _GroupHead extends StatelessWidget {
  const _GroupHead({
    required this.palette,
    required this.title,
    required this.color,
    required this.have,
    required this.total,
  });

  final BracketPalette palette;
  final String title;
  final Color color;
  final int have, total;

  @override
  Widget build(BuildContext context) {
    final ink = palette.isDark
        ? Color.lerp(color, Colors.white, 0.25)!
        : Color.lerp(color, Colors.black, 0.35)!;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 3),
      child: Row(
        children: [
          Container(width: 6, height: 6, color: color),
          const SizedBox(width: 8),
          Text(title, style: caseMono(10, ink, spacing: 1.2)),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: palette.lineSoft)),
          const SizedBox(width: 10),
          Text(
            '$have/$total',
            style: caseMono(
              10,
              palette.muted,
              weight: FontWeight.w700,
              spacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ElementHead extends StatelessWidget {
  const _ElementHead({required this.element, required this.palette});

  final String element;
  final BracketPalette palette;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      MarkDiamond(color: elementLight(element), size: 5),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          element.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: caseMono(8, palette.muted, spacing: 0.3),
        ),
      ),
    ],
  );
}

class _Cell extends StatelessWidget {
  const _Cell({
    super.key,
    required this.entry,
    required this.count,
    required this.palette,
    required this.faded,
    required this.onTap,
    this.showElement = false,
  });

  final CreatureEntry entry;
  final int count;
  final BracketPalette palette;
  final bool faded;
  final VoidCallback onTap;

  /// A small element mark in the corner — the shelves have no element rows.
  final bool showElement;

  @override
  Widget build(BuildContext context) {
    final c = entry.creature;
    final known = entry.player.discovered;
    Widget cell;
    if (known) {
      cell = CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: caseElementLight(c).withValues(alpha: 0.6),
          bracketSize: 5,
          strokeWidth: 1,
        ),
        child: Container(
          color: kVialGlass,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(3, 3, 3, 5),
                child: Image.asset(
                  'assets/images/${c.image}',
                  fit: BoxFit.contain,
                  cacheHeight: 220,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => const SizedBox(),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 2,
                child: ColoredBox(
                  color: BreedConstants.getRarityColor(
                    c.rarity,
                  ).withValues(alpha: 0.85),
                ),
              ),
              if (count > 1)
                Positioned(
                  top: 1,
                  right: 3,
                  child: Text(
                    '×$count',
                    style: caseMono(
                      8,
                      kCaseGlassInk,
                      weight: FontWeight.w900,
                      spacing: 0,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    } else {
      cell = Container(
        color: palette.isDark
            ? Colors.white.withValues(alpha: 0.025)
            : Colors.black.withValues(alpha: 0.04),
        child: _Shadow(species: c, dark: palette.isDark),
      );
    }
    if (showElement) {
      cell = Stack(
        fit: StackFit.expand,
        children: [
          cell,
          Positioned(
            left: 5,
            top: 5,
            child: MarkDiamond(
              color: caseElementLight(c).withValues(alpha: known ? 1 : 0.55),
              size: 4.5,
            ),
          ),
        ],
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: AspectRatio(
        aspectRatio: 0.92,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: faded ? 0.22 : 1,
          child: RepaintBoundary(child: cell),
        ),
      ),
    );
  }
}

/// An unknown species: the Codex's locked grain shadow, painted once.
class _Shadow extends StatefulWidget {
  const _Shadow({required this.species, required this.dark});

  final Creature species;
  final bool dark;

  @override
  State<_Shadow> createState() => _ShadowState();
}

class _ShadowState extends State<_Shadow> {
  PortraitBody? _body;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_Shadow old) {
    super.didUpdateWidget(old);
    if (old.species.id != widget.species.id) {
      _body = null;
      _load();
    }
  }

  Future<void> _load() async {
    final c = widget.species;
    final body = await PortraitBody.load(
      c.image.startsWith('assets/') ? c.image : 'assets/images/${c.image}',
      height: 52,
      element: c.types.isEmpty ? 'Spirit' : c.types.first,
      color: const Color(0xFF3A404C),
      locked: true,
      maxGrains: 480,
    );
    if (!mounted) return;
    setState(() => _body = body);
  }

  @override
  Widget build(BuildContext context) => _body == null
      ? const SizedBox.expand()
      : CustomPaint(
          size: Size.infinite,
          painter: _ShadowPainter(_body!, widget.dark ? 0.55 : 0.4),
        );
}

class _ShadowPainter extends CustomPainter {
  _ShadowPainter(this.body, this.opacity);

  final PortraitBody body;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) => body.paint(
    canvas,
    size.center(Offset.zero),
    1.3,
    opacity: opacity,
    scale: 0.9,
  );

  @override
  bool shouldRepaint(_ShadowPainter old) =>
      old.body != body || old.opacity != opacity;
}

/// A newly found species, landing: the cell pops and a gilt frame flares and
/// fades. No blur — the frame is drawn, not glowed.
class _RevealPulse extends StatefulWidget {
  const _RevealPulse({super.key, required this.child});

  final Widget child;

  @override
  State<_RevealPulse> createState() => _RevealPulseState();
}

class _RevealPulseState extends State<_RevealPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctl,
    builder: (_, child) {
      final t = _ctl.value;
      final scale = t < 0.25
          ? 0.85 + 0.23 * (t / 0.25)
          : t < 0.45
          ? 1.08 - 0.08 * ((t - 0.25) / 0.2)
          : 1.0;
      final flare = (1 - t).clamp(0.0, 1.0);
      return Transform.scale(
        scale: scale,
        child: CustomPaint(
          foregroundPainter: BracketFramePainter(
            color: kCaseGilt.withValues(alpha: flare),
            bracketSize: 7,
            strokeWidth: 1 + 1.5 * flare,
          ),
          child: child,
        ),
      );
    },
    child: widget.child,
  );
}
