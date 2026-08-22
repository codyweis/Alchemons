// `toMaterialTheme` is handed the AMBIENT text theme — whatever brightness the
// app happens to be in. It used to pass that straight through, so a dark theme
// built while the app was in light mode reported `brightness: dark` and set
// light icons, but every piece of inherited text stayed near-black.
//
// That is what made the constellation screens unreadable in light mode: they
// paint onto a star field, so black text landed on black sky.

import 'package:alchemons/models/faction.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rough perceptual lightness, enough to tell "readable on dark" from "not".
double _luminance(Color c) => c.computeLuminance();

void main() {
  group('a theme tints inherited text to its own brightness', () {
    for (final faction in FactionId.values) {
      test('${faction.name}: dark theme built from a LIGHT text theme', () {
        // The exact situation the bug needed: app in light mode, screen forces
        // dark.
        final ambient = ThemeData.light().textTheme;
        final data = factionThemeFor(
          faction,
          brightness: Brightness.dark,
        ).toMaterialTheme(ambient);

        expect(data.brightness, Brightness.dark);
        for (final style in [
          data.textTheme.bodyMedium,
          data.textTheme.bodyLarge,
          data.textTheme.titleMedium,
        ]) {
          expect(
            _luminance(style!.color!),
            greaterThan(0.4),
            reason: 'dark surfaces need light text, got ${style.color}',
          );
        }
      });

      test('${faction.name}: light theme built from a DARK text theme', () {
        final ambient = ThemeData.dark().textTheme;
        final data = factionThemeFor(
          faction,
          brightness: Brightness.light,
        ).toMaterialTheme(ambient);

        expect(data.brightness, Brightness.light);
        expect(
          _luminance(data.textTheme.bodyMedium!.color!),
          lessThan(0.4),
          reason: 'light surfaces need dark text',
        );
      });
    }
  });

  test('text colour agrees with the icon colour it sits beside', () {
    // These disagreed before: icons took the theme's own text colour while
    // text took the ambient one.
    for (final brightness in Brightness.values) {
      final ambient = brightness == Brightness.dark
          ? ThemeData.light().textTheme
          : ThemeData.dark().textTheme;
      final data = factionThemeFor(
        FactionId.volcanic,
        brightness: brightness,
      ).toMaterialTheme(ambient);

      expect(
        data.textTheme.bodyMedium!.color,
        data.iconTheme.color,
        reason: 'text and icons must be legible against the same surface',
      );
    }
  });

  test('the passed text theme still supplies typography, only colours change', () {
    final ambient = ThemeData.light().textTheme.copyWith(
      bodyMedium: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900),
    );
    final data = factionThemeFor(
      FactionId.oceanic,
      brightness: Brightness.dark,
    ).toMaterialTheme(ambient);

    expect(data.textTheme.bodyMedium!.fontSize, 42);
    expect(data.textTheme.bodyMedium!.fontWeight, FontWeight.w900);
  });
}
