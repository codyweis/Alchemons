// lib/widgets/avatar_widget.dart
//
// The profile button on home: the player's division, as the starter orb they
// chose it by in the faction picker — the same orb, turning — held in a
// soft white glow. It wore a dark medallion with a gold rim once, which read
// as a frame round a picture rather than a light. It replaced an
// illustrated sticker (a baby dragon in a mortar)
// that bobbed forever. Tapped, the orb flies out of the medallion into the
// profile's header (ProfileScreen.route).

import 'dart:ui' as ui;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The division orb's [Hero] tag: it flies from this medallion into the
/// profile's header and back (ProfileScreen.route).
const Object kDivisionOrbHeroTag = 'division-orb';

class AvatarButton extends StatelessWidget {
  const AvatarButton({super.key, required this.theme, required this.onTap});

  final FactionTheme theme;
  final VoidCallback onTap;

  static const double _size = 80;

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
            const CustomPaint(painter: _GlowPainter()),
            Center(
              child: Hero(
                tag: kDivisionOrbHeroTag,
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
            ),
          ],
        ),
      ),
    );
  }
}

/// Behind the orb, a pool of white light that fades to nothing at the
/// button's edge: no ring and no blur, only a radial gradient.
class _GlowPainter extends CustomPainter {
  const _GlowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          r,
          [
            Colors.white.withValues(alpha: 0.34),
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0),
          ],
          const [0.0, 0.45, 0.78, 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) => false;
}
