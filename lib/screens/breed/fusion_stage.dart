part of 'breed_tab.dart';

// The fusion chamber's pieces: the room count, the floor, the plates under
// the pair, and the line that says what is in the way.

TextStyle _mono(
  double size,
  Color color, {
  FontWeight weight = FontWeight.w800,
  double spacing = 1.2,
}) => TextStyle(
  fontFamily: 'monospace',
  color: color,
  fontSize: size,
  fontWeight: weight,
  letterSpacing: spacing,
);

/// An element's color, deepened on the parchment where the pale ones
/// (Air, Light, Ice) would wash out.
Color _readable(Color c, BracketPalette palette) =>
    palette.isDark ? c : Color.lerp(c, Colors.black, 0.32)!;

/// Where a new cultivation can go: the open chambers, how many are busy, and
/// cold storage behind them.
class _Room {
  const _Room({
    required this.known,
    this.chambers = 0,
    this.busy = 0,
    this.stored,
    this.capacity,
  });

  factory _Room.of(List<IncubatorSlot>? slots, int? stored, int? capacity) {
    if (slots == null) return const _Room(known: false);
    final open = slots.where((s) => s.unlocked).toList();
    return _Room(
      known: true,
      chambers: open.length,
      busy: open.where((s) => s.eggId != null).length,
      stored: stored,
      capacity: capacity,
    );
  }

  /// Whether the chambers have been read yet.
  final bool known;
  final int chambers, busy;
  final int? stored, capacity;

  int get free => math.max(0, chambers - busy);

  bool get storageFull =>
      stored != null && capacity != null && stored! >= capacity!;
}

/// The chambers, one cell each — lit while cultivating — and how many are
/// free.
class _ChamberCells extends StatelessWidget {
  const _ChamberCells({
    required this.room,
    required this.palette,
    required this.gold,
  });

  final _Room room;
  final BracketPalette palette;
  final Color gold;

  @override
  Widget build(BuildContext context) {
    if (!room.known) return const SizedBox(height: 16);
    final (label, color) = room.free > 0
        ? ('${room.free} FREE', palette.ink)
        : room.storageFull
        ? ('ALL FULL', palette.isDark ? _kDanger : const Color(0xFFB4442F))
        : (
            room.capacity == null
                ? 'FULL'
                : 'FULL · STORAGE ${room.stored ?? 0}/${room.capacity}',
            palette.muted,
          );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 16),
      child: Row(
        children: [
          Text('CHAMBERS', style: _mono(10, palette.muted, spacing: 1.8)),
          const SizedBox(width: 10),
          for (var i = 0; i < room.chambers; i++)
            Container(
              width: 14,
              height: 6,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: i < room.busy ? gold.withValues(alpha: 0.85) : null,
                border: i < room.busy
                    ? null
                    : Border.all(
                        color: palette.line.withValues(alpha: 0.8),
                        width: 1,
                      ),
              ),
            ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: _mono(10.5, color, spacing: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Under a specimen: its name, element and level, and its stamina. Empty, it
/// keeps its height so nothing below moves when one is chosen.
class _Plate extends StatelessWidget {
  const _Plate({
    required this.name,
    required this.element,
    required this.level,
    required this.stamina,
    required this.palette,
    required this.gold,
    required this.onRemove,
  });

  final String? name;
  final String? element;
  final int? level;
  final StaminaState? stamina;
  final BracketPalette palette;
  final Color gold;
  final VoidCallback? onRemove;

  /// About how tall it stands, for laying the stage out round it. It sizes
  /// to its text, which runs taller on some phones' fonts than this.
  static const double height = 62;

  @override
  Widget build(BuildContext context) {
    final name = this.name;
    if (name == null) return const SizedBox.shrink();
    final type = element ?? '';
    final typeColor = _readable(
      type.isEmpty ? gold : BreedConstants.getTypeColor(type),
      palette,
    );
    final s = stamina;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _mono(12.5, palette.ink, spacing: 1.3),
              ),
            ),
            if (onRemove != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: context.soundAction(onRemove),
                child: SizedBox(
                  width: 30,
                  height: 22,
                  child: Icon(
                    AppIcons.close,
                    size: 12,
                    color: palette.muted.withValues(alpha: 0.8),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: type.toUpperCase(),
                style: _mono(10.5, typeColor, spacing: 1.4),
              ),
              if (level != null)
                TextSpan(
                  text: '  ·  LV $level',
                  style: _mono(10.5, palette.muted, spacing: 1.4),
                ),
            ],
          ),
          maxLines: 1,
        ),
        const SizedBox(height: 8),
        if (s != null)
          s.bars < 1
              ? Text(
                  'RESTING',
                  style: _mono(
                    9.5,
                    palette.isDark ? _kDanger : const Color(0xFFB4442F),
                    spacing: 1.6,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'STAMINA',
                      style: _mono(9, palette.muted, spacing: 1.6),
                    ),
                    const SizedBox(width: 7),
                    for (var i = 0; i < s.max; i++)
                      Container(
                        width: 11,
                        height: 4,
                        margin: const EdgeInsets.only(right: 3),
                        color: i < s.bars
                            ? gold.withValues(alpha: 0.9)
                            : palette.line.withValues(alpha: 0.45),
                      ),
                  ],
                ),
      ],
    );
  }
}

