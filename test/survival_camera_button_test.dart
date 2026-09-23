import 'package:alchemons/games/cosmic_survival/components/survival_camera_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('camera highlight persists and reacts to external mode changes', (
    tester,
  ) async {
    final mode = ValueNotifier(false);
    addTearDown(mode.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SurvivalCameraButton(
              cameraMode: mode,
              onToggle: () => mode.value = !mode.value,
            ),
          ),
        ),
      ),
    );
    final button = find.byType(SurvivalCameraButton);
    final normalColor = tester
        .widget<Material>(
          find.descendant(of: button, matching: find.byType(Material)),
        )
        .color;
    expect(tester.getSize(button), const Size(44, 44));
    expect(find.byTooltip('Zoom out and pan'), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(mode.value, isTrue);
    expect(find.byTooltip('Exit camera mode'), findsOneWidget);
    final selectedColor = tester
        .widget<Material>(
          find.descendant(of: button, matching: find.byType(Material)),
        )
        .color;
    expect(selectedColor, isNot(normalColor));
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester
          .widget<Material>(
            find.descendant(of: button, matching: find.byType(Material)),
          )
          .color,
      selectedColor,
    );
    mode.value = false;
    await tester.pump();
    expect(find.byTooltip('Zoom out and pan'), findsOneWidget);
    expect(
      tester
          .widget<Material>(
            find.descendant(of: button, matching: find.byType(Material)),
          )
          .color,
      normalColor,
    );
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    expect(mode.value, isFalse);
    expect(tester.takeException(), isNull);
  });
}
