import 'dart:math' as math;

import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// How a section of the shop or the inventory lays out what it holds. Both
/// were grey tiles with a price strip until 2026-10, the last row's odd one
/// left centred on its own.
///
/// - [ledger]: a list. Art, name, a line on what it does, price on the right.
///   For things bought for what they do (the shop's supplies).
/// - [featured]: the headline thing as a wide lit card, the rest on one
///   sideways shelf under it. For things bought for how they look (the
///   cosmetics); with no headline, a shelf per kind (the inventory).
enum ShelfKind { ledger, featured }

/// How a [ShelfLayout] wants one of its children drawn.
enum ShelfSlot { row, hero, shelf }

class ShelfSlotScope extends InheritedWidget {
  const ShelfSlotScope({
    super.key,
    required this.slot,
    this.artSize = 64,
    required super.child,
  });

  final ShelfSlot slot;

  /// How big a [ShelfSlot.shelf] card draws its thing.
  final double artSize;

  static ShelfSlotScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShelfSlotScope>();

  @override
  bool updateShouldNotify(ShelfSlotScope oldWidget) =>
      oldWidget.slot != slot || oldWidget.artSize != artSize;
}

/// Lays [children] out the [kind] way, telling each how to draw itself
/// through [ShelfSlotScope].
class ShelfLayout extends StatelessWidget {
  const ShelfLayout({
    super.key,
    required this.kind,
    required this.children,
    this.heroIndex = 0,
    this.aspectRatio = 0.8,
    this.spacing = 10,
  });

  final ShelfKind kind;
  final List<Widget> children;

