// lib/widgets/catalog/species_table.dart
//
// The species catalog as a table: the eight families across, the seventeen
// elements down, grouped by realm. A found species is a glass cell with its
// portrait and a thin rarity edge; an unknown one is the Codex's still grain
// shadow and nothing else. Progress is the table filling in.
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

class SpeciesTable extends StatelessWidget {
  const SpeciesTable({
    super.key,
    required this.entries,
    required this.counts,
    required this.palette,
    required this.onTap,
    this.query = '',
    this.revealCreatureId,
    this.controller,
    this.onOpenProgress,
  });

  final List<CreatureEntry> entries;

  /// Specimens owned, by species id.
  final Map<String, int> counts;
  final BracketPalette palette;
  final void Function(Creature species, bool discovered) onTap;

  /// Found species that do not match fade back; unknowns never match.
  final String query;
  final String? revealCreatureId;
  final ScrollController? controller;
  final VoidCallback? onOpenProgress;

  static const double _rowHead = 62;

  /// Wider screens get a centred table rather than huge cells.
  static const double _maxWidth = 560;

  @override
  Widget build(BuildContext context) {
    // Slot every species by (element, family). A slot holding more than one
    // (the Mask family's second Bloodmask) spills into an extra row beneath
    // its element.
    final slots = <String, Map<CreatureFamily, List<CreatureEntry>>>{};
    for (final e in entries) {
      final c = e.creature;
      if (c.types.isEmpty) continue;
      final family = _familyOf(c);
      if (family == null) continue;
      (slots[c.types.first] ??= {})[family] ??= [];
      slots[c.types.first]![family]!.add(e);
    }

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

    final rows = <Widget>[];
    for (final group in ElementalGroup.values) {
      final inGroup = entries
          .where(
            (e) =>
                e.creature.types.isNotEmpty &&
                group.elementTypes.contains(e.creature.types.first),
          )
          .toList();
      rows.add(
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
        final depth = bySlot.values.fold<int>(
          1,
          (d, list) => list.length > d ? list.length : d,
        );
        for (var layer = 0; layer < depth; layer++) {
          rows.add(
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: _rowHead,
                    child: layer == 0
                        ? _ElementHead(element: element, palette: palette)
                        : const SizedBox(),
                  ),
                  for (final family in CreatureFamily.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: () {
                          final list = bySlot[family];
                          final entry = list != null && layer < list.length
                              ? list[layer]
                              : null;
                          if (entry == null) {
                            return const AspectRatio(aspectRatio: 0.92);
                          }
                          final cell = _Cell(
                            key: ValueKey('species:${entry.creature.id}'),
                            entry: entry,
                            count: counts[entry.creature.id] ?? 0,
                            palette: palette,
                            faded: !matches(entry),
                            onTap: () =>
                                onTap(entry.creature, entry.player.discovered),
                          );
                          if (entry.creature.id != revealCreatureId) {
                            return cell;
                          }
                          // Keyed so the filing-away card lands on this
                          // exact cell.
                          final key =
                              NewDiscoveryReveal
                                  .instance
                                  .revealTileKey ??= GlobalKey(
                                debugLabel: 'reveal-tile-${entry.creature.id}',
                              );
                          return _RevealPulse(key: key, child: cell);
                        }(),
                      ),
                    ),
                ],
              ),
            ),
          );
        }
      }
      rows.add(const SizedBox(height: 10));
    }

    return SingleChildScrollView(
      controller: controller,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Tally(
                palette: palette,
                found: found,
                total: entries.length,
                onOpenProgress: onOpenProgress,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const SizedBox(width: _rowHead),
                  for (final family in CreatureFamily.values)
                    Expanded(
                      child: Center(
                        child: Text(
                          family.code,
                          style: caseMono(8.5, palette.muted, spacing: 0.6),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              ...rows,
            ],
          ),
        ),
      ),
    );
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
    required this.found,
    required this.total,
    this.onOpenProgress,
  });

  final BracketPalette palette;
  final int found, total;
  final VoidCallback? onOpenProgress;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        '$found',
        style: caseMono(15, palette.ink, weight: FontWeight.w900, spacing: 0.5),
      ),
      Text(
        ' / $total  SPECIES',
        style: caseMono(10.5, palette.muted, weight: FontWeight.w700),
      ),
      const Spacer(),
      if (onOpenProgress != null)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: context.soundAction(onOpenProgress!),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Text(
              'PROGRESS ›',
              style: caseMono(10, palette.muted, spacing: 1.2),
            ),
          ),
        ),
    ],
  );
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
  });

  final CreatureEntry entry;
  final int count;
  final BracketPalette palette;
  final bool faded;
  final VoidCallback onTap;

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
                  cacheHeight: 120,
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
      height: 30,
      element: c.types.isEmpty ? 'Spirit' : c.types.first,
      color: const Color(0xFF3A404C),
      locked: true,
      maxGrains: 260,
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
