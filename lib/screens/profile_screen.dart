// lib/screens/profile_screen.dart
//
// The profile: who you are, then how the game is set up.
//
//   Your division, as the realm you chose it by — its living grains across
//   the top, the starter orb, the name, its creed and perks — and then the
//   journal, display, sound, notifications, your account and save, a fresh
//   start, and the developer switches.
//
// It is dark glass and ink like the rest of the game (bracket_frame.dart):
// the sections are plain panels, nothing outlined, and the thing to do is
// lit from below. Until 2026-10-06 it was the last "Scorched Forge" screen:
// accent bars, rounded outlines, stock icons on every label, a particle
// backdrop and a white close disc.

import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/wilderness/field/grain_field.dart'
    show VolcanoField;
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/models/scenes/volcano/volcano_scene.dart';
import 'package:alchemons/models/wild_fusion.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/screens/alchemical_encyclopedia_screen.dart';
import 'package:alchemons/screens/debug/dungeon_debug_screen.dart';
import 'package:alchemons/screens/heart_puzzle/altar_levels_screen.dart';
import 'package:alchemons/screens/faction_picker.dart';
import 'package:alchemons/screens/story/story_intro_screen.dart';
import 'package:alchemons/services/account_cloud_save_service.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/account_session_service.dart';
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:alchemons/services/debug_settings_service.dart';
import 'package:alchemons/services/device_identity_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/mobile_store_service.dart';
import 'package:alchemons/services/notification_preferences_service.dart';
import 'package:alchemons/services/onboarding_tasks.dart';
import 'package:alchemons/services/progress_reset_service.dart';
import 'package:alchemons/services/push_notification_service.dart';
import 'package:alchemons/services/save_restore_reload_service.dart';
import 'package:alchemons/services/save_transfer_service.dart';
import 'package:alchemons/services/wilderness_spawn_service.dart';
import 'package:alchemons/utils/app_scaffold_messenger.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/avatar_widget.dart';
import 'package:alchemons/widgets/background/faction_realm.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/campaign_rewards_button.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:alchemons/widgets/reset_progress_dialog.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ──────────────────────────────────────────────────────────────────────────────
// TYPE
// ──────────────────────────────────────────────────────────────────────────────

/// A row's name, a section's head, a button's word: letterspaced capitals.
TextStyle _mono(
  double size,
  Color color, {
  FontWeight weight = FontWeight.w800,
  double spacing = 1.4,
}) => TextStyle(
  fontFamily: 'monospace',
  color: color,
  fontSize: size,
  fontWeight: weight,
  letterSpacing: spacing,
  height: 1.2,
);

/// What a row does, in the book face.
TextStyle _prose(BuildContext context, Color color, {double size = 12.5}) =>
    bracketText(context, size, color).copyWith(height: 1.4);

const Color _kDanger = Color(0xFFE57373);

// ──────────────────────────────────────────────────────────────────────────────
// PROFILE SCREEN
// ──────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen(void Function() param0, {super.key});

  /// The way in. The page fades up from black while the division orb flies
  /// out of the home avatar's medallion into the header (a [Hero] on
  /// [kDivisionOrbHeroTag]); once it lands the realm pours out of it, and
  /// then the page's words ease in. Back, the orb flies home from wherever
  /// it is, docked or not.
  static Route<void> route() => PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 900),
    reverseTransitionDuration: const Duration(milliseconds: 520),
    pageBuilder: (context, _, _) =>
        ProfileScreen(() => Navigator.of(context).pop()),
    transitionsBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: const Interval(0, 0.45, curve: Curves.easeOut),
      ),
      child: child,
    ),
  );

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

/// Where the header's orb stands, below the top of the page and the safe
/// area: the top bar's padding, its row and a gap.
const double _kOrbSlotTop = 10 + 38 + 6;
const Size _kOrbSlot = Size(220, 160);
const double _kOrbSize = 136;