  /// The child [ShelfKind.featured] puts first, wide; below zero, none, and
  /// everything goes on the shelf.
  final int heroIndex;
  final double aspectRatio;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return switch (kind) {
      ShelfKind.ledger => _ledger(context),
      ShelfKind.featured => _featured(context),
    };
  }

  Widget _ledger(BuildContext context) {
    final line = BracketPalette.of(context).lineSoft;
    return Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Container(height: 1, color: line.withValues(alpha: 0.7)),
          ShelfSlotScope(slot: ShelfSlot.row, child: children[i]),
        ],
      ],
    );
  }

  Widget _featured(BuildContext context) {
    final hero = heroIndex < 0 ? -1 : heroIndex.clamp(0, children.length - 1);
    final rest = [
      for (var i = 0; i < children.length; i++)
        if (i != hero) children[i],
    ];
    // Three and a bit across the screen, so the cut-off one says "there is
    // more". Measured off the screen rather than a LayoutBuilder: built
    // during layout, a baked effect's live frame costs an animation frame.
    final w = ((MediaQuery.sizeOf(context).width - 28 - spacing * 2) / 3.3)
        .floorToDouble();
    final h = (w / aspectRatio).floorToDouble();
    final art = math.min(w * 0.62, h * 0.52).floorToDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hero >= 0)
          ShelfSlotScope(
            slot: ShelfSlot.hero,
            child: SizedBox(height: 156, child: children[hero]),
          ),
        if (rest.isNotEmpty) ...[
          if (hero >= 0) const SizedBox(height: 14),
          SizedBox(
            height: h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              // Runs out to the screen's edge past the section's margin.
              clipBehavior: Clip.none,
              physics: const BouncingScrollPhysics(),
              itemCount: rest.length,
              separatorBuilder: (_, _) => SizedBox(width: spacing),
              itemBuilder: (_, i) => SizedBox(
                width: w,
                child: ShelfSlotScope(
                  slot: ShelfSlot.shelf,
                  artSize: art,
                  child: rest[i],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// One thing on a shelf, drawn for the slot its [ShelfLayout] gave it.
///
/// [art] is asked for at the size the slot wants. [price] sits under the
/// name on a shelf and on the right in a row; [count] is how many are held.
class ShelfEntry extends StatelessWidget {
  const ShelfEntry({
    super.key,
    required this.art,
    required this.name,
    this.description,
    this.price,
    this.count,
    this.dim = false,
    this.theme,
  });

  final Widget Function(double size) art;
  final String name;
  final String? description;
  final Widget? price;
  final String? count;
  final bool dim;

  /// The faction theme, for a caller that holds one; otherwise the ambient
  /// one is read.
  final FactionTheme? theme;

  @override
  Widget build(BuildContext context) {
    final palette = theme != null
        ? BracketPalette.fromTheme(theme!)
        : BracketPalette.of(context);
    final scope = ShelfSlotScope.maybeOf(context);
    return switch (scope?.slot ?? ShelfSlot.shelf) {
      ShelfSlot.row => _row(context, palette),
      ShelfSlot.hero => _hero(context, palette),
      ShelfSlot.shelf => _shelf(context, palette, scope?.artSize ?? 64),
    };
  }

  Widget _art(double size, {double pool = 1}) => SizedBox.square(
    dimension: size,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _PoolPainter(strength: pool)),
        ),
        Positioned.fill(
          child: Opacity(opacity: dim ? 0.4 : 1, child: art(size)),
        ),
      ],
    ),
  );

  Widget _name(
    BuildContext context,
    BracketPalette palette,
    double size, {
    TextAlign align = TextAlign.center,
    int lines = 2,
  }) {
    return Text(
      name,
      textAlign: align,
      maxLines: lines,
      overflow: TextOverflow.ellipsis,
      style: bracketText(
        context,
        size,
        dim ? palette.muted : palette.ink,
        weight: FontWeight.w600,
      ).copyWith(height: 1.1),
    );
  }

  Widget? _countText(BracketPalette palette) => count == null
      ? null
      : Text(
          count!,
          style: TextStyle(
            fontFamily: 'monospace',
            color: palette.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        );

  Widget _shelf(BuildContext context, BracketPalette palette, double size) {
    final count = _countText(palette);
    // Under the name when there is no price (the inventory); otherwise
    // at the thing's shoulder.
    final under = price ?? count;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _art(size),
                if (price != null && count != null)
                  Positioned(top: 0, right: -12, child: count),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _name(context, palette, 12.5),
        ),
        if (under != null) ...[
          const SizedBox(height: 5),
          SizedBox(
            height: 18,
            child: FittedBox(fit: BoxFit.scaleDown, child: under),
          ),
        ],
      ],
    );
  }

  /// The headline thing is the chosen one: lit from below, like a chosen
  /// tab or panel in the bracket kit.
  Widget _hero(BuildContext context, BracketPalette palette) {
    return CustomPaint(
      foregroundPainter: BracketFramePainter(
        color: palette.isDark
            ? ForgeTokens(
                theme ?? context.read<FactionTheme>(),
              ).amber.withValues(alpha: 0.75)
            : palette.line,
        strokeWidth: 1.2,
      ),
      child: Container(
        color: palette.surfaceMutedFill(darkAlpha: 0.35),
        padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
        child: Row(
          children: [
            _art(118, pool: 1.4),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _name(context, palette, 18, align: TextAlign.start, lines: 1),
                  if (description != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: bracketText(
                        context,
                        12,
                        palette.muted,
                      ).copyWith(height: 1.25),
                    ),
                  ],
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      ?price,
                      if (_countText(palette) case final c?) ...[
                        const SizedBox(width: 12),
                        c,
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, BracketPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _art(58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _name(context, palette, 14.5, align: TextAlign.start, lines: 1),
                if (description != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: bracketText(
                      context,
                      11.5,
                      palette.muted,
                    ).copyWith(height: 1.2),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ?price,
              if (_countText(palette) case final c?) ...[
                if (price != null) const SizedBox(height: 5),
                c,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The soft pool of light a thing stands in, low under it.
class _PoolPainter extends CustomPainter {
  const _PoolPainter({this.strength = 1});

  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Rect.fromCenter(
      center: Offset(w / 2, h * 0.86),
      width: w * 1.15,
      height: h * 0.34,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFE6E2DA).withValues(alpha: 0.11 * strength),
            const Color(0xFFE6E2DA).withValues(alpha: 0.035 * strength),
            const Color(0x00E6E2DA),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _PoolPainter oldDelegate) =>
      oldDelegate.strength != strength;
}

/// A section's heading on a shelf page: a bar, the title in spaced capitals,
/// a hairline to the edge.
class ShelfSectionHeader extends StatelessWidget {
  const ShelfSectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final accent = ForgeTokens(context.read<FactionTheme>()).amberBright;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            color: accent,
            margin: const EdgeInsets.only(right: 10),
          ),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'monospace',
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(height: 1, color: accent.withValues(alpha: 0.2)),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}
