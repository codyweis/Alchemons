import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/celebration_costume.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/alchemy_effects/alchemy_effect_view.dart';
import 'package:alchemons/widgets/fx/costume_paint.dart';
import 'package:drift/native.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'saved celebration costumes render at detail and HUD sizes, mirrored and scaled',
    (tester) async {
      final db = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final data =
          jsonDecode(
                File('assets/data/alchemons_creatures.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final entries = data['creatures'] as List;
      final creatures = <Creature>[];
      final instances = <CreatureInstance>[];
      await tester.runAsync(() async {
        for (final id in ['WNG04', 'PIP01']) {
          final creature = Creature.fromJson(
            entries.cast<Map<String, dynamic>>().singleWhere(
              (e) => e['id'] == id,
            ),
          );
          creatures.add(creature);
          await db.creatureDao.insertInstance(instanceId: id, baseId: id);
          await db.creatureDao.updateAlchemyEffect(
            instanceId: id,
            effect: FamilyCostume.effectFor(id),
          );
          instances.add((await db.creatureDao.getInstance(id))!);
          final sheet = creature.spriteData!.spriteSheetPath;
          final codec = await ui.instantiateImageCodec(
            File('assets/images/$sheet').readAsBytesSync(),
          );
          Flame.images.add(sheet, (await codec.getNextFrame()).image);
          codec.dispose();
        }
      });
      tester.view.physicalSize = const Size(800, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: const Color(0xFF182030),
              child: Column(
                children: [
                  const SizedBox(height: 65),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (var i = 0; i < 2; i++)
                        InstanceSprite(
                          creature: creatures[i],
                          instance: instances[i],
                          size: 260,
                          flipX: i == 1,
                        ),
                    ],
                  ),
                  const SizedBox(height: 55),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (var i = 0; i < 2; i++)
                        InstanceSprite(
                          creature: creatures[i],
                          instance: instances[i],
                          size: 64,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      // Drawn by the sprite over its frame, not wrapped round it.
      expect(find.byType(WornCostume), findsNWidgets(4));
      expect(find.byType(AlchemyEffectView), findsNothing);
      expect(tester.takeException(), isNull);
      final out = Platform.environment['CELEBRATION_WIDGET_OUT'];
      if (out != null) {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
      Flame.images.clearCache();
    },
  );
}
