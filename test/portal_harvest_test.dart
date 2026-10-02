import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/harvester_profile.dart';
import 'package:alchemons/widgets/fx/portal_harvest.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// A harvest in a portal screen takes the sprite standing there: it is read
// into grains and cut away, and a take leaves nothing of it behind.
void main() {
  testWidgets('a take cuts the live sprite away; a break hands it back', (
    tester,
  ) async {
    late ui.Image png;
    await tester.runAsync(() async {
      final data = await rootBundle.load(
        'assets/images/creatures/rare/HOR01_firehorn.png',
      );
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      png = (await codec.getNextFrame()).image;
    });

    for (final held in [true, false]) {
      final harvest = PortalHarvest();
      late BuildContext host;
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(held),
          home: Builder(
            builder: (context) {
              host = context;
              return Scaffold(
                body: Center(
                  child: harvest.wrap(
                    SizedBox(
                      width: 170,
                      height: 170,
                      child: RawImage(image: png),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      var closed = false;
      harvest
          .run(
            host,
            Colors.orange,
            () async => held,
            HarvesterProfile.forBiome('arcane'),
          )
          .then((_) => closed = true);
      var sawCut = false;
      for (var i = 0; i < 80 && !closed; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        if (harvest.cut.value != null) sawCut = true;
      }
      expect(closed, isTrue);
      if (held) {
        expect(sawCut, isTrue, reason: 'the live sprite was never read');
        expect(harvest.cut.value, double.infinity);
      } else {
        expect(harvest.cut.value, isNull);
      }
      harvest.dispose();
    }
  });
}
