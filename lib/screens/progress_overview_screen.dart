import 'package:alchemons/audio/audio.dart';
// lib/screens/progress_overview_screen.dart
//
// Breeding milestones: every species you have bred, one row each — its
// portrait in a lit case, its name, how far it is to the next milestone and
// what that is worth, and the milestone track. Rows closest to their next
// milestone come first; species with every milestone reached sink to the
// bottom in gilt.
//
// Opened from the catalog, from the constellation screen, and from the
// "milestone reached" notice after a hatch (which lights that species' row).

import 'dart:async';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/constellation_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/catalog/milestone_track.dart';
import 'package:alchemons/widgets/instance_widgets/specimen_case.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ConstellationProgressOverviewScreen extends StatefulWidget {
  const ConstellationProgressOverviewScreen({
    super.key,
    this.highlightSpeciesId,
    this.onOpenSpecies,
  });

  /// A species whose row is brought into view and lit — the one a
  /// "milestone reached" notice was about.
  final String? highlightSpeciesId;

  /// Tapping a row: the Creatures tab passes this to show that species'
  /// specimens. Elsewhere rows are not tappable.
  final ValueChanged<String>? onOpenSpecies;

  @override
  State<ConstellationProgressOverviewScreen> createState() =>
      _ConstellationProgressOverviewScreenState();
}

class _ConstellationProgressOverviewScreenState
    extends State<ConstellationProgressOverviewScreen> {
  Future<List<BreedingStatistic>>? _stats;
  final GlobalKey _highlightKey = GlobalKey(debugLabel: 'milestone-highlight');
  bool _scrolledToHighlight = false;

  @override
  void initState() {
    super.initState();
    final id = widget.highlightSpeciesId;
    if (id != null) {
      // This screen is where the showcase is seen; don't play it twice.
      context
          .read<ConstellationService>()
          .consumePendingMilestoneShowcaseForSpecies(id);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stats = context.watch<ConstellationService>().getAllBreedingStats();
  }

  void _scrollToHighlight() {
    if (_scrolledToHighlight) return;
    _scrolledToHighlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _highlightKey.currentContext;
      if (!mounted || ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.3,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final palette = BracketPalette.fromTheme(theme);
    final accent = bracketReadableAccent(theme);
    final catalog = context.watch<CreatureCatalog>();
    final gilt = palette.isDark ? kCaseGilt : const Color(0xFF8A5A12);

    return Scaffold(
      backgroundColor: palette.bg1,
      body: SafeArea(
        child: FutureBuilder<List<BreedingStatistic>>(
          future: _stats,
          builder: (context, snap) {
            final rows = <(Creature, int)>[
              for (final s in snap.data ?? const <BreedingStatistic>[])
                if (s.totalBred > 0)
                  if (catalog.getCreatureById(s.speciesId) case final c?)
                    (c, s.totalBred),
            ];
            int? toGo((Creature, int) r) {
              final next = BreedingMilestone.nextMilestone(r.$2);
              return next == null ? null : next.count - r.$2;
            }

            rows.sort((a, b) {
              final ga = toGo(a), gb = toGo(b);
              if (ga == null && gb == null) {
                return a.$1.name.compareTo(b.$1.name);
              }
              if (ga == null) return 1;
              if (gb == null) return -1;
              return ga != gb
                  ? ga.compareTo(gb)
                  : a.$1.name.compareTo(b.$1.name);
            });
            final bred = rows.fold<int>(0, (sum, r) => sum + r.$2);
            final points = rows.fold<int>(
              0,
              (sum, r) => sum + breedingPointsEarned(r.$2, r.$1.rarity),
            );
            if (widget.highlightSpeciesId != null && rows.isNotEmpty) {
              _scrollToHighlight();
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
              children: [
                Row(
                  children: [
                    BracketIconButton(
                      icon: AppIcons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).maybePop(),
                      palette: palette,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BREEDING MILESTONES',
                            style: caseMono(13, palette.ink, spacing: 1.6),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Breed a species to earn constellation points',
                            style: caseMono(
                              9.5,
                              palette.muted,
                              weight: FontWeight.w600,
                              spacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      '$bred',
                      style: caseMono(15, palette.ink, weight: FontWeight.w900),
                    ),
                    Text(' BRED    ', style: caseMono(10.5, palette.muted)),
                    Text(
                      '$points',
                      style: caseMono(15, gilt, weight: FontWeight.w900),
                    ),
                    Text(
                      ' POINTS EARNED',
                      style: caseMono(10.5, palette.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (snap.hasData && rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(
                      'Nothing bred yet. Each species pays out at '
                      '${BreedingMilestone.milestones.map((m) => m.count).join(', ')} bred.',
                      style: caseMono(
                        11,
                        palette.muted,
                        weight: FontWeight.w600,
                        spacing: 0.3,
                      ),
                    ),
                  ),
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: () {
                      final row = _MilestoneRow(
                        species: r.$1,
                        bred: r.$2,
                        palette: palette,
                        accent: accent,
                        onTap: widget.onOpenSpecies == null
                            ? null
                            : () => widget.onOpenSpecies!(r.$1.id),
                      );
                      if (r.$1.id != widget.highlightSpeciesId) return row;
                      return _Highlight(key: _highlightKey, child: row);
                    }(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.species,
    required this.bred,
    required this.palette,
    required this.accent,
    this.onTap,
  });

  final Creature species;
  final int bred;
  final BracketPalette palette;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final next = BreedingMilestone.nextMilestone(bred);
    final done = next == null;
    final gilt = palette.isDark ? kCaseGilt : const Color(0xFF8A5A12);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null ? null : context.soundAction(onTap!),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: done
              ? gilt.withValues(alpha: 0.85)
              : palette.line.withValues(alpha: 0.5),
          bracketSize: 7,
        ),
        child: Container(
          color: palette.surfaceMutedFill(),
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
          child: Row(
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: CustomPaint(
                  painter: CaseLightPainter(color: caseElementLight(species)),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(
                      'assets/images/${species.image}',
                      cacheHeight: 120,
                      errorBuilder: (_, _, _) => const SizedBox(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            species.name.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: caseMono(10.5, palette.ink, spacing: 1),
                          ),
                        ),
                        Text(
                          done
                              ? 'ALL DONE'
                              : '$bred/${next.count}  '
                                    '+${next.getPointsForRarity(species.rarity)}',
                          style: caseMono(
                            9.5,
                            done ? gilt : palette.muted,
                            spacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    MilestoneTrack(
                      bred: bred,
                      palette: palette,
                      accent: accent,
                      labels: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The row a milestone notice was about: a gilt frame that flares twice and
/// settles. Drawn, not glowed.
class _Highlight extends StatefulWidget {
  const _Highlight({super.key, required this.child});

  final Widget child;

  @override
  State<_Highlight> createState() => _HighlightState();
}

class _HighlightState extends State<_Highlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    // Let the scroll arrive first.
    Timer(const Duration(milliseconds: 360), () {
      if (mounted) _ctl.forward();
    });
  }

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
      // Two flares, then a steady gilt frame.
      final flare = t < 0.6 ? (1 - ((t / 0.3) % 1 - 0.5).abs() * 2) : 0.0;
      final steady = t <= 0 ? 0.0 : 0.7;
      final a = (steady + 0.3 * flare).clamp(0.0, 1.0);
      return CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: kCaseGilt.withValues(alpha: a),
          bracketSize: 10,
          strokeWidth: 1.4 + 1.2 * flare,
        ),
        child: child,
      );
    },
    child: widget.child,
  );
}
