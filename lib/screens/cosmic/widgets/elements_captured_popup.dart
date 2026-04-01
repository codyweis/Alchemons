import 'package:flutter/material.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';

String _fmt(num n) {
  final s = n.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0 && s[i] != '-') buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

class ElementsCapturedPopup extends StatelessWidget {
  const ElementsCapturedPopup({
    super.key,
    required this.breakdown,
    required this.onDismiss,
  });

  final Map<String, double> breakdown;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final lost = breakdown.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        alignment: Alignment.center,
        child: GestureDetector(
          // Prevent tap-through to the dismiss backdrop
          onTap: () {},
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              color: const Color(0xF0080D1E),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.25),
                width: 0.9,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.redAccent.withValues(alpha: 0.08),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title row
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SUMMON FAILED',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Elements didn\'t match the recipe',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                if (lost.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                        width: 0.7,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PARTICLES LOST',
                          style: TextStyle(
                            color: Colors.redAccent.withValues(alpha: 0.7),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          children: lost
                              .map((e) => _ElementLossBadge(e: e))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                GestureDetector(
                  onTap: onDismiss,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 0.8,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'UNDERSTOOD',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ElementLossBadge extends StatelessWidget {
  const _ElementLossBadge({required this.e});
  final MapEntry<String, double> e;

  @override
  Widget build(BuildContext context) {
    final c = elementColor(e.key);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.22), width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '${e.key}  ${_fmt(e.value)}',
            style: TextStyle(
              color: c.withValues(alpha: 0.9),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// CUSTOMIZATION MENU OVERLAY
// ─────────────────────────────────────────────────────────
