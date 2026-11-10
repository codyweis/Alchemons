// The bed of grains under a creature (ready_bed_vfx.dart): how ready its
// special is, and how grown it is, read off the body.
//   READY_BED_OUT=file.png flutter test test/survival_ready_bed_test.dart
// writes a sheet: spent to ready left to right; a new creature, a grown
// one, and a grown one under a blessing top to bottom.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/ready_bed_vfx.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicSurvivalCompanion _companion(String family, String element) =>
    CosmicSurvivalCompanion(
      member: CosmicPartyMember(
        instanceId: 'p0',
        baseId: 'X',
        displayName: 'X',
        family: family,
        element: element,
        level: 10,
        slotIndex: 0,
        statSpeed: 4,
        statIntelligence: 4,
        statStrength: 4,
        statBeauty: 4,
        staminaBars: 3,
        staminaMax: 3,
      ),
      position: ui.Offset.zero,
      anchor: ui.Offset.zero,
      maxHp: 100,
      physAtk: 10,
      elemAtk: 10,
      abilityAtk: 4,
      physDef: 1,
      elemDef: 1,
    );

void main() {
  test('a grown creature stands on more than a new one', () {
    expect(readyBedGrains(0), 6);
    expect(readyBedGrains(1), 15);
    expect(readyBedGrains(0.5), greaterThan(readyBedGrains(0.2)));
  });

  test('the body follows the cooldown and a cast throws the bed out', () {
    final c = _companion('Mane', 'Lava');
    final total = c.effectiveSpecialCooldown;
    c.specialCooldown = total;
    expect(c.specialReadiness, 0);
    c.specialCooldown = total / 2;
    expect(c.specialReadiness, closeTo(0.5, 1e-9));
    c.specialCooldown = 0;
    expect(c.specialReadiness, 1);
    c.specialCooldown = double.infinity;
    expect(c.specialReadiness, 0);

    // Ready and settled, then spent: gone in about half a second, not in
    // a frame.
    c.specialCooldown = 0;
    for (var f = 0; f < 240; f++) {
      c.tickReady(1 / 60, c.specialReadiness);
    }
    expect(c.shownReady, greaterThan(0.99));
    c.specialCooldown = total;
    c.tickReady(1 / 60, c.specialReadiness);
    expect(c.shownReady, greaterThan(0.85));
    for (var f = 0; f < 40; f++) {
      c.tickReady(1 / 60, c.specialReadiness);
    }
    expect(c.shownReady, lessThan(0.08));
  });

  test('an ability that is always on is always ready', () {
    final c = _companion('Kin', 'Fire')..specialCooldown = 99;
    expect(c.specialReadiness, 1);
  });

  testWidgets('sheet', (tester) async {
    final out = Platform.environment['READY_BED_OUT'];
    if (out == null) return;
    const cell = 150.0;
    const cols = 5, rows = 3;
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    canvas.scale(2);
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, cell * cols, cell * rows),
      ui.Paint()..color = const ui.Color(0xFF0B1220),
    );
    const elements = ['Lava', 'Water', 'Poison'];
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        canvas.save();
        canvas.translate(cell * (col + 0.5), cell * (row + 0.5));
        drawReadyBed(
          canvas: canvas,
          element: elements[row],
          color: elementColor(elements[row]),
          ready: col / (cols - 1),
          power: row == 0 ? 0 : 1,
          time: 3.0 + col,
          blessed: row == 2,
          seed: row.toDouble(),
        );
        // Where the body stands.
        canvas.drawCircle(
          ui.Offset.zero,
          13,
          ui.Paint()..color = const ui.Color(0xFF1A1A22),
        );
        canvas.restore();
      }
    }
    final pic = rec.endRecording();
    await tester.runAsync(() async {
      final img = await pic.toImage(
        (cell * cols * 2).toInt(),
        (cell * rows * 2).toInt(),
      );
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(png!.buffer.asUint8List());
      img.dispose();
    });
    pic.dispose();
  });
}
