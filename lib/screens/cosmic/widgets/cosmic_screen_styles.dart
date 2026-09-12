import 'package:flutter/material.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/widgets/app_icons.dart';

class CosmicScreenStyles {
  // Black, not brown — and now with the contrast to match.
  //
  // The first pass fixed the ground: bg2/bg3 carried a warm cast (171511 and
  // 201D17 are brown, not grey), so every panel sat on a muddy yellow and
  // amber ink on brown is the lowest-contrast pairing in the app. That was
  // right, but it left the INK alone, and the ink was the other half of the
  // problem: body copy at B5A98A over a 121212 ground is parchment a few
  // stops above its own background, which reads as faded rather than as
  // atmospheric, and borders ended up doing the work contrast should do.
  //
  // These now match the survival surge panel, which is where the treatment was
  // worked out — one set of tokens across nineteen files, so the dialogs
  // cannot drift apart again.
  static const bg0 = Color(0xFF050507);
  static const bg1 = Color(0xFF0B0B10);
  static const bg2 = Color(0xFF14141B);
  static const bg3 = Color(0xFF1F1F28);
  static const amber = Color(0xFFD9B368);
  static const amberBright = Color(0xFFF2C96F);
  static const amberGlow = Color(0xFFFBE4A4);
  static const teal = Color(0xFF5BC8E8);
  static const astralShardIcon = AppIcons.diamond_rounded;
  static const astralShardColor = Color(0xFFAB47BC);
  static const textPrimary = Color(0xFFF4EEDF);
  static const textSecondary = Color(0xFFC8BFA8);
  static const textMuted = Color(0xFF8A8296);
  static const danger = Color(0xFFFF5A57);
  static const success = Color(0xFF3FDE8A);
  static const borderDim = Color(0xFF2B2B36);
  static const borderMid = Color(0xFF4A4658);
  static const borderAccent = Color(0xFF8A7345);
}

// ─────────────────────────────────────────────────────────
// SHIP MENU OVERLAY
// ─────────────────────────────────────────────────────────

/// Element colours are tuned for planets against a starfield. Several of them —
/// Dark (#4A148C), Mud (#5D4037), Earth (#795548), Spirit (#3F51B5) — are close
/// to invisible as small text or hairline borders on the panel chrome, which is
/// near-black. Lift toward white before using an element colour as UI ink.
///
/// The portal painter does the same thing for the same reason.
Color elementInk(String element) {
  // Lerping toward white washes a saturated element out while still leaving a
  // dark one dark — Dark (#4A148C) at 32% white is still too dim to read as
  // small text. Raising lightness with the hue intact fixes both ends: the
  // vivid elements keep their colour and the murky ones actually lift.
  final hsl = HSLColor.fromColor(elementColor(element));
  return hsl
      .withSaturation(hsl.saturation.clamp(0.42, 1.0))
      .withLightness(hsl.lightness.clamp(0.62, 0.82))
      .toColor();
}

/// Whether a stored key is an element the game still knows about.
///
/// Saves can carry keys from builds where the element list was different, and
/// `elementColor` renders anything unknown as flat grey — so it shows up as a
/// real-looking resource with no colour. Filter storage listings through this.
bool isKnownElement(String key) => kElementColors.containsKey(key);
