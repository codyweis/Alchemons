// lib/screens/alchemical_encyclopedia_screen.dart
//
// THE FUSION CODEX: what the player has learned about fusing, by what it is
// made of.
//
//   ELEMENTS  the seventeen, in their five groups, each a glass orb of its
//             grains once it is known (an empty bulb until then). Open one
//             and it stands on a stage under dark glass — tap it and it comes
//             apart into its element — over the formulas that MAKE it and
//             those it FUSES INTO. Play a formula and its two makers pour
//             together on the stage and what they make gathers out of them.
//   SPECIES   the eight families the same way, shown by a creature of each.
//   NATURES   the behaviour log, once a Gene Analyzer is built.
//
// After a hatch that found something new, the Codex opens on it and plays
// the formula that made it (see [AlchemicalEncyclopediaScreen.unlockShowcase]).

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/nature.dart';
import 'package:alchemons/services/alchemical_encyclopedia_service.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/nature_effect_formatter.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart'
    show kVialGlass;
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/fx/codex_stage.dart';
import 'package:alchemons/widgets/fx/element_orb.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Gilt: the Codex's own accent.
const Color _kGilt = Color(0xFFE4B356);

/// Light ink, for what is written on the dark glass whatever the theme.
const Color _kGlassInk = Color(0xFFE8DCC8);
const Color _kGlassMuted = Color(0xFF8D8478);

TextStyle _mono(
  double size,
  Color color, {
  FontWeight weight = FontWeight.w700,
  double spacing = 1.2,
}) => TextStyle(
  fontFamily: 'monospace',
  color: color,
  fontSize: size,
  fontWeight: weight,
  letterSpacing: spacing,
);

/// An element's color as its orb shows it.
Color _elementTint(String element) =>
    elementOrbTint(EssenceElement.of(element));

/// A family's color.
Color _familyTint(String family) {
  for (final f in CreatureFamily.values) {
    if (f.displayName == family) return f.color;
  }
  return _kGilt;
}

class AlchemicalEncyclopediaScreen extends StatefulWidget {
  /// Formulas just found, to open on and play.
  final List<EncyclopediaRecipeEntry> unlockShowcase;

  const AlchemicalEncyclopediaScreen({
    super.key,
    this.unlockShowcase = const [],
  });

  @override
  State<AlchemicalEncyclopediaScreen> createState() =>
      _AlchemicalEncyclopediaScreenState();
}

