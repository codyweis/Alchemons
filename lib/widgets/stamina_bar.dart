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
  late final Stream<DateTime> _ticker;

  @override
  void initState() {
    super.initState();
    // Tick once per second
    _ticker = Stream.periodic(
      const Duration(seconds: 1),
      (_) => DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    final stamina = context.read<StaminaService>();

    return StreamBuilder<CreatureInstance?>(
      stream: db.creatureDao.watchInstanceById(widget.instanceId),
      builder: (context, instSnap) {
        final row = instSnap.data;
        if (row == null) return _empty;

        return StreamBuilder<DateTime>(
          stream: _ticker,
          builder: (_, __) {
            final state = stamina.computeState(row);
            return _buildUi(state);
          },
        );
      },
    );
  }

  Widget get _empty => const SizedBox(width: 60, height: 16);

  Widget _buildUi(StaminaState state) {
    String countdown = 'full';
    if (state.bars < state.max && widget.showCountdown) {
      final now = DateTime.now().toUtc();
      final next = state.nextTickUtc ?? now;
      final diff = next.difference(now);
      final m = diff.inMinutes.remainder(60);
      final h = diff.inHours;

      countdown = h > 0 ? '${h}h ${m}m' : '${m}m';
      if (diff.isNegative) countdown = 'soon';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.local_fire_department, size: 14, color: Colors.green),
        const SizedBox(width: 4),
        StaminaBar(current: state.bars, max: state.max, size: 8, gap: 2),
        if (widget.showCountdown) ...[
          const SizedBox(width: 6),
          Text(
            countdown,
            style: TextStyle(
              fontSize: 10,
              color: state.bars >= state.max
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
