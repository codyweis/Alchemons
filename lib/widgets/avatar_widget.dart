// lib/widgets/avatar_widget.dart
//
// The profile button on home: the player's division, as the starter orb they
// chose it by in the faction picker — the same orb, turning — set in a dark
// medallion with a gold rim, the pair of the Upgrade medallion across the
// screen. It replaced an illustrated sticker (a baby dragon in a mortar)
// that bobbed forever.

import 'dart:ui' as ui;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AvatarButton extends StatelessWidget {
  const AvatarButton({super.key, required this.theme, required this.onTap});

  final FactionTheme theme;
  final VoidCallback onTap;

  static const double _size = 60;

  @override
  Widget build(BuildContext context) {
    final faction = context.watch<FactionService>().current;
    final group = faction == null
        ? ElementalGroup.arcane
        : ElementalGroup.values.byName(faction.name);
    return GestureDetector(
      onTap: context.soundAction(onTap),
      behavior: HitTestBehavior.opaque,
      child: SizedBox.square(
        dimension: _size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: _MedallionPainter(front: false)),
            Center(
              child: ExtractionVialOrb(
                vial: ExtractionVial(
                  price: null,
                  id: 'starter_${group.name}',
                  name: 'STARTER VIAL',
                  group: group,
                  rarity: VialRarity.uncommon,
                  quantity: 1,
                ),
                size: _size * 0.92,
              ),
            ),
            const IgnorePointer(
              child: CustomPaint(painter: _MedallionPainter(front: true)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Behind the orb, the medallion's dark glass; in front of it, its gold rim
/// and a catchlight. The rim is a filled band, not a stroke.
class _MedallionPainter extends CustomPainter {
  const _MedallionPainter({required this.front});

  final bool front;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    if (!front) {
      canvas.drawCircle(
        c,
        r * 0.96,
        Paint()
          ..shader = ui.Gradient.radial(
            c + Offset(-r * 0.3, -r * 0.35),
            r * 1.4,
            const [Color(0xFF1C1822), Color(0xFF060508)],
          ),
      );
      return;
    }
    final band = Rect.fromCircle(center: c, radius: r);
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(Rect.fromCircle(center: c, radius: r * 0.98))
        ..addOval(Rect.fromCircle(center: c, radius: r * 0.9)),
      Paint()
        ..shader = ui.Gradient.linear(
          band.topLeft,
          band.bottomRight,
          const [Color(0xFFF2D58A), Color(0xFF8A6420), Color(0xFFC9A04E)],
          const [0.0, 0.6, 1.0],
        ),
    );
    canvas.save();
    canvas.translate(c.dx - r * 0.42, c.dy - r * 0.5);
    canvas.rotate(-0.7);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 0.42, height: r * 0.16),
      Paint()..color = Colors.white.withValues(alpha: 0.32),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MedallionPainter old) => old.front != front;
}
