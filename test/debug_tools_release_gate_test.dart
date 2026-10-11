import 'package:alchemons/services/debug_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The developer tools used to answer to their switch alone, in every build.
/// The App Store build showed the switch to every player, and with it FREE
/// SHOP, every mastery node unlocked and forced wild mutations. A release
/// build now honours the switch only for a developer's signed-in account.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    DebugSettingsService.releaseBuild = false;
    DebugSettingsService.setAccount(null);
    DebugSettingsService.enabledNotifier.value = false;
  });

  test('a release build ignores the switch for a player', () async {
    SharedPreferences.setMockInitialValues({
      'debug.developer_tools_enabled': true,
      'debug.free_shop': true,
    });
    final settings = DebugSettingsService();
    await settings.setEnabled(true);
    await settings.setFreeShop(true);
    expect(DebugSettingsService.toolsVisible, isTrue);
    expect(DebugSettingsService.freeShop, isTrue);

    DebugSettingsService.releaseBuild = true;
    for (final uid in [null, 'some-player']) {
      DebugSettingsService.setAccount(uid);
      expect(DebugSettingsService.toolsAllowed, isFalse);
      expect(DebugSettingsService.toolsVisible, isFalse);
      expect(await settings.isEnabled(), isFalse);
      expect(DebugSettingsService.freeShop, isFalse);
      expect(DebugSettingsService.priced({'gold': 150}), {'gold': 150});
      expect(await settings.pendingForcedWildMutation(), isNull);
    }

    // The switch itself is kept: a debug build still sees it as left.
    DebugSettingsService.releaseBuild = false;
    DebugSettingsService.setAccount(null);
    expect(DebugSettingsService.toolsVisible, isTrue);
    expect(DebugSettingsService.freeShop, isTrue);
  });

  test('a developer account keeps the tools in a release build', () {
    DebugSettingsService.releaseBuild = true;
    for (final uid in kDeveloperAccountUids) {
      DebugSettingsService.setAccount(uid);
      expect(DebugSettingsService.toolsAllowed, isTrue);
    }
  });
}
