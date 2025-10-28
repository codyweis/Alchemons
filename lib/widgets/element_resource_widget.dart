// widgets/element_resource_widget.dart — CLEAN V1 (solid, gamey, less glass)
// Drop-in replacement for ResourceCollectionWidget
// - Keeps expand/contract animation, removes blur + glass, uses solid cards
// - Resource pills use accent rim, subtle shadow, clearer hierarchy
// - Same public API: ResourceCollectionWidget(accentColor: ...)

import 'dart:ui';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/element_resource.dart';

class ResourceCollectionWidget extends StatefulWidget {
  final FactionTheme theme;
  const ResourceCollectionWidget({super.key, required this.theme});
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
    final db = context.read<AlchemonsDatabase>();
    return StreamBuilder<Map<String, int>>(
      stream: db.watchResourceBalances(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final res =
            _toElementResources(snap.data!).where((r) => r.amount > 0).toList()
              ..sort((a, b) => b.amount.compareTo(a.amount));
        if (res.isEmpty) return const SizedBox.shrink();

        const compactSpacing = 8.0;
        return RepaintBoundary(
          child: GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return AnimatedBuilder(
                  animation: _t,
                  builder: (context, _) {
                    final height = lerpDouble(60, 80, _t.value)!;

                    return SizedBox(
                      height: height,
                      child: ListView.separated(
                        key: const PageStorageKey('resource-strip-clean'),
                        scrollDirection: Axis.horizontal,
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          lerpDouble(12, 12, _t.value)!,
                          lerpDouble(6, 10, _t.value)!,
                          lerpDouble(12, 12, _t.value)!,
                          lerpDouble(6, 10, _t.value)!,
                        ),
                        itemBuilder: (context, i) => _ResourcePill(
                          key: ValueKey(res[i].id),
                          r: res[i],
                          t: _t.value,
                          theme: widget.theme,
                        ),
                        separatorBuilder: (_, __) => SizedBox(
                          width: lerpDouble(compactSpacing, 12, _t.value)!,
                        ),
                        itemCount: res.length,
                        cacheExtent: 1000,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  List<ElementResource> _toElementResources(Map<String, int> m) =>
      ElementId.values.map((e) => ElementResource.fromDbMap(m, e)).toList();
}

class _ResourcePill extends StatelessWidget {
  final FactionTheme theme;
  final ElementResource r;
  final double t; // 0..1 parent animation
  const _ResourcePill({
    super.key,
    required this.r,
    required this.t,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    const compactSize = 38.0;
    final showDetails = t >= 0.30;

    final iconWrap = lerpDouble(38.0, 52, t)!;
    final hPad = lerpDouble(0, 10, t)!;
    final vPad = lerpDouble(0, 8, t)!;
    final iconSize = lerpDouble(20, 24, t)!;
    final radius = lerpDouble(compactSize / 2, 5, t)!;

    final baseWidth = iconWrap + (hPad * 2);
    const detailsSpacing = 8.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutQuart,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon bubble
          Container(
            width: iconWrap,
            height: iconWrap,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.surface,
              border: Border.all(color: r.color.withOpacity(0.55), width: 1.5),
            ),
            child: Icon(r.icon, size: iconSize, color: r.color),
          ),

          if (showDetails) const SizedBox(width: detailsSpacing),
          if (showDetails)
            Flexible(
              child: Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - t)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        r.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textMuted,
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
                          color: r.color,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '${r.amount}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
