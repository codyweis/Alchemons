part of 'feeding_screen.dart';

// The chrome round the stage: the header, the level line and the four stat
// readouts under the specimen, and the first-visit card.

TextStyle _mono(
  double size,
  Color color, {
  FontWeight weight = FontWeight.w800,
  double spacing = 1.0,
}) => TextStyle(
  fontFamily: 'monospace',
  color: color,
  fontSize: size,
  fontWeight: weight,
  letterSpacing: spacing,
);

String _short(AlchemicalPowerupType t) => switch (t) {
  AlchemicalPowerupType.speed => 'SPD',
  AlchemicalPowerupType.intelligence => 'INT',
  AlchemicalPowerupType.strength => 'STR',
  AlchemicalPowerupType.beauty => 'BEA',
};

class _EnhanceHeader extends StatelessWidget {
  const _EnhanceHeader({
    required this.subtitle,
    required this.onBack,
    this.silver,
  });

  final String subtitle;
  final VoidCallback onBack;

  /// Shown once something here can cost it.
  final int? silver;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 14, 8),
      child: Row(
        children: [
          BracketIconButton(
            icon: AppIcons.arrow_back,
            palette: _kPalette,
            onTap: onBack,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ENHANCE',
                  style: _mono(
                    15,
                    _kAccent,
                    weight: FontWeight.w900,
                    spacing: 2.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _mono(
                    10.5,
                    _kPalette.muted,
                    weight: FontWeight.w700,
                    spacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          if (silver != null)
            CoinAmount(kind: CoinKind.silver, amount: silver!, size: 12.5),
        ],
      ),
    );
  }
}

/// Search the picker by nickname or species.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: _kPalette.ink,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    );
    return CustomPaint(
      painter: BracketFramePainter(
        color: _kPalette.line.withValues(alpha: 0.55),
        bracketSize: 8,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: Colors.white.withValues(alpha: 0.03),
        child: Row(
          children: [
            Icon(AppIcons.search_rounded, size: 15, color: _kPalette.muted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                cursorColor: _kAccent,
                style: style,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Search your Alchemons',
                  hintStyle: style.copyWith(color: _kPalette.muted),
                ),
                onChanged: onChanged,
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        controller.clear();
                        onChanged('');
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(
                          AppIcons.close_rounded,
                          size: 14,
                          color: _kPalette.muted,
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

/// On a picker card: how many spares it could take in for XP.
class _KinBadge extends StatelessWidget {
  const _KinBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 3, 6, 3),
      decoration: BoxDecoration(
        color: _kPalette.chromeMutedFill(),
        border: const Border(right: BorderSide(color: _kGold, width: 2)),
      ),
      child: Text('XP ×$count', style: _mono(9.5, _kGold, spacing: 0.6)),
    );
  }
}

class _QuietNote extends StatelessWidget {
  const _QuietNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text.toUpperCase(),
          textAlign: TextAlign.center,
          style: _mono(11, _kPalette.muted, spacing: 1.4),
        ),
      ),
    );
  }
}

/// Level and the way to the next, with what the chosen kin would make of it.
///
///   LV 3  ▮▮▮▮▯▯▯▯▯▯  → LV 6
///         120 / 430 XP       +215 XP
class _LevelLine extends StatelessWidget {
  const _LevelLine({
    required this.coord,
    required this.rarity,
    required this.preview,
    required this.xpBoost,
  });

  /// Level + the fraction of the way to the next.
  final double coord;
  final String rarity;
  final FeedResult? preview;
  final double xpBoost;

