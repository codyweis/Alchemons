// lib/screens/database_dialogs.dart
//
// The Alchemon Database's two dialogs: its first-visit tutorial, and the card
// for a species not yet discovered. Both in the bracket confirm's frame
// (bracket_controls.dart) -- they were the last of the screen still in the
// old forge chrome, with a heading hard-coded dark grey that vanished on the
// dark theme.

import 'package:alchemons/models/creature.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/creature_image.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/silhouette_widget.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';

/// What the database is for, shown on the first visit.
Future<void> showDatabaseTutorial(BuildContext context, FactionTheme theme) {
  final palette = BracketPalette.fromTheme(theme);
  final accent = bracketReadableAccent(theme);
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (ctx) => _DatabaseDialog(
      palette: palette,
      accent: accent,
      children: [
        _DialogTitle(
          'ALCHEMON DATABASE',
          palette: palette,
          icon: AppIcons.category_rounded,
          accent: accent,
        ),
        const SizedBox(height: 12),
        Text(
          'Every Alchemon you own, and every species you have found.',
          style: bracketText(ctx, 14, palette.ink.withValues(alpha: 0.9)),
        ),
        const SizedBox(height: 16),
        _TutorialRow(
          palette: palette,
          accent: accent,
          icon: AppIcons.grid_view_rounded,
          title: 'Specimens',
          body:
              'The first tab is every Alchemon you own. Search from the bar '
              'at the top; sort and filter just above them.',
        ),
        const SizedBox(height: 12),
        _TutorialRow(
          palette: palette,
          accent: accent,
          icon: AppIcons.category_rounded,
          title: 'Species catalog',
          body:
              'The second tab is every species: families across, elements '
              'down. Tap one you have found to see your specimens of it.',
        ),
        const SizedBox(height: 12),
        _TutorialRow(
          palette: palette,
          accent: accent,
          icon: AppIcons.show_chart_rounded,
          title: 'Breeding milestones',
          body:
              'Open a species from the catalog; the button beside its name '
              'tracks them.',
        ),
        const SizedBox(height: 20),
        BracketButton(
          label: 'GOT IT',
          height: 44,
          palette: palette,
          accent: accent,
          onTap: () => Navigator.of(ctx).pop(),
        ),
      ],
    ),
  );
}

/// A species in the catalog that has not been discovered: its silhouette.
Future<void> showUnknownSpeciesDialog(
  BuildContext context,
  FactionTheme theme,
  Creature species,
) {
  final palette = BracketPalette.fromTheme(theme);
  final accent = bracketReadableAccent(theme);
  final spriteData = species.spriteData;
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.8),
    builder: (ctx) => _DatabaseDialog(
      palette: palette,
      accent: palette.line,
      maxWidth: 340,
      children: [
        SizedBox(
          height: 240,
          child: Center(
            child: Silhouette(
              enabled: true,
              child: SizedBox.square(
                dimension: 220,
                child: spriteData != null
                    ? CreatureSprite(
                        spritePath: spriteData.spriteSheetPath,
                        totalFrames: spriteData.totalFrames,
                        rows: spriteData.rows,
                        frameSize: Vector2(
                          spriteData.frameWidth.toDouble(),
                          spriteData.frameHeight.toDouble(),
                        ),
                        stepTime: spriteData.frameDurationMs / 1000.0,
                      )
                    : CreatureImage(c: species, discovered: false, rounded: 6),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const BracketSectionDivider(label: 'UNKNOWN SPECIES'),
        const SizedBox(height: 10),
        Text(
          'Discover this species to reveal its true form.',
          textAlign: TextAlign.center,
          style: bracketText(ctx, 14, palette.ink.withValues(alpha: 0.9)),
        ),
        const SizedBox(height: 10),
        Center(child: _ClassPlate(palette: palette)),
        const SizedBox(height: 18),
        BracketButton(
          label: 'CLOSE',
          primary: false,
          height: 42,
          palette: palette,
          accent: accent,
          onTap: () => Navigator.pop(ctx),
        ),
      ],
    ),
  );
}

/// The frame both dialogs share: the bracket confirm's look (accent corners
/// on the palette's ground), with any content inside.
class _DatabaseDialog extends StatelessWidget {
  const _DatabaseDialog({
    required this.palette,
    required this.accent,
    required this.children,
    this.maxWidth = 380,
  });

  final BracketPalette palette;
  final Color accent;
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: CustomPaint(
          foregroundPainter: BracketFramePainter(
            color: accent.withValues(alpha: 0.9),
            bracketSize: 14,
            strokeWidth: 1.3,
          ),
          child: Container(
            color: palette.bg1,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogTitle extends StatelessWidget {
  const _DialogTitle(
    this.text, {
    required this.palette,
    required this.icon,
    required this.accent,
  });

  final String text;
  final BracketPalette palette;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: accent, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'monospace',
              color: palette.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
        ),
      ],
    );
  }
}

/// One thing the tutorial points at: an icon in a small bracket, a name, and
/// a line on what it does.
class _TutorialRow extends StatelessWidget {
  const _TutorialRow({
    required this.palette,
    required this.accent,
    required this.icon,
    required this.title,
    required this.body,
  });

  final BracketPalette palette;
  final Color accent;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomPaint(
          painter: BracketFramePainter(
            color: accent.withValues(alpha: 0.6),
            bracketSize: 6,
            strokeWidth: 1.0,
          ),
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            color: palette.accentWash(accent),
            child: Icon(icon, color: accent, size: 14),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: bracketText(
                  context,
                  13,
                  palette.ink,
                  weight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(body, style: bracketText(context, 12.5, palette.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

/// "CLASS ?": the catalog card's rarity line for an unknown species.
class _ClassPlate extends StatelessWidget {
  const _ClassPlate({required this.palette});

  final BracketPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.muted.withValues(alpha: 0.12),
        border: Border(left: BorderSide(color: palette.muted, width: 2)),
      ),
      child: Text(
        'CLASS ?',
        style: bracketText(
          context,
          10.5,
          palette.muted,
          weight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