class _AlchemicalEncyclopediaScreenState
    extends State<AlchemicalEncyclopediaScreen> {
  late Future<AlchemicalEncyclopediaSnapshot> _snapshotFuture;
  int _tab = 0;
  bool _showcaseQueued = false;

  /// What the showcase found, marked NEW on the tables.
  final Set<String> _fresh = {};

  /// A sheet covers the tables: they hold still under it.
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _snapshotFuture = AlchemicalEncyclopediaService.loadSnapshot(
      db: context.read<AlchemonsDatabase>(),
      catalog: _catalogOrNull(),
    );
  }

  CreatureCatalog? _catalogOrNull() {
    try {
      return context.read<CreatureCatalog>();
    } catch (_) {
      return null;
    }
  }

  void _reload() => setState(_load);

  // ── the showcase ──────────────────────────────────────────────────────

  void _queueShowcase(AlchemicalEncyclopediaSnapshot data) {
    if (_showcaseQueued || widget.unlockShowcase.isEmpty) return;
    _showcaseQueued = true;
    final seen = <String>{};
    final plays = <(EncyclopediaRecipeEntry, String)>[];
    for (final entry in widget.unlockShowcase) {
      if (!seen.add('${entry.kind.name}:${entry.pairKey}')) continue;
      final recipes = entry.kind == EncyclopediaRecipeKind.element
          ? data.elementRecipes
          : data.familyRecipes;
      final recipe = recipes.firstWhere(
        (r) => r.pairKey == entry.pairKey,
        orElse: () => entry,
      );
      final made = recipe.outcomes
          .map((o) => o.result)
          .where((r) => data.outcomeFound(recipe, r))
          .firstOrNull;
      if (made == null) continue;
      plays.add((recipe, made));
      _fresh.add(made);
    }
    if (plays.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final (recipe, made) in plays) {
        if (!mounted) return;
        final element = recipe.kind == EncyclopediaRecipeKind.element;
        setState(() => _tab = element ? 0 : 1);
        await Future<void>.delayed(const Duration(milliseconds: 240));
        if (!mounted) return;
        await _openSheet(data, kind: recipe.kind, name: made, showcase: recipe);
      }
    });
  }

  Future<void> _openSheet(
    AlchemicalEncyclopediaSnapshot data, {
    required EncyclopediaRecipeKind kind,
    required String name,
    EncyclopediaRecipeEntry? showcase,
  }) async {
    HapticFeedback.selectionClick();
    setState(() => _sheetOpen = true);
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        constraints: const BoxConstraints(maxWidth: 640),
        builder: (_) => _CodexSheet(
          data: data,
          kind: kind,
          name: name,
          showcase: showcase,
          fresh: _fresh,
        ),
      );
    } finally {
      if (mounted) setState(() => _sheetOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    final hasNatureTab = context
        .watch<ConstellationEffectsService>()
        .hasGeneAnalyzer();
    if (!hasNatureTab && _tab > 1) _tab = 0;

    return Scaffold(
      backgroundColor: palette.bg0,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [palette.bg1, palette.bg0],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<AlchemicalEncyclopediaSnapshot>(
            future: _snapshotFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _LoadFailure(palette: palette, onRetry: _reload);
              }
              final data = snapshot.data;
              if (data == null) {
                return Center(child: CircularProgressIndicator(color: _kGilt));
              }
              _queueShowcase(data);
              final found =
                  data.discoveredElementKeys.length +
                  data.discoveredFamilyKeys.length;
              final total =
                  data.elementRecipes.length + data.familyRecipes.length;
              return Column(
                children: [
                  _Header(
                    palette: palette,
                    found: found,
                    total: total,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: BracketTabs(
                      labels: [
                        'ELEMENTS',
                        'SPECIES',
                        if (hasNatureTab) 'NATURES',
                      ],
                      selected: _tab,
                      onSelect: (i) => setState(() => _tab = i),
                      palette: palette,
                      accent: _kGilt,
                    ),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _tab,
                      children: [
                        _ElementTable(
                          data: data,
                          palette: palette,
                          fresh: _fresh,
                          live: _tab == 0 && !_sheetOpen,
                          onOpen: (e) => _openSheet(
                            data,
                            kind: EncyclopediaRecipeKind.element,
                            name: e,
                          ),
                        ),
                        _SpeciesTable(
                          data: data,
                          palette: palette,
                          fresh: _fresh,
                          live: _tab == 1 && !_sheetOpen,
                          onOpen: (f) => _openSheet(
                            data,
                            kind: EncyclopediaRecipeKind.family,
                            name: f,
                          ),
                        ),
                        if (hasNatureTab)
                          _NatureLog(data: data, palette: palette),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.palette,
    required this.found,
    required this.total,
    required this.onBack,
  });

  final BracketPalette palette;
  final int found, total;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : (found * 100 / total).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          BracketIconButton(
            icon: AppIcons.arrow_back_rounded,
            onTap: onBack,
            palette: palette,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ALCHEMY', style: _mono(11, palette.muted, spacing: 2.2)),
                const SizedBox(height: 2),
                Text(
                  'FUSION CODEX',
                  style: _mono(16, palette.ink, weight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$pct%',
                style: _mono(
                  16,
                  palette.isDark ? _kGilt : const Color(0xFF9A6B00),
                  weight: FontWeight.w900,
                  spacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$found / $total FORMULAS',
                style: _mono(10, palette.muted, spacing: 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.palette, required this.onRetry});

  final BracketPalette palette;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'THE CODEX WOULD NOT OPEN',
            textAlign: TextAlign.center,
            style: _mono(13, palette.ink, weight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Its records could not be read.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 160,
            child: BracketButton(
              label: 'TRY AGAIN',
              onTap: onRetry,
              palette: palette,
              accent: _kGilt,
              height: 40,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Tallies ────────────────────────────────────────────────────────────────

/// "12 / 17 ELEMENTS KNOWN" over a thin bar.
class _Tally extends StatelessWidget {
  const _Tally({
    required this.palette,
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final BracketPalette palette;
  final String label;
  final int value, total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = total == 0 ? 0.0 : value / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$value',
                style: _mono(15, palette.ink, weight: FontWeight.w900),
              ),
              TextSpan(
                text: ' / $total  ',
                style: _mono(11, palette.muted, weight: FontWeight.w700),
              ),
              TextSpan(text: label, style: _mono(10, palette.muted)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: palette.lineSoft),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: p.clamp(0.0, 1.0),
                child: ColoredBox(color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── The element table ──────────────────────────────────────────────────────

class _ElementTable extends StatelessWidget {
  const _ElementTable({
    required this.data,
    required this.palette,
    required this.fresh,
    required this.live,
    required this.onOpen,
  });

  final AlchemicalEncyclopediaSnapshot data;
  final BracketPalette palette;
  final Set<String> fresh;

  /// Whether its cells move: only the table in view, with nothing over it.
  final bool live;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final known = data.knownElements;
    return ListView(
      key: const PageStorageKey('codex-elements'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: _Tally(
                palette: palette,
                label: 'ELEMENTS KNOWN',
                value: Elements.values
                    .where((e) => known.contains(_title(e.name)))
                    .length,
                total: Elements.values.length,
                color: _kGilt,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _Tally(
                palette: palette,
                label: 'FORMULAS FOUND',
                value: data.discoveredElementKeys.length,
                total: data.elementRecipes.length,
                color: const Color(0xFF7FB8E0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        for (final group in ElementalGroup.values) ...[
          _GroupRow(
            palette: palette,
            title: group.displayName.toUpperCase(),
            color: group.color,
            names: group.elementTypes,
            known: known,
            cell: (name) => _ElementCell(
              name: name,
              known: known.contains(name),
              live: live,
              fresh: fresh.contains(name),
              onTap: () => onOpen(name),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Open an element to see what makes it and what it makes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

String _title(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

/// A group's name and its cells, four to a row so the columns line up.
class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.palette,
    required this.title,
    required this.color,
    required this.names,
    required this.known,
    required this.cell,
  });

  final BracketPalette palette;
  final String title;
  final Color color;
  final List<String> names;
  final Set<String> known;
  final Widget Function(String name) cell;

  @override
  Widget build(BuildContext context) {
    final have = names.where(known.contains).length;
    final ink = palette.isDark
        ? Color.lerp(color, Colors.white, 0.25)!
        : Color.lerp(color, Colors.black, 0.35)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 6, height: 6, color: color),
            const SizedBox(width: 8),
            Text(title, style: _mono(11, ink, weight: FontWeight.w800)),
            const SizedBox(width: 10),
            Expanded(child: Container(height: 1, color: palette.lineSoft)),
            const SizedBox(width: 10),
            Text(
              '$have/${names.length}',
              style: _mono(11, palette.muted, spacing: 0.5),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: i < names.length ? cell(names[i]) : const SizedBox(),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// A dark glass case, bracketed in [frame]: how a cell, the stage and a
/// formula's tokens are framed, as the vials are.
class _GlassCase extends StatelessWidget {
  const _GlassCase({
    required this.frame,
    required this.child,
    this.bracket = 7,
    this.padding = EdgeInsets.zero,
  });

  final Color frame;
  final Widget child;
  final double bracket;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: BracketFramePainter(
      color: frame,
      bracketSize: bracket,
      strokeWidth: 1.2,
    ),
    child: Container(color: kVialGlass, padding: padding, child: child),
  );
}

class _ElementCell extends StatelessWidget {
  const _ElementCell({
    required this.name,
    required this.known,
    required this.live,
    required this.fresh,
    required this.onTap,
  });

  final String name;
  final bool known, live, fresh;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = _elementTint(name);
    final frame = fresh
        ? _kGilt
        : known
        ? tint.withValues(alpha: 0.75)
        : const Color(0xFF3A404C);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: _GlassCase(
        frame: frame,
        padding: const EdgeInsets.fromLTRB(4, 7, 4, 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                SizedBox(
                  height: 52,
                  child: _Orb(
                    name: name,
                    locked: !known,
                    radius: 19,
                    live: live,
                  ),
                ),
                const SizedBox(height: 4),
                _CellName(name: name, known: known),
              ],
            ),
            if (fresh) const Positioned(top: -2, right: 0, child: _NewPip()),
          ],
        ),
      ),
    );
  }
}

class _CellName extends StatelessWidget {
  const _CellName({required this.name, required this.known});

  final String name;
  final bool known;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      name.toUpperCase(),
      maxLines: 1,
      style: _mono(
        10.5,
        known ? _kGlassInk : _kGlassMuted.withValues(alpha: 0.7),
        weight: FontWeight.w800,
        spacing: 0.8,
      ),
    ),
  );
}

class _NewPip extends StatelessWidget {
  const _NewPip();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    color: _kGilt,
    child: Text(
      'NEW',
      style: _mono(8, const Color(0xFF1A1206), weight: FontWeight.w900),
    ),
  );
}

/// Paints [draw] at the shared glyph clock's time, or at one still moment
/// when there is no clock.
class _ClockPainter extends CustomPainter {
  _ClockPainter(this.draw, this.clock) : super(repaint: clock);

  final void Function(Canvas canvas, Offset centre, double t) draw;
  final ValueListenable<double>? clock;

  @override
  void paint(Canvas canvas, Size size) =>
      draw(canvas, size.center(Offset.zero), clock?.value ?? 1.3);

  @override
  bool shouldRepaint(_ClockPainter old) =>
      old.clock != clock || old.draw != draw;
}

/// An element's orb: turning while [live] (a table's cell), still otherwise
/// (a formula's token). Every live one runs off the one glyph clock.
class _Orb extends StatefulWidget {
  const _Orb({
    required this.name,
    required this.locked,
    required this.radius,
    this.live = false,
  });

  final String name;
  final bool locked;
  final double radius;
  final bool live;

  @override
  State<_Orb> createState() => _OrbState();
}

class _OrbState extends State<_Orb> with GlyphClockLease<_Orb> {
  late ElementOrb _orb = _make();
  bool _ticking = true;

  ElementOrb _make() => ElementOrb(
    EssenceElement.of(widget.name),
    radius: widget.radius,
    locked: widget.locked,
  );

  @override
  bool get wantsClock => widget.live && _ticking && !widget.locked;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Under another page, nobody is looking.
    _ticking = TickerMode.valuesOf(context).enabled;
    syncGlyphClock();
  }

  @override
  void didUpdateWidget(_Orb old) {
    super.didUpdateWidget(old);
    if (old.name != widget.name ||
        old.locked != widget.locked ||
        old.radius != widget.radius) {
      _orb = _make();
    }
    syncGlyphClock();
  }

  @override
  void dispose() {
    releaseGlyphClock();
    super.dispose();
  }

  void _draw(Canvas canvas, Offset c, double t) => _orb.paint(canvas, c, t);

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _ClockPainter(_draw, glyphClock),
      size: Size.square(widget.radius * 2.6),
    ),
  );
}

/// A species' face in a cell: the creature in grains, drifting while
/// [live]; a still grey shadow of grains while it is not yet known.
class _Face extends StatefulWidget {
  const _Face({
    required this.family,
    required this.face,
    required this.known,
    required this.live,
  });

  final String family;
  final Creature face;
  final bool known, live;

  @override
  State<_Face> createState() => _FaceState();
}

class _FaceState extends State<_Face> with GlyphClockLease<_Face> {
  PortraitBody? _body;
  bool _ticking = true;

  /// The cell's face, read coarsely: eight of them drift at once.
  static const double _height = 54;
  static const int _grains = 850;

  @override
  bool get wantsClock =>
      widget.live && widget.known && _ticking && _body != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final f = widget.face;
    final body = await PortraitBody.load(
      _faceAsset(f),
      height: _height,
      element: f.types.isEmpty ? 'Spirit' : f.types.first,
      color: _familyTint(widget.family),
      locked: !widget.known,
      maxGrains: _grains,
    );
    if (!mounted) return;
    setState(() => _body = body);
    syncGlyphClock();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ticking = TickerMode.valuesOf(context).enabled;
    syncGlyphClock();
  }

  @override
  void didUpdateWidget(_Face old) {
    super.didUpdateWidget(old);
    if (old.face.id != widget.face.id || old.known != widget.known) {
      _body = null;
      _load();
    }
    syncGlyphClock();
  }

  @override
  void dispose() {
    releaseGlyphClock();
    super.dispose();
  }

  void _draw(Canvas canvas, Offset c, double t) => _body?.paint(canvas, c, t);

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _ClockPainter(_draw, glyphClock),
      size: const Size(64, _height),
    ),
  );
}

// ─── The species table ──────────────────────────────────────────────────────

class _SpeciesTable extends StatelessWidget {
  const _SpeciesTable({
    required this.data,
    required this.palette,
    required this.fresh,
    required this.live,
    required this.onOpen,
  });

  final AlchemicalEncyclopediaSnapshot data;
  final BracketPalette palette;
  final Set<String> fresh;

  /// Whether its cells move: only the table in view, with nothing over it.
  final bool live;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final families = [for (final f in CreatureFamily.values) f.displayName];
    final known = data.knownFamilies;
    return ListView(
      key: const PageStorageKey('codex-species'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: _Tally(
                palette: palette,
                label: 'SPECIES KNOWN',
                value: families.where(known.contains).length,
                total: families.length,
                color: _kGilt,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _Tally(
                palette: palette,
                label: 'FORMULAS FOUND',
                value: data.discoveredFamilyKeys.length,
                total: data.familyRecipes.length,
                color: const Color(0xFF7FB8E0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        for (var row = 0; row < families.length; row += 4) ...[
          Row(
            children: [
              for (var i = row; i < row + 4; i++) ...[
                if (i > row) const SizedBox(width: 8),
                Expanded(
                  child: i < families.length
                      ? _SpeciesCell(
                          family: families[i],
                          face: data.familyFaces[families[i]],
                          known: known.contains(families[i]),
                          live: live,
                          fresh: fresh.contains(families[i]),
                          onTap: () => onOpen(families[i]),
                        )
                      : const SizedBox(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            'Open a species to see what makes it and what it makes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

String _faceAsset(Creature c) =>
    c.image.startsWith('assets/') ? c.image : 'assets/images/${c.image}';

class _SpeciesCell extends StatelessWidget {
  const _SpeciesCell({
    required this.family,
    required this.face,
    required this.known,
    required this.live,
    required this.fresh,
    required this.onTap,
  });

  final String family;
  final Creature? face;
  final bool known, live, fresh;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = _familyTint(family);
    final frame = fresh
        ? _kGilt
        : known
        ? tint.withValues(alpha: 0.75)
        : const Color(0xFF3A404C);
    final f = face;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: _GlassCase(
        frame: frame,
        padding: const EdgeInsets.fromLTRB(4, 7, 4, 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                SizedBox(
                  height: 54,
                  child: f == null
                      ? null
                      : _Face(
                          family: family,
                          face: f,
                          known: known,
                          live: live,
                        ),
                ),
                const SizedBox(height: 4),
                _CellName(name: family, known: known),
              ],
            ),
            if (fresh) const Positioned(top: -2, right: 0, child: _NewPip()),
          ],
        ),
      ),
    );
  }
}

// ─── The sheet ──────────────────────────────────────────────────────────────

/// One formula as a row plays it: who makes it, and what.
class _Play {
  const _Play(this.recipe, this.a, this.b, this.result);

  final EncyclopediaRecipeEntry recipe;
  final String a, b, result;

  String get tag => '${recipe.pairKey}::$result';
}

/// An element or a species on its stage, over the formulas that make it
/// and that it fuses into. A formula's result can be opened in place.
class _CodexSheet extends StatefulWidget {
  const _CodexSheet({
    required this.data,
    required this.kind,
    required this.name,
    required this.fresh,
    this.showcase,
  });

  final AlchemicalEncyclopediaSnapshot data;
  final EncyclopediaRecipeKind kind;
  final String name;
  final Set<String> fresh;

  /// A formula just found, played as the sheet opens.
  final EncyclopediaRecipeEntry? showcase;

  @override
  State<_CodexSheet> createState() => _CodexSheetState();
}

class _CodexSheetState extends State<_CodexSheet> {
  final CodexStageController _stage = CodexStageController();
  late String _name = widget.name;

  /// The last formula played, for its caption; null at rest.
  _Play? _shown;

  /// The showcase's row, marked NEW.
  String? _newTag;

  static const double _stageHeight = 220;

  bool get _isElement => widget.kind == EncyclopediaRecipeKind.element;

  AlchemicalEncyclopediaSnapshot get _data => widget.data;

  bool _known(String name) => _isElement
      ? _data.knownElements.contains(name)
      : _data.knownFamilies.contains(name);

  Color _tint(String name) =>
      _isElement ? _elementTint(name) : _familyTint(name);

  @override
  void initState() {
    super.initState();
    _stage.addListener(_onStage);
    _showSubject(reveal: widget.showcase == null);
    final s = widget.showcase;
    if (s != null) {
      final result = widget.name;
      _newTag = '${s.pairKey}::$result';
      Future<void>.delayed(const Duration(milliseconds: 420), () {
        if (mounted) _play(_Play(s, s.parentA, s.parentB, result));
      });
    }
  }

  @override
  void dispose() {
    _stage.removeListener(_onStage);
    _stage.dispose();
    super.dispose();
  }

  void _onStage() {
    if (mounted) setState(() {});
  }

  // ── bodies ─────────────────────────────────────────────────────────────

  double get _orbRadius => _stageHeight * 0.25;
  double get _faceHeight => _stageHeight * 0.66;

  Future<CodexBody?> _body(String name) async {
    final locked = !_known(name);
    if (_isElement) {
      return OrbBody(name, radius: _orbRadius, locked: locked);
    }
    final face = _data.familyFaces[name];
    if (face == null) return null;
    return PortraitBody.load(
      _faceAsset(face),
      height: _faceHeight,
      element: face.types.isEmpty ? 'Spirit' : face.types.first,
      color: _familyTint(name),
      locked: locked,
    );
  }

  Future<void> _showSubject({bool reveal = false}) async {
    final name = _name;
    final body = await _body(name);
    if (!mounted || body == null || name != _name) return;
    _stage.show(body, reveal: reveal);
  }

  Future<void> _play(_Play p) async {
    final bodies = await Future.wait([_body(p.a), _body(p.b), _body(p.result)]);
    if (!mounted || bodies.any((b) => b == null)) return;
    setState(() => _shown = p);
    _stage.combine(bodies[0]!, bodies[1]!, bodies[2]!, tag: p.tag);
  }

  void _openHere(String name) {
    if (name == _name) return;
    HapticFeedback.selectionClick();
    setState(() {
      _name = name;
      _shown = null;
    });
    _showSubject(reveal: true);
  }

  // ── build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    final media = MediaQuery.of(context);
    final name = _name;
    final tint = _tint(name);
    final known = _known(name);
    final made = _isElement
        ? _data.elementMadeFrom(name)
        : _data.familyMadeFrom(name);
    final uses = _isElement
        ? _data.elementFusesInto(name)
        : _data.familyFusesInto(name);

    return Container(
      height: media.size.height * 0.9,
      decoration: BoxDecoration(
        color: palette.bg1,
        border: Border(top: BorderSide(color: tint.withValues(alpha: 0.6))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(width: 38, height: 4, color: palette.lineSoft),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
            child: _SheetHeader(
              palette: palette,
              title: name,
              subtitle: _subtitle(name, known),
              tint: tint,
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: _stageHeight,
              child: _GlassCase(
                frame: tint.withValues(alpha: known ? 0.8 : 0.35),
                bracket: 12,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Held inside its glass: a flame rises past the top.
                    ClipRect(child: CodexStage(controller: _stage)),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 10,
                      child: IgnorePointer(
                        ignoring: _stage.busy,
                        child: _StageCaption(
                          play: _shown,
                          busy: _stage.busy,
                          subject: name,
                          isElement: _isElement,
                          onOpen: _openHere,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                24 + media.padding.bottom,
              ),
              children: [
                _SectionTitle(
                  palette: palette,
                  title: 'MADE FROM',
                  found: made.where(_data.isDiscovered).length,
                  total: made.length,
                ),
                if (made.isEmpty)
                  _Empty(
                    palette: palette,
                    text: 'Nothing makes ${_title(name)}. It is only found.',
                  ),
                for (final r in made.where(_data.isDiscovered))
                  _rowFor(r, palette, makes: true),
                _Unfound(
                  palette: palette,
                  count: made.where((r) => !_data.isDiscovered(r)).length,
                ),
                const SizedBox(height: 18),
                _SectionTitle(
                  palette: palette,
                  title: 'FUSES INTO',
                  found: uses.where(_data.isDiscovered).length,
                  total: uses.length,
                ),
                if (uses.isEmpty)
                  _Empty(
                    palette: palette,
                    text: 'No formula uses ${_title(name)}.',
                  ),
                for (final r in uses.where(_data.isDiscovered))
                  _rowFor(r, palette, makes: false),
                _Unfound(
                  palette: palette,
                  count: uses.where((r) => !_data.isDiscovered(r)).length,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle(String name, bool known) {
    final where = _isElement
        ? ElementalGroup.values
              .firstWhere(
                (g) => g.elementTypes.contains(name),
                orElse: () => ElementalGroup.arcane,
              )
              .displayName
              .toUpperCase()
        : 'SPECIES';
    return known ? where : '$where · NOT YET FOUND';
  }

  Widget _rowFor(
    EncyclopediaRecipeEntry r,
    BracketPalette palette, {
    required bool makes,
  }) {
    final name = _name;
    final found = _data.isDiscovered(r);
    final partner = makes ? null : (r.parentA == name ? r.parentB : r.parentA);
    // What the row plays: for MADE FROM, this; for FUSES INTO, the first
    // outcome found.
    final outcomes = makes
        ? [r.outcomes.firstWhere((o) => o.result == name)]
        : r.outcomes;
    final foundOutcomes = [
      for (final o in outcomes)
        if (_data.outcomeFound(r, o.result)) o,
    ];
    final play = !found || foundOutcomes.isEmpty
        ? null
        : _Play(
            r,
            makes ? r.parentA : name,
            makes ? r.parentB : partner!,
            foundOutcomes.first.result,
          );
    final playing = play != null && _stage.playing == play.tag;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _FormulaRow(
        palette: palette,
        isElement: _isElement,
        makers: makes ? [r.parentA, r.parentB] : [partner!],
        leadingJoin: !makes,
        outcomes: [
          for (final o in outcomes)
            (_data.outcomeFound(r, o.result) ? o.result : null, o.weight),
        ],
        found: found,
        playing: playing,
        isNew: play != null && play.tag == _newTag,
        tintOf: _tint,
        onTap: play == null ? null : () => _play(play),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.palette,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.onClose,
  });

  final BracketPalette palette;
  final String title, subtitle;
  final Color tint;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ink = palette.isDark
        ? Color.lerp(tint, Colors.white, 0.35)!
        : Color.lerp(tint, Colors.black, 0.4)!;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: _mono(20, palette.ink, weight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(subtitle, style: _mono(10.5, ink, spacing: 1.4)),
            ],
          ),
        ),
        BracketIconButton(
          icon: AppIcons.close_rounded,
          onTap: onClose,
          palette: palette,
        ),
      ],
    );
  }
}

/// Under the stage: what it is doing, or what to do with it.
class _StageCaption extends StatelessWidget {
  const _StageCaption({
    required this.play,
    required this.busy,
    required this.subject,
    required this.isElement,
    required this.onOpen,
  });

  final _Play? play;
  final bool busy, isElement;
  final String subject;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final p = play;
    // Nothing to say until a formula has played.
    if (p == null) return const SizedBox.shrink();
    final word = _mono(10.5, _kGlassInk, weight: FontWeight.w800);
    const mark = TextStyle(color: _kGilt, fontSize: 13);
    final away = !busy && p.result != subject;
    return Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: away ? Alignment.centerLeft : Alignment.center,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: p.a.toUpperCase(), style: word),
                  const TextSpan(text: '  ⊕  ', style: mark),
                  TextSpan(text: p.b.toUpperCase(), style: word),
                  const TextSpan(text: '  →  ', style: mark),
                  TextSpan(text: p.result.toUpperCase(), style: word),
                ],
              ),
            ),
          ),
        ),
        if (away)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: context.soundAction(() => onOpen(p.result)),
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'OPEN ${p.result.toUpperCase()}',
                    style: _mono(10, _kGilt, weight: FontWeight.w900),
                  ),
                  const Icon(
                    AppIcons.chevron_right_rounded,
                    size: 16,
                    color: _kGilt,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.palette,
    required this.title,
    required this.found,
    required this.total,
  });

  final BracketPalette palette;
  final String title;
  final int found, total;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(title, style: _mono(11.5, palette.ink, weight: FontWeight.w800)),
      const SizedBox(width: 10),
      Expanded(child: Container(height: 1, color: palette.lineSoft)),
      if (total > 0) ...[
        const SizedBox(width: 10),
        Text('$found / $total FOUND', style: _mono(10, palette.muted)),
      ],
    ],
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.palette, required this.text});

  final BracketPalette palette;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Text(text, style: TextStyle(color: palette.muted, fontSize: 12.5)),
  );
}

/// The formulas not yet found, as one line: how many, and nothing more.
class _Unfound extends StatelessWidget {
  const _Unfound({required this.palette, required this.count});

  final BracketPalette palette;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: palette.lineSoft,
          bracketSize: 7,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(
                AppIcons.lock_outline_rounded,
                size: 13,
                color: palette.muted.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Text(
                count == 1
                    ? '1 MORE NOT YET FOUND'
                    : '$count MORE NOT YET FOUND',
                style: _mono(10.5, palette.muted, spacing: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A formula: its makers, joined, and what it gives.
///
/// [makers] are both makers for MADE FROM, or only the partner for FUSES
/// INTO ([leadingJoin] puts the join before it: the subject is the other
/// maker). [outcomes] are (name or null if not yet made, chance).
class _FormulaRow extends StatelessWidget {
  const _FormulaRow({
    required this.palette,
    required this.isElement,
    required this.makers,
    required this.leadingJoin,
    required this.outcomes,
    required this.found,
    required this.playing,
    required this.isNew,
    required this.tintOf,
    required this.onTap,
  });

  final BracketPalette palette;
  final bool isElement;
  final List<String> makers;
  final bool leadingJoin;
  final List<(String?, int)> outcomes;
  final bool found, playing, isNew;
  final Color Function(String) tintOf;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final join = palette.isDark ? _kGilt : const Color(0xFF9A6B00);
    final frame = playing || isNew
        ? _kGilt
        : found
        ? palette.line
        : palette.lineSoft;
    Widget glyph(String g) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        g,
        style: TextStyle(
          color: found ? join : palette.muted.withValues(alpha: 0.6),
          fontSize: 15,
        ),
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: frame,
          bracketSize: 7,
          strokeWidth: playing ? 1.4 : 1,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
          color: playing
              ? palette.accentWash(_kGilt, darkAlpha: 0.12, lightAlpha: 0.08)
              : palette.surfaceMutedFill(),
          child: Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (leadingJoin) glyph('⊕'),
                      for (var i = 0; i < makers.length; i++) ...[
                        if (i > 0) glyph('⊕'),
                        _Token(
                          palette: palette,
                          name: found ? makers[i] : null,
                          isElement: isElement,
                          tintOf: tintOf,
                        ),
                      ],
                      glyph('→'),
                      for (var i = 0; i < outcomes.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        _Token(
                          palette: palette,
                          name: found ? outcomes[i].$1 : null,
                          isElement: isElement,
                          tintOf: tintOf,
                          chance: found && outcomes[i].$1 != null
                              ? outcomes[i].$2
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (isNew && !playing)
                const _NewPip()
              else if (onTap != null)
                Icon(
                  playing
                      ? AppIcons.auto_awesome_rounded
                      : AppIcons.play_arrow_rounded,
                  size: 18,
                  color: playing ? _kGilt : palette.muted,
                )
              else
                Icon(
                  AppIcons.lock_outline_rounded,
                  size: 14,
                  color: palette.muted.withValues(alpha: 0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One element or species in a formula: a small orb (or face) and its
/// name, or a question mark.
class _Token extends StatelessWidget {
  const _Token({
    required this.palette,
    required this.name,
    required this.isElement,
    required this.tintOf,
    this.chance,
  });

  final BracketPalette palette;
  final String? name;
  final bool isElement;
  final Color Function(String) tintOf;
  final int? chance;

  @override
  Widget build(BuildContext context) {
    final n = name;
    if (n == null) {
      return Text(
        '?',
        style: _mono(13, palette.muted.withValues(alpha: 0.7), spacing: 0),
      );
    }
    final tint = tintOf(n);
    final ink = palette.isDark
        ? Color.lerp(tint, Colors.white, 0.3)!
        : Color.lerp(tint, Colors.black, 0.45)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isElement)
          SizedBox(
            width: 22,
            height: 22,
            child: _Orb(name: n, locked: false, radius: 8),
          )
        else
          Container(width: 6, height: 6, color: tint),
        const SizedBox(width: 5),
        Text(
          n.toUpperCase(),
          style: _mono(
            11.5,
            palette.ink,
            weight: FontWeight.w800,
            spacing: 0.8,
          ),
        ),
        if (chance != null) ...[
          const SizedBox(width: 5),
          Text(
            '$chance%',
            style: _mono(11, ink, weight: FontWeight.w900, spacing: 0),
          ),
        ],
      ],
    );
  }
}

// ─── Natures ────────────────────────────────────────────────────────────────

class _NatureLog extends StatelessWidget {
  const _NatureLog({required this.data, required this.palette});

  final AlchemicalEncyclopediaSnapshot data;
  final BracketPalette palette;

  @override
  Widget build(BuildContext context) {
    final entries = [...data.natureEntries]
      ..sort((a, b) {
        if (a.discovered != b.discovered) return a.discovered ? -1 : 1;
        final seen = b.observedCount.compareTo(a.observedCount);
        if (seen != 0) return seen;
        return a.nature.id.compareTo(b.nature.id);
      });
    final known = entries.where((e) => e.discovered).length;
    return ListView(
      key: const PageStorageKey('codex-natures'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        _Tally(
          palette: palette,
          label: 'NATURES OBSERVED',
          value: known,
          total: entries.length,
          color: const Color(0xFF22C55E),
        ),
        const SizedBox(height: 14),
        for (final e in entries) ...[
          _NatureRow(entry: e, palette: palette),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _NatureRow extends StatelessWidget {
  const _NatureRow({required this.entry, required this.palette});

  final EncyclopediaNatureEntry entry;
  final BracketPalette palette;

  @override
  Widget build(BuildContext context) {
    final locked = !entry.discovered;
    final accent = locked ? palette.lineSoft : _natureAccent(entry.nature);
    final seen = locked
        ? 'Not yet observed'
        : entry.observedCount > 0
        ? 'On ${entry.observedCount} specimen${entry.observedCount == 1 ? '' : 's'} you keep'
        : 'Seen on a specimen you no longer keep';
    return CustomPaint(
      foregroundPainter: BracketFramePainter(
        color: locked ? palette.lineSoft : accent.withValues(alpha: 0.8),
        bracketSize: 7,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        color: palette.surfaceMutedFill(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 7,
                height: 7,
                color: locked ? palette.lineSoft : accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locked ? '???' : entry.nature.id,
                    style: _mono(
                      13,
                      locked ? palette.muted : palette.ink,
                      weight: FontWeight.w800,
                      spacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locked
                        ? '???'
                        : formatNatureEffectSummary(entry.nature.effect),
                    style: TextStyle(
                      color: locked ? palette.muted : palette.ink,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    seen,
                    style: TextStyle(color: palette.muted, fontSize: 11.5),
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

Color _natureAccent(NatureDef nature) {
  final effect = nature.effect.modifiers;
  if (effect.containsKey('stat_strength_bonus')) {
    return const Color(0xFFEF4444);
  }
  if (effect.containsKey('stat_speed_bonus')) return const Color(0xFF0EA5E9);
  if (effect.containsKey('stat_intelligence_bonus')) {
    return const Color(0xFF38BDF8);
  }
  if (effect.containsKey('stat_beauty_bonus')) return const Color(0xFFF59E0B);
  return const Color(0xFF22C55E);
}
