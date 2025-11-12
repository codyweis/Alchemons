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

class StaminaBadge extends StatelessWidget {
  final String instanceId;
  final bool showCountdown;

  const StaminaBadge({
    super.key,
    required this.instanceId,
    this.showCountdown = true,
  });

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h <= 0 && m <= 0) return 'soon';
    if (h <= 0) return '${m}m';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    final stamina = context.read<StaminaService>();

    return StreamBuilder<CreatureInstance?>(
      stream: db.creatureDao.watchInstanceById(instanceId),
      builder: (context, snapshot) {
        final row = snapshot.data;

        if (row == null) {
          return const SizedBox(
            height: 16,
            width: 60,
            child: SizedBox.shrink(),
          );
        }

        final now = DateTime.now().toUtc().millisecondsSinceEpoch;
        final maxStamina = stamina.effectiveMaxStamina(row);

        // Calculate time until next bar
        final regenPerBar = stamina.regenPerBar;
        final untilNextMs = (row.staminaBars >= maxStamina)
            ? 0
            : (row.staminaLastUtcMs + regenPerBar.inMilliseconds) - now;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_fire_department,
              size: 14,
              color: Colors.green,
            ),
            const SizedBox(width: 4),
            StaminaBar(
              current: row.staminaBars,
              max: maxStamina,
              size: 8,
              gap: 2,
            ),
            if (showCountdown) ...[
              const SizedBox(width: 6),
              Text(
                row.staminaBars >= maxStamina
                    ? 'full'
                    : '${_fmt(Duration(milliseconds: untilNextMs.clamp(0, 1 << 31)))}',
                style: TextStyle(
                  fontSize: 10,
                  color: row.staminaBars >= maxStamina
                      ? Colors.green.shade700
                      : Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
