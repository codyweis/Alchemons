import 'dart:math' as math;

import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/element_resource_glyph.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The player's running stock of every element currency, as a single strip.
///
/// Built for the top of the harvest screen: a collect has to visibly land on
/// something, and the thing it lands on should be the balance it changed —
/// not the projected yield of the run that produced it. [totalKeys] anchors
/// each element's figure so the collect animation can fly to it.
class ElementResourceTotalsBar extends StatefulWidget {
  const ElementResourceTotalsBar({
    super.key,
    required this.theme,
    this.totalKeys = const {},
  });

  final FactionTheme theme;

  /// Keyed by biome id. Optional — the strip renders fine unanchored.
  final Map<String, GlobalKey> totalKeys;

  @override
  State<ElementResourceTotalsBar> createState() =>
      _ElementResourceTotalsBarState();
}

class _ElementResourceTotalsBarState extends State<ElementResourceTotalsBar> {
  /// Held rather than rebuilt: this strip sits inside listenables that fire on
  /// every tap boost, and a fresh query stream per build would resubscribe
  /// each time.
  late final Stream<Map<String, int>> _balances = context
      .read<AlchemonsDatabase>()
      .currencyDao
      .watchResourceBalances();

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(widget.theme);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: t.bg2.withValues(alpha: 0.7),
          border: Border(
            top: BorderSide(color: t.borderDim),
            bottom: BorderSide(color: t.borderDim),
          ),
        ),
        child: StreamBuilder<Map<String, int>>(
          stream: _balances,
          builder: (context, snap) {
            final balances = snap.data ?? const <String, int>{};
            return Row(
              children: [
                for (final resource in ElementResources.all)
                  Expanded(
                    child: _ResourceTotal(
                      anchorKey: widget.totalKeys[resource.biomeId],
                      resource: resource,
                      amount: balances[resource.settingsKey] ?? 0,
                      theme: widget.theme,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One element's running total. Swells when it goes up, so an arriving collect
/// visibly lands on something.
class _ResourceTotal extends StatefulWidget {
  const _ResourceTotal({
    required this.resource,
    required this.amount,
    required this.theme,
    this.anchorKey,
  });

  final ElementResource resource;
  final int amount;
  final FactionTheme theme;
  final GlobalKey? anchorKey;

  @override
  State<_ResourceTotal> createState() => _ResourceTotalState();
}

class _ResourceTotalState extends State<_ResourceTotal>
    with SingleTickerProviderStateMixin {
  /// Spans the incoming particles' flight. The balance lands in the database
  /// the instant a collect is pressed, so printing it straight away made the
  /// number jump before the particles it belongs to had left the chamber.
  late final AnimationController _arrive;

  /// What is currently printed, and where the current rise started. Held so a
  /// second collect landing mid-flight counts on from what the player can see
  /// rather than snapping back.
  late int _shown = widget.amount;
  late int _from = widget.amount;

  static const _riseStart = 0.42;

  @override
  void initState() {
    super.initState();
    _arrive = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    );
  }

  @override
  void didUpdateWidget(covariant _ResourceTotal old) {
    super.didUpdateWidget(old);
    if (widget.amount == old.amount) return;
    if (widget.amount > old.amount) {
      // Only a gain celebrates, and it waits for the particles.
      _from = _shown;
      _arrive.forward(from: 0);
    } else {
      // Spending elsewhere in the app should not make this strip perform.
      _arrive.value = 0;
      _shown = widget.amount;
      _from = widget.amount;
    }
  }

  @override
  void dispose() {
    _arrive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(widget.theme);
    return Tooltip(
      message: widget.resource.biomeLabel,
      child: AnimatedBuilder(
        animation: _arrive,
        builder: (context, child) {
          // Nothing moves until the leading particles are most of the way
          // here; then the count runs up and the chip swells with it.
          final rise = Curves.easeOutCubic.transform(
            ((_arrive.value - _riseStart) / (1 - _riseStart)).clamp(0.0, 1.0),
          );
          _shown = (_from + (widget.amount - _from) * rise).round();
          final swell = rise == 0 || rise == 1 ? 0.0 : math.sin(rise * math.pi);
          return Transform.scale(
            scale: 1 + 0.18 * swell,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                child!,
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatResourceTotal(_shown),
                    maxLines: 1,
                    style: TextStyle(
                      color: Color.lerp(
                        _shown > 0 ? t.textPrimary : t.textMuted,
                        widget.resource.color,
                        swell,
                      ),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: Container(
          key: widget.anchorKey,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: ElementResourceGlyph(
            biomeId: widget.resource.biomeId,
            color: widget.resource.color,
            size: 20,
          ),
        ),
      ),
    );
  }
}

/// Five of these share a phone-width row, so past a thousand the count is
/// abbreviated rather than allowed to squeeze its neighbours.
String formatResourceTotal(int amount) {
  if (amount < 1000) return '$amount';
  if (amount < 10000) return '${(amount / 1000).toStringAsFixed(1)}k';
  return '${(amount / 1000).round()}k';
}
