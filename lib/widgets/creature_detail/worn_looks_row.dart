// lib/widgets/creature_detail/worn_looks_row.dart
//
// The case it stands in and the trail it leaves (the Athanor's), at the end
// of WHAT IT WEARS on its details (WornStrip's trailing): one plus square
// each, lit while one is worn, shown only once one of that kind is owned.
// Each opens the ones owned, and the plain look, drawn. What is chosen is
// kept per creature by CosmeticWearService.
//
// Squares, not a row of their own, so the strip spaces all its squares
// alike.

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/cosmetic_wear.dart';
import 'package:alchemons/services/cosmetic_wear_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/creature_detail/worn_strip.dart';
import 'package:alchemons/widgets/fx/cosmetics/cosmetic_previews.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:alchemons/widgets/instance_widgets/specimen_case.dart'
    show CaseLightPainter;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// The case and trail squares for [instance], each only once one of its
/// kind is owned. Watches [CosmeticWearService] through [context].
List<WornSquare> wornLookSquares(
  BuildContext context, {
  required CreatureInstance instance,
  required String creatureName,
  required Color light,
}) {
  final wear = context.watch<CosmeticWearService?>();
  if (wear == null) return const [];
  return _WornLooks(
    instance: instance,
    creatureName: creatureName,
    light: light,
  ).squares(context, wear);
}

class _WornLooks {
  const _WornLooks({
    required this.instance,
    required this.creatureName,
    required this.light,
  });

  final CreatureInstance instance;
  final String creatureName;

  /// Its element's light, as its case shows it.
  final Color light;

  List<WornSquare> squares(BuildContext context, CosmeticWearService wear) {
    final cases = wear.ownedCases;
    final trails = wear.ownedTrails;
    final palette = BracketPalette.of(context);
    final accent = bracketReadableAccent(context.read<FactionTheme>());
    final id = instance.instanceId;
    final worn = wear.caseOf(id);
    final trail = wear.trailOf(id);
    return [
      if (cases.isNotEmpty)
        WornSquare(
          key: const ValueKey('worn-case'),
          label: 'CASE',
          lit: worn != null,
          onTap: () => _pickCase(context, wear, cases, worn, palette, accent),
        ),
      if (trails.isNotEmpty)
        WornSquare(
          key: const ValueKey('worn-trail'),
          label: 'TRAIL',
          lit: trail != null,
          onTap: () =>
              _pickTrail(context, wear, trails, trail, palette, accent),
        ),
    ];
  }

  Future<void> _pickCase(
    BuildContext context,
    CosmeticWearService wear,
    List<CaseStyle> owned,
    CaseStyle? worn,
    BracketPalette palette,
    Color accent,
  ) async {
    final picked = await _sheet<CaseStyle>(
      context,
      title: 'CASE · ${creatureName.toUpperCase()}',
      note: 'What it stands in on the Creatures tab.',
      options: [null, ...owned],
      worn: worn,
      nameOf: (s) => s?.title ?? 'Plain',
      art: (s) => _CaseArt(style: s, light: light),
      palette: palette,
      accent: accent,
    );
    if (picked == null) return;
    await wear.wearCase(instance.instanceId, picked.$1);
  }

  Future<void> _pickTrail(
    BuildContext context,
    CosmeticWearService wear,
    List<TrailStyle> owned,
    TrailStyle? worn,
    BracketPalette palette,
    Color accent,
  ) async {
    final picked = await _sheet<TrailStyle>(
      context,
      title: 'TRAIL · ${creatureName.toUpperCase()}',
      note: 'Left on the ground where it walks at home.',
      options: [null, ...owned],
      worn: worn,
      nameOf: (s) => s?.title ?? 'None',
      art: (s) => s == null ? const SizedBox.shrink() : _TrailArt(style: s),
      palette: palette,
      accent: accent,
    );
    if (picked == null) return;
    await wear.wearTrail(instance.instanceId, picked.$1);
  }

