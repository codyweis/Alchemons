// lib/widgets/game_card.dart
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';

class GameCard extends StatelessWidget {
  final Widget child;

  /// Preferred: pass the full theme so card styling is always in sync.
  final FactionTheme? theme;

  /// Back-compat: if you still pass an accent color, we’ll use it for the rim.
  final Color? accent;

  final EdgeInsets padding;

  const GameCard({
    super.key,
    required this.child,
    this.theme,
    this.accent,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    // Rim color: theme.accent → explicit accent → reasonable default.
    final Color rim = theme?.accent ?? accent ?? const Color(0xFF7C86FF);

    if (theme != null) {
      // Theme-driven decoration
      return Container(
        decoration: theme!.cardDecoration(rim: rim),
        padding: padding,
        child: child,
      );
    }

    // Fallback decoration (when you haven’t passed a theme yet)
    // Matches the defaults used inside FactionTheme.cardDecoration.
    const fallbackSurface = Color(0xFF111422);
    return Container(
      decoration: BoxDecoration(
        color: theme?.surface ?? fallbackSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
          BoxShadow(
            color: rim.withOpacity(0.14),
            blurRadius: 26,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
  }
}
