import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/parent_snapshot.dart' show decodeGenetics;
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/models/wild_fusion.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/utils/color_util.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/creature_detail/creature_background_pref.dart';
import 'package:alchemons/widgets/creature_detail/creature_dialog.dart';
import 'package:alchemons/widgets/creature_detail/specimen_readouts.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/fx/mutation_sheets.dart' show mutationAccent;
import 'package:alchemons/widgets/stamina_bar.dart';
import 'package:alchemons/widgets/app_icons.dart';

/// The quick look: a long press on a specimen. A condensed card for
/// flicking through a list and comparing: the creature on its backdrop
/// with its name, the four stats in one row, and only what sets it apart
/// from others of its kind. Everything else is behind FULL DETAILS.
///
/// [siblings] is the list it was opened from, in that list's order: the card
/// swipes left and right through it. Without it the card stands alone.
Future<void> showQuickInstanceDialog({
  required BuildContext context,
  required FactionTheme theme,
  required Creature creature,
  required CreatureInstance instance,
  List<CreatureInstance>? siblings,
}) async {
  final catalog = context.read<CreatureCatalog?>();
  // Every page needs its species; a sibling whose species is not loaded is
  // left out rather than shown blank.
  final pages = <(Creature, CreatureInstance)>[];
  var initial = 0;
  for (final inst in siblings ?? const <CreatureInstance>[]) {
    final species = inst.instanceId == instance.instanceId
        ? creature
        : catalog?.getCreatureById(inst.baseId);
    if (species == null) continue;
    if (inst.instanceId == instance.instanceId) initial = pages.length;
    pages.add((species, inst));
  }
  if (!pages.any((p) => p.$2.instanceId == instance.instanceId)) {
    pages
      ..clear()
      ..add((creature, instance));
    initial = 0;
  }

  await showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .75),
    builder: (_) => _QuickInstancePager(
      theme: theme,
      pages: pages,
      initial: initial,
      hostContext: context,
    ),
  );
}

/// The quick-look cards side by side, a swipe apart.
class _QuickInstancePager extends StatefulWidget {
  const _QuickInstancePager({
    required this.theme,
    required this.pages,
    required this.initial,
    required this.hostContext,
  });

  final FactionTheme theme;
  final List<(Creature, CreatureInstance)> pages;
  final int initial;
  final BuildContext hostContext;

  @override
  State<_QuickInstancePager> createState() => _QuickInstancePagerState();
}

class _QuickInstancePagerState extends State<_QuickInstancePager> {
  late final PageController _pages = PageController(
    initialPage: widget.initial,
  );
  late int _index = widget.initial;

  /// Specimens changed while their card was up (a favourite, say), so a
  /// card swiped away and back is not drawn from the stale list.
  final Map<String, CreatureInstance> _fresh = {};

  /// Each card gathers out of its element as it arrives. The cards either
  /// side are built ahead, so they are handed a ticket and held, out of
  /// sight, until they are the one in view.
  final Map<int, EssenceReveal> _reveals = {};

  @override
  void initState() {
    super.initState();
    _armAround(widget.initial, alsoCurrent: true);
  }

