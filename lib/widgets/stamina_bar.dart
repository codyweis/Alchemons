import 'dart:async';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StaminaBar extends StatelessWidget {
  final int current; // e.g. 2
  final int max; // e.g. 4
  final double size; // width/height of each cell
  final double gap; // spacing between cells
  final Color fillColor;
  final Color emptyColor;
  final BorderRadius radius;

  const StaminaBar({
    super.key,
    required this.current,
    required this.max,
    this.size = 10,
    this.gap = 3,
    this.fillColor = const Color(0xFF22C55E),
    this.emptyColor = const Color(0xFFE5E7EB),
    this.radius = const BorderRadius.all(Radius.circular(3)),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(max, (i) {
        final filled = i < current;
        return Container(
          width: size,
          height: size,
          margin: EdgeInsets.only(right: i == max - 1 ? 0 : gap),
          decoration: BoxDecoration(
            color: filled ? fillColor : emptyColor,
            borderRadius: radius,
            border: Border.all(
              color: filled
                  ? fillColor.withOpacity(0.8)
                  : const Color(0xFFD1D5DB),
              width: 1,
            ),
          ),
        );
      }),
    );
  }
}

class StaminaBadge extends StatefulWidget {
  final String instanceId;
  final bool showCountdown;

  const StaminaBadge({
    super.key,
    required this.instanceId,
    this.showCountdown = true,
  });

  @override
  State<StaminaBadge> createState() => _StaminaBadgeState();
}

class _StaminaBadgeState extends State<StaminaBadge> {
  CreatureInstance? _row;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _refresh();
    // tick every 30s just for countdown freshness (cheap)
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final stamina = context.read<StaminaService>();
    final updated = await stamina.refreshAndGet(widget.instanceId);
    if (!mounted) return;
    setState(() => _row = updated);
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h <= 0 && m <= 0) return 'soon';
    if (h <= 0) return '${m}m';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final row = _row;
    if (row == null) {
      return const SizedBox(
        height: 16,
        width: 60,
        child: LinearProgressIndicator(),
      );
    }

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final regenPerBar = context.read<StaminaService>().regenPerBar;
    final untilNextMs = (row.staminaBars >= row.staminaMax)
        ? 0
        : (row.staminaLastUtcMs + regenPerBar.inMilliseconds) - now;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.local_fire_department, size: 14, color: Colors.green),
        const SizedBox(width: 4),
        StaminaBar(
          current: row.staminaBars,
          max: context.read<StaminaService>().effectiveMaxStamina(row),
          size: 8,
          gap: 2,
        ),
        if (widget.showCountdown) ...[
          const SizedBox(width: 6),
          Text(
            row.staminaBars >= row.staminaMax
                ? 'full'
                : 'next ${_fmt(Duration(milliseconds: untilNextMs.clamp(0, 1 << 31)))}',
            style: TextStyle(
              fontSize: 10,
              color: row.staminaBars >= row.staminaMax
                  ? Colors.green.shade700
                  : Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
