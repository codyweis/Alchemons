import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class CountdownBadge extends StatefulWidget {
  final Duration Function() remaining; // e.g. access.timeUntilReset
  const CountdownBadge({super.key, required this.remaining});

  @override
  State<CountdownBadge> createState() => CountdownBadgeState();
}

class CountdownBadgeState extends State<CountdownBadge> {
  late Duration _left;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _left = widget.remaining();
    _ticker = Ticker((_) {
      final d = widget.remaining();
      if (mounted) setState(() => _left = d);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange[600],
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            _fmt(_left),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
