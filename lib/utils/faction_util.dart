// lib/utils/faction_theme.dart
// Faction-aware Light/Dark theme with helpers + legacy shims.

import 'package:flutter/material.dart';
import 'package:alchemons/models/faction.dart';

class FactionTheme {
  final Brightness brightness;

  final Color primary; // dominant hue for faction
  final Color secondary; // supporting hue
  final Color accent; // bright UI accent
  final Color accentSoft; // low-sat accent for borders/rails

  final Color surface; // main card background
  final Color surfaceAlt; // alt card (chips/pills)
  final Color border; // hairline/border

  final Color text; // primary text
  final Color textMuted; // secondary text

  final List<Color> backgroundGradient; // bg/hero widgets

  const FactionTheme({
    required this.brightness,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.accentSoft,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.backgroundGradient,
  });

  bool get isDark => brightness == Brightness.dark;
}

// ======= Base role colors (separate for Dark/Light) =======

class _Role {
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color accentSoft;

  const _Role(this.primary, this.secondary, this.accent, this.accentSoft);
}

// Dark theme: bright, vivid colors that pop on dark backgrounds
const _darkRoles = <FactionId, _Role>{
  FactionId.fire: _Role(
    Color(0xFFEF5350), // bright red
    Color(0xFFFF7043), // coral
    Color(0xFFFF6E40), // vivid orange-red
    Color(0xFFFFAB91), // soft peach
  ),
  FactionId.water: _Role(
    Color(0xFF64B5F6), // bright blue
    Color(0xFF26C6DA), // cyan
    Color(0xFF54A1C5), // ocean blue
    Color(0xFF9AD7F2), // soft sky
  ),
  FactionId.air: _Role(
    Color(0xFFAECAD6), // muted teal
    Color(0xFFC7E3EA), // pale cyan
    Color(0xFF9FB0B9), // steel blue
    Color(0xFFD7E6EE), // very pale blue
  ),
  FactionId.earth: _Role(
    Color(0xFF7C5F3B), // brown
    Color(0xFF2A8437), // forest green
    Color(0xFF846933), // golden brown
    Color(0xFFC6B28A), // tan
  ),
};

// Light theme: darker, saturated colors for contrast on light backgrounds
const _lightRoles = <FactionId, _Role>{
  FactionId.fire: _Role(
    Color.fromARGB(255, 255, 129, 129), // deep red
    Color(0xFFE64A19), // deep orange
    Color(0xFFFF5722), // vivid deep orange
    Color(0xFFFF8A65), // medium coral
  ),
  FactionId.water: _Role(
    Color(0xFF1976D2), // deep blue
    Color.fromARGB(255, 213, 240, 255), // dark cyan
    Color(0xFF0288D1), // strong blue
    Color(0xFF4FC3F7), // medium sky blue
  ),
  FactionId.air: _Role(
    Color(0xFF546E7A), // dark blue-grey
    Color.fromARGB(255, 0, 0, 0),
    Color(0xFF78909C), // medium blue-grey
    Color(0xFF90A4AE), // light blue-grey
  ),
  FactionId.earth: _Role(
    Color(0xFF5D4037), // deep brown
    Color(0xFF388E3C), // deep green
    Color(0xFF6D4C41), // rich brown
    Color(0xFF8D6E63), // medium brown
  ),
};

// Defaults for "unknown" / null faction
const _defaultDarkRole = _Role(
  Color(0xFF8E9AF7),
  Color(0xFFB388FF),
  Color(0xFF7C86FF),
  Color(0xFFB3BBFF),
);

const _defaultLightRole = _Role(
  Color(0xFF5E35B1), // deep purple
  Color(0xFF7B1FA2), // deep purple-pink
  Color(0xFF6A1B9A), // vivid purple
  Color(0xFF9C27B0), // medium purple
);

// ======= System neutrals for Dark / Light =======