  @override
  Widget build(BuildContext context) {
    const max = AlchemonStatSystem.maxLevel;
    final maxed = coord >= max;
    final level = maxed ? max : coord.floor();
    final fraction = maxed ? 1.0 : coord - level;
    final need = CreatureInstanceServiceFeeding.xpNeededForLevel(
      level,
      rarity: rarity,
    );
    final p = preview;
    double? ghost;
    if (p != null && !maxed) {
      ghost = p.newLevel > level
          ? 1.0
          : (need <= 0 ? 0.0 : p.newXpRemainder / need).clamp(0.0, 1.0);
    }
    final note = maxed
        ? 'MAX LEVEL'
        : '${(fraction * need).round()} / $need XP'
              '${xpBoost > 1.001 ? '  ·  ×${xpBoost.toStringAsFixed(2)}' : ''}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 62,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('LV', style: _mono(10, _kPalette.muted)),
              const SizedBox(width: 4),
              Text(
                '$level',
                style: _mono(
                  24,
                  maxed ? _kGold : _kPalette.ink,
                  weight: FontWeight.w900,
                  spacing: 0,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 8,
                child: CustomPaint(
                  painter: _CellGaugePainter(
                    fraction: fraction,
                    ghost: ghost,
                    color: _kGold,
                    track: _kPalette.line.withValues(alpha: 0.35),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note,
                      maxLines: 1,
                      style: _mono(
                        9.5,
                        maxed ? _kGold : _kPalette.muted,
                        weight: FontWeight.w700,
                        spacing: 0.6,
                      ),
                    ),
                  ),
                  if (p != null)
                    Text(
                      '+${formatCoins(p.totalXpGained)} XP',
                      style: _mono(9.5, _kGold, spacing: 0.6),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (p != null && p.newLevel > level) ...[
          const SizedBox(width: 10),
          Text(
            '→ LV ${p.newLevel}',
            style: _mono(13, _kGold, weight: FontWeight.w900, spacing: 0.4),
          ),
        ],
      ],
    );
  }
}

@immutable
class _StatCellData {
  const _StatCellData({
    required this.type,
    required this.rating,
    required this.after,
    required this.rank,
    required this.rankAfter,
    required this.potential,
    required this.lit,
  });

  final AlchemicalPowerupType type;
  final int rating;

  /// What the rating becomes with what is chosen or held.
  final int? after;
  final int rank;
  final int? rankAfter;

  /// Null without the Potential Analyzer: the figure is not theirs to read.
  final int? potential;

  /// Dimmed while an orb of another stat is in the hand.
  final bool lit;
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.cells});

  final List<_StatCellData> cells;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _StatCell(data: cells[row * 2])),
              const SizedBox(width: 18),
              Expanded(child: _StatCell(data: cells[row * 2 + 1])),
            ],
          ),
        ],
      ],
    );
  }
}

/// One stat: its rating (and what it will be), its Enhancement ranks as ten
/// cells, and its Potential for those who can read it.
class _StatCell extends StatelessWidget {
  const _StatCell({required this.data});

  final _StatCellData data;

  @override
  Widget build(BuildContext context) {
    const maxRank = AlchemonStatSystem.maxEnhancementRank;
    final color = data.type.color;
    final rankMaxed = data.rank >= maxRank;
    final potentialMaxed =
        data.potential != null &&
        data.potential! >= AlchemonStatSystem.maxPotential;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: data.lit ? 1 : 0.35,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _short(data.type),
                style: _mono(10.5, color, weight: FontWeight.w900),
              ),
              const Spacer(),
              Text(
                '${data.rating}',
                style: _mono(
                  13,
                  data.after == null ? _kPalette.ink : _kPalette.muted,
                  spacing: 0,
                ),
              ),
              if (data.after != null) ...[
                Text('  →  ', style: _mono(10, _kPalette.muted, spacing: 0)),
                Text(
                  '${data.after}',
                  style: _mono(13, color, weight: FontWeight.w900, spacing: 0),
                ),
              ],
            ],
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 5,
            child: CustomPaint(
              painter: _CellGaugePainter(
                fraction: data.rank / maxRank,
                ghost: data.rankAfter == null
                    ? null
                    : data.rankAfter! / maxRank,
                color: rankMaxed ? _kGold : color,
                track: _kPalette.line.withValues(alpha: 0.35),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                rankMaxed ? 'ENH MAX' : 'ENH ${data.rank}/$maxRank',
                style: _mono(
                  9,
                  rankMaxed ? _kGold : _kPalette.muted,
                  weight: FontWeight.w700,
                  spacing: 0.5,
                ),
              ),
              const Spacer(),
              if (data.potential != null)
                Text(
                  potentialMaxed ? 'P100 MAX' : 'P${data.potential}',
                  style: _mono(
                    9,
                    potentialMaxed ? _kGold : _kPalette.muted,
                    weight: FontWeight.w700,
                    spacing: 0.5,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ten cells, lit as far as the gauge is full, the last lit one only partly;
/// [ghost] lights faintly as far as what is chosen would take it.
class _CellGaugePainter extends CustomPainter {
  _CellGaugePainter({
    required this.fraction,
    required this.color,
    required this.track,
    this.ghost,
  });

  final double fraction;
  final double? ghost;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const cells = 10;
    const gap = 2.0;
    final w = (size.width - gap * (cells - 1)) / cells;
    final f = fraction.clamp(0.0, 1.0);
    final g = (ghost ?? 0).clamp(0.0, 1.0);
    final dim = Paint()..color = track;
    final lit = Paint();
    final faint = Paint()..color = color.withValues(alpha: 0.32);
    for (var i = 0; i < cells; i++) {
      final x = i * (w + gap);
      canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), dim);
      final ghostFill = (g * cells - i).clamp(0.0, 1.0);
      if (ghostFill > 0) {
        canvas.drawRect(Rect.fromLTWH(x, 0, w * ghostFill, size.height), faint);
      }
      final fill = (f * cells - i).clamp(0.0, 1.0);
      if (fill > 0) {
        lit.color = color.withValues(alpha: 0.6 + 0.4 * fill);
        canvas.drawRect(Rect.fromLTWH(x, 0, w * fill, size.height), lit);
      }
    }
  }

  @override
  bool shouldRepaint(_CellGaugePainter old) =>
      old.fraction != fraction ||
      old.ghost != ghost ||
      old.color != color ||
      old.track != track;
}

