import 'package:alchemons/audio/audio.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';

String _fmt(num n) {
  final s = n.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0 && s[i] != '-') buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// A gate offering that did not match its recipe: what was lost, plainly.
/// (It read RESONANCE MISALIGNED … PARTICLES DISPERSED … RECALIBRATE on a
/// navy card with an amber glow until 2026-10.)
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
    const palette = BracketPalette.dark;
    final lost = breakdown.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return GestureDetector(
      onTap: context.soundAction(onDismiss),
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        alignment: Alignment.center,
        child: GestureDetector(
          // Prevent tap-through to the dismiss backdrop
          onTap: () {},
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            color: palette.bg1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'THE GATE DID NOT TAKE IT',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: palette.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'The elements you brought did not match its recipe, and '
                  'they are gone.',
                  style: bracketText(
                    context,
                    14,
                    palette.ink.withValues(alpha: 0.9),
                  ),
                ),
                if (lost.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const BracketSectionDivider(label: 'LOST'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      for (final e in lost)
                        Text(
                          '${e.key}  ${_fmt(e.value)}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: elementColor(e.key).withValues(alpha: 0.9),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                BracketButton(
                  label: 'CONTINUE',
                  height: 42,
                  palette: palette,
                  accent: kLeaveQuietAccent,
                  onTap: onDismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// CUSTOMIZATION MENU OVERLAY
// ─────────────────────────────────────────────────────────