const _darkText = Color(0xFFE8EAED);
const _darkMuted = Color(0xFFB6C0CC);
const _darkSurface = Color(0xFF111422);
const _darkSurfaceAlt = Color(0xFF0E1120);
const _darkBorder = Color(0x1AFFFFFF);

const _lightText = Color(0xFF0F1221);
const _lightMuted = Color(0xFF4B5563);
const _lightSurface = Color(0xFFF6F7FB);
const _lightSurfaceAlt = Color(0xFFFFFFFF);
const _lightBorder = Color(0x14000000); // ~8% black

// ======= Gradients per faction (Dark / Light) =======

Map<FactionId?, List<Color>> _darkGrad = {
  null: const [Color(0xFF0A0E27), Color(0xFF111638), Color(0xFF171C44)],
  FactionId.fire: const [
    Color(0xFF1A0D0D),
    Color(0xFF2A0E12),
    Color(0xFF3A1712),
  ],
  FactionId.water: const [
    Color(0xFF0A0E27),
    Color(0xFF0B1D3A),
    Color(0xFF0C2A4A),
  ],
  FactionId.air: const [
    Color(0xFF0E1720),
    Color(0xFF0F1C24),
    Color(0xFF12242B),
  ],
  FactionId.earth: const [
    Color(0xFF0F120D),
    Color(0xFF141A12),
    Color(0xFF1A2416),
  ],
};

Map<FactionId?, List<Color>> _lightGrad = {
  null: const [Color(0xFFE8ECFF), Color(0xFFDCE3FF), Color(0xFFD0D9FF)],
  FactionId.fire: const [
    Color(0xFFFFE5E5), // warm peachy-pink
    Color(0xFFFFD6D6), // deeper warm pink
    Color(0xFFFFC7C7), // rich coral-pink
  ],
  FactionId.water: const [
    Color(0xFFD6EBFF), // vibrant sky blue
    Color(0xFFC2E0FF), // deeper sky
    Color(0xFFADD4FF), // rich blue
  ],
  FactionId.air: const [
    Color(0xFFE1F1F7), // soft cyan-white
    Color(0xFFD2E8F2), // deeper cyan
    Color(0xFFC3DFED), // rich cyan-grey
  ],
  FactionId.earth: const [
    Color(0xFFF0EBE0), // warm cream
    Color(0xFFE8E0D0), // deeper cream
    Color(0xFFDFD5C0), // rich tan
  ],
};

// ======= Public factory (Light or Dark) =======

FactionTheme factionThemeFor(
  FactionId? id, {
  Brightness brightness = Brightness.dark,
}) {
  // Pick the right role set based on brightness
  final role = brightness == Brightness.dark
      ? (id == null ? _defaultDarkRole : _darkRoles[id] ?? _defaultDarkRole)
      : (id == null ? _defaultLightRole : _lightRoles[id] ?? _defaultLightRole);

  if (brightness == Brightness.dark) {
    // Custom dark overrides you had for Fire/Earth surfaces preserved
    final surface = switch (id) {
      FactionId.fire => const Color.fromARGB(255, 18, 12, 12),
      FactionId.earth => const Color.fromARGB(255, 9, 14, 8),
      _ => _darkSurface,
    };
    final surfaceAlt = switch (id) {
      FactionId.fire => const Color.fromARGB(255, 25, 11, 11),
      FactionId.earth => const Color.fromARGB(141, 9, 12, 8),
      FactionId.water => const Color.fromARGB(112, 14, 17, 32),
      FactionId.air => const Color.fromARGB(111, 61, 72, 95),
      _ => _darkSurfaceAlt,
    };

    return FactionTheme(
      brightness: Brightness.dark,
      primary: role.primary,
      secondary: role.secondary,
      accent: role.accent,
      accentSoft: role.accentSoft,
      surface: surface,
      surfaceAlt: surfaceAlt,
      border: _darkBorder,
      text: _darkText,
      textMuted: _darkMuted,
      backgroundGradient: _darkGrad[id] ?? _darkGrad[null]!,
    );
  } else {
    // Light scheme with faction-tinted surfaces
    final surface = switch (id) {
      FactionId.fire => const Color(0xFFFFF5F5), // warm pink-white
      FactionId.water => const Color(0xFFF0F9FF), // cool blue-white
      FactionId.air => const Color(0xFFF5FAFE), // airy cyan-white
      FactionId.earth => const Color(0xFFFAF8F3), // warm beige-white
      _ => _lightSurface, // neutral fallback
    };
    final surfaceAlt = switch (id) {
      FactionId.fire => const Color(0xFFFFEBEB), // slightly deeper warm
      FactionId.water => const Color(0xFFE6F4FF), // slightly deeper cool
      FactionId.air => const Color(0xFFEBF7FD), // slightly deeper airy
      FactionId.earth => const Color.fromARGB(
        173,
        245,
        242,
        234,
      ), // slightly deeper earth
      _ => _lightSurfaceAlt, // neutral fallback
    };

    return FactionTheme(
      brightness: Brightness.light,
      primary: role.primary,
      secondary: role.secondary,
      accent: role.accent,
      accentSoft: role.accentSoft,
      surface: surface,
      surfaceAlt: surfaceAlt,
      border: _lightBorder,
      text: _lightText,
      textMuted: _lightMuted,
      backgroundGradient: _lightGrad[id] ?? _lightGrad[null]!,
    );
  }
}

