import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alchemons/models/potential_genetics.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/color_util.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/creature_detail/creature_background_pref.dart';
import 'package:alchemons/widgets/creature_detail/creature_dialog.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/stamina_bar.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/models/stat_system.dart';

/// Quick-look dialog — modern rounded card with clean layout.
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
            // Sized to what it holds and centred; the space round it is the
            // dialog's backdrop, so a tap there closes it.
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: SingleChildScrollView(
                    child: GestureDetector(
                      // The card's own taps stay on the card.
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: card,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

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
    final next = !_instance.isFavorite;
    if (next) HapticFeedback.mediumImpact();
    setState(() => _favoriteBusy = true);
    try {
      await db.creatureDao.setFavorite(_instance.instanceId, next);
      final refreshed = await db.creatureDao.getInstance(_instance.instanceId);
      if (refreshed != null && mounted) {
        _instance = refreshed;
        _changed();
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

  static Color _rarityColor(String rarity, BracketPalette palette) =>
      switch (rarity.toLowerCase()) {
        'mystic' => const Color(0xFFE879F9),
        'legendary' => const Color(0xFFFFB020),
        'rare' => const Color(0xFF60A5FA),
        'uncommon' => const Color(0xFF34D399),
        _ => palette.muted,
      };

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.fromTheme(theme);
    final accent = bracketReadableAccent(theme);
    final t = ForgeTokens(theme);
    final effects = context.watch<ConstellationEffectsService>();
    final showPotential = effects.hasPotentialAnalyzer();
    // Pre-Dominants creatures fall back to whatever they are best at.
    final showDominants = effects.hasDominantAnalyzer();
    final dominants =
        DominantStats.decode(_instance.dominantStats) ??
        DominantStats.fromPotentials(
          speed: _instance.statSpeedPotential,
          intelligence: _instance.statIntelligencePotential,
          strength: _instance.statStrengthPotential,
          beauty: _instance.statBeautyPotential,
        );
    final genetics = decodeGenetics(_instance.geneticsJson);
    final nick = _instance.nickname?.trim();
    final hasNick = nick != null && nick.isNotEmpty;

    final variant = (_instance.variantFaction ?? '').trim();
    final variantDisplay = variant.isEmpty
        ? null
        : variant[0].toUpperCase() + variant.substring(1);

    final traits = <(String, String, Color)>[
      if (genetics?.get('size') != null)
        ('SIZE', _titleCase(genetics!.get('size')!), const Color(0xFF60A5FA)),
      if (genetics?.get('tinting') != null)
        (
          'TINT',
          _titleCase(genetics!.get('tinting')!),
          const Color(0xFF60A5FA),
        ),
      if (_natureLabel(_instance) != null)
        ('NATURE', _natureLabel(_instance)!, t.amberBright),
      if (variantDisplay != null)
        ('VARIANT', variantDisplay, FactionColors.of(variantDisplay)),
      if (_instance.isPrismaticSkin == true)
        ('SKIN', 'Prismatic', const Color(0xFFC084FC)),
    ];

    _StatTileData stat(
      String label,
      IconData icon,
      Color color,
      double value,
      double potential,
      int enhancement,
      StatKind kind,
    ) => _StatTileData(
      label: label,
      icon: icon,
      color: color,
      value: value,
      potential: showPotential ? potential : null,
      enhancement: enhancement,
      isDominant: showDominants && dominants.contains(kind),
    );

    final stats = [
      stat(
        'Speed',
        AppIcons.speed_rounded,
        const Color(0xFF60A5FA),
        _instance.statSpeed,
        _instance.statSpeedPotential,
        _instance.statSpeedEnhancement,
        StatKind.speed,
      ),
      stat(
        'Intelligence',
        AppIcons.psychology_rounded,
        const Color(0xFFC084FC),
        _instance.statIntelligence,
        _instance.statIntelligencePotential,
        _instance.statIntelligenceEnhancement,
        StatKind.intelligence,
      ),
      stat(
        'Strength',
        AppIcons.fitness_center_rounded,
        const Color(0xFFF87171),
        _instance.statStrength,
        _instance.statStrengthPotential,
        _instance.statStrengthEnhancement,
        StatKind.strength,
      ),
      stat(
        'Beauty',
        AppIcons.favorite_rounded,
        const Color(0xFFF9A8D4),
        _instance.statBeauty,
        _instance.statBeautyPotential,
        _instance.statBeautyEnhancement,
        StatKind.beauty,
      ),
    ];

    const favoriteAccent = Color(0xFFE91E63);
    final isFavorite = _instance.isFavorite;

    return CustomPaint(
      foregroundPainter: BracketFramePainter(
        color: accent.withValues(alpha: 0.86),
        bracketSize: 14,
        strokeWidth: 1.3,
      ),
      child: Container(
        color: palette.bg1,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header: who it is ──────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasNick ? nick : creature.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: bracketText(
                          context,
                          20,
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
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _QuickTag(
                            label: creature.rarity,
                            color: _rarityColor(creature.rarity, palette),
                          ),
                          for (final type in creature.types.take(2))
                            _QuickTag(label: type, color: accent),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _FramedIconButton(
                  icon: isFavorite
                      ? AppIcons.star_filled
                      : AppIcons.star_border_rounded,
                  iconColor: isFavorite ? favoriteAccent : palette.muted,
                  frameColor: isFavorite ? favoriteAccent : palette.line,
                  palette: palette,
                  busy: _favoriteBusy,
                  onTap: _toggleFavorite,
                ),
                const SizedBox(width: 8),
                _FramedIconButton(
                  icon: AppIcons.close_rounded,
                  iconColor: palette.muted,
                  frameColor: palette.line,
                  palette: palette,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── The plate: its backdrop, and it ────────────────────────
            _buildPlate(context, palette, accent, t),
            const SizedBox(height: 10),

            // ── XP and breeding stamina ────────────────────────────────
            Row(
              children: [
                Text(
                  '${_instance.xp} XP',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: palette.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(width: 12),
                StaminaBadge(
                  instanceId: _instance.instanceId,
                  showCountdown: true,
                ),
                const Spacer(),
                _StaminaRestore(
                  instance: _instance,
                  creatureName: creature.name,
                  palette: palette,
                  accent: accent,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Attributes ─────────────────────────────────────────────
            const BracketSectionDivider(label: 'ATTRIBUTES'),
            const SizedBox(height: 8),
            for (var row = 0; row < 2; row++) ...[
              if (row > 0) const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      data: stats[row * 2],
                      palette: palette,
                      tokens: t,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatTile(
                      data: stats[row * 2 + 1],
                      palette: palette,
                      tokens: t,
                    ),
                  ),
                ],
              ),
            ],

            // ── Traits ─────────────────────────────────────────────────
            // Named rows instead of a row of pills: SIZE, TINT and NATURE
            // were once indistinguishable chips, so "SMALL COOL SWIFT" left
            // you guessing which was which.
            if (traits.isNotEmpty) ...[
              const SizedBox(height: 14),
              const BracketSectionDivider(label: 'TRAITS'),
              const SizedBox(height: 4),
              for (final (label, value, color) in traits)
                _TraitRow(
                  label: label,
                  value: value,
                  color: color,
                  palette: palette,
                ),
            ],
            const SizedBox(height: 16),

            // ── Everything else ────────────────────────────────────────
            _QuickActionButton(
              label: 'FULL DETAILS',
              icon: AppIcons.open_in_full_rounded,
              palette: palette,
              accent: accent,
              onTap: _openDetails,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlate(
    BuildContext context,
    BracketPalette palette,
    Color accent,
    ForgeTokens t,
  ) {
    final bg = _bg;
    final light = _lightBackdrop;
    // What sits over the backdrop follows the backdrop.
    final over = light ? BracketPalette.light : BracketPalette.dark;
    final variant = (_instance.variantFaction ?? '').trim();

    return CustomPaint(
      foregroundPainter: BracketFramePainter(
        color: accent.withValues(alpha: 0.82),
        bracketSize: 12,
        strokeWidth: 1.1,
      ),
      child: ClipRect(
        child: SizedBox(
          height: 200,
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
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _QuickScanlines()),
                ),
              ),
              // Somewhere to stand: a soft pool under it, never a ring.
              Center(
                child: IgnorePointer(
                  child: Container(
                    width: 180,
                    height: 180,
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
              Center(
                child: SizedBox(
                  width: 140,
                  height: 140,
                  child: ElementalEssence(
                    element: creature.types.isEmpty
                        ? null
                        : creature.types.first,
                    dark: !light,
                    reveal: widget.reveal,
                    hold: widget.hold,
                    // The sprite draws at 190 in this 140 slot.
                    captureScale: 190 / 140,
                    child: InstanceSprite(
                      creature: creature,
                      instance: _instance,
                      size: 190,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: _CornerBadge(
                  label: 'LV ${_instance.level}',
                  color: t.amberBright,
                  palette: palette,
                ),
              ),
              if (_instance.isPrismaticSkin == true || variant.isNotEmpty)
                Positioned(
                  top: 10,
                  right: 10,
                  child: _CornerBadge(
                    label: _instance.isPrismaticSkin == true
                        ? 'Prismatic'
                        : variant,
                    color: _instance.isPrismaticSkin == true
                        ? const Color(0xFFE879F9)
                        : FactionColors.of(
                            variant[0].toUpperCase() + variant.substring(1),
                          ),
                    palette: palette,
                  ),
                ),
              if (widget.total > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 8,
                  child: Center(
                    child: Text(
                      '${widget.position} / ${widget.total}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: over.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ),
              // To the specimens either side, out at the edges, for anyone
              // who does not think to swipe.
              Positioned(
                left: 0,
                top: 0,
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
                top: 0,
                bottom: 0,
                child: _PageArrow(
                  icon: AppIcons.chevron_right_rounded,
                  onTap: widget.onNext,
                  show: widget.total > 1,
                  color: over.ink,
                  alignment: Alignment.centerRight,
                ),
              ),
            ],
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

/// The details' hero plate has these too: a faint line texture over the
/// backdrop.
class _QuickScanlines extends CustomPainter {
  static final Paint _p = Paint()..color = Colors.black.withValues(alpha: 0.06);

  @override
  void paint(Canvas canvas, Size size) {
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), _p);
    }
  }

  @override
  bool shouldRepaint(_QuickScanlines old) => false;
}

class _QuickTag extends StatelessWidget {
  const _QuickTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label.toUpperCase(),
        style: bracketText(
          context,
          11,
          color,
          weight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _CornerBadge extends StatelessWidget {
  const _CornerBadge({
    required this.label,
    required this.color,
    required this.palette,
  });

  final String label;
  final Color color;
  final BracketPalette palette;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: BracketFramePainter(
        color: color.withValues(alpha: 0.8),
        bracketSize: 6,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        color: palette.surfaceFill(lightAlpha: 0.96),
        child: Text(
          label.toUpperCase(),
          style: bracketText(
            context,
            11,
            color,
            weight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _FramedIconButton extends StatelessWidget {
  const _FramedIconButton({
    required this.icon,
    required this.iconColor,
    required this.frameColor,
    required this.palette,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final Color iconColor, frameColor;
  final BracketPalette palette;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: context.soundAction(busy ? null : onTap),
      child: CustomPaint(
        painter: BracketFramePainter(
          color: frameColor.withValues(alpha: 0.8),
          bracketSize: 7,
        ),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          color: palette.surfaceFill(lightAlpha: 0.94),
          child: busy
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                  ),
                )
              : Icon(icon, color: iconColor, size: 17),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.palette,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
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
          height: 42,
          alignment: Alignment.center,
          color: palette.accentWash(accent, darkAlpha: 0.18, lightAlpha: 0.1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: accent),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: palette.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Restores breeding stamina with an elixir, when it is down and there is
/// one to spend. Nothing otherwise.
class _StaminaRestore extends StatelessWidget {
  const _StaminaRestore({
    required this.instance,
    required this.creatureName,
    required this.palette,
    required this.accent,
  });

  final CreatureInstance instance;
  final String creatureName;
  final BracketPalette palette;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    return StreamBuilder<CreatureInstance?>(
      stream: db.creatureDao.watchInstanceById(instance.instanceId),
      builder: (context, instSnap) {
        final inst = instSnap.data;
        if (inst == null) return const SizedBox.shrink();
        final sState = context.read<StaminaService>().computeState(inst);
        if (sState.bars >= sState.max) return const SizedBox.shrink();
        return StreamBuilder<List<InventoryItem>>(
          stream: db.inventoryDao.watchItemInventory(),
          builder: (context, snapshot) {
            var qty = 0;
            for (final item in snapshot.data ?? const <InventoryItem>[]) {
              if (item.key == InvKeys.staminaPotion) {
                qty = item.qty;
                break;
              }
            }
            if (qty <= 0) return const SizedBox.shrink();
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: context.soundAction(() => _restore(context, db, qty)),
              child: CustomPaint(
                painter: BracketFramePainter(
                  color: accent.withValues(alpha: 0.8),
                  bracketSize: 6,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  color: palette.accentWash(accent),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.local_drink_rounded,
                        color: accent,
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'RESTORE ×$qty',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: palette.ink,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _restore(
    BuildContext context,
    AlchemonsDatabase db,
    int qty,
  ) async {
    final t = ForgeTokens(context.read<FactionTheme>());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: t.bg1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        title: Text(
          'Restore Breeding Stamina?',
          style: TextStyle(
            color: t.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          "Use 1 Stamina Elixir to restore $creatureName's breeding "
          'stamina? ($qty remaining)',
          style: TextStyle(color: t.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: Text('Cancel', style: TextStyle(color: t.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: Text(
              'Restore',
              style: TextStyle(
                color: t.amberBright,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await db.inventoryDao.addItemQty(InvKeys.staminaPotion, -1);
    await StaminaService(db).restoreToFull(instance.instanceId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Breeding stamina restored!',
          style: TextStyle(
            fontFamily: 'monospace',
            color: t.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: t.bg1,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Genetics and natures are stored lowercase or capitalised inconsistently;
/// this keeps the panel reading as prose rather than SHOUTING.
String _titleCase(String raw) {
  if (raw.isEmpty) return raw;
  return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
}

/// Both natures on one line — two separate rows labelled NATURE read as a
/// mistake rather than as a pair.
String? _natureLabel(CreatureInstance instance) {
  final parts = <String>[
    if (instance.natureId != null && instance.natureId!.isNotEmpty)
      _titleCase(instance.natureId!),
    if (instance.natureId2 != null && instance.natureId2!.isNotEmpty)
      _titleCase(instance.natureId2!),
  ];
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

// ── Stat tile: value, Potential and the Enhancement track ──────────────────
//
// The number carries the value (an old bar plotted it against a soft curve,
// which told you less than the number did). The pips are the one thing a
// number cannot show: how many of the ten Enhancement ranks are bought.

class _StatTileData {
  const _StatTileData({
    required this.label,
    required this.icon,
    required this.color,
    required this.value,
    required this.potential,
    required this.enhancement,
    required this.isDominant,
  });

  final String label;
  final IconData icon;
  final Color color;
  final double value;

  /// Null without the Potential analyzer.
  final double? potential;
  final int enhancement;

  /// One of the two stats this Alchemon passes down most reliably.
  final bool isDominant;
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.data,
    required this.palette,
    required this.tokens,
  });

  final _StatTileData data;
  final BracketPalette palette;
  final ForgeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final rating = AlchemonStatSystem.displayRating(d.value);
    final p = d.potential == null
        ? null
        : AlchemonStatSystem.normalizePotential(d.potential!);
    final potentialMaxed = p != null && p >= AlchemonStatSystem.maxPotential;
    const maxRank = AlchemonStatSystem.maxEnhancementRank;
    final enhanceMaxed = d.enhancement >= maxRank;
    final labelColor = d.isDominant ? tokens.dominant : palette.muted;

    return CustomPaint(
      painter: BracketFramePainter(
        color: (d.isDominant ? tokens.dominant : palette.line).withValues(
          alpha: d.isDominant ? 0.85 : 0.7,
        ),
        bracketSize: 8,
      ),
      child: Container(
        color: palette.surfaceFill(),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(d.icon, size: 12, color: d.color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    d.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: labelColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                    ),
                  ),
                ),
                if (p != null)
                  Text(
                    'P$p',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: potentialMaxed
                          ? tokens.amberBright
                          : palette.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$rating',
              style: TextStyle(
                fontFamily: 'monospace',
                color: d.color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 0; i < maxRank; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: i < d.enhancement
                            ? (enhanceMaxed ? tokens.amberBright : d.color)
                            : palette.lineSoft.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                Text(
                  enhanceMaxed ? 'MAX' : '${d.enhancement}/$maxRank',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: d.enhancement > 0 ? d.color : palette.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A named characteristic. Reading "SIZE  Small" beats a pill that just says
/// SMALL and leaves you to infer what kind of thing it is.
class _TraitRow extends StatelessWidget {
  const _TraitRow({
    required this.label,
    required this.value,
    required this.color,
    required this.palette,
  });

  final String label;
  final String value;
  final Color color;
  final BracketPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                color: palette.muted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: bracketText(context, 13, color, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
