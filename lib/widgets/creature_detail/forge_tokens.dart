// lib/widgets/creature_detail/forge_tokens.dart
//
// Shared design tokens for the Scorched Forge aesthetic.
// All creature_detail widgets import this instead of using FactionTheme.
//

import 'package:flutter/material.dart';

// ──────────────────────────────────────────────────────────────────────────────
// COLORS
// ──────────────────────────────────────────────────────────────────────────────

class FC {
  static const bg0 = Color(0xFF080A0E);
  static const bg1 = Color(0xFF0E1117);
  static const bg2 = Color(0xFF141820);
  static const bg3 = Color(0xFF1C2230);

  static const amber = Color(0xFFD97706);
  static const amberBright = Color(0xFFF59E0B);
  static const amberDim = Color(0xFF92400E);
  static const amberGlow = Color(0xFFFFB020);

  static const teal = Color(0xFF0EA5E9);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFC0392B);
  static const purple = Color(0xFF9333EA);
  static const blue = Color(0xFF3B82F6);
  static const orange = Color(0xFFF97316);

  static const textPrimary = Color(0xFFE8DCC8);
  static const textSecondary = Color(0xFF8A7B6A);
  static const textMuted = Color(0xFF4A3F35);

  static const borderDim = Color(0xFF252D3A);
  static const borderMid = Color(0xFF3A3020);
  static const borderAccent = Color(0xFF6B4C20);
}

// ──────────────────────────────────────────────────────────────────────────────
// TEXT STYLES
// ──────────────────────────────────────────────────────────────────────────────

class FT {
  static const heading = TextStyle(
    fontFamily: 'monospace',
    color: FC.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.0,
  );

  static const label = TextStyle(
    fontFamily: 'monospace',
    color: FC.textSecondary,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
  );

  static const body = TextStyle(
    color: FC.textSecondary,
    fontSize: 12,
    height: 1.5,
  );

  static const sectionTitle = TextStyle(
    fontFamily: 'monospace',
    color: FC.amberBright,
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.0,
  );

  static const mono = TextStyle(
    fontFamily: 'monospace',
    color: FC.textPrimary,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// SHARED MICRO WIDGETS
// ──────────────────────────────────────────────────────────────────────────────

/// Forge-style section block with etched header (public, reusable)
class ForgeSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Color? accentColor;

  const ForgeSection({
    super.key,
    required this.title,
    required this.child,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? FC.amber;
    return Container(
      decoration: BoxDecoration(
        color: FC.bg2,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: FC.borderDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: FC.bg3,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(2),
              ),
              border: const Border(bottom: BorderSide(color: FC.borderDim)),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 10,
                  color: accent,
                  margin: const EdgeInsets.only(right: 8),
                ),
                Text(
                  title.toUpperCase(),
                  style: FT.sectionTitle.copyWith(color: accent),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }
}

/// Etched divider with optional label
class ForgeEtchedDivider extends StatelessWidget {
  final String? label;
  const ForgeEtchedDivider({super.key, this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Container(height: 1, color: FC.borderMid)),
      if (label != null) ...[
        const SizedBox(width: 10),
        Text(label!, style: FT.label),
        const SizedBox(width: 10),
      ],
      Expanded(child: Container(height: 1, color: FC.borderMid)),
    ],
  );
}

/// Lozenge badge
class ForgeTagBadge extends StatelessWidget {
  final String label;
  final Color color;
  const ForgeTagBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(2),
      border: Border.all(color: color.withOpacity(0.45), width: 0.8),
    ),
    child: Text(
      label.toUpperCase(),
      style: TextStyle(
        fontFamily: 'monospace',
        color: color,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    ),
  );
}

/// Label + value data row
class ForgeDataRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const ForgeDataRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 130, child: Text(label.toUpperCase(), style: FT.label)),
        Expanded(
          child: Text(
            value,
            style: FT.body.copyWith(
              color: valueColor ?? FC.textPrimary,
              fontSize: 11,
            ),
          ),
        ),
      ],
    ),
  );
}
