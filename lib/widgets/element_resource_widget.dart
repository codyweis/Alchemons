import 'dart:ui';
import 'package:alchemons/models/element_resource.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ResourceCollectionWidget extends StatefulWidget {
  final Color accentColor;

  const ResourceCollectionWidget({super.key, required this.accentColor});

  @override
  State<ResourceCollectionWidget> createState() =>
      _ResourceCollectionWidgetState();
}

class _ResourceCollectionWidgetState extends State<ResourceCollectionWidget>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late final AnimationController _controller;
  late final Animation<double> _t; // 0 (compact) -> 1 (expanded)

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 520),
      vsync: this,
    );
    _t = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
      reverseCurve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final resources = getSampleResources().where((r) => r.amount > 0).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    if (resources.isEmpty) return const SizedBox.shrink();

    const compactIconSize = 30.0;
    const compactSpacing = 8.0;

    final compactWidth =
        (resources.length * compactIconSize) +
        ((resources.length - 1) * compactSpacing) +
        24;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: _toggle,
        behavior: HitTestBehavior.opaque,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return AnimatedBuilder(
              animation: _t,
              builder: (context, _) {
                final maxWidth = constraints.maxWidth;
                final width = lerpDouble(compactWidth, maxWidth, _t.value)!;
                final height = lerpDouble(60, 128, _t.value)!;
                final radius = lerpDouble(28, 18, _t.value)!;
                final glassOpacity = lerpDouble(0.16, 0.12, _t.value)!;

                return ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: width,
                      height: height,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(glassOpacity),
                        borderRadius: BorderRadius.circular(radius),
                        border: Border.all(
                          color: widget.accentColor.withOpacity(
                            (1 - _t.value) * 0.45,
                          ),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.accentColor.withOpacity(
                              0.10 + 0.10 * (1 - _t.value),
                            ),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        key: const PageStorageKey('resource-strip'),
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          lerpDouble(12, 8, _t.value)!, // left
                          lerpDouble(6, 8, _t.value)!, // top
                          lerpDouble(12, 8, _t.value)!, // right
                          lerpDouble(6, 8, _t.value)!, // bottom
                        ),
                        itemBuilder: (context, i) => _ResourceTile(
                          key: ValueKey('${resources[i].name}-$i'),
                          r: resources[i],
                          t: _t.value,
                        ),
                        separatorBuilder: (_, __) => SizedBox(
                          width: lerpDouble(compactSpacing, 10, _t.value)!,
                        ),
                        itemCount: resources.length,
                        cacheExtent: 1000,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  final ElementResource r;
  final double t; // parent animation value 0..1

  const _ResourceTile({super.key, required this.r, required this.t});

  @override
  Widget build(BuildContext context) {
    const compactSize = 38.0;
    final bool showDetails = t >= 0.35;

    final iconWrap = lerpDouble(38.0, 52, t)!;
    final hPad = lerpDouble(0, 10, t)!;
    final vPad = lerpDouble(0, 8, t)!;

    const detailsWidth = 108.0;
    final radius = lerpDouble(compactSize / 2, 16, t)!;

    final borderOpacity = (1 - (t * 6)).clamp(0.0, 1.0);
    final iconSize = lerpDouble(20, 24, t)!;

    final baseWidth = iconWrap + (hPad * 2);
    const detailsSpacing = 8.0;

    // We remove the fixed width and allow flex to negotiate space.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutQuart,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(lerpDouble(0.06, 0.08, t)!),
        borderRadius: BorderRadius.circular(radius),
        border: borderOpacity > 0
            ? Border.all(
                color: r.color.withOpacity(0.55 * borderOpacity),
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: r.color.withOpacity(lerpDouble(0.30, 0.18, t)!),
            blurRadius: lerpDouble(8, 14, t)!,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon bubble (fixed)
          Container(
            width: iconWrap,
            height: iconWrap,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  r.color.withOpacity(lerpDouble(0.45, 0.55, t)!),
                  r.color.withOpacity(0.08),
                ],
              ),
              border: borderOpacity > 0
                  ? Border.all(
                      color: r.color.withOpacity(0.65 * borderOpacity),
                      width: 2,
                    )
                  : null,
            ),
            child: Icon(r.icon, size: iconSize, color: r.color),
          ),

          // Details (spacing + flexible content)
          if (showDetails) const SizedBox(width: detailsSpacing),
          if (showDetails)
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  // target max size; can shrink if tight
                  maxWidth: baseWidth + detailsWidth * t,
                  // keep at least enough room for text to be legible
                  minWidth: detailsWidth * 0.4 * t,
                ),
                child: Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, 8 * (1 - t)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          r.resourceName.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.92),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          r.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.60),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: r.color.withOpacity(0.20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${r.amount}',
                            style: TextStyle(
                              color: r.color,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
