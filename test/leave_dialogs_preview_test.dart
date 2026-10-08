import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/screens/cosmic/widgets/leave_expedition_dialog.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/exit_game_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Every leave/exit question, on a phone, with real fonts:
//
//   LEAVE_OUT=/tmp/leave flutter test test/leave_dialogs_preview_test.dart
//
// Without LEAVE_OUT the test returns at once and passes.
void main() {
  testWidgets('leave dialogs preview', (tester) async {
    final out = Platform.environment['LEAVE_OUT'];
    if (out == null) return;
    Directory(out).createSync(recursive: true);

    Future<void> loadFont(String family, String path) async {
      final file = File(path);
      if (!file.existsSync()) return;
      await (FontLoader(family)..addFont(
            Future.value(ByteData.view(file.readAsBytesSync().buffer)),
          ))
          .load();
    }

    await tester.runAsync(() async {
      await loadFont(
        'monospace',
        '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
      );
      await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
    });

    final key = GlobalKey();
    final nav = GlobalKey<NavigatorState>();
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        builder: (context, child) => RepaintBoundary(key: key, child: child!),
        home: const Scaffold(backgroundColor: Color(0xFF1B2230)),
      ),
    );

    final dialogs = <(String, Future<Object?> Function(BuildContext))>[
      ('1_exit_alchemons', showExitGameDialog),
      (
        '2_leave_rift',
        (c) => showBracketConfirm(
          c,
          palette: BracketPalette.dark,
          accent: kLeaveDangerAccent,
          title: 'LEAVE THE RIFT?',
          message:
              'Your Portal Key is already spent. Leaving now takes you back '
              'with nothing from this rift.',
          cancelLabel: 'STAY',
          confirmLabel: 'LEAVE',
        ),
      ),
      (
        '3_leave_scene',
        (c) => showBracketConfirm(
          c,
          palette: BracketPalette.dark,
          accent: kLeaveDangerAccent,
          title: 'LEAVE SCENE?',
          message: 'Any active encounters will be lost.',
          cancelLabel: 'STAY',
          confirmLabel: 'LEAVE',
        ),
      ),
      (
        '4_let_it_go',
        (c) => showBracketConfirm(
          c,
          palette: BracketPalette.dark,
          accent: kLeaveDangerAccent,
          title: 'LET IT GO?',
          message:
              'After a failed attempt it will not stay. If you leave now, it '
              'is gone.',
          cancelLabel: 'STAY',
          confirmLabel: 'LEAVE',
        ),
      ),
      (
        '5_expedition_loaded',
        (c) => showLeaveExpeditionConfirm(
          c,
          cargoUnits: 47.4,
          cargoBreakdown: const {'Fire': 22.2, 'Water': 15.1, 'Earth': 10.1},
          unbankedShards: 240,
          bankedShards: 1204,
        ),
      ),
      (
        '6_expedition_empty',
        (c) => showLeaveExpeditionConfirm(
          c,
          cargoUnits: 0,
          cargoBreakdown: const {},
          unbankedShards: 0,
          bankedShards: 1204,
        ),
      ),
    ];

    for (final (name, show) in dialogs) {
      show(nav.currentContext!);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      nav.currentState!.pop();
      await tester.pumpAndSettle();
    }
  });
}
