import 'dart:io';
import 'dart:ui' as ui;
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_projectile_vfx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Projectile trap(String element) => createCosmicSpecialAbility(
  origin: Offset.zero,
  baseAngle: 0,
  family: 'mask',
  element: element,
  damage: 40,
  maxHp: 400,
  targetPos: const Offset(120, 0),
).projectiles.first;

const maskGroups = {
  'first-four': ['Crystal', 'Light', 'Water', 'Dark'],
  'embers-and-pools': [
    'Fire',
    'Fire pool',
    'Lava',
    'Poison',
    'Blood',
    'Earth',
    'Mud',
  ],
  'remnants-and-relics': [
    'Air',
    'Dust',
    'Steam',
    'Lightning',
    'Ice',
    'Plant',
    'Spirit',
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'contact echoes survive consumption, debounce hits, and remain bounded',
    () {
      final fx = MaskTrapVisuals();
      final p = trap('Crystal');
      final life = p.life;
      final damage = p.damage;
      for (var i = 0; i < 100; i++) {
        fx.contact(p);
      }
      expect(fx.activeCount, 1);
      expect(p.life, life);
      expect(p.damage, damage);
      p.life = 0;
      fx.update(0.3);
      expect(fx.activeCount, 1);
      fx.update(0.3);
      expect(fx.activeCount, 0);
      for (var i = 0; i < 100; i++) {
        fx.contact(trap('Water'));
      }
      expect(fx.activeCount, 24);
      fx.update(0.6);
      expect(fx.activeCount, 0);
    },
  );
  test('new materials claim real contact traps but not other families', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (final element
        in maskGroups.values.expand((v) => v).where((v) => v != 'Fire pool')) {
      final p = trap(element);
      expect(
        drawMaskElementalProjectileVisual(
          canvas: canvas,
          projectile: p,
          position: Offset.zero,
          color: elementColor(element),
          time: 0.3,
        ),
        isTrue,
      );
      final other = Projectile(
        position: Offset.zero,
        angle: 0,
        life: 2,
        element: element,
        damage: 10,
        abilityFamily: 'kin',
        visualStyle: ProjectileVisualStyle.sigil,
        stationary: true,
      );
      expect(
        drawMaskTrapFixture(
          canvas: canvas,
          projectile: other,
          position: Offset.zero,
          time: 0.3,
        ),
        isFalse,
      );
    }
    recorder.endRecording().dispose();
  });
  for (final group in maskGroups.entries) {
    test('render Mask ${group.key} at normal and reduced detail', () async {
      final font = File('/System/Library/Fonts/Supplemental/Arial.ttf');
      if (font.existsSync()) {
        await (FontLoader('Preview')..addFont(
              Future.value(ByteData.sublistView(font.readAsBytesSync())),
            ))
            .load();
      }
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xFF090E1C), BlendMode.src);
      void label(String text, double x, double y) {
        final p = TextPainter(
          text: TextSpan(
            text: text,
            style: const TextStyle(
              fontFamily: 'Preview',
              fontSize: 16,
              color: Color(0xFFC9D8EE),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        p.paint(canvas, Offset(x, y));
      }

      label('MASK / ${group.key} / dark alchemical materials', 24, 22);
      label('Armed', 190, 70);
      label('Contact', 435, 70);
      label('Later', 675, 70);
      label('Zoomed out / fewer effects', 872, 70);
      final elements = group.value;
      for (var row = 0; row < elements.length; row++) {
        final name = elements[row];
        final element = name == 'Fire pool' ? 'Fire' : name;
        final authored = trap(element);
        final p = name == 'Fire pool'
            ? copyProjectile(authored, tickEffect: AbilityEffectKind.burn)
            : authored;
        p.position = Offset.zero;
        final radius = p.effectRadius.clamp(20.0, 260.0);
        final y = 180.0 + row * 165;
        label(name, 24, y - 8);
        for (var col = 0; col < 4; col++) {
          canvas.save();
          canvas.translate(220 + col * 240.0, y);
          // Normalize fixture footprint for comparison; last column is 55% zoom.
          canvas.scale(58 / radius * (col == 3 ? 0.55 : 1));
          p.abilityGrowthTimer =
              col == 1 && (element == 'Light' || element == 'Crystal')
              ? 1 - 0.18 * 0.55 * 1.6
              : 0;
          final consumed =
              (element == 'Light' || element == 'Crystal') && col == 2;
          if (!consumed) {
            drawMaskElementalProjectileVisual(
              canvas: canvas,
              projectile: p,
              position: Offset.zero,
              color: elementColor(element),
              time: 0.5 + col * 0.5,
              reduceAmbient: col == 3,
            );
          }
          if (element == 'Plant') {
            drawMaskPlantWormyTendrils(
              canvas: canvas,
              vine: p,
              color: elementColor(element),
              time: 0.5 + col * 0.5,
              targetsInReach: const [],
            );
          }
          if (col == 1 || col == 2) {
            drawMaskTrapContact(
              canvas: canvas,
              position: Offset.zero,
              radius: radius,
              element: element,
              progress: col == 1 ? 0.18 : 0.80,
            );
          }
          canvas.restore();
        }
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(1160, 110 + elements.length * 165);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(bytes, isNotNull);
      final output = Platform.environment['MASK_VFX_OUT'];
      if (output != null) {
        await Directory(output).create(recursive: true);
        await File(
          '$output/mask-${group.key}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      }
      image.dispose();
      picture.dispose();
    });
  }
}
