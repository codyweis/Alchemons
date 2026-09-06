import 'package:flutter/material.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/widgets/app_icons.dart';

class CosmicScreenStyles {
  static const bg0 = Color(0xFF080808);
  static const bg1 = Color(0xFF111111);
  static const bg2 = Color(0xFF171511);
  static const bg3 = Color(0xFF201D17);
  static const amber = Color(0xFFC4A35A);
  static const amberBright = Color(0xFFE4C16A);
  static const amberGlow = Color(0xFFF1D78A);
  static const teal = Color(0xFF5BC8E8);
  static const astralShardIcon = AppIcons.diamond_rounded;
  static const astralShardColor = Color(0xFFAB47BC);
  static const textPrimary = Color(0xFFE8DFC8);
  static const textSecondary = Color(0xFFB5A98A);
  static const textMuted = Color(0xFF6B6050);
  static const danger = Color(0xFFC0392B);
  static const success = Color(0xFF22C55E);
  static const borderDim = Color(0xFF2E2A23);
  static const borderMid = Color(0xFF4A4032);
  static const borderAccent = Color(0xFF74613A);
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
Color elementInk(String element) =>
    Color.lerp(elementColor(element), Colors.white, 0.32)!;

/// Whether a stored key is an element the game still knows about.
///
/// Saves can carry keys from builds where the element list was different, and
/// `elementColor` renders anything unknown as flat grey — so it shows up as a
/// real-looking resource with no colour. Filter storage listings through this.
bool isKnownElement(String key) => kElementColors.containsKey(key);
