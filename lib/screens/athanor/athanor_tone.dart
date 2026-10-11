// lib/screens/athanor/athanor_tone.dart
//
// The Athanor's colors and words: the ink-black and pale brass the rest of
// the game wears, the furnace's own fire, and the tincture (the alchemist's
// red, a warm vermilion so it never reads as gold or as blood).

import 'package:alchemons/models/athanor.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';

abstract final class AthanorTone {
  static const BracketPalette palette = BracketPalette.dark;

  static const Color void0 = Color(0xFF060507);
  static const Color void1 = Color(0xFF0C0B0E);
  static const Color parchment = Color(0xFFE6E2DA);
  static const Color parchmentDim = Color(0xFFB4AEA3);
  static const Color muted = Color(0xFF8E8C88);
  static const Color ash = Color(0xFF5A5852);

  static const Color brass = Color(0xFFCDB07A);
  static const Color brassDeep = Color(0xFF6B5A36);
  static const Color brassGlow = Color(0xFFE2C98F);

  /// The tincture: a pour's color, and its balance.
  static const Color tincture = Color(0xFFD8644A);
  static const Color tinctureDeep = Color(0xFF5E1E14);
  static const Color tinctureBright = Color(0xFFF4A585);

  /// The tincture as grains in glass: deeper, so its lit grains stay red.
  static const Color tinctureGrain = Color(0xFFC4452E);

  /// A gold pour's grains.
  static const Color gold = Color(0xFFE4C16A);

  /// The fire in the furnace's mouth, darkest first.
  /// The fire's own light: the furnace's crown at rest.
  static const Color ember = Color(0xFFE0822E);

  static const List<Color> fire = [
    Color(0xFF2A0D05),
    Color(0xFF6E260C),
    Color(0xFFB04A16),
    Color(0xFFE0822E),
    Color(0xFFF6B85A),
    Color(0xFFFFE3A8),
  ];

  /// What a pour is made of, by how it is paid for.
  static Color pourColor(bool gold) => gold ? AthanorTone.gold : tinctureGrain;

  static Color rarity(AthanorRarity r) => switch (r) {
    AthanorRarity.common => const Color(0xFFB9B2A4),
    AthanorRarity.rare => const Color(0xFF86AEDB),
    AthanorRarity.epic => const Color(0xFFBC92EC),
  };

  /// The capstone's color: the brass, lit.
  static const Color capstone = brassGlow;
}

/// Small capitals: overlines, counts, button words.
TextStyle athanorMono(
  double size,
  Color color, {
  double spacing = 1.8,
  FontWeight weight = FontWeight.w800,
}) => TextStyle(
  fontFamily: 'monospace',
  color: color,
  fontSize: size,
  fontWeight: weight,
  letterSpacing: spacing,
  height: 1.25,
);

/// A piece's name.
TextStyle athanorName(BuildContext context, double size, {Color? color}) =>
    (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
      color: color ?? AthanorTone.parchment,
      fontSize: size,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      height: 1.1,
    );

/// Plain sentences.
TextStyle athanorBody(BuildContext context, {Color? color, double size = 13}) =>
    (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
      color: color ?? AthanorTone.parchmentDim,
      fontSize: size,
      height: 1.4,
    );

/// 0.1234 → "12.3%".
String athanorPercent(double chance) => '${(chance * 100).toStringAsFixed(1)}%';

/// How long until the next UTC day, when the free pour comes back.
Duration athanorUntilNextDay(DateTime now) {
  final u = now.toUtc();
  final next = DateTime.utc(u.year, u.month, u.day + 1);
  return next.difference(u) + const Duration(seconds: 1);
}
