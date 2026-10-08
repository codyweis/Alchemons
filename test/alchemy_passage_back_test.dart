import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/navigation/emblem_passage.dart';
import 'package:alchemons/screens/heart_puzzle/altar_levels_screen.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/alchemy_emblem.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Going back from ALCHEMY to home (the author, 2026-10-08: "the home menu
// flashes before animating"): the level select gives way over the
// passage's black, and home only comes up as the orb flies back into its
// circle — never through the page while it fades.
//
// Home here is magenta, which nothing on the page is; any frame of the
// page's fade that lets it through fails. PASSAGE_OUT=dir keeps the frames.
void main() {
  final out = Platform.environment['PASSAGE_OUT'];

  testWidgets('going back home never shows home through the fading page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // Partway on, so the page glides down to the next level and its header
    // docks: the way back must leave from the docked orb.
    SharedPreferences.setMockInitialValues({
      'altars.stars.v1': jsonEncode({for (var n = 1; n <= 24; n++) '$n': 3}),
    });
    const home = Color(0xFFFF00FF);
    final nav = GlobalKey<NavigatorState>();
    final from = GlobalKey();
    final shot = GlobalKey();
    await tester.pumpWidget(
      Provider<FactionTheme>.value(
        value: FactionTheme.scorchForge(),
        child: MaterialApp(
          navigatorKey: nav,
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) =>
              RepaintBoundary(key: shot, child: child!),
          home: Scaffold(
            backgroundColor: home,
            body: Align(
              alignment: const Alignment(0, .2),
              child: SizedBox(key: from, width: 84, height: 84),
            ),
          ),
        ),
      ),
    );

    Future<void> run(double seconds) async {
      for (var i = 0; i < (seconds / .033).round(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
        await tester.pump(const Duration(milliseconds: 33));
      }
    }

    /// The share of the screen that is home showing through.
    Future<double> homeShowing(String name) async {
      late double share;
      await tester.runAsync(() async {
        final b =
            shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await b.toImage(pixelRatio: .5);
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        var hits = 0;
        final n = data.lengthInBytes ~/ 4;
        for (var i = 0; i < n; i++) {
          final r = data.getUint8(i * 4),
              g = data.getUint8(i * 4 + 1),
              bl = data.getUint8(i * 4 + 2);
          if ((r < bl ? r : bl) - g > 40) hits++;
        }
        share = hits / n;
        if (out != null) {
          Directory(out).createSync(recursive: true);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
        }
        image.dispose();
      });
      return share;
    }

    EmblemPassage.pushScene<void>(
      from.currentContext!,
      scene: const AlchemyPassageScene(),
      from: from,
      page: const AltarLevelsScreen(),
    );
    // In, landed, and glided down to level 25.
    await run(4.5);
    expect(alchemyPickerScroll.value, greaterThan(100));
    expect(await homeShowing('0_page'), 0);

    nav.currentState!.pop();
    // The page gives way over the first third of the way back; the orb
    // flies home after it. Home may not show at all while the page fades.
    for (var i = 1; i <= 10; i++) {
      await run(.033);
      final share = await homeShowing('back_$i');
      expect(share, lessThan(.002), reason: 'frame $i of the way back');
    }
    // And by the end home is all there is.
    await run(1.2);
    expect(await homeShowing('back_end'), greaterThan(.9));
    expect(alchemyPickerScroll.value, 0);
  });
}
