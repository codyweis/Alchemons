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
  };

  static Color of(String key) =>
      _map[key] ?? Colors.grey.shade500.withOpacity(.5);
}