/// One plain line over the button: what stops the fusion (and FUSE waits on
/// it), or what is worth knowing before it.
class _ReadinessLine extends StatelessWidget {
  const _ReadinessLine({
    required this.block,
    required this.note,
    required this.palette,
  });

  final String? block, note;
  final BracketPalette palette;

  @override
  Widget build(BuildContext context) {
    final text = block ?? note;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 28),
      child: Center(
        child: text == null
            ? null
            : Text(
                text.toUpperCase(),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: _mono(
                  10.5,
                  block != null
                      ? (palette.isDark ? _kDanger : const Color(0xFFB4442F))
                      : palette.muted,
                  spacing: 1.1,
                ).copyWith(height: 1.3),
              ),
      ),
    );
  }
}

/// The floor the pair stand on: a broad faint light, a pool of each one's
/// element under it, and where the two pools meet; behind them, the room
/// lit faintly in their colors. An empty place keeps a dim, colorless
/// pool. [lit] dims each light as the merge empties its chamber.
class _FusionFloorPainter extends CustomPainter {
  const _FusionFloorPainter({
    required this.floorY,
    required this.knotY,
    required this.xs,
    required this.frames,
    required this.colors,
    required this.lit,
    required this.palette,
  });

  final double floorY, knotY;
  final List<double> xs, frames, lit;
  final List<Color?> colors;
  final BracketPalette palette;

  void _pool(
    Canvas canvas,
    Offset at,
    double radius,
    double squash,
    List<Color> colors,
    List<double> stops,
  ) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(1, squash);
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: colors,
          stops: stops,
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius)),
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final dark = palette.isDark;
    final floor = dark ? const Color(0xFFB8A27A) : const Color(0xFF6B5A40);
    // The room behind them, lit faintly in their colors from the middle.
    final present = [
      for (var s = 0; s < 2; s++)
        if (colors[s] != null && frames[s] > 0) colors[s]!,
    ];
    final room = switch (present.length) {
      0 => floor,
      1 => present[0],
      _ => Color.lerp(present[0], present[1], 0.5)!,
    };
    final roomLit = present.isEmpty
        ? 0.6
        : math.min(lit[0], lit[1]).clamp(0.0, 1.0);
    _pool(
      canvas,
      Offset(w / 2, knotY),
      w * 0.8,
      0.85,
      [
        room.withValues(alpha: (dark ? 0.09 : 0.06) * roomLit),
        room.withValues(alpha: (dark ? 0.03 : 0.02) * roomLit),
        room.withValues(alpha: 0),
      ],
      const [0, 0.5, 1],
    );
    // The floor itself.
    _pool(
      canvas,
      Offset(w / 2, floorY),
      w * 0.56,
      0.12,
      [
        floor.withValues(alpha: dark ? 0.11 : 0.09),
        floor.withValues(alpha: dark ? 0.04 : 0.035),
        floor.withValues(alpha: 0),
      ],
      const [0, 0.55, 1],
    );
    final strength = dark ? 1.0 : 0.7;
    for (var side = 0; side < 2; side++) {
      final c = colors[side];
      final at = Offset(xs[side], floorY);
      if (c == null || frames[side] <= 0) {
        _pool(
          canvas,
          at,
          62,
          0.2,
          [
            palette.line.withValues(alpha: dark ? 0.2 : 0.16),
            palette.line.withValues(alpha: 0),
          ],
          const [0, 1],
        );
        continue;
      }
      final k = lit[side].clamp(0.0, 1.0) * strength;
      _pool(
        canvas,
        at,
        (frames[side] * 0.46).clamp(54.0, 124.0),
        0.2,
        [
          c.withValues(alpha: 0.46 * k),
          c.withValues(alpha: 0.15 * k),
          c.withValues(alpha: 0),
        ],
        const [0, 0.5, 1],
      );
    }
    // Where the two lights meet, under the knot.
    final a = colors[0], b = colors[1];
    if (a != null && b != null && frames[0] > 0 && frames[1] > 0) {
      final mix = Color.lerp(a, b, 0.5)!;
      final k = math.min(lit[0], lit[1]).clamp(0.0, 1.0) * strength;
      _pool(
        canvas,
        Offset(w / 2, floorY),
        w * 0.22,
        0.16,
        [mix.withValues(alpha: 0.2 * k), mix.withValues(alpha: 0)],
        const [0, 1],
      );
    }
  }

  @override
  bool shouldRepaint(_FusionFloorPainter old) =>
      old.floorY != floorY ||
      old.knotY != knotY ||
      old.palette != palette ||
      !listEquals(old.xs, xs) ||
      !listEquals(old.frames, frames) ||
      !listEquals(old.lit, lit) ||
      !listEquals(old.colors, colors);
}
