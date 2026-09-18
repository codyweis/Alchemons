@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_projectile_vfx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final output = Platform.environment['MANE_ALCHEMY_OUT'];
  testWidgets('Mane residue and scaled ward preview', (tester) async {
    final font = File('/System/Library/Fonts/Supplemental/Arial.ttf');
    if (font.existsSync()) {
      await (FontLoader('Label')..addFont(
            Future.value(ByteData.sublistView(font.readAsBytesSync())),
          ))
          .load();
    }
    final samples = <(String, Projectile)>[
      for (final e in [
        'Lava',
        'Steam',
        'Dust',
        'Earth',
        'Lightning',
        'Plant',
        'Poison',
        'Mud',
      ])
        (
          '$e residue',
          Projectile(
            position: Offset.zero,
            angle: 0,
            element: e,
            damage: 0,
            life: 3,
            stationary: true,
            abilityFamily: 'mane',
            visualStyle: ProjectileVisualStyle.sigil,
            effectRadius: 60,
            tickEffect: AbilityEffectKind.zoneDamage,
          ),
        ),
      for (final tier in [0, 2, 4])
        (
          'Light ward ${tier + 1}',
          createCosmicSpecialAbility(
            origin: Offset.zero,
            baseAngle: 0,
            family: 'mane',
            element: 'Light',
            damage: 40,
            maxHp: 400,
          ).projectiles.single..visualScale = kManeLightVisualByLevel[tier],
        ),
      (
        'Plant fully grown',
        createCosmicSpecialAbility(
          origin: Offset.zero,
          baseAngle: 0,
          family: 'mane',
          element: 'Plant',
          damage: 40,
          maxHp: 400,
        ).projectiles.single..visualScale = kManePlantMaxVisual,
      ),
    ];
    await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawColor(const Color(0xFF090F20), BlendMode.src);
      for (var i = 0; i < samples.length; i++) {
        final (name, p) = samples[i];
        final x = (i % 3) * 260.0;
        final y = (i ~/ 3) * 190.0;
        final tp = TextPainter(
          text: TextSpan(
            text: name,
            style: const TextStyle(
              fontFamily: 'Label',
              fontSize: 14,
              color: Color(0xFFBDD1DA),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, Offset(x + 12, y + 12));
        c.save();
        c.clipRect(Rect.fromLTWH(x, y + 36, 260, 150));
        c.translate(x + 130, y + 110);
        c.scale(i == 11 ? 0.22 : 0.7);
        final claimed =
            drawMaskElementalProjectileVisual(
              canvas: c,
              projectile: p,
              position: Offset.zero,
              color: elementColor(p.element!),
              time: 0.8,
            ) ||
            drawManeElementalProjectileVisual(
              canvas: c,
              projectile: p,
              position: Offset.zero,
              color: elementColor(p.element!),
              time: 0.8,
            );
        expect(claimed, isTrue);
        drawProjectileRoleOverlay(
          canvas: c,
          projectile: p,
          position: Offset.zero,
          color: elementColor(p.element!),
          time: 0.8,
        );
        c.restore();
      }
      final pic = rec.endRecording();
      final img = await pic.toImage(780, 760);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory(output!).createSync(recursive: true);
      File(
        '$output/mane_alchemical_zones.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      img.dispose();
      pic.dispose();
    });
  }, skip: output == null);
}