// ======= Legacy shims (back-compat) =======

(Color, Color, Color) getFactionColors(FactionId? factionId) {
  final t = factionThemeFor(factionId); // defaults to Dark
  return (t.primary, t.secondary, t.accent);
}

Color accentForFaction(FactionId f) => factionThemeFor(f).accent;

// ======= UI helpers =======

extension FactionThemeX on FactionTheme {
  Color get meterTrack =>
      isDark ? const Color(0xFF1A1E31) : const Color(0xFFE7EAF5);
  List<Color> get meterFill => [
    accent.withOpacity(isDark ? 0.35 : 0.25),
    accent,
  ];

  // Card styles for GameCard etc.
  BoxDecoration cardDecoration({required Color rim}) => BoxDecoration(
    color: surfaceAlt,
    borderRadius: BorderRadius.circular(5),

    boxShadow: [
      if (isDark)
        BoxShadow(
          color: Colors.black.withOpacity(0.45),
          blurRadius: 22,
          offset: const Offset(0, 12),
        ),
      BoxShadow(
        color: rim.withOpacity(isDark ? 0.14 : 0.10),
        blurRadius: 26,
        spreadRadius: 1,
      ),
    ],
  );

  // Chip / pill
  BoxDecoration chipDecoration({required Color rim}) => BoxDecoration(
    color: surfaceAlt,
    borderRadius: BorderRadius.circular(5),
    boxShadow: [
      BoxShadow(color: rim.withOpacity(isDark ? 0.16 : 0.12), blurRadius: 18),
    ],
  );
}

// ======= Material ThemeData helper (optional) =======
// Use this to build your app ThemeData from FactionTheme.
// Example:
// final t = context.watch<FactionTheme>();
// final themeData = t.toMaterialTheme(GoogleFonts.aBeeZeeTextTheme(Theme.of(context).textTheme));

extension FactionMaterialTheme on FactionTheme {
  ThemeData toMaterialTheme(TextTheme textTheme) {
    final base = isDark ? ThemeData.dark() : ThemeData.light();
    final scheme = isDark
        ? ColorScheme.dark(
            primary: accent,
            secondary: secondary,
            surface: surface,
            onPrimary: Colors.black,
            onSecondary: Colors.black,
            onSurface: text,
          )
        : ColorScheme.light(
            primary: accent,
            secondary: secondary,
            surface: surface,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: text,
          );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF0A0E27)
          : const Color(0xFFF7F8FC),
      cardColor: surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation: 0,
      ),
      dividerColor: border,
      iconTheme: IconThemeData(color: text),
      dialogTheme: DialogThemeData(backgroundColor: surface),
    );
  }
}
