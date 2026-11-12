import 'dart:math' as math;

import 'package:flutter/material.dart';

class FamilyColors {
  // === Canonical families ===
  static const Map<String, String> _nameToCode = {
    'Let': 'LET',
    'Horn': 'HOR',
    'Kin': 'KIN',
    'Mane': 'MAN',
    'Mask': 'MSK',
    'Pip': 'PIP',
    'Wing': 'WNG',
    'Mystic': 'MYS',
  };
  static const Map<String, String> _codeToName = {
    'LET': 'Let',
    'HOR': 'Horn',
    'KIN': 'Kin',
    'MAN': 'Mane',
    'MSK': 'Mask',
    'PIP': 'Pip',
    'WNG': 'Wing',
    'MYS': 'Mystic',
  };

  // Pick clear, distinct colors that read well on dark UI.
  // Tweak to taste.
  static const Map<String, Color> _codeToColor = {
    'LET': Color(0xFF93C5FD), // soft sky
    'HOR': Color(0xFFEAB308), // amber
    'KIN': Color(0xFF34D399), // green
    'MAN': Color(0xFFF97316), // orange
    'MSK': Color(0xFFA78BFA), // violet
    'PIP': Color(0xFF6EE7B7), // mint
    'WNG': Color(0xFFFCA5A5), // rose
    'MYS': Color(0xFF60A5FA), // blue
  };

  /// Pretty label for any raw key ('Let' | 'LET' | 'CreatureFamily.Let' | etc).
  static String label(String raw) {
    final code = _canonCode(raw);
    return _codeToName[code] ?? _titleCase(_trimEnumPrefix(raw));
  }

  /// Color for any raw key; unknowns get a deterministic fallback.
  static Color of(String raw) {
    final code = _canonCode(raw);
    return _codeToColor[code] ?? _seedColor(code);
  }

  /// Canonical 3-letter code for any raw key; 'UNK' if unknown.
  static String code(String raw) => _canonCode(raw);

  // ---- internals ----

  static String _canonCode(String raw) {
    final s = _trimEnumPrefix(raw).trim();
    if (s.isEmpty) return 'UNK';

    // Direct code?
    final up = s.toUpperCase();
    if (_codeToName.containsKey(up)) return up;

    // Named form? (Let/Horn/…)
    final named = _titleCase(s);
    final code = _nameToCode[named];
    if (code != null) return code;

    return 'UNK';
  }

  static String _trimEnumPrefix(String s) {
    // Handles 'CreatureFamily.Let' → 'Let'
    final i = s.indexOf('.');
    return (i >= 0 && i + 1 < s.length) ? s.substring(i + 1) : s;
  }

  static String _titleCase(String s) {
    if (s.isEmpty) return s;
    final parts = s.split(RegExp(r'[_\-\s]+')).where((p) => p.isNotEmpty);
    return parts
        .map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase())
        .join(' ');
  }

  // Deterministic fallback color so unknown families still look nice.
  static Color _seedColor(String key) {
    int hash = 0;
    for (final r in key.codeUnits) {
      hash = (hash * 31 + r) & 0x7FFFFFFF;
    }
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.55, 0.55).toColor();
  }
}

class FactionColors {
  static const Map<String, Color> _map = {
    // Warm red-orange, less intense
    'Volcanic': Color(0xFFFF9999), // Was 0xFFF87171 (too saturated)
    // Cool blue, slightly softer
    'Oceanic': Color(
      0xFF7CB3FF,
    ), // Was 0xFF60A5FA (good, made slightly lighter)
    // Green is already pretty good, maybe slightly more saturated
    'Verdant': Color(
      0xFF9DD9B3,
    ), // Was (157, 210, 177) - similar but hex format
    // Warmer brown, less muddy
    'Earthen': Color(0xFFD4A574), // Was (195, 139, 82) - lighter, warmer

    'Arcane': Color.fromARGB(
      255,
      255,
      116,
      250,
    ), // Was 0xFFFDE68A (slightly more saturated)
    'Bloodborn': Color(0xFFFF5252),
    'bloodborn': Color(0xFFFF5252),
  };

  static Color of(String key) =>
      _map[key] ?? Colors.grey.shade500.withValues(alpha: .5);
}

/// A creature's tint gene as a 4x5 colour matrix: [saturation] moves its
/// colours away from (over 1) or toward (under 1) their own grey, their
/// light and shade kept, and [brightness] then scales the lot. So a Vibrant
/// one is richer, never just brighter — a pale creature keeps its face —
/// and a Pale one is washed out, not dimmed.
///
/// A strong boost (Vibrant) also lifts the darks a little first, the lights
/// left where they are: a near-black creature has almost no colour to
/// enrich, and the lift gives the boost something to work on.
List<double> tintGeneMatrix(double brightness, double saturation) {
  const lr = 0.299, lg = 0.587, lb = 0.114;
  // Pale is lifted too, and further: washed toward white, so even a
  // near-black creature goes ashen.
  final lift = saturation > 1.3
      ? kVibrantDarkLift
      : saturation < 0.6
      ? kPaleLift
      : 0.0;
  final s = saturation, b = brightness * (1 - lift), k = 1 - s;
  final t = brightness * 255 * lift;
  return <double>[
    b * (k * lr + s), b * k * lg, b * k * lb, 0, t, //
    b * k * lr, b * (k * lg + s), b * k * lb, 0, t,
    b * k * lr, b * k * lg, b * (k * lb + s), 0, t,
    0, 0, 0, 1, 0,
  ];
}

/// How far a Vibrant creature's darkest tones are raised toward white.
const double kVibrantDarkLift = 0.09;

/// How far a Pale creature's tones are washed toward white.
const double kPaleLift = 0.14;

/// The hue shift a Warm or a Cool creature carries ([hueFromGenes]), in
/// degrees round the wheel as every sprite pipeline is handed it.
const double kWarmHueDeg = 15, kCoolHueDeg = 345;

/// A creature's hue shift of [degrees] as a 4x5 colour matrix. Warm and Cool
/// ([kWarmHueDeg], [kCoolHueDeg]) are not turns of the wheel but a change of
/// light: Warm leans every colour toward amber, Cool toward blue. (A turn
/// warms only the reds: it sent a yellow or a green creature greener for
/// Warm, and yellower for Cool.) Any other angle — a prismatic creature's —
/// is the turn it says.
List<double> hueShiftMatrix(double degrees) {
  if (degrees == kWarmHueDeg) {
    return const <double>[
      1.14, 0.06, 0, 0, 0, //
      0, 1.0, 0, 0, 0,
      0, 0, 0.68, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }
  if (degrees == kCoolHueDeg) {
    return const <double>[
      0.74, 0, 0, 0, 0, //
      0, 0.95, 0.05, 0, 0,
      0, 0.08, 1.18, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }
  final radians = degrees * (math.pi / 180.0);
  final c = math.cos(radians), s = math.sin(radians);
  return <double>[
    0.213 + c * 0.787 - s * 0.213,
    0.715 - c * 0.715 - s * 0.715,
    0.072 - c * 0.072 + s * 0.928,
    0,
    0,
    0.213 - c * 0.213 + s * 0.143,
    0.715 + c * 0.285 + s * 0.140,
    0.072 - c * 0.072 - s * 0.283,
    0,
    0,
    0.213 - c * 0.213 - s * 0.787,
    0.715 - c * 0.715 + s * 0.715,
    0.072 + c * 0.928 + s * 0.072,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}