/// Light pooled on the floor under the specimen: an ellipse of gradient, not
/// a ring. Always faintly there — it is where the Alchemon stands.
class _FloorLightPainter extends CustomPainter {
  const _FloorLightPainter({required this.color, required this.strength});

  final Color color;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.62);
    final r = math.min(size.width * 0.34, 150.0);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(1, 0.2);
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.42 * strength),
            color.withValues(alpha: 0.14 * strength),
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FloorLightPainter old) =>
      old.color != color || old.strength != strength;
}

/// The first visit: what each tray does, in plain words.
class _BasicsDialog extends StatelessWidget {
  const _BasicsDialog({required this.orbs, required this.souls});

  final bool orbs;
  final bool souls;

  @override
  Widget build(BuildContext context) {
    Widget line(String head, String body, Color accent) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 54,
            child: Text(
              head,
              style: _mono(11, accent, weight: FontWeight.w900),
            ),
          ),
          Expanded(
            child: Text(
              body,
              style: TextStyle(color: _kPalette.ink, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: _kAccent.withValues(alpha: 0.9),
          bracketSize: 14,
          strokeWidth: 1.3,
        ),
        child: Container(
          color: _kPalette.bg1,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ENHANCE',
                style: _mono(
                  14,
                  _kAccent,
                  weight: FontWeight.w900,
                  spacing: 2.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pick an Alchemon, then strengthen it.',
                style: TextStyle(color: _kPalette.muted, fontSize: 13),
              ),
              line(
                'XP',
                'Give up spare Alchemons of the same species. It gains XP and levels, up to 10. The ones given up are gone.',
                _kGold,
              ),
              if (orbs)
                line(
                  'ORBS',
                  'Drag a Power Orb onto it. Each raises one stat\'s Enhancement by a rank, up to 10.',
                  AlchemicalPowerupType.speed.color,
                ),
              if (souls)
                line(
                  'SOULS',
                  'Raise one Potential. The new Potential passes on through breeding.',
                  _kSoul,
                ),
              const SizedBox(height: 18),
              BracketButton(
                label: 'GOT IT',
                palette: _kPalette,
                accent: _kAccent,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A hand tracing the way from the first orb to the specimen, the first time
/// the orb tray is open.
class _DragHintOverlay extends StatefulWidget {
  const _DragHintOverlay({required this.from, required this.to});

  final Offset from;
  final Offset to;

  @override
  State<_DragHintOverlay> createState() => _DragHintOverlayState();
}

class _DragHintOverlayState extends State<_DragHintOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Offset _at(double t) {
    final a = widget.from, b = widget.to;
    final c = Offset((a.dx + b.dx) / 2 - 54, (a.dy + b.dy) / 2 - 10);
    final m = 1 - t;
    return a * (m * m) + c * (2 * m * t) + b * (t * t);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final raw = _ctrl.value;
        final travel = Curves.easeInOut.transform((raw / 0.7).clamp(0.0, 1.0));
        final opacity = raw < 0.08
            ? raw / 0.08
            : raw > 0.86
            ? (1 - (raw - 0.86) / 0.14).clamp(0.0, 1.0)
            : 1.0;
        final pos = _at(travel);
        return Stack(
          children: [
            Positioned(
              left: pos.dx - 13,
              top: pos.dy - 5,
              child: Opacity(
                opacity: opacity,
                child: const Icon(
                  AppIcons.hand_pointing_fill,
                  size: 30,
                  color: _kGold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: (widget.from.dy + widget.to.dy) / 2 + 8,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  color: _kPalette.bg1.withValues(alpha: 0.92),
                  child: Text(
                    'DRAG AN ORB ONTO IT',
                    style: _mono(11, _kPalette.ink, spacing: 1.4),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
