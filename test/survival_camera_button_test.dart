import 'package:alchemons/games/cosmic_survival/components/survival_camera_button.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('one zoom key cycles: camera free, zoom locked, normal', (
    tester,
  ) async {
    // The screen's cycle (cosmic_survival_screen.dart `_cycleCamera`).
    final camera = ValueNotifier(false);
    final locked = ValueNotifier(false);
    addTearDown(camera.dispose);
    addTearDown(locked.dispose);
    void cycle() {
      if (camera.value) {
        locked.value = true;
        camera.value = false;
      } else if (locked.value) {
        locked.value = false;
      } else {
        camera.value = true;
      }
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SurvivalCameraButton(
              cameraMode: camera,
              zoomLocked: locked,
              onToggle: cycle,
            ),
          ),
        ),
      ),
    );
    final button = find.byType(SurvivalCameraButton);
    Color? fill() => tester
        .widget<Material>(
          find.descendant(of: button, matching: find.byType(Material)),
        )
        .color;
    final normal = fill();
    expect(tester.getSize(button), const Size(44, 44));
    expect(find.byTooltip('Zoom out and pan'), findsOneWidget);

    // Camera free: lit, and it stays lit.
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(camera.value, isTrue);
    expect(find.byTooltip('Lock this zoom and fly'), findsOneWidget);
    final lit = fill();
    expect(lit, isNot(normal));
    await tester.pump(const Duration(seconds: 2));
    expect(fill(), lit);

    // Zoom locked: still lit, now a lock.
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(camera.value, isFalse);
    expect(locked.value, isTrue);
    expect(find.byTooltip('Back to the normal zoom'), findsOneWidget);
    expect(find.byIcon(AppIcons.lock_rounded), findsOneWidget);
    expect(fill(), lit);

    // Back to the normal zoom.
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(locked.value, isFalse);
    expect(find.byTooltip('Zoom out and pan'), findsOneWidget);
    expect(fill(), normal);

    // A change from elsewhere (a controller's Back) shows too.
    camera.value = true;
    await tester.pump();
    expect(find.byTooltip('Lock this zoom and fly'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
