// lib/widgets/creature_detail/forge_tokens.dart
//
// Shared design tokens for the Scorched Forge aesthetic.
// All creature_detail widgets import this instead of using FactionTheme.
//

import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ──────────────────────────────────────────────────────────────────────────────
// COLORS  (instance-based — respects light/dark via ForgeTokens)
// ──────────────────────────────────────────────────────────────────────────────

class FC {
  FC(FactionTheme theme) : _t = ForgeTokens(theme);
  final ForgeTokens _t;

  static FC of(BuildContext context) => FC(context.read<FactionTheme>());

  // Backgrounds
  Color get bg0 => _t.bg0;
  Color get bg1 => _t.bg1;
  Color get bg2 => _t.bg2;
  Color get bg3 => _t.bg3;

  // Accent
  Color get amber => _t.amber;
  Color get amberBright => _t.amberBright;
  Color get amberDim => _t.amberDim;
  Color get amberGlow => _t.amberGlow;

  // Status (game-semantic, fixed)
  Color get teal => _t.teal;
  Color get success => _t.success;
  Color get danger => _t.danger;
  static const purple = Color(0xFF9333EA);
  static const blue = Color(0xFF3B82F6);
  static const orange = Color(0xFFF97316);

  // Text
  Color get textPrimary => _t.textPrimary;
  Color get textSecondary => _t.textSecondary;
  Color get textMuted => _t.textMuted;

  // Borders
  Color get borderDim => _t.borderDim;
  Color get borderMid => _t.borderMid;
  Color get borderAccent => _t.borderAccent;
}

// ──────────────────────────────────────────────────────────────────────────────
// TEXT STYLES  (instance-based — colors pulled from FC instance)
// ──────────────────────────────────────────────────────────────────────────────

class FT {
  FT(this._c);
  final FC _c;

  TextStyle get heading => TextStyle(
    fontFamily: 'monospace',
    color: _c.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.0,
  );

  TextStyle get label => TextStyle(
    fontFamily: 'monospace',
    color: _c.textSecondary,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
  );

  TextStyle get body =>
      TextStyle(color: _c.textSecondary, fontSize: 12, height: 1.5);

  TextStyle get sectionTitle => TextStyle(
    fontFamily: 'monospace',
    color: _c.amberBright,
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.0,
  );

  TextStyle get mono => TextStyle(
    fontFamily: 'monospace',
    color: _c.textPrimary,
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
    final fc = FC.of(context);
    final ft = FT(fc);
    final accent = accentColor ?? fc.amber;
    return Container(
      decoration: BoxDecoration(
        color: fc.bg2,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: fc.borderDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: fc.bg3,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(2),
              ),
              border: Border(bottom: BorderSide(color: fc.borderDim)),
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
                  style: ft.sectionTitle.copyWith(color: accent),
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
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final ft = FT(fc);
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: fc.borderMid)),
        if (label != null) ...[
          const SizedBox(width: 10),
          Text(label!, style: ft.label),
          const SizedBox(width: 10),
        ],
        Expanded(child: Container(height: 1, color: fc.borderMid)),
      ],
    );
  }
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
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(2),
      border: Border.all(color: color.withValues(alpha: 0.45), width: 0.8),
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
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final ft = FT(fc);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label.toUpperCase(), style: ft.label),
          ),
          Expanded(
            child: Text(
              value,
              style: ft.body.copyWith(
                color: valueColor ?? fc.textPrimary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