  /// Fresh tickets for the cards either side of [i] (and [i] itself).
  void _armAround(int i, {bool alsoCurrent = false}) {
    for (final j in [i - 1, if (alsoCurrent) i, i + 1]) {
      if (j >= 0 && j < widget.pages.length) {
        _reveals[j] = EssenceReveal.once();
      }
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int to) => _pages.animateToPage(
    to,
    duration: const Duration(milliseconds: 190),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    final total = widget.pages.length;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(vertical: 24),
      backgroundColor: Colors.transparent,
      child: NotificationListener<ScrollEndNotification>(
        // Once the swipe has settled the cards either side are off screen:
        // arm them again, so coming back to one reveals it too.
        onNotification: (n) {
          // The pager's own, not a card's stats scrolling.
          if (n.depth == 0) setState(() => _armAround(_index));
          return false;
        },
        child: PageView.builder(
          controller: _pages,
          itemCount: total,
          physics: const _SnappyPagePhysics(),
          // The cards either side are built ahead, so a swipe never slides
          // in one whose sprite is still loading.
          allowImplicitScrolling: true,
          onPageChanged: (i) {
            HapticFeedback.lightImpact();
            setState(() => _index = i);
          },
          itemBuilder: (context, i) {
            final (creature, listed) = widget.pages[i];
            final instance = _fresh[listed.instanceId] ?? listed;
            final card = _QuickInstanceCard(
              key: ValueKey(listed.instanceId),
              theme: widget.theme,
              creature: creature,
              instance: instance,
              hostContext: widget.hostContext,
              position: i + 1,
              total: total,
              onPrev: i > 0 && i == _index ? () => _go(i - 1) : null,
              onNext: i < total - 1 && i == _index ? () => _go(i + 1) : null,
              onChanged: (inst) => _fresh[inst.instanceId] = inst,
              reveal: _reveals[i],
              hold: i != _index,
            );
            // Sized to what it holds; the space round it is the dialog's
            // backdrop, so a tap there closes it. Every card's top stands
            // at the same height, where a typical card would be centred, so
            // the plate holds still across a swipe while a card with more
            // to say runs further down. On a short screen the card scrolls
            // inside, round its docked button.
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: LayoutBuilder(
                builder: (context, box) {
                  final top = ((box.maxHeight - _typicalCardHeight) / 2).clamp(
                    12.0,
                    double.infinity,
                  );
                  return Padding(
                    padding: EdgeInsets.fromLTRB(12, top, 12, 12),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        // The card's own taps stay on the card.
                        behavior: HitTestBehavior.opaque,
                        onTap: () {},
                        child: card,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// About what a card stands: plate, name, stats, one line of traits, foot.
const double _typicalCardHeight = 470;

/// A swipe that lands: the page snaps home on a stiff, critically damped
/// spring instead of the default soft one, which took a beat to settle (and
/// ignored taps until it had). Still bounces at the ends of the list.
class _SnappyPagePhysics extends BouncingScrollPhysics {
  const _SnappyPagePhysics({super.parent});

  @override
  _SnappyPagePhysics applyTo(ScrollPhysics? ancestor) =>
      _SnappyPagePhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring =>
      SpringDescription.withDampingRatio(mass: 0.4, stiffness: 520, ratio: 1.0);
}

/// One specimen's quick look.
class _QuickInstanceCard extends StatefulWidget {
  const _QuickInstanceCard({
    super.key,
    required this.theme,
    required this.creature,
    required this.instance,
    required this.hostContext,
    required this.position,
    required this.total,
    required this.onPrev,
    required this.onNext,
    required this.onChanged,
    this.reveal,
    this.hold = false,
  });

  final FactionTheme theme;
  final Creature creature;
  final CreatureInstance instance;

  /// Where the dialog was opened from: the full details open there, once
  /// this card's dialog is gone.
  final BuildContext hostContext;

  /// This card's place in the list, from 1, and the list's length.
  final int position, total;

  /// To the card either side; null at the ends.
  final VoidCallback? onPrev, onNext;
  final ValueChanged<CreatureInstance> onChanged;

  /// Its sprite's reveal, held while the card is not the one in view.
  final EssenceReveal? reveal;
  final bool hold;

  @override
  State<_QuickInstanceCard> createState() => _QuickInstanceCardState();
}

class _QuickInstanceCardState extends State<_QuickInstanceCard> {
  late CreatureInstance _instance = widget.instance;

  /// The backdrop chosen for it in the viewer, so the quick look shows it
  /// as the details do. Null until read.
  CreatureBgOption? _bg;
  bool _favoriteBusy = false;

  Creature get creature => widget.creature;
  FactionTheme get theme => widget.theme;

  @override
  void initState() {
    super.initState();
    _loadBackdrop();
  }

  Future<void> _loadBackdrop() async {
    final option = await loadCreatureBg(
      context.read<AlchemonsDatabase>(),
      baseId: creature.id,
      instanceId: _instance.instanceId,
    );
    if (mounted) setState(() => _bg = option ?? defaultCreatureBg);
  }

  void _changed() {
    setState(() {});
    widget.onChanged(_instance);
  }

  Future<void> _toggleFavorite() async {
    if (_favoriteBusy) return;
    final db = context.read<AlchemonsDatabase>();
    final before = _instance;
    final next = !before.isFavorite;
    // A firm knock for a favourite, a click for taking it back, and the
    // star turns at once: the save follows it.
    if (next) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    setState(() {
      _favoriteBusy = true;
      _instance = _instance.copyWith(isFavorite: next, locked: next);
    });
    try {
      await db.creatureDao.setFavorite(_instance.instanceId, next);
      final refreshed = await db.creatureDao.getInstance(_instance.instanceId);
      if (refreshed != null && mounted) {
        _instance = refreshed;
        _changed();
      }
    } catch (_) {
      // Not saved: the star goes back.
      if (mounted) {
        setState(() {
          _instance = before;
        });
      }
    } finally {
      if (mounted) setState(() => _favoriteBusy = false);
    }
  }

  Future<void> _openDetails() async {
    Navigator.of(context).pop();
    await CreatureDetailsDialog.show(
      widget.hostContext,
      creature,
      true,
      instanceId: _instance.instanceId,
    );
  }

  /// White and grey want dark ink over them, and a shadow, not a glow.
  bool get _lightBackdrop {
    final bg = _bg;
    return bg != null &&
        bg.kind == CreatureBgKind.color &&
        bg.color.computeLuminance() > 0.35;
  }

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.fromTheme(theme);
    final accent = bracketReadableAccent(theme);
    final effects = context.watch<ConstellationEffectsService>();
    final stats = statTilesFor(
      _instance,
      showPotential: effects.hasPotentialAnalyzer(),
      showDominants: effects.hasDominantAnalyzer(),
    );
    final marks = _distinctions();

    return ColoredBox(
      color: palette.bg1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // On a short screen the readouts scroll under the plate, round
          // the docked foot, so FULL DETAILS is never scrolled away.
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPlate(context, palette, accent),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: _buildName(context, palette),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _StatStrip(stats: stats, palette: palette),
                  ),
                  if (marks.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          for (final m in marks)
                            _Distinction(mark: m, palette: palette),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              children: [
                StaminaBadge(
                  instanceId: _instance.instanceId,
                  showCountdown: true,
                ),
                const Spacer(),
                _DetailsButton(
                  palette: palette,
                  accent: accent,
                  onTap: _openDetails,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// What sets this one apart from others of its kind: its nature, and any
  /// size, tint, variant, mutation or skin that is not the usual. Element
  /// and family are its species', already said by the name and the mark.
  List<(String, String, Color)> _distinctions() {
    final t = ForgeTokens(theme);
    final ink = BracketPalette.fromTheme(theme).ink;
    final genetics = decodeGenetics(_instance.geneticsJson);
    final size = genetics?.get('size');
    final tint = genetics?.get('tinting');
    final natures = [
      for (final id in [_instance.natureId, _instance.natureId2])
        if (id != null && id.isNotEmpty) titleCaseWord(id),
    ];
    final variant = (_instance.variantFaction ?? '').trim();
    final variantName = variant.isEmpty
        ? null
        : variant[0].toUpperCase() + variant.substring(1);
    final mutation = AlchemonMutation.byId(_instance.mutation);
    return [
      if (natures.isNotEmpty) ('NATURE', natures.join(' · '), t.amberBright),
      if (size != null && size != 'normal')
        ('SIZE', sizeLabels[size] ?? titleCaseWord(size), ink),
      if (tint != null && tint != 'normal')
        ('TINT', tintLabels[tint] ?? titleCaseWord(tint), ink),
      if (variantName != null)
        ('VARIANT', variantName, FactionColors.of(variantName)),
      if (mutation != null)
        ('MUTATION', mutation.label, mutationAccent(mutation)),
      if (_instance.isPrismaticSkin == true)
        ('SKIN', 'Prismatic', const Color(0xFFE879F9)),
    ];
  }

  /// Who it is: its name (or nickname, the species after it), its stars
  /// and its element.
  Widget _buildName(BuildContext context, BracketPalette palette) {
    final nick = _instance.nickname?.trim();
    final hasNick = nick != null && nick.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hasNick ? nick : creature.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: bracketText(
                  context,
                  22,
                  palette.ink,
                  weight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              if (hasNick)
                Text(
                  creature.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bracketText(
                    context,
                    12,
                    palette.muted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        RarityElementMark(
          species: creature,
          prismatic: _instance.isPrismaticSkin == true,
        ),
      ],
    );
  }

  Widget _buildPlate(
    BuildContext context,
    BracketPalette palette,
    Color accent,
  ) {
    final bg = _bg;
    final light = _lightBackdrop;
    // What sits over the backdrop follows the backdrop.
    final over = light ? BracketPalette.light : BracketPalette.dark;
    final t = ForgeTokens(theme);
    const favoriteAccent = Color(0xFFE91E63);
    final isFavorite = _instance.isFavorite;

    return ClipRect(
      child: SizedBox(
        height: 250,
        child: Stack(
          children: [
            Positioned.fill(
              child: bg == null
                  ? ColoredBox(color: palette.bg0)
                  // A card swiped past keeps its stars still.
                  : TickerMode(
                      enabled: !widget.hold,
                      child: CreatureBgLayer(option: bg, spaceStarCount: 90),
                    ),
            ),
            // Somewhere to stand: a soft pool under it, never a ring.
            Align(
              alignment: const Alignment(0, 0.1),
              child: IgnorePointer(
                child: Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        (light ? Colors.black : accent).withValues(
                          alpha: light ? 0.06 : 0.12,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0, 0.1),
              child: SizedBox(
                width: 170,
                height: 170,
                child: ElementalEssence(
                  element: creature.types.isEmpty ? null : creature.types.first,
                  dark: !light,
                  reveal: widget.reveal,
                  hold: widget.hold,
                  // Gathered in about half a second, not a second and a
                  // half: the card is one of a list being flicked through.
                  revealSpeed: 3,
                  // The sprite draws at 230 in this 170 slot.
                  captureScale: 230 / 170,
                  child: InstanceSprite(
                    creature: creature,
                    instance: _instance,
                    size: 230,
                  ),
                ),
              ),
            ),
            // To the specimens either side, out at the edges, for anyone
            // who does not think to swipe.
            Positioned(
              left: 0,
              top: 44,
              bottom: 0,
              child: _PageArrow(
                icon: AppIcons.chevron_left_rounded,
                onTap: widget.onPrev,
                show: widget.total > 1,
                color: over.ink,
                alignment: Alignment.centerLeft,
              ),
            ),
            Positioned(
              right: 0,
              top: 44,
              bottom: 0,
              child: _PageArrow(
                icon: AppIcons.chevron_right_rounded,
                onTap: widget.onNext,
                show: widget.total > 1,
                color: over.ink,
                alignment: Alignment.centerRight,
              ),
            ),
            // Top: its level, its place in the list, and the favourite star.
            Positioned(
              left: 16,
              top: 14,
              child: Text(
                'LV ${_instance.level}',
                style: _mono(12, light ? t.amberDim : t.amberBright),
              ),
            ),
            if (widget.total > 1)
              Positioned(
                left: 0,
                right: 0,
                top: 15,
                child: IgnorePointer(
                  child: Center(
                    child: Text(
                      '${widget.position} / ${widget.total}',
                      style: _mono(10, over.muted, spacing: 1.4),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 4,
              top: 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: context.soundAction(
                  _favoriteBusy ? null : _toggleFavorite,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    isFavorite
                        ? AppIcons.star_filled
                        : AppIcons.star_border_rounded,
                    size: 22,
                    color: isFavorite
                        ? favoriteAccent
                        : over.ink.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle _mono(double size, Color color, {double spacing = 0.8}) => TextStyle(
  fontFamily: 'monospace',
  color: color,
  fontSize: size,
  fontWeight: FontWeight.w800,
  letterSpacing: spacing,
);

/// The four stats in one row: each one's figure, its ten Enhancement ranks
/// as a hairline of pips, and its potential once the analyzer reads it. A
/// dominant stat's label is lit.
class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.stats, required this.palette});

  final List<StatTileData> stats;
  final BracketPalette palette;

  static String _short(String label) => switch (label) {
    'Speed' => 'SPD',
    'Intelligence' => 'INT',
    'Strength' => 'STR',
    'Beauty' => 'BEA',
    _ => label.toUpperCase(),
  };

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    const maxRank = AlchemonStatSystem.maxEnhancementRank;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: Builder(
              builder: (context) {
                final d = stats[i];
                final p = d.potential == null
                    ? null
                    : AlchemonStatSystem.normalizePotential(d.potential!);
                final maxed = d.enhancement >= maxRank;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _short(d.label),
                      style: _mono(
                        9.5,
                        d.isDominant ? t.dominant : palette.muted,
                        spacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${AlchemonStatSystem.displayRating(d.value)}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: d.color,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        for (var r = 0; r < maxRank; r++) ...[
                          if (r > 0) const SizedBox(width: 1.5),
                          Expanded(
                            child: Container(
                              height: 3,
                              color: r < d.enhancement
                                  ? (maxed ? t.amberBright : d.color)
                                  : palette.lineSoft.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (p != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'P$p',
                        style: _mono(
                          9.5,
                          p >= AlchemonStatSystem.maxPotential
                              ? t.amberBright
                              : palette.muted,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// One thing that sets it apart: a quiet label, then what it is.
class _Distinction extends StatelessWidget {
  const _Distinction({required this.mark, required this.palette});

  final (String, String, Color) mark;
  final BracketPalette palette;

  @override
  Widget build(BuildContext context) {
    final (label, value, color) = mark;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label  ',
            style: _mono(9, palette.muted, spacing: 1),
          ),
          TextSpan(
            text: value,
            style: bracketText(context, 13, color, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Everything else: the full details, lit from below.
class _DetailsButton extends StatelessWidget {
  const _DetailsButton({
    required this.palette,
    required this.accent,
    required this.onTap,
  });

  final BracketPalette palette;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: accent,
          bracketSize: 9,
          strokeWidth: 1.2,
        ),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          color: palette.accentWash(accent, darkAlpha: 0.18, lightAlpha: 0.1),
          child: Text(
            'FULL DETAILS',
            style: _mono(11.5, palette.ink, spacing: 1.6),
          ),
        ),
      ),
    );
  }
}

/// A step to the next or previous card: faint, and gone at either end.
class _PageArrow extends StatelessWidget {
  const _PageArrow({
    required this.icon,
    required this.onTap,
    required this.show,
    required this.color,
    required this.alignment,
  });

  final IconData icon;
  final VoidCallback? onTap;

  /// False for a card on its own.
  final bool show;
  final Color color;

  /// Toward the edge it sits at.
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: SizedBox(
        width: 48,
        child: show
            ? AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: onTap == null ? 0 : 0.8,
                child: Align(
                  alignment: alignment,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(icon, size: 22, color: color),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
