@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/dock_sets.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/screens/profile_screen.dart';
import 'package:alchemons/services/account_cloud_save_service.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/account_session_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/avatar_widget.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The profile on a phone, with the app's own fonts (fetched from Google, so
// run with network): the division header over its realm, each section down
// the page, signed out and signed in, the developer tools open, and a
// sign-in dialog.
//
//   PROFILE_OUT=/tmp/profile flutter test \
//     test/profile_screen_preview_test.dart --tags preview
//
// PROFILE_FACTIONS=earthen,volcanic narrows the divisions.
void main() {
  final out = Platform.environment['PROFILE_OUT'];
  final factionFilter = Platform.environment['PROFILE_FACTIONS'];

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  }

  setUpAll(() async {
    await loadFont(
      'monospace',
      '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
    );
    await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
    final home =
        Platform.environment['PUB_CACHE'] ??
        '${Platform.environment['HOME']}/.pub-cache';
    await loadFont(
      'packages/phosphoricons_flutter/PhosphorBold',
      '$home/hosted/pub.dev/phosphoricons_flutter-1.0.0/lib/fonts/Phosphor-Bold.ttf',
    );
  });

  final factions = [
    for (final f in FactionId.values)
      if (factionFilter == null || factionFilter.split(',').contains(f.name)) f,
  ];

  for (final faction in factions) {
    testWidgets('profile ${faction.name}', (tester) async {
      if (out == null) return;
      Directory(out).createSync(recursive: true);

      HttpOverrides.global = null;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => Directory.systemTemp.createTempSync('fonts').path,
      );
      for (final channel in const [
        'dev.fluttercommunity.plus/sensors/method',
        'dev.fluttercommunity.plus/sensors/accelerometer',
        'dexterous.com/flutter/local_notifications',
      ]) {
        messenger.setMockMethodCallHandler(
          MethodChannel(channel),
          (_) async => null,
        );
      }
      messenger.allMessagesHandler = (channel, handler, message) {
        if (channel.startsWith('com.ryanheise.just_audio')) {
          return Future.value(
            const StandardMethodCodec().encodeSuccessEnvelope(
              <String, dynamic>{},
            ),
          );
        }
        return handler?.call(message);
      };
      addTearDown(() => messenger.allMessagesHandler = null);
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 44 * 3, bottom: 30 * 3);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        'cosmic_trait_hint_notes_v1': '',
      });

      final db = AlchemonsDatabase(NativeDatabase.memory());
      late CreatureCatalog catalog;
      await tester.runAsync(() async {
        final json =
            jsonDecode(
                  File(
                    'assets/data/alchemons_creatures.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        catalog = CreatureCatalog.fromList([
          for (final c in json['creatures'] as List)
            Creature.fromJson(c as Map<String, dynamic>),
        ]);
        GoogleFonts.imFellEnglishTextTheme();
        GoogleFonts.imFellEnglish(fontStyle: FontStyle.italic);
        GoogleFonts.cinzel(fontWeight: FontWeight.w700);
        for (final name in appFontMap.keys) {
          GoogleFonts.getFont(name, fontWeight: FontWeight.w600);
        }
        await GoogleFonts.pendingFonts();
        // A player who came from another faction and bought one set there:
        // three dock sets to choose between on the profile.
        final factions = FactionService(db);
        final before = FactionId.values[(faction.index + 1) % 4];
        await factions.setId(before);
        await factions.grantDockSet(DockSet.ofFaction(before)[1]);
        await factions.setId(faction);
      });

      final dir = '$out/${faction.name}';
      Directory(dir).createSync(recursive: true);
      final key = GlobalKey();
      Future<void> shoot(String name) async {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      Future<void> settle([int frames = 10]) async {
        for (var i = 0; i < frames; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      Future<void> scrollShot(String name, {double by = 650}) async {
        await tester.dragFrom(const Offset(195, 600), Offset(0, -by));
        await settle(8);
        await shoot(name);
      }

      Future<void> show({required bool signedIn, bool fromHome = false}) async {
        await tester.pumpWidget(
          MultiProvider(
            key: UniqueKey(),
            providers: [
              Provider<AlchemonsDatabase>.value(value: db),
              Provider<CreatureCatalog>.value(value: catalog),
              ChangeNotifierProvider<AccountService>(
                create: (_) => _FakeAccount(signedIn: signedIn),
              ),
              ChangeNotifierProvider<AccountSessionService>(
                create: (_) => _FakeSession(active: !signedIn),
              ),
              Provider<AccountCloudSaveService>(
                create: (_) => _FakeCloudSave(),
              ),
              ChangeNotifierProvider<AudioController>(
                create: (_) => AudioController(db),
              ),
              ChangeNotifierProvider<ThemeNotifier>(
                create: (_) => ThemeNotifier(db),
              ),
              ChangeNotifierProvider<FactionService>(
                create: (_) => FactionService(db)..loadId(),
              ),
              ProxyProvider<FactionService, FactionTheme>(
                update: (_, svc, _) =>
                    factionThemeFor(svc.current, brightness: Brightness.dark),
              ),
            ],
            child: Builder(
              builder: (context) {
                final themeNotifier = context.watch<ThemeNotifier>();
                final factionId = context.watch<FactionService>().current;
                final textTheme = themeNotifier.currentTextThemeFn(
                  ThemeData.dark().textTheme,
                );
                return MaterialApp(
                  debugShowCheckedModeBanner: false,
                  themeMode: ThemeMode.dark,
                  darkTheme: factionThemeFor(
                    factionId,
                    brightness: Brightness.dark,
                  ).toMaterialTheme(textTheme),
                  builder: (context, child) =>
                      RepaintBoundary(key: key, child: child!),
                  home: fromHome
                      ? const _MiniHome()
                      : ProfileScreen(() {}, key: UniqueKey()),
                );
              },
            ),
          ),
        );
        await settle(45);
      }

      Future<void> setOffset(double y) async {
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(y);
        await settle(2);
      }

      await show(signedIn: false);
      await shoot('1_top');
      await scrollShot('2_journal_display');
      await scrollShot('3_sound_notifications');
      await scrollShot('4_account');
      await scrollShot('5_bottom', by: 1500);

      // The developer tools, switched on.
      await tester.tap(find.text('DEBUG TOOLS'));
      await settle(10);
      await scrollShot('6_debug_open', by: 300);

      // Signed in, on a device that is not the account's active one.
      await show(signedIn: true);
      await tester.dragFrom(const Offset(195, 600), const Offset(0, -2000));
      await settle(8);
      await tester.scrollUntilVisible(
        find.text('TRANSFER ACCOUNT'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(8);
      await shoot('7_signed_in');

      // A sign-in dialog.
      await show(signedIn: false);
      await tester.scrollUntilVisible(
        find.text('SIGN IN'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(4);
      await tester.tap(find.text('SIGN IN'));
      await settle(10);
      await shoot('8_sign_in_dialog');

      // Larger text, as the Fold's monospace runs: nothing may overflow
      // (an overflow fails the test).
      Navigator.of(tester.element(find.text('SIGN IN').last)).pop();
      await settle(4);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await show(signedIn: true);
      await shoot('9_large_text');
      for (var i = 0; i < 6; i++) {
        await tester.dragFrom(const Offset(195, 600), const Offset(0, -600));
        await settle(4);
      }
      await shoot('9b_large_text_lower');

      // The way in, from the home avatar: the orb flies out of its
      // medallion into the header, then the realm pours out of it.
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await show(signedIn: false, fromHome: true);
      await shoot('t0_home');
      await tester.tap(find.byType(AvatarButton));
      await tester.pump();
      for (final ms in [90, 180, 270, 360, 450, 540, 630, 720, 900]) {
        await tester.pump(const Duration(milliseconds: 90));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        if (ms == 900) await tester.pump(const Duration(milliseconds: 1));
        await shoot('t1_in_${ms.toString().padLeft(3, '0')}');
      }
      for (final ms in [400, 800, 1400, 2200]) {
        await settle(ms == 400 ? 8 : (ms == 800 ? 8 : (ms == 1400 ? 12 : 16)));
        await shoot('t2_realm_${ms.toString().padLeft(4, '0')}');
      }

      // Scrolled: the orb rides up, shrinks and docks by the encyclopedia.
      for (final y in [40.0, 80.0, 110.0, 160.0, 520.0]) {
        await setOffset(y);
        await shoot('d_${y.toInt().toString().padLeft(3, '0')}');
      }

      // Back, docked: the orb flies home into its medallion.
      await tester.tap(find.byType(BracketIconButton).first);
      await tester.pump();
      for (final ms in [100, 200, 300, 400, 520]) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await shoot('t3_out_$ms');
      }
      await settle(4);
      await shoot('t4_home_again');

      await tester.pumpWidget(const SizedBox());
      await settle(4);
      await tester.runAsync(db.close);
    });
  }
}

/// Home's corner, enough of it for the avatar the profile opens from.
class _MiniHome extends StatelessWidget {
  const _MiniHome();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 0, 0),
          child: Align(
            alignment: Alignment.topLeft,
            child: AvatarButton(
              theme: theme,
              onTap: () => Navigator.push(context, ProfileScreen.route()),
            ),
          ),
        ),
      ),
    );
  }
}

class _FakeAccount extends ChangeNotifier implements AccountService {
  _FakeAccount({required this.signedIn});

  final bool signedIn;

  @override
  bool get initialized => true;
  @override
  bool get isConfigured => true;
  @override
  bool get isSignedIn => signedIn;
  @override
  String get displayName => signedIn ? 'Alchemist' : 'NO NAME SET';
  @override
  String get email => signedIn ? 'alchemist@example.com' : '';
  @override
  String? get configurationError => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeSession extends ChangeNotifier implements AccountSessionService {
  _FakeSession({required this.active});

  final bool active;

  @override
  AccountSessionState get state => active
      ? const AccountSessionState.active(activeDeviceId: 'here')
      : const AccountSessionState.idle();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeCloudSave implements AccountCloudSaveService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
