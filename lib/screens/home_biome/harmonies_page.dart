// lib/screens/home_biome/harmonies_page.dart
//
// The journal's page of harmonies found in the home biome (models/
// home_secrets.dart): each pair of elements whose fusion makes something,
// in the recipe table's order. Those found show the two elements and what
// they make; the rest are blank places in the list, so the page says how
// many there are without saying what. It only appears in the journal once
// the first has been found.

import 'package:alchemons/games/cosmic/cosmic_data.dart' show elementColor;
import 'package:alchemons/models/home_secrets.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';

class HarmoniesPage extends StatelessWidget {
  const HarmoniesPage({super.key, required this.found});

  /// Harmonies found, by key ('Fire+Water').
  final Set<String> found;

  static Future<void> open(BuildContext context, Set<String> found) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => HarmoniesPage(found: found)),
      );

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    final all = kHarmonies.entries.toList();
    final count = all.where((e) => found.contains(e.key)).length;
    return Scaffold(
      backgroundColor: palette.bg0,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 18, 4),
              child: Row(
                children: [
                  BracketIconButton(
                    icon: AppIcons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(),
                    palette: palette,
                    size: 42,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Harmonies',
                    style: bracketText(context, 24, palette.ink),
                  ),
                  const Spacer(),
                  Text(
                    '$count / ${all.length}',
                    style: bracketText(
                      context,
                      13,
                      palette.muted,
                      weight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
                itemCount: all.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final e = all[i];
                  return found.contains(e.key)
                      ? _FoundRow(pair: e.key, makes: e.value)
                      : const _BlankRow();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoundRow extends StatelessWidget {
  const _FoundRow({required this.pair, required this.makes});

  final String pair, makes;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    final parts = pair.split('+');
    Widget element(String name) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Bead(color: elementColor(name)),
        const SizedBox(width: 7),
        Text(
          name.toUpperCase(),
          style: bracketText(
            context,
            12,
            palette.ink,
            weight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
    final dim = bracketText(context, 12, palette.muted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      color: palette.surfaceFill(),
      child: Row(
        children: [
          element(parts[0]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('+', style: dim),
          ),
          element(parts[1]),
          const Spacer(),
          Text('=', style: dim),
          const SizedBox(width: 10),
          element(makes),
        ],
      ),
    );
  }
}

class _BlankRow extends StatelessWidget {
  const _BlankRow();

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    return Container(
      height: 40,
      color: palette.surfaceFill().withValues(alpha: 0.35),
    );
  }
}

/// An element's color as a small lit bead.
class _Bead extends StatelessWidget {
  const _Bead({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 11,
    height: 11,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        center: const Alignment(-0.3, -0.35),
        colors: [
          Color.lerp(color, Colors.white, 0.55)!,
          color,
          Color.lerp(color, Colors.black, 0.5)!,
        ],
        stops: const [0, 0.5, 1],
      ),
    ),
  );
}