  /// The options as a grid; the one picked (a record, so "none" can be
  /// picked), or null if the sheet was closed.
  Future<(T?,)?> _sheet<T>(
    BuildContext context, {
    required String title,
    required String note,
    required List<T?> options,
    required T? worn,
    required String Function(T?) nameOf,
    required Widget Function(T?) art,
    required BracketPalette palette,
    required Color accent,
  }) => showModalBottomSheet<(T?,)>(
    context: context,
    backgroundColor: palette.bg1,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'monospace',
                color: palette.ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(note, style: bracketText(sheetCtx, 12, palette.muted)),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, box) {
                const gap = 8.0;
                final across = box.maxWidth >= 420 ? 4 : 3;
                final w = (box.maxWidth - gap * (across - 1)) / across;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final o in options)
                      SizedBox(
                        key: ValueKey('look-${nameOf(o)}'),
                        width: w,
                        child: _Slot(
                          lit: o == worn,
                          palette: palette,
                          accent: accent,
                          onTap: o == worn
                              ? null
                              : () => Navigator.of(sheetCtx).pop((o,)),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                            child: Column(
                              children: [
                                SizedBox(height: 74, child: art(o)),
                                const SizedBox(height: 6),
                                Text(
                                  nameOf(o),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: bracketText(
                                    context,
                                    11.5,
                                    palette.ink,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  o == worn ? 'WORN' : ' ',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// The fill and light the squares share: lit from below when worn.
class _Slot extends StatelessWidget {
  const _Slot({
    required this.lit,
    required this.palette,
    required this.accent,
    required this.onTap,
    required this.child,
  });

  final bool lit;
  final BracketPalette palette;
  final Color accent;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap == null
        ? null
        : context.soundAction(() {
            HapticFeedback.selectionClick();
            onTap!();
          }),
    child: CustomPaint(
      foregroundPainter: BracketFramePainter(
        color: lit ? accent : palette.line,
        strokeWidth: 1.2,
      ),
      child: Container(
        color: lit
            ? palette.accentWash(accent, darkAlpha: 0.12)
            : palette.surfaceMutedFill(),
        child: child,
      ),
    ),
  );
}

/// A case, small: a style, or the plain dark glass for null.
class _CaseArt extends StatelessWidget {
  const _CaseArt({required this.style, required this.light});

  final CaseStyle? style;
  final Color light;

  @override
  Widget build(BuildContext context) => Center(
    child: AspectRatio(
      aspectRatio: 104 / 132,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: style == null
              ? CaseLightPainter(color: light)
              : _CasePreviewPainter(style!, light),
        ),
      ),
    ),
  );
}

class _CasePreviewPainter extends CustomPainter {
  const _CasePreviewPainter(this.style, this.light);

  final CaseStyle style;
  final Color light;

  @override
  void paint(Canvas canvas, Size size) =>
      paintCasePreview(canvas, style, Offset.zero & size, light: light);

  @override
  bool shouldRepaint(_CasePreviewPainter old) =>
      old.style != style || old.light != light;
}

/// A trail's prints coming and going.
class _TrailArt extends StatefulWidget {
  const _TrailArt({required this.style});

  final TrailStyle style;

  @override
  State<_TrailArt> createState() => _TrailArtState();
}

class _TrailArtState extends State<_TrailArt> with GlyphClockLease {
  bool _visible = true;

  @override
  bool get wantsClock => _visible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    syncGlyphClock();
  }

  @override
  void dispose() {
    releaseGlyphClock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.infinite,
      painter: _TrailPainter(widget.style, glyphClock),
    ),
  );
}

class _TrailPainter extends CustomPainter {
  _TrailPainter(this.style, this.clock) : super(repaint: clock);

  final TrailStyle style;
  final ValueListenable<double>? clock;

  @override
  void paint(Canvas canvas, Size size) =>
      paintTrailPreview(canvas, style, Offset.zero & size, clock?.value ?? 2.4);

  @override
  bool shouldRepaint(_TrailPainter old) =>
      old.style != style || old.clock != clock;
}