/// The orb docked in the top bar, as a share of its size in the header.
const double _kDockScale = 0.37;

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  _ProfileData? _data;
  late final PageController _cosmicHintsController;
  final ScrollController _scroll = ScrollController();

  /// The header's realm: made here so it can pour out of the orb.
  FactionRealmField? _realmField;
  final GlobalKey _realmKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _dockKey = GlobalKey();

  /// The middle of the orb's place in the top bar, in the page: measured
  /// after layout, never during a build.
  final ValueNotifier<Offset?> _dock = ValueNotifier(null);

  /// The realm, hidden until it pours out of the landed orb.
  late final AnimationController _realmIn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  /// The page's words, once the orb has landed.
  Animation<double> _reveal = kAlwaysCompleteAnimation;
  Animation<double>? _routeAnimation;
  ModalRoute<Object?>? _route;
  bool _emergeAsked = false;
  final NotificationPreferencesService _notificationPrefs =
      NotificationPreferencesService();
  final CinematicQualityService _cinematicQualityService =
      CinematicQualityService();
  final PushNotificationService _pushNotifications = PushNotificationService();
  bool _cultivationsEnabled = true;
  bool _wildernessEnabled = true;
  bool _extractionsEnabled = true;
  bool _notificationPrefsLoaded = false;
  CinematicQuality _cinematicQuality = CinematicQuality.cinematic;
  bool _cinematicQualityLoaded = false;
  final DebugSettingsService _debugSettings = DebugSettingsService();
  bool _debugToolsEnabled = false;
  bool _debugToolsLoaded = false;
  bool _freeShop = false;
  bool _saveTransferBusy = false;
  int _cosmicHintPage = 0;

  @override
  void initState() {
    super.initState();
    // Arriving earns the task; collecting it happens in the journal.
    OnboardingTaskService.recordArrival(context, 'profile');
    _cosmicHintsController = PageController();
    _loadProfileData();
    _loadNotificationPrefs();
    _loadCinematicQuality();
    _loadDebugTools();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    _route = route;
    final animation = route?.animation;
    if (animation != _routeAnimation) {
      _routeAnimation?.removeListener(_watchRoute);
      _routeAnimation = animation;
      _reveal = animation == null
          ? kAlwaysCompleteAnimation
          : CurvedAnimation(
              parent: animation,
              curve: const Interval(0.5, 1, curve: Curves.easeOutCubic),
            );
      animation?.addListener(_watchRoute);
    }
    _watchRoute();
  }

  /// The orb is nearly down at just past half way (the hero flight eases
  /// out): the realm starts to pour. Not on the frame the route is laid out
  /// offstage to measure the hero — its animation reads complete there.
  void _watchRoute() {
    final animation = _routeAnimation;
    if (animation == null) {
      _askEmerge();
      return;
    }
    if (_route?.offstage ?? false) return;
    if (animation.status == AnimationStatus.reverse) return;
    if (animation.value >= 0.55) _askEmerge();
  }

  void _askEmerge() {
    if (_emergeAsked) return;
    _emergeAsked = true;
    _emergeWhenLaidOut();
  }

  /// Every grain of the realm to the orb's middle, then out to its place
  /// (the faction picker's opening), in the orb's own color.
  void _emergeWhenLaidOut() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final field = _realmField;
      final realm = _realmKey.currentContext?.findRenderObject();
      final faction = context.read<FactionService>().current;
      if (field == null ||
          faction == null ||
          realm is! RenderBox ||
          !realm.hasSize) {
        // No realm yet (or none at all): just show the page.
        if (field != null) _emergeWhenLaidOut();
        return;
      }
      final top = MediaQuery.paddingOf(context).top;
      // The orb's middle in the realm's own terms: the realm fills the
      // header, and the orb's place in the header is fixed.
      final centre = Offset(
        realm.size.width / 2,
        top + _kOrbSlotTop + _kOrbSlot.height / 2,
      );
      final group = ElementalGroup.values.byName(faction.name);
      field
        ..emergeFrom(centre, color: group.color.toARGB32())
        // Into the knot now, so the first frame shown is the knot and not
        // the settled realm it is about to leave.
        ..step(0);
      _realmIn.forward();
    });
  }

  @override
  void dispose() {
    _routeAnimation?.removeListener(_watchRoute);
    _dock.dispose();
    _realmIn.dispose();
    _scroll.dispose();
    _realmField?.dispose();
    _cosmicHintsController.dispose();
    super.dispose();
  }

  void _measureDock() {
    final dock = _dockKey.currentContext?.findRenderObject();
    final stack = _stackKey.currentContext?.findRenderObject();
    if (dock is! RenderBox || stack is! RenderBox) return;
    if (!dock.hasSize || !stack.hasSize) return;
    final centre = dock.localToGlobal(
      dock.size.center(Offset.zero),
      ancestor: stack,
    );
    if (centre != _dock.value) _dock.value = centre;
  }

  Future<void> _loadProfileData() async {
    final data = await _fetch();
    if (mounted) setState(() => _data = data);
  }

  BracketPalette get _palette =>
      BracketPalette.fromTheme(context.read<FactionTheme>());

  Color get _accent => bracketReadableAccent(context.read<FactionTheme>());

  Future<_ProfileData> _fetch() async {
    final svc = context.read<FactionService>();
    final fid = svc.current;
    final prefs = await SharedPreferences.getInstance();
    final noteIds = deserialiseContestHintIds(
      prefs.getString('cosmic_trait_hint_notes_v1') ?? '',
    );
    final cosmicHints = kCosmicContestHintLore
        .where((h) => noteIds.contains(h.id))
        .toList();

    if (fid == null) return _ProfileData(null, 0, cosmicHints);
    final discovered = await svc.discoveredCount();
    return _ProfileData(fid, discovered, cosmicHints);
  }

  Future<void> _replayStory() async {
    HapticFeedback.mediumImpact();
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const StoryIntroScreen()),
    );
  }

  /// Reopens the faction picker so it can be seen again.
  ///
  /// The picker is normally the first thing in the game and runs exactly
  /// once per save, which makes it the hardest screen here to look at
  /// twice. This is a bypass of the shop's paid faction change on purpose:
  /// it is for looking at the picker, not for playing.
  Future<void> _openFactionTester() async {
    final before = context.read<FactionService>().current;
    final selected = await showDialog<FactionId>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const FactionPickerDialog(),
    );
    if (!mounted || selected == null) return;
    showGameSnack(
      context,
      selected == before
          ? 'Faction unchanged — ${selected.name}'
          : 'Faction set to ${selected.name}',
    );
  }

  Future<void> _bringWeather(
    String sceneId,
    WeatherKind kind,
    String what,
  ) async {
    HapticFeedback.mediumImpact();
    final came = await context.read<WildernessSpawnService>().debugBringWeather(
      sceneId,
      kind,
    );
    if (!mounted) return;
    showGameSnack(
      context,
      came ? '$what has come' : 'No $what — that region is not open yet',
    );
  }

  Future<void> _advanceVolcano() async {
    HapticFeedback.mediumImpact();
    final next = await context
        .read<WildernessSpawnService>()
        .debugAdvanceFieldStage('volcano', volcanoScene);
    if (!mounted) return;
    final mood = switch (next) {
      VolcanoField.smoking => 'smoking',
      VolcanoField.erupting => 'erupting',
      _ => 'quiet',
    };
    showGameSnack(context, 'The next visit finds the Volcano $mood');
  }

  Future<void> _owedAftermath(String sceneId, String message) async {
    HapticFeedback.mediumImpact();
    await context.read<WildernessSpawnService>().debugSetAftermath(sceneId);
    if (!mounted) return;
    showGameSnack(context, message);
  }

  Future<void> _openDungeonDebug() async {
    HapticFeedback.mediumImpact();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const DungeonDebugScreen()),
    );
  }

  Future<void> _openAltars() async {
    HapticFeedback.mediumImpact();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const AltarLevelsScreen()),
    );
  }

  Future<void> _openEncyclopedia() async {
    HapticFeedback.mediumImpact();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const AlchemicalEncyclopediaScreen()),
    );
  }

  Future<void> _loadNotificationPrefs() async {
    final cultivations = await _notificationPrefs.isCultivationsEnabled();
    final wilderness = await _notificationPrefs.isWildernessEnabled();
    final extractions = await _notificationPrefs.isExtractionsEnabled();
    if (!mounted) return;
    setState(() {
      _cultivationsEnabled = cultivations;
      _wildernessEnabled = wilderness;
      _extractionsEnabled = extractions;
      _notificationPrefsLoaded = true;
    });
  }

  Future<void> _toggleCultivations(bool value) async {
    setState(() => _cultivationsEnabled = value);
    await _notificationPrefs.setCultivationsEnabled(value);
    if (!value) {
      await _pushNotifications.cancelEggNotification();
    }
  }

  Future<void> _toggleWilderness(bool value) async {
    setState(() => _wildernessEnabled = value);
    await _notificationPrefs.setWildernessEnabled(value);
    if (!value) {
      await _pushNotifications.cancelWildernessNotifications();
    }
  }

  Future<void> _toggleExtractions(bool value) async {
    setState(() => _extractionsEnabled = value);
    await _notificationPrefs.setExtractionsEnabled(value);
    if (!value) {
      await _pushNotifications.cancelHarvestNotification();
    }
  }

  Future<void> _loadCinematicQuality() async {
    final quality = await _cinematicQualityService.getQuality();
    if (!mounted) return;
    setState(() {
      _cinematicQuality = quality;
      _cinematicQualityLoaded = true;
    });
  }

  Future<void> _setCinematicQuality(CinematicQuality value) async {
    setState(() => _cinematicQuality = value);
    await _cinematicQualityService.setQuality(value);
  }

  Future<void> _loadDebugTools() async {
    final enabled = await _debugSettings.isEnabled();
    final freeShop = await _debugSettings.isFreeShop();
    // Hydrates the notifier the WILD MUTATION row listens to.
    await _debugSettings.forcedWildMutation();
    if (!mounted) return;
    setState(() {
      _debugToolsEnabled = enabled;
      _freeShop = freeShop;
      _debugToolsLoaded = true;
    });
  }

  Future<void> _setDebugTools(bool value) async {
    setState(() => _debugToolsEnabled = value);
    await _debugSettings.setEnabled(value);
  }

  Future<void> _setFreeShop(bool value) async {
    setState(() => _freeShop = value);
    await _debugSettings.setFreeShop(value);
  }

  Future<void> _setForcedMutation(String? id) =>
      _debugSettings.setForcedWildMutation(id);

  Future<void> _reloadProfileState() async {
    if (!mounted) return;
    await _loadProfileData();
    await _loadNotificationPrefs();
    await _loadCinematicQuality();
  }

  String _formatCosmicHintText(String text) {
    final separator = text.indexOf(':');
    final raw = separator < 0
        ? text.trim()
        : text.substring(separator + 1).trim();
    return raw
        .replaceFirst(RegExp(r'^[\"“”]+'), '')
        .replaceFirst(RegExp(r'[\"“”]+$'), '')
        .trim();
  }

  Widget _buildCosmicHints(
    BracketPalette palette,
    Color accent,
    List<CosmicContestHintLore> cosmicHints,
  ) {
    if (cosmicHints.isEmpty) {
      return Text(
        'None found yet. They turn up at contests in space.',
        style: _prose(context, palette.muted),
      );
    }

    final hints = cosmicHints.take(6).toList(growable: false);
    final currentPage = _cosmicHintPage.clamp(0, hints.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 52,
          child: PageView.builder(
            controller: _cosmicHintsController,
            itemCount: hints.length,
            onPageChanged: (index) {
              if (!mounted) return;
              setState(() => _cosmicHintPage = index);
            },
            itemBuilder: (context, index) => SizedBox.expand(
              child: Text(
                _formatCosmicHintText(hints[index].text),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _prose(
                  context,
                  palette.ink.withValues(alpha: 0.88),
                  size: 13,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ),
        ),
        if (hints.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < hints.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 5),
                  width: i == currentPage ? 16 : 5,
                  height: 3,
                  color: i == currentPage
                      ? accent
                      : palette.line.withValues(alpha: 0.5),
                ),
            ],
          ),
        ],
      ],
    );
  }

  // ───────────────────────────── account ──────────────────────────────────

  Future<void> _createAccount() async {
    final result = await _showCredentialDialog(
      title: 'CREATE ACCOUNT',
      submitLabel: 'CREATE',
      includeDisplayName: true,
    );
    if (!mounted || result == null) return;

    _showProgressDialog(
      title: 'CREATING ACCOUNT',
      message: 'Setting up your transfer account.',
    );

    final accountService = context.read<AccountService>();
    final sessionService = context.read<AccountSessionService>();
    try {
      await accountService.createAccount(
        email: result.email,
        password: result.password,
        displayName: result.displayName,
      );
      await sessionService.claimCurrentDevice(force: true);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack('Account created. Save transfer is now unlocked.');
    } on AccountException catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack(error.message, isError: true);
    } catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack('Account creation failed: $error', isError: true);
    }
  }

  bool _resetBusy = false;

  Future<void> _resetProgress() async {
    if (_resetBusy) return;
    setState(() => _resetBusy = true);
    final account = context.read<AccountService>();
    final store = context.read<MobileStoreService>();
    final reset = ProgressResetService(context.read<AlchemonsDatabase>());
    final uid = account.user?.uid;
    try {
      if (!account.initialized) {
        throw StateError('Please wait for your account to finish loading.');
      }
      final deviceId = await context
          .read<DeviceIdentityService>()
          .getDeviceId();
      await store.pauseForReset();
      final preview = uid == null ? null : await reset.preview(deviceId);
      if (!mounted) return;
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => ResetProgressDialog(
          purchasedGold: (preview?['goldAmount'] as num?)?.toInt(),
        ),
      );
      if (!mounted) return;
      if (choice == 'sign-in') {
        store.cancelResetPause();
        await _signInAccount();
      } else if (choice == 'reset') {
        if (account.user?.uid != uid) {
          throw StateError('Your account changed. Review the reset again.');
        }
        await store.pauseForReset();
        await reset.request(uid: uid, deviceId: deviceId, preview: preview);
      }
    } catch (error) {
      if (mounted) {
        _showTransferSnack('Reset could not start: $error', isError: true);
      }
    } finally {
      store.cancelResetPause();
      if (mounted) setState(() => _resetBusy = false);
    }
  }

  Future<void> _signInAccount() async {
    final result = await _showCredentialDialog(
      title: 'SIGN IN',
      submitLabel: 'SIGN IN',
    );
    if (!mounted || result == null) return;

    _showProgressDialog(
      title: 'SIGNING IN',
      message: 'Verifying your account for save transfer.',
    );

    final accountService = context.read<AccountService>();
    final sessionService = context.read<AccountSessionService>();
    try {
      await accountService.signIn(
        email: result.email,
        password: result.password,
      );
      await sessionService.refresh();
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack(
        'Signed in. Your local save stays active on this device until you choose restore or switch the account here.',
      );
    } on AccountException catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack(error.message, isError: true);
    } catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack('Sign in failed: $error', isError: true);
    }
  }

  Future<void> _renameAccount(AccountService account) async {
    final controller = TextEditingController(text: account.displayName);
    final name = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => _FormDialog(
        title: 'ACCOUNT NAME',
        submitLabel: 'SAVE',
        onSubmit: () => Navigator.pop(context, controller.text.trim()),
        children: [
          _FormField(
            controller: controller,
            hint: 'Display name',
            autofocus: true,
          ),
        ],
      ),
    );

    if (!mounted || name == null || name.isEmpty) return;

    _showProgressDialog(
      title: 'UPDATING ACCOUNT',
      message: 'Saving your new account name.',
    );
    try {
      await account.updateDisplayName(name);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack('Account name updated.');
    } on AccountException catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack(error.message, isError: true);
    }
  }

  Future<void> _changePassword(AccountService account) async {
    final result = await _showPasswordDialog(
      title: 'CHANGE PASSWORD',
      submitLabel: 'UPDATE',
      includeNewPassword: true,
      message: 'Enter your current password, then choose a new one.',
    );
    if (!mounted || result == null) return;

    _showProgressDialog(
      title: 'CHANGING PASSWORD',
      message: 'Updating your account security.',
    );
    try {
      await account.changePassword(
        currentPassword: result.currentPassword,
        newPassword: result.newPassword,
      );
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack('Password updated.');
    } on AccountException catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack(error.message, isError: true);
    }
  }

  Future<void> _deleteAccount(AccountService account) async {
    final result = await _showPasswordDialog(
      title: 'DELETE ACCOUNT',
      submitLabel: 'DELETE',
      message:
          'This removes your Firebase account. Local game progress on this device is not deleted automatically.',
    );
    if (!mounted || result == null) return;

    final confirmed = await showBracketConfirm(
      context,
      palette: _palette,
      accent: _kDanger,
      title: 'DELETE ACCOUNT?',
      message:
          'You will lose account-based save transfer until you create another account.',
      warning: 'This cannot be undone.',
      confirmLabel: 'DELETE',
    );

    if (!confirmed || !mounted) return;

    _showProgressDialog(
      title: 'DELETING ACCOUNT',
      message: 'Removing your account credentials.',
    );
    try {
      await account.deleteAccount(currentPassword: result.currentPassword);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack('Account deleted.');
    } on AccountException catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack(error.message, isError: true);
    }
  }

  Future<void> _signOutAccount(AccountService account) async {
    try {
      await account.signOut();
      _showTransferSnack('Signed out.');
    } on AccountException catch (error) {
      _showTransferSnack(error.message, isError: true);
    }
  }

  Future<void> _exportSave() async {
    if (_saveTransferBusy) return;
    final account = context.read<AccountService>();
    final session = context.read<AccountSessionService>();
    if (!account.isSignedIn) {
      _showTransferSnack(
        'Sign in with an account before backing up this save.',
        isError: true,
      );
      return;
    }
    if (!session.state.activeOnThisDevice) {
      _showTransferSnack(
        'This device is not the active device for the signed-in account.',
        isError: true,
      );
      return;
    }
    setState(() => _saveTransferBusy = true);
    _showProgressDialog(
      title: 'BACKING UP SAVE',
      message: 'Uploading this device save to your account.',
    );

    try {
      final db = context.read<AlchemonsDatabase>();
      final cloudSave = context.read<AccountCloudSaveService>();
      final transfer = SaveTransferService(db);
      final saveCode = await transfer.exportSaveCode(
        ownerAccountId: account.user!.uid,
      );
      final snapshot = await cloudSave.uploadSave(
        uid: account.user!.uid,
        sourceDeviceId: session.deviceId!,
        saveCode: saveCode,
      );
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      _showTransferSnack(
        'Account backup uploaded${snapshot.revision > 0 ? ' (revision ${snapshot.revision})' : ''}. Sign into this account on another device and restore it there.',
      );
    } on SaveTransferException catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      _showTransferSnack(error.message, isError: true);
    } on AccountCloudSaveException catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      _showTransferSnack(error.message, isError: true);
    } catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      _showTransferSnack('Save export failed: $error', isError: true);
    } finally {
      if (mounted) setState(() => _saveTransferBusy = false);
    }
  }

  Future<void> _importSave() async {
    if (_saveTransferBusy) return;
    final account = context.read<AccountService>();
    final session = context.read<AccountSessionService>();
    if (!account.isSignedIn) {
      _showTransferSnack(
        'Sign in with an account before restoring a cloud save.',
        isError: true,
      );
      return;
    }
    final confirmed = await showBracketConfirm(
      context,
      palette: _palette,
      accent: _accent,
      title: 'RESTORE BACKUP?',
      message:
          'This replaces the save on this device with the latest backup from this account.',
      warning:
          'Progress on this device is lost unless it has been backed up somewhere else.',
      confirmLabel: 'RESTORE',
    );

    if (!confirmed || !mounted) return;

    setState(() => _saveTransferBusy = true);
    _showProgressDialog(
      title: 'RESTORING BACKUP',
      message:
          'Downloading the latest account save and moving this account here.',
    );
    try {
      final db = context.read<AlchemonsDatabase>();
      final cloudSave = context.read<AccountCloudSaveService>();
      await session.rotateCurrentDeviceId();
      final transferCode = await cloudSave.downloadSaveCode(account.user!.uid);
      final transfer = SaveTransferService(db);
      await transfer.importSaveCode(
        transferCode,
        ownerAccountId: account.user!.uid,
      );
      if (!mounted) return;
      await reloadStateAfterSaveRestore(context);
      await session.claimCurrentDevice(force: true);
      await session.refresh();
      await _reloadProfileState();
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      _showTransferSnack('Account backup restored. This device is now active.');
    } on SaveTransferException catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      _showTransferSnack(error.message, isError: true);
    } on AccountCloudSaveException catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      _showTransferSnack(error.message, isError: true);
    } catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      _showTransferSnack('Save import failed: $error', isError: true);
    } finally {
      if (mounted) setState(() => _saveTransferBusy = false);
    }
  }

  Future<void> _activateThisDevice(AccountSessionService session) async {
    final confirmed = await showBracketConfirm(
      context,
      palette: _palette,
      accent: _accent,
      title: 'USE THIS DEVICE?',
      message:
          'Account transfer stops working on the device that was active before.',
      confirmLabel: 'TAKE OVER',
    );

    if (!confirmed || !mounted) return;

    _showProgressDialog(
      title: 'ACTIVATING DEVICE',
      message: 'Marking this device as the only active device for the account.',
    );

    try {
      await session.rotateCurrentDeviceId();
      await session.claimCurrentDevice(force: true);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack('This device is now active for the account.');
    } on AccountSessionException catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack(error.message, isError: true);
    } catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack(
        'Could not activate this device: $error',
        isError: true,
      );
    }
  }

  void _showTransferSnack(String message, {bool isError = false}) {
    showAppSnack(message, isError: isError, fallbackContext: context);
  }

  void _showProgressDialog({required String title, required String message}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => PopScope(
        canPop: false,
        child: _DialogShell(
          title: title,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _accent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(message, style: _prose(context, _palette.ink)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<_CredentialDialogResult?> _showCredentialDialog({
    required String title,
    required String submitLabel,
    bool includeDisplayName = false,
  }) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nameController = TextEditingController();

    return showDialog<_CredentialDialogResult>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => _FormDialog(
        title: title,
        submitLabel: submitLabel,
        onSubmit: () => Navigator.pop(
          context,
          _CredentialDialogResult(
            email: emailController.text.trim(),
            password: passwordController.text,
            displayName: nameController.text.trim(),
          ),
        ),
        children: [
          if (includeDisplayName) ...[
            _FormField(controller: nameController, hint: 'Account name'),
            const SizedBox(height: 10),
          ],
          _FormField(
            controller: emailController,
            hint: 'Email',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          _FormField(
            controller: passwordController,
            hint: 'Password',
            secret: true,
          ),
        ],
      ),
    );
  }

  Future<_PasswordDialogResult?> _showPasswordDialog({
    required String title,
    required String submitLabel,
    required String message,
    bool includeNewPassword = false,
  }) async {
    final currentController = TextEditingController();
    final nextController = TextEditingController();

    return showDialog<_PasswordDialogResult>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => _FormDialog(
        title: title,
        message: message,
        submitLabel: submitLabel,
        onSubmit: () => Navigator.pop(
          context,
          _PasswordDialogResult(
            currentPassword: currentController.text,
            newPassword: nextController.text,
          ),
        ),
        children: [
          _FormField(
            controller: currentController,
            hint: 'Current password',
            secret: true,
          ),
          if (includeNewPassword) ...[
            const SizedBox(height: 10),
            _FormField(
              controller: nextController,
              hint: 'New password',
              secret: true,
            ),
          ],
        ],
      ),
    );
  }

  // ───────────────────────────── build ────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final factionTheme = context.watch<FactionTheme>();
    final audio = context.watch<AudioController>();
    final account = context.watch<AccountService>();
    final accountSession = context.watch<AccountSessionService>();
    final palette = BracketPalette.fromTheme(factionTheme);
    final accent = bracketReadableAccent(factionTheme);

    final faction = context.watch<FactionService>().current;
    final data = _data;
    final bottom = MediaQuery.paddingOf(context).bottom;
    if (faction != null) {
      _realmField ??= FactionRealmField(faction: faction);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _measureDock();
      });
    }

    return Scaffold(
      backgroundColor: palette.bg0,
      body: Stack(
        key: _stackKey,
        children: [
          ListView(
            controller: _scroll,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(bottom: bottom + 40),
            children: [
              if (faction == null)
                _BareHeader(
                  palette: palette,
                  onBack: () => Navigator.of(context).maybePop(),
                  onEncyclopedia: _openEncyclopedia,
                )
              else
                _DivisionHeader(
                  faction: faction,
                  discovered: data?.discoveredCount,
                  field: _realmField!,
                  realmKey: _realmKey,
                  realmIn: _realmIn,
                  reveal: _reveal,
                  palette: palette,
                  accent: accent,
                ),
              FadeTransition(
                opacity: _reveal,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (faction != null)
                        _Section(
                          label: 'DIVISION PERKS',
                          palette: palette,
                          children: [
                            for (final perk
                                in FactionService.catalog[faction]!.perks)
                              _PerkRow(
                                title: perk.title,
                                description: perk.description,
                                palette: palette,
                                accent: accent,
                              ),
                          ],
                        ),

                      _Section(
                        label: 'JOURNAL',
                        palette: palette,
                        children: [
                          const CampaignRewardsButton(
                            style: CampaignRewardsStyle.tile,
                          ),
                          _Row(
                            title: 'COSMIC NOTES',
                            palette: palette,
                            below: _buildCosmicHints(
                              palette,
                              accent,
                              data?.cosmicHints ?? const [],
                            ),
                          ),
                          _Row(
                            title: 'REPLAY INTRO',
                            description: 'Watch the opening story again',
                            palette: palette,
                            trailing: _QuietButton(
                              label: 'WATCH',
                              height: 36,
                              palette: palette,
                              accent: accent,
                              onTap: _replayStory,
                            ),
                          ),
                        ],
                      ),

                      _Section(
                        label: 'DISPLAY',
                        palette: palette,
                        children: [
                          _Row(
                            title: 'FONT',
                            description: 'The typeface for names and text',
                            palette: palette,
                            below: _FontChoice(
                              palette: palette,
                              accent: accent,
                            ),
                          ),
                          _Row(
                            title: 'VISUAL EFFECTS',
                            description:
                                'Performance trims the fusion, hatch and '
                                'harvest cinematics for slower phones',
                            palette: palette,
                            below: Opacity(
                              opacity: _cinematicQualityLoaded ? 1 : 0.45,
                              child: IgnorePointer(
                                ignoring: !_cinematicQualityLoaded,
                                child: _Choice<CinematicQuality>(
                                  options: const [
                                    (CinematicQuality.cinematic, 'CINEMATIC'),
                                    (
                                      CinematicQuality.performance,
                                      'PERFORMANCE',
                                    ),
                                  ],
                                  value: _cinematicQuality,
                                  onChanged: _setCinematicQuality,
                                  palette: palette,
                                  accent: accent,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      _Section(
                        label: 'SOUND',
                        palette: palette,
                        children: [
                          BracketToggleRow(
                            title: 'ALL SOUND',
                            description: 'Music and sound effects together',
                            value: audio.masterEnabled,
                            enabled: audio.isLoaded,
                            onChanged: audio.setMasterEnabled,
                            palette: palette,
                            accent: accent,
                          ),
                          BracketToggleRow(
                            title: 'MUSIC',
                            description: 'Background tracks',
                            value: audio.musicEnabled,
                            enabled: audio.isLoaded,
                            onChanged: audio.setMusicEnabled,
                            palette: palette,
                            accent: accent,
                          ),
                          BracketToggleRow(
                            title: 'SOUND EFFECTS',
                            description: 'Taps, alchemy and creatures',
                            value: audio.soundsEnabled,
                            enabled: audio.isLoaded,
                            onChanged: audio.setSoundsEnabled,
                            palette: palette,
                            accent: accent,
                          ),
                          BracketToggleRow(
                            title: 'HAPTICS',
                            description:
                                'Vibration when you act, get hit or earn a star',
                            value: audio.hapticsEnabled,
                            enabled: audio.isLoaded,
                            onChanged: audio.setHapticsEnabled,
                            palette: palette,
                            accent: accent,
                          ),
                        ],
                      ),

                      _Section(
                        label: 'NOTIFICATIONS',
                        palette: palette,
                        children: [
                          BracketToggleRow(
                            title: 'CULTIVATIONS',
                            description: 'When a vial is ready to extract',
                            value: _cultivationsEnabled,
                            enabled: _notificationPrefsLoaded,
                            onChanged: _toggleCultivations,
                            palette: palette,
                            accent: accent,
                          ),
                          BracketToggleRow(
                            title: 'WILDERNESS',
                            description: 'When wild Alchemons appear',
                            value: _wildernessEnabled,
                            enabled: _notificationPrefsLoaded,
                            onChanged: _toggleWilderness,
                            palette: palette,
                            accent: accent,
                          ),
                          BracketToggleRow(
                            title: 'EXTRACTIONS',
                            description: 'When a biome harvest finishes',
                            value: _extractionsEnabled,
                            enabled: _notificationPrefsLoaded,
                            onChanged: _toggleExtractions,
                            palette: palette,
                            accent: accent,
                          ),
                        ],
                      ),

                      _Section(
                        label: 'ACCOUNT',
                        palette: palette,
                        children: [
                          _accountRow(account, accountSession, palette, accent),
                          _cloudSaveRow(
                            account,
                            accountSession,
                            palette,
                            accent,
                          ),
                        ],
                      ),

                      _Section(
                        label: 'FRESH START',
                        palette: palette,
                        children: [
                          _Row(
                            title: 'RESET PROGRESS',
                            description:
                                'Start a new game. Your account and verified '
                                'gold purchases are kept.',
                            palette: palette,
                            trailing: _QuietButton(
                              label: _resetBusy ? 'CHECKING…' : 'RESET',
                              enabled: !_resetBusy,
                              palette: palette,
                              accent: accent,
                              onTap: _resetProgress,
                            ),
                          ),
                        ],
                      ),

                      _Section(
                        label: 'DEVELOPER',
                        palette: palette,
                        children: [
                          BracketToggleRow(
                            title: 'DEBUG TOOLS',
                            description:
                                'Testing shortcuts in the cosmos: unseal a '
                                'gate, and descend with a planet\'s ideal trio',
                            value: _debugToolsEnabled,
                            enabled: _debugToolsLoaded,
                            onChanged: _setDebugTools,
                            palette: palette,
                            accent: accent,
                          ),
                          // Gated on the switch above rather than on
                          // DebugSettingsService.toolsVisible: these rows sit
                          // directly under the control that governs them, so
                          // appearing in a debug build with the switch OFF
                          // would read as the switch being broken.
                          if (_debugToolsEnabled) ...[
                            BracketToggleRow(
                              title: 'FREE SHOP',
                              description:
                                  'Every shop purchase costs nothing while the '
                                  'debug tools are on',
                              value: _freeShop,
                              enabled: _debugToolsLoaded,
                              onChanged: _setFreeShop,
                              palette: palette,
                              accent: accent,
                            ),
                            // Re-reads the setting when a fusion spends it, so
                            // the row goes back to OFF on its own.
                            ValueListenableBuilder<String?>(
                              valueListenable: DebugSettingsService
                                  .forcedWildMutationNotifier,
                              builder: (context, forced, _) => _Row(
                                title: 'WILD MUTATION',
                                description:
                                    'The next successful wilderness fusion '
                                    'comes out mutated, then this turns off',
                                palette: palette,
                                trailing: _WildMutationSelector(
                                  palette: palette,
                                  accent: accent,
                                  value: forced,
                                  enabled: _debugToolsLoaded,
                                  onChanged: _setForcedMutation,
                                ),
                              ),
                            ),
                            for (final tool in _debugActions())
                              _Row(
                                title: tool.title,
                                description: tool.description,
                                palette: palette,
                                trailing: _QuietButton(
                                  label: tool.action,
                                  height: 34,
                                  palette: palette,
                                  accent: accent,
                                  onTap: tool.onTap,
                                ),
                              ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (faction != null) ...[
            _TopBar(
              scroll: _scroll,
              dockKey: _dockKey,
              palette: palette,
              accent: accent,
              onBack: () => Navigator.of(context).maybePop(),
              onEncyclopedia: _openEncyclopedia,
            ),
            _DockingOrb(
              faction: faction,
              scroll: _scroll,
              dock: _dock,
              pool: _reveal,
              accent: accent,
            ),
          ],
        ],
      ),
    );
  }

  Widget _accountRow(
    AccountService account,
    AccountSessionService session,
    BracketPalette palette,
    Color accent,
  ) {
    if (!account.initialized) {
      return _Row(
        title: 'TRANSFER ACCOUNT',
        description: 'Loading account services…',
        palette: palette,
      );
    }
    if (!account.isConfigured) {
      return _Row(
        title: 'TRANSFER ACCOUNT',
        description:
            account.configurationError ??
            'Firebase Auth is not configured yet.',
        palette: palette,
      );
    }
    if (!account.isSignedIn) {
      return _Row(
        title: 'TRANSFER ACCOUNT',
        description:
            'Sign in to move your save between devices. The account is only '
            'used for transfer and recovery.',
        palette: palette,
        below: Row(
          children: [
            Expanded(
              child: BracketButton(
                label: 'SIGN IN',
                height: 40,
                palette: palette,
                accent: accent,
                onTap: _signInAccount,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuietButton(
                label: 'CREATE ACCOUNT',
                height: 40,
                palette: palette,
                accent: accent,
                onTap: _createAccount,
              ),
            ),
          ],
        ),
      );
    }

    final activeHere = session.state.activeOnThisDevice;
    return _Row(
      title: 'TRANSFER ACCOUNT',
      palette: palette,
      below: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Reading(label: 'NAME', value: account.displayName, palette: palette),
          _Reading(label: 'EMAIL', value: account.email, palette: palette),
          _Reading(
            label: 'THIS DEVICE',
            value: activeHere
                ? 'Active · playing the account save'
                : 'Not active · playing its local save',
            palette: palette,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Each as wide as its word: a wrap would stretch them.
              for (final button in [
                if (!activeHere)
                  BracketButton(
                    label: 'USE THIS DEVICE',
                    height: 36,
                    palette: palette,
                    accent: accent,
                    onTap: () => _activateThisDevice(session),
                  ),
                _QuietButton(
                  label: 'RENAME',
                  palette: palette,
                  accent: accent,
                  onTap: () => _renameAccount(account),
                ),
                _QuietButton(
                  label: 'PASSWORD',
                  palette: palette,
                  accent: accent,
                  onTap: () => _changePassword(account),
                ),
                _QuietButton(
                  label: 'SIGN OUT',
                  palette: palette,
                  accent: accent,
                  onTap: () => _signOutAccount(account),
                ),
                _QuietButton(
                  label: 'DELETE ACCOUNT',
                  palette: palette,
                  accent: accent,
                  onTap: () => _deleteAccount(account),
                ),
              ])
                IntrinsicWidth(child: button),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cloudSaveRow(
    AccountService account,
    AccountSessionService session,
    BracketPalette palette,
    Color accent,
  ) {
    final ready =
        !_saveTransferBusy &&
        account.initialized &&
        account.isConfigured &&
        account.isSignedIn;
    final canBackUp = ready && session.state.activeOnThisDevice;
    return _Row(
      title: 'CLOUD SAVE',
      description: !account.isSignedIn
          ? 'Sign in to back up or restore a save.'
          : !session.state.activeOnThisDevice
          ? 'This account is active on another device. You can keep playing '
                'the local save here, restore the account backup onto this '
                'device, or make this device the active one.'
          : 'Back up this save to your account, then restore it on another '
                'device. Restoring replaces that device\'s save.',
      palette: palette,
      below: Row(
        children: [
          Expanded(
            child: canBackUp
                ? BracketButton(
                    label: _saveTransferBusy ? 'WORKING…' : 'BACK UP',
                    height: 40,
                    palette: palette,
                    accent: accent,
                    onTap: _exportSave,
                  )
                : _QuietButton(
                    label: _saveTransferBusy ? 'WORKING…' : 'BACK UP',
                    height: 40,
                    enabled: false,
                    palette: palette,
                    accent: accent,
                    onTap: _exportSave,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuietButton(
              label: _saveTransferBusy ? 'WORKING…' : 'RESTORE',
              height: 40,
              enabled: ready,
              palette: palette,
              accent: accent,
              onTap: _importSave,
            ),
          ),
        ],
      ),
    );
  }

  List<_DebugAction> _debugActions() => [
    _DebugAction(
      'ALCHEMY',
      'Fusion puzzles in levels, chapter by chapter through the realms',
      'OPEN',
      _openAltars,
    ),
    _DebugAction(
      'DUNGEON DEBUG',
      'Drop straight into any of the ${kPlanetDungeonLayouts.length} built '
          'dungeons with its ideal trio',
      'OPEN',
      _openDungeonDebug,
    ),
    _DebugAction(
      'SKY STORM',
      'Replace the Sky\'s spawns with a batch that comes with a lightning '
          'storm',
      'BRING',
      () => _bringWeather('sky', WeatherKind.storm, 'The storm'),
    ),
    _DebugAction(
      'VALLEY RAIN',
      'Replace the Valley\'s spawns with a batch that comes with rain',
      'BRING',
      () => _bringWeather('valley', WeatherKind.rain, 'The rain'),
    ),
    _DebugAction(
      'VALLEY SNOW',
      'Replace the Valley\'s spawns with a batch that comes with snow',
      'BRING',
      () => _bringWeather('valley', WeatherKind.snow, 'The snow'),
    ),
    _DebugAction(
      'VALLEY RAINBOW',
      'Make the next clear visit to the Valley find a rainbow',
      'SET',
      () => _owedAftermath(
        'valley',
        'The next clear visit to the Valley has a rainbow',
      ),
    ),
    _DebugAction(
      'SWAMP DRY',
      'Replace the Swamp\'s spawns with a batch that finds it dried out',
      'BRING',
      () => _bringWeather('swamp', WeatherKind.dry, 'The dry spell'),
    ),
    _DebugAction(
      'ARCANE METEORS',
      'Replace the Arcane\'s spawns with a batch that comes with a meteor '
          'shower',
      'BRING',
      () => _bringWeather('arcane', WeatherKind.meteors, 'The meteor shower'),
    ),
    _DebugAction(
      'ARCANE AURORA',
      'Replace the Arcane\'s spawns with a batch that comes with the '
          'northern lights',
      'BRING',
      () => _bringWeather('arcane', WeatherKind.aurora, 'The northern lights'),
    ),
    _DebugAction(
      'TIDAL FOG',
      'Replace the Tidal Shelf\'s spawns with a batch that comes with sea '
          'fog',
      'BRING',
      () => _bringWeather('tidal', WeatherKind.fog, 'Sea fog'),
    ),
    _DebugAction(
      'TIDAL SWELL',
      'Replace the Tidal Shelf\'s spawns with a batch that comes with a '
          'swell',
      'BRING',
      () => _bringWeather('tidal', WeatherKind.swell, 'A swell'),
    ),
    _DebugAction(
      'TIDAL SHELLS',
      'Make the next clear visit to the Tidal Shelf show what a swell left',
      'SET',
      () => _owedAftermath(
        'tidal',
        'The next clear visit to the Tidal Shelf shows what the swell left',
      ),
    ),
    _DebugAction(
      'GEODE FROSTFALL',
      'Replace Geode Hollow\'s spawns with a batch that comes with a '
          'frostfall',
      'BRING',
      () => _bringWeather('geode', WeatherKind.frostfall, 'A frostfall'),
    ),
    _DebugAction(
      'GEODE RIME',
      'Make the next clear visit to Geode Hollow show the rime after a '
          'frostfall',
      'SET',
      () => _owedAftermath(
        'geode',
        'The next clear visit to Geode Hollow shows the rime',
      ),
    ),
    _DebugAction(
      'DUNES SANDSTORM',
      'Replace the Glass Dunes\' spawns with a batch that comes with a '
          'sandstorm',
      'BRING',
      () => _bringWeather('dunes', WeatherKind.sandstorm, 'A sandstorm'),
    ),
    _DebugAction(
      'DUNES GLASS',
      'Make the next clear visit to the Glass Dunes show the glass after a '
          'storm',
      'SET',
      () => _owedAftermath(
        'dunes',
        'The next clear visit to the Glass Dunes shows the glass',
      ),
    ),
    _DebugAction(
      'VOLCANO STAGE',
      'Move the Volcano on a visit: quiet twice, smoking twice, then '
          'erupting',
      'NEXT',
      _advanceVolcano,
    ),
    _DebugAction(
      'FACTION TEST',
      'Reopen the picker and switch faction for free — the only way to '
          'watch the commit animation more than once per save',
      'PICK',
      _openFactionTester,
    ),
  ];
}

class _DebugAction {
  const _DebugAction(this.title, this.description, this.action, this.onTap);
  final String title;
  final String description;
  final String action;
  final VoidCallback onTap;
}

// ──────────────────────────────────────────────────────────────────────────────
// HEADER
// ──────────────────────────────────────────────────────────────────────────────

/// The division, in the realm the player chose it by: the home screen's
/// own living grains across the top, fading into the page, and under the
/// orb (which [_DockingOrb] draws, above the scroll) the name, the creed
/// and the count, set as the picker set them. The realm at rest is one
/// recorded picture a frame; a finger stirs it, as on home.
///
/// Its height must not change once the realm has poured out — a new size
/// recomposes the realm — so the count holds its line while it loads.
class _DivisionHeader extends StatelessWidget {
  const _DivisionHeader({
    required this.faction,
    required this.discovered,
    required this.field,
    required this.realmKey,
    required this.realmIn,
    required this.reveal,
    required this.palette,
    required this.accent,
  });

  final FactionId faction;
  final int? discovered;
  final FactionRealmField field;
  final GlobalKey realmKey;
  final Animation<double> realmIn;
  final Animation<double> reveal;
  final BracketPalette palette;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final info = FactionService.catalog[faction]!;
    final top = MediaQuery.paddingOf(context).top;
    final shadow = [
      Shadow(color: palette.bg0.withValues(alpha: 0.9), blurRadius: 12),
    ];

    return Stack(
      children: [
        Positioned.fill(
          child: FadeTransition(
            opacity: realmIn,
            child: RepaintBoundary(
              child: FactionRealmView(
                key: realmKey,
                faction: faction,
                field: field,
              ),
            ),
          ),
        ),
        // The realm fades into the page rather than ending on a line.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 110,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    palette.bg0.withValues(alpha: 0),
                    palette.bg0.withValues(alpha: 0.7),
                    palette.bg0,
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, top + _kOrbSlotTop, 16, 6),
          child: IgnorePointer(
            child: Column(
              children: [
                // The orb's place; it is drawn above the scroll.
                SizedBox.fromSize(size: _kOrbSlot),
                FadeTransition(
                  opacity: reveal,
                  child: Column(
                    children: [
                      Text(
                        info.name,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cinzel(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: accent,
                          letterSpacing: 1.2,
                          shadows: shadow,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'DIVISION',
                        style: _mono(
                          10.5,
                          palette.muted,
                          weight: FontWeight.w700,
                        ).copyWith(letterSpacing: 4),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          info.philosophy,
                          textAlign: TextAlign.center,
                          style: _prose(context, palette.ink, size: 14.5)
                              .copyWith(
                                fontStyle: FontStyle.italic,
                                height: 1.45,
                                shadows: shadow,
                              ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: discovered == null ? '·' : '$discovered',
                              style: _mono(
                                14,
                                palette.ink,
                                weight: FontWeight.w900,
                              ),
                            ),
                            TextSpan(
                              text: '  SPECIES DISCOVERED',
                              style: _mono(10.5, palette.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Back and the encyclopedia, held at the top while the page scrolls
/// under them, with the place the orb docks between. Clear over the realm;
/// as the orb comes up to dock it gathers a ground of the page's black, so
/// what scrolls under it goes dark rather than showing through.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.scroll,
    required this.dockKey,
    required this.palette,
    required this.accent,
    required this.onBack,
    required this.onEncyclopedia,
  });

  final ScrollController scroll;
  final GlobalKey dockKey;
  final BracketPalette palette;
  final Color accent;
  final VoidCallback onBack;
  final VoidCallback onEncyclopedia;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final height = top + 10 + 38 + 10;
    final row = Padding(
      padding: EdgeInsets.fromLTRB(16, top + 10, 16, 0),
      child: Row(
        children: [
          BracketIconButton(
            icon: AppIcons.arrow_back_rounded,
            onTap: onBack,
            palette: palette,
          ),
          const Spacer(),
          SizedBox.square(key: dockKey, dimension: 38),
          const SizedBox(width: 10),
          _QuietButton(
            label: 'ENCYCLOPEDIA',
            height: 38,
            palette: palette,
            accent: accent,
            onTap: onEncyclopedia,
          ),
        ],
      ),
    );
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: scroll,
            builder: (context, _) {
              final offset = scroll.hasClients ? scroll.offset : 0.0;
              final a = Curves.easeInOut.transform(
                ((offset - 40) / 80).clamp(0.0, 1.0),
              );
              if (a == 0) return const SizedBox.shrink();
              return IgnorePointer(
                child: Column(
                  children: [
                    Container(
                      height: height,
                      color: palette.bg0.withValues(alpha: 0.96 * a),
                    ),
                    // A soft edge, not a rule.
                    Container(
                      height: 18,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            palette.bg0.withValues(alpha: 0.96 * a),
                            palette.bg0.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          row,
        ],
      ),
    );
  }
}

/// The division's starter orb, above the scroll. At the top of the page it
/// stands in the header in a pool of the division's light; scrolled, it
/// rides up with the page, shrinks and slides into its place in the top
/// bar beside the encyclopedia, and stays there. The orb is drawn at one
/// size and scaled, so its grains are never re-laid out on the way.
class _DockingOrb extends StatelessWidget {
  const _DockingOrb({
    required this.faction,
    required this.scroll,
    required this.dock,
    required this.pool,
    required this.accent,
  });

  final FactionId faction;
  final ScrollController scroll;

  /// Its place in the top bar, once the bar has been laid out.
  final ValueListenable<Offset?> dock;

  /// The light under it comes up once it has landed.
  final Animation<double> pool;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final group = ElementalGroup.values.byName(faction.name);
    final orb = Hero(
      tag: kDivisionOrbHeroTag,
      child: ExtractionVialOrb(
        vial: ExtractionVial(
          price: null,
          id: 'starter_${group.name}',
          name: 'STARTER VIAL',
          group: group,
          rarity: VialRarity.uncommon,
          quantity: 1,
        ),
        size: _kOrbSize,
      ),
    );
    final light = DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            accent.withValues(alpha: 0.2),
            accent.withValues(alpha: 0.06),
            accent.withValues(alpha: 0),
          ],
          stops: const [0, 0.5, 1],
        ),
      ),
      child: SizedBox.fromSize(size: _kOrbSlot),
    );

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, box) {
          final top = MediaQuery.paddingOf(context).top;
          final home = Offset(
            box.maxWidth / 2,
            top + _kOrbSlotTop + _kOrbSlot.height / 2,
          );
          return Stack(
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([scroll, pool, dock]),
                builder: (context, _) {
                  final offset = scroll.hasClients ? scroll.offset : 0.0;
                  final dock =
                      this.dock.value ??
                      Offset(box.maxWidth - 172, top + 10 + 19);
                  // Docked once its place in the header would pass the bar's.
                  final reach = math.max(1.0, home.dy - dock.dy);
                  final t = Curves.easeInOut.transform(
                    (offset / reach).clamp(0.0, 1.0),
                  );
                  final centre = Offset(
                    home.dx + (dock.dx - home.dx) * t,
                    (home.dy - offset) + (dock.dy - (home.dy - offset)) * t,
                  );
                  final scale = 1 + (_kDockScale - 1) * t;
                  return Positioned(
                    left: centre.dx - _kOrbSlot.width / 2,
                    top: centre.dy - _kOrbSlot.height / 2,
                    width: _kOrbSlot.width,
                    height: _kOrbSlot.height,
                    child: IgnorePointer(
                      child: Transform.scale(
                        scale: scale,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: (pool.value * (1 - 0.7 * t)).clamp(
                                0.0,
                                1.0,
                              ),
                              child: light,
                            ),
                            orb,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// No division yet (a save mid-way through the opening): just the way out.
class _BareHeader extends StatelessWidget {
  const _BareHeader({
    required this.palette,
    required this.onBack,
    required this.onEncyclopedia,
  });

  final BracketPalette palette;
  final VoidCallback onBack;
  final VoidCallback onEncyclopedia;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top + 10, 16, 6),
      child: Row(
        children: [
          BracketIconButton(
            icon: AppIcons.arrow_back_rounded,
            onTap: onBack,
            palette: palette,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('PROFILE', style: _mono(13, palette.ink))),
          _QuietButton(
            label: 'ENCYCLOPEDIA',
            height: 38,
            palette: palette,
            accent: palette.line,
            onTap: onEncyclopedia,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// SECTIONS AND ROWS
// ──────────────────────────────────────────────────────────────────────────────

/// A head and a plain panel of rows, hairlines between them.
class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.palette,
    required this.children,
  });

  final String label;
  final BracketPalette palette;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 26, 2, 9),
          child: Text(
            label,
            style: _mono(10.5, palette.muted).copyWith(letterSpacing: 2.4),
          ),
        ),
        ColoredBox(
          color: palette.bg1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Container(
                    height: 1,
                    margin: const EdgeInsets.only(left: 14),
                    color: palette.lineSoft,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A setting: its name, what it does, and its control — beside it when
/// small, under it when wide.
class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.palette,
    this.description,
    this.trailing,
    this.below,
  });

  final String title;
  final String? description;
  final BracketPalette palette;
  final Widget? trailing;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _mono(11.5, palette.ink)),
                    if (description != null) ...[
                      const SizedBox(height: 4),
                      Text(description!, style: _prose(context, palette.muted)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
          if (below != null) ...[const SizedBox(height: 12), below!],
        ],
      ),
    );
  }
}

/// The other kind of button, sunk into its panel as a darker well: the
/// kit's quiet fill alone is the panel's own color.
class _QuietButton extends StatelessWidget {
  const _QuietButton({
    required this.label,
    required this.onTap,
    required this.palette,
    required this.accent,
    this.height = 36,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onTap;
  final BracketPalette palette;
  final Color accent;
  final double height;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: palette.bg0,
    child: BracketButton(
      label: label,
      onTap: onTap,
      palette: palette,
      accent: accent,
      height: height,
      enabled: enabled,
      primary: false,
    ),
  );
}

/// A few words to choose between, the chosen one lit from below.
class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.options,
    required this.value,
    required this.onChanged,
    required this.palette,
    required this.accent,
  });

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final BracketPalette palette;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _ChoiceCell(
              selected: options[i].$1 == value,
              palette: palette,
              accent: accent,
              onTap: () {
                if (options[i].$1 == value) return;
                HapticFeedback.selectionClick();
                onChanged(options[i].$1);
              },
              child: Text(
                options[i].$2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _mono(
                  11,
                  options[i].$1 == value ? palette.ink : palette.muted,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChoiceCell extends StatelessWidget {
  const _ChoiceCell({
    required this.selected,
    required this.palette,
    required this.accent,
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 10),
    this.fill = true,
  });

  final bool selected;
  final BracketPalette palette;
  final Color accent;
  final VoidCallback onTap;
  final Widget child;
  final EdgeInsets padding;

  /// Whether it takes the width it is given (a row of choices) or only its
  /// word's (a wrap of them).
  final bool fill;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: selected ? accent : palette.line,
          strokeWidth: 1.2,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 36,
          padding: padding,
          alignment: fill ? Alignment.center : null,
          color: selected
              ? palette.accentWash(accent, darkAlpha: 0.18)
              : palette.bg0,
          child: fill ? child : Center(widthFactor: 1, child: child),
        ),
      ),
    );
  }
}

/// Every typeface, each written in itself.
class _FontChoice extends StatelessWidget {
  const _FontChoice({required this.palette, required this.accent});

  final BracketPalette palette;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final current = context.watch<ThemeNotifier>().fontName;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final name in appFontMap.keys)
          _ChoiceCell(
            selected: name == current,
            palette: palette,
            accent: accent,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            fill: false,
            onTap: () {
              if (name == current) return;
              HapticFeedback.selectionClick();
              context.read<ThemeNotifier>().setFont(name);
            },
            child: Text(
              name,
              style: GoogleFonts.getFont(
                name,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: name == current ? palette.ink : palette.muted,
              ),
            ),
          ),
      ],
    );
  }
}

/// One perk: a diamond in the division's color, its name, what it gives.
class _PerkRow extends StatelessWidget {
  const _PerkRow({
    required this.title,
    required this.description,
    required this.palette,
    required this.accent,
  });

  final String title;
  final String description;
  final BracketPalette palette;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 12),
            child: Transform.rotate(
              angle: 0.785,
              child: Container(width: 6, height: 6, color: accent),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: _mono(11.5, accent)),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: _prose(context, palette.ink.withValues(alpha: 0.86)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A label over its value, for the account's name, email and device.
class _Reading extends StatelessWidget {
  const _Reading({
    required this.label,
    required this.value,
    required this.palette,
  });

  final String label;
  final String value;
  final BracketPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(label, style: _mono(9.5, palette.muted)),
            ),
          ),
          Expanded(
            child: Text(value, style: _prose(context, palette.ink, size: 13)),
          ),
        ],
      ),
    );
  }
}

/// OFF, or the mutation the next wilderness fusion is forced to.
class _WildMutationSelector extends StatelessWidget {
  const _WildMutationSelector({
    required this.palette,
    required this.accent,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final BracketPalette palette;
  final Color accent;
  final String? value;
  final bool enabled;
  final Future<void> Function(String? id) onChanged;

  static const _off = 'off';

  @override
  Widget build(BuildContext context) {
    final current = AlchemonMutation.byId(value)?.id ?? _off;
    final items = <(String, String)>[
      (_off, 'OFF'),
      for (final m in AlchemonMutation.values) (m.id, m.label.toUpperCase()),
    ];
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Container(
        padding: const EdgeInsets.only(left: 10, right: 4),
        color: current == _off
            ? palette.bg0
            : palette.accentWash(accent, darkAlpha: 0.18),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: current,
            icon: Icon(AppIcons.arrow_drop_down, color: palette.muted),
            dropdownColor: palette.bg1,
            isDense: true,
            onChanged: enabled
                ? (next) {
                    if (next == null) return;
                    HapticFeedback.selectionClick();
                    onChanged(next == _off ? null : next);
                  }
                : null,
            items: [
              for (final (id, label) in items)
                DropdownMenuItem<String>(
                  value: id,
                  child: Text(label, style: _mono(11, palette.ink)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// DIALOGS
// ──────────────────────────────────────────────────────────────────────────────

/// The frame every dialog here shares: the confirm dialog's dark glass.
class _DialogShell extends StatelessWidget {
  const _DialogShell({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        color: palette.bg1,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: _mono(14, palette.ink).copyWith(letterSpacing: 1.8),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _FormDialog extends StatelessWidget {
  const _FormDialog({
    required this.title,
    required this.submitLabel,
    required this.onSubmit,
    required this.children,
    this.message,
  });

  final String title;
  final String? message;
  final String submitLabel;
  final VoidCallback onSubmit;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final palette = BracketPalette.fromTheme(theme);
    final accent = bracketReadableAccent(theme);
    return _DialogShell(
      title: title,
      children: [
        if (message != null) ...[
          Text(message!, style: _prose(context, palette.ink, size: 13.5)),
          const SizedBox(height: 14),
        ],
        ...children,
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _QuietButton(
                label: 'CANCEL',
                height: 42,
                palette: palette,
                accent: accent,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BracketButton(
                label: submitLabel,
                height: 42,
                palette: palette,
                accent: accent,
                onTap: onSubmit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A text field sunk into the dialog: a darker well, its hint in the book
/// face, and a lit edge under it while it has the cursor.
class _FormField extends StatefulWidget {
  const _FormField({
    required this.controller,
    required this.hint,
    this.secret = false,
    this.autofocus = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final bool secret;
  final bool autofocus;
  final TextInputType? keyboardType;

  @override
  State<_FormField> createState() => _FormFieldState();
}

class _FormFieldState extends State<_FormField> {
  late bool _hidden = widget.secret;

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final palette = BracketPalette.fromTheme(theme);
    final accent = bracketReadableAccent(theme);
    final edge = UnderlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: palette.bg0, width: 1.5),
    );
    return TextField(
      controller: widget.controller,
      obscureText: _hidden,
      autofocus: widget.autofocus,
      autocorrect: false,
      keyboardType: widget.keyboardType,
      cursorColor: accent,
      style: _prose(context, palette.ink, size: 14),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: _prose(context, palette.muted, size: 14),
        filled: true,
        fillColor: palette.bg0,
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(12, 13, 12, 13),
        border: edge,
        enabledBorder: edge,
        focusedBorder: edge.copyWith(
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        suffixIcon: widget.secret
            ? IconButton(
                onPressed: context.soundAction(
                  () => setState(() => _hidden = !_hidden),
                ),
                icon: Icon(
                  _hidden
                      ? AppIcons.visibility_rounded
                      : AppIcons.visibility_off_rounded,
                  size: 18,
                  color: palette.muted,
                ),
              )
            : null,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// DATA
// ──────────────────────────────────────────────────────────────────────────────

class _ProfileData {
  final FactionId? faction;
  final int discoveredCount;
  final List<CosmicContestHintLore> cosmicHints;
  const _ProfileData(this.faction, this.discoveredCount, this.cosmicHints);
}

class _CredentialDialogResult {
  final String email;
  final String password;
  final String displayName;

  const _CredentialDialogResult({
    required this.email,
    required this.password,
    this.displayName = '',
  });
}

class _PasswordDialogResult {
  final String currentPassword;
  final String newPassword;

  const _PasswordDialogResult({
    required this.currentPassword,
    this.newPassword = '',
  });
}
