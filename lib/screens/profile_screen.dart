// lib/screens/profile_screen.dart
//
// The profile: who you are, then how the game is set up.
//
//   Your division, as the realm you chose it by — its living grains across
//   the top, the starter orb, the name, the title worn and its creed — then
//   the cosmetics worn for the whole game (title, dock, fusion), its perks,
//   friends, the journal, display, sound, notifications, your account and
//   save, a fresh start, and the developer switches.
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
import 'package:alchemons/games/cosmic/cosmic_data.dart'
    show kBloodPlanetElement, kPolishedDungeons;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_screen.dart';
import 'package:alchemons/screens/story/blood_finale.dart';
import 'package:alchemons/games/wilderness/field/grain_field.dart'
    show VolcanoField;
import 'package:alchemons/models/dock_sets.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/models/profile_titles.dart';
import 'package:alchemons/models/scenes/volcano/volcano_scene.dart';
import 'package:alchemons/models/wild_fusion.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/screens/battle/battle_screen.dart';
import 'package:alchemons/screens/stadium/stadium_screen.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/screens/alchemical_encyclopedia_screen.dart';
import 'package:alchemons/screens/debug/ability_lab_screen.dart';
import 'package:alchemons/screens/debug/bloodborn_vial_debug_screen.dart';
import 'package:alchemons/screens/debug/dungeon_debug_screen.dart';
import 'package:alchemons/screens/heart_puzzle/altar_levels_screen.dart';
import 'package:alchemons/screens/faction_picker.dart';
import 'package:alchemons/screens/friends/friends_panel.dart';
import 'package:alchemons/screens/story/story_intro_screen.dart';
import 'package:alchemons/services/account_cloud_save_service.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/account_session_service.dart';
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:alchemons/services/debug_settings_service.dart';
import 'package:alchemons/services/device_identity_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/friend_service.dart';
import 'package:alchemons/services/trade_service.dart';
import 'package:alchemons/services/mobile_store_service.dart';
import 'package:alchemons/services/notification_preferences_service.dart';
import 'package:alchemons/services/onboarding_tasks.dart';
import 'package:alchemons/services/progress_reset_service.dart';
import 'package:alchemons/services/push_notification_service.dart';
import 'package:alchemons/services/save_generation_service.dart';
import 'package:alchemons/services/save_restore_reload_service.dart';
import 'package:alchemons/services/account_sign_in.dart';
import 'package:alchemons/services/cloud_autosave_service.dart';
import 'package:alchemons/services/save_transfer_service.dart';
import 'package:alchemons/services/wilderness_spawn_service.dart';
import 'package:alchemons/utils/app_scaffold_messenger.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/avatar_widget.dart';
import 'package:alchemons/widgets/background/faction_realm.dart';
import 'package:alchemons/services/cosmetic_wear_service.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/nav_emblems.dart';
import 'package:alchemons/widgets/campaign_rewards_button.dart';
import 'package:alchemons/widgets/choice_strip.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:alchemons/widgets/fusion_style_choice.dart';
import 'package:alchemons/widgets/reset_progress_dialog.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:alchemons/widgets/grain_loader.dart';

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

/// "4 minutes ago": when the game last went up to the account.
String _savedAgo(DateTime at) {
  final d = DateTime.now().difference(at);
  String ago(int n, String unit) => '$n $unit${n == 1 ? '' : 's'} ago';
  if (d.inMinutes < 1) return 'Just now';
  if (d.inHours < 1) return ago(d.inMinutes, 'minute');
  if (d.inDays < 1) return ago(d.inHours, 'hour');
  return ago(d.inDays, 'day');
}

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

  /// The account this device's game belongs to (null: a guest game).
  String? _saveOwner;

  /// Signed in, but the game on this device is another account's: it can't
  /// be made active, backed up or bought into from this account.
  bool _ownedElsewhere(AccountService account) =>
      _saveOwner != null &&
      account.user != null &&
      account.user!.uid != _saveOwner;

  Future<void> _loadSaveOwner() async {
    final owner = await SaveGenerationService.owner(
      context.read<AlchemonsDatabase>(),
    );
    if (mounted) setState(() => _saveOwner = owner);
  }

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
    _loadSaveOwner();
    DebugSettingsService.allowedNotifier.addListener(_onDebugToolsAllowed);
  }

  /// Signing in or out of a developer's account shows or hides the
  /// DEVELOPER section, and the switch takes effect with it.
  void _onDebugToolsAllowed() {
    if (!mounted) return;
    setState(() => _debugToolsEnabled = DebugSettingsService.toolsVisible);
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
    DebugSettingsService.allowedNotifier.removeListener(_onDebugToolsAllowed);
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
    if (mounted) {
      setState(() {
        _data = data;
        _lastMadeTitle ??= data.titles.wornMade;
      });
    }
  }

  BracketPalette get _palette =>
      BracketPalette.fromTheme(context.read<FactionTheme>());

  Color get _accent => bracketReadableAccent(context.read<FactionTheme>());

  Future<_ProfileData> _fetch() async {
    final svc = context.read<FactionService>();
    final db = context.read<AlchemonsDatabase>();
    final fid = svc.current;
    final titles = await ProfileTitles.load(db);
    final prefs = await SharedPreferences.getInstance();
    final noteIds = deserialiseContestHintIds(
      prefs.getString('cosmic_trait_hint_notes_v1') ?? '',
    );
    final cosmicHints = kCosmicContestHintLore
        .where((h) => noteIds.contains(h.id))
        .toList();

    if (fid == null) return _ProfileData(null, 0, cosmicHints, titles);
    final discovered = await svc.discoveredCount();
    return _ProfileData(fid, discovered, cosmicHints, titles);
  }

  /// Wears [id] under the name, or nothing for null.
  Future<void> _wearTitle(String? id) async {
    final data = _data;
    if (data == null) return;
    final db = context.read<AlchemonsDatabase>();
    if (!await ProfileTitles.wear(db, id)) return;
    final titles = await ProfileTitles.load(db);
    if (!mounted) return;
    setState(() {
      _data = data.withTitles(titles);
      _lastMadeTitle = titles.wornMade ?? _lastMadeTitle;
    });
  }

  /// The colour and word last worn together, so choosing an earned title
  /// and then a colour comes back to the same word.
  MadeTitle? _lastMadeTitle;

  /// The title popup; wears what it comes back with (no title, too), and
  /// nothing changes if it is closed.
  Future<void> _chooseTitle(List<(String, String)> earned) async {
    final data = _data;
    if (data == null) return;
    final picked = await showDialog<({String? id})>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => _TitleDialog(
        earned: earned,
        worn: data.titles.worn,
        lastMade: _lastMadeTitle,
      ),
    );
    if (picked == null || picked.id == data.titles.worn) return;
    await _wearTitle(picked.id);
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

  Future<void> _openAbilityLab() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AbilityLabScreen()),
    );
  }

  /// The first descent's cinematic again, over a planet picked at random
  /// (any finished one but Blood, the last), with the space party. It is
  /// the real descent's page: the portal is its loading screen while the
  /// realms are pictured, then the run goes on as any run does. Seeing it
  /// again is not saved.
  Future<void> _playFirstDescent() async {
    HapticFeedback.mediumImpact();
    final party = await stadiumPartyFromSave(context);
    if (!mounted) return;
    if (party.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Alchemons to take down with you.')),
      );
      return;
    }
    final planets = [
      for (final e in kPolishedDungeons)
        if (e != kBloodPlanetElement && kPlanetDungeonLayouts.containsKey(e)) e,
    ];
    final element = planets[math.Random().nextInt(planets.length)];
    final ready = ValueNotifier<bool>(false);
    final revealed = ValueNotifier<bool>(false);
    // The portal opens onto the page once it is ready; the cinematic's
    // first seconds are the Valley alone, so it may begin as it opens.
    void shown() {
      if (ready.value) revealed.value = true;
    }

    ready.addListener(shown);
    await VoidPortal.pushThroughGlyphs<void>(
      context,
      page: PlanetDungeonScreen(
        element: element,
        party: party.take(3).toList(),
        replayReveal: true,
        revealReady: ready,
        revealed: revealed,
      ),
      title: kPlanetDungeonLayouts[element]?.descentTitle ?? element,
      label: 'DESCENDING',
      element: element,
      ready: ready,
      orientation: const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      returnOrientation: const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ],
    );
    ready.removeListener(shown);
    ready.dispose();
    revealed.dispose();
    if (!mounted) return;
    unawaited(context.read<AudioController>().playHomeMusic());
  }

  /// The finale again, after the Blood Ring's ritual: the space party's
  /// first Alchemon offered, the credits over the census of this save.
  /// Nothing happens to the Alchemon and nothing is saved.
  Future<void> _playFinale() async {
    HapticFeedback.mediumImpact();
    final party = await stadiumPartyFromSave(context);
    if (!mounted) return;
    if (party.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No Alchemons to offer.')));
      return;
    }
    await VoidPortal.pushThroughGlyphs<void>(
      context,
      page: BloodFinalePage(offering: party.first),
      title: 'The Blood Ring',
      label: 'ENTERING',
      element: 'Blood',
      orientation: const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      returnOrientation: const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ],
    );
    if (!mounted) return;
    unawaited(context.read<AudioController>().playHomeMusic());
  }

  /// The Bloodborn Vial and its extraction, for the space party's first
  /// Alchemon, without the ending. Not saved.
  Future<void> _openBloodbornVial() async {
    HapticFeedback.mediumImpact();
    final party = await stadiumPartyFromSave(context);
    if (!mounted) return;
    if (party.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No Alchemons to offer.')));
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BloodbornVialDebugScreen(instanceId: party.first.instanceId),
      ),
    );
  }

  Future<void> _openDungeonDebug() async {
    HapticFeedback.mediumImpact();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const DungeonDebugScreen()),
    );
  }

  /// The stadium, turned on its side as it is from space; home's music
  /// again after.
  Future<void> _openStadium() async {
    HapticFeedback.mediumImpact();
    final party = await stadiumPartyFromSave(context);
    if (!mounted) return;
    await VoidPortal.pushThroughGlyphs<void>(
      context,
      page: StadiumScreen(party: party),
      title: 'The Trials',
      element: 'Light',
    );
    if (!mounted) return;
    unawaited(context.read<AudioController>().playHomeMusic());
  }

  /// A battle against the computer; home's music again after.
  Future<void> _openBattle() async {
    HapticFeedback.mediumImpact();
    await openBattleAgainstComputer(context);
    if (!mounted) return;
    unawaited(context.read<AudioController>().playHomeMusic());
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
    await _loadSaveOwner();
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
        'None found yet. They drift in open space.',
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
    await _loadSaveOwner();
    if (!mounted) return;
    if (_saveOwner != null) {
      // A new account can't take over a game another account owns.
      _showTransferSnack(
        'The game on this device belongs to another account. Sign into that '
        'account to keep playing it, or reset progress to start a new game, '
        'then create your new account.',
        isError: true,
      );
      return;
    }
    final accountService = context.read<AccountService>();
    final sessionService = context.read<AccountSessionService>();
    final autosave = context.read<CloudAutosaveService>();
    final done = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => _CredentialDialog(
        title: 'CREATE ACCOUNT',
        submitLabel: 'CREATE',
        includeDisplayName: true,
        message:
            'The game on this device becomes the account\'s save, and saves '
            'to it from now on.',
        submit: (result) async {
          try {
            await accountService.createAccount(
              email: result.email,
              password: result.password,
              displayName: result.displayName,
            );
          } on AccountException catch (error) {
            return error.message;
          }
          try {
            await sessionService.claimCurrentDevice(force: true);
          } catch (error) {
            // Signed in should always mean this device plays the account.
            await accountService.signOut();
            return 'Your account was created, but this device could not be '
                'linked to it: $error Use SIGN IN to finish.';
          }
          return null;
        },
      ),
    );
    if (done != true || !mounted) return;
    unawaited(autosave.save());
    await _loadSaveOwner();
    _showTransferSnack('Account created. Your game now saves to it.');
  }

  static final Uri _privacyPolicyUrl = Uri.parse(
    'https://alchemons.com/privacy/',
  );

  Future<void> _openPrivacyPolicy() async {
    final opened = await launchUrl(
      _privacyPolicyUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      _showTransferSnack(
        'Couldn\'t open the browser. The policy is at alchemons.com/privacy.',
        isError: true,
      );
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
      await _loadSaveOwner();
      // Another account's game is reset locally only: the server reset belongs
      // to the account that owns the game. The fresh game is a guest game this
      // account can then make its own.
      final serverUid = _ownedElsewhere(account) ? null : uid;
      await store.pauseForReset();
      final preview = serverUid == null ? null : await reset.preview(deviceId);
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
        await reset.request(
          uid: serverUid,
          deviceId: deviceId,
          preview: preview,
        );
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
    SignInResult? signedIn;
    final done = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => _CredentialDialog(
        title: 'SIGN IN',
        submitLabel: 'SIGN IN',
        message:
            'Your account\'s save comes to this device, and this becomes the '
            'account\'s device.',
        warning:
            'If the account has a save, it replaces the game here. Progress '
            'on this device that isn\'t in that account is lost.',
        submit: (result) async {
          try {
            signedIn = await signInAndBringSave(
              context,
              email: result.email,
              password: result.password,
            );
            return null;
          } catch (error) {
            return signInErrorText(error);
          }
        },
      ),
    );
    if (done != true || !mounted) return;
    await _loadSaveOwner();
    if (signedIn == SignInResult.restored) await _reloadProfileState();
    _showTransferSnack(switch (signedIn) {
      SignInResult.restored => 'Your account\'s save is on this device now.',
      SignInResult.savedHere =>
        'Signed in. This game now saves to your account.',
      _ => 'Signed in.',
    });
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
      final friends = context.read<FriendService>();
      final trades = context.read<TradeService>();
      await account.deleteAccount(
        currentPassword: result.currentPassword,
        // What they have up on trade tables comes back, their planet and
        // home come down, and they leave every friend's list; a failure
        // there must not keep the account from going.
        beforeDelete: () async {
          await trades.forget().timeout(const Duration(seconds: 20)).catchError(
            (Object e) {
              debugPrint('Trades cleanup before account deletion failed: $e');
            },
          );
          await friends
              .forget()
              .timeout(const Duration(seconds: 20))
              .catchError((Object e) {
                debugPrint(
                  'Friends cleanup before account deletion failed: $e',
                );
              });
        },
      );
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack('Account deleted.');
    } on AccountException catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack(error.message, isError: true);
    }
  }

  Future<void> _signOutAccount(AccountService account) async {
    final autosave = context.read<CloudAutosaveService>();
    if (autosave.enabled) {
      _showProgressDialog(
        title: 'SIGNING OUT',
        message: 'Saving your game to your account first.',
      );
      final saved = await autosave.save();
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      if (!saved) {
        final confirmed = await showBracketConfirm(
          context,
          palette: _palette,
          accent: _kDanger,
          title: 'SIGN OUT WITHOUT SAVING?',
          message:
              autosave.error ?? 'Your game could not be saved to your account.',
          warning: 'Progress since the last save stays only on this device.',
          confirmLabel: 'SIGN OUT',
        );
        if (!confirmed || !mounted) return;
      }
    }
    try {
      await account.signOut();
      await _loadSaveOwner();
      _showTransferSnack('Signed out.');
    } on AccountException catch (error) {
      _showTransferSnack(error.message, isError: true);
    }
  }

  Future<void> _saveNow() async {
    final autosave = context.read<CloudAutosaveService>();
    final saved = await autosave.save(force: true);
    if (!mounted) return;
    _showTransferSnack(
      saved
          ? 'Saved to your account.'
          : autosave.error ?? 'Could not save to your account.',
      isError: !saved,
    );
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
      title: 'RESTORE HERE?',
      message:
          'This replaces the game on this device with the account\'s latest save, and makes this the account\'s device.',
      warning:
          'Progress on this device is lost unless it has been backed up somewhere else.',
      confirmLabel: 'RESTORE',
    );

    if (!confirmed || !mounted) return;

    setState(() => _saveTransferBusy = true);
    _showProgressDialog(
      title: 'RESTORING',
      message: 'Bringing the account\'s latest save to this device.',
    );
    try {
      final db = context.read<AlchemonsDatabase>();
      final cloudSave = context.read<AccountCloudSaveService>();
      await context.read<CloudAutosaveService>().hold(() async {
        final transferCode = await cloudSave.downloadSaveCode(
          account.user!.uid,
        );
        await SaveTransferService(
          db,
        ).importSaveCode(transferCode, ownerAccountId: account.user!.uid);
        if (mounted) await reloadStateAfterSaveRestore(context);
        // A fresh device identity only once the backup is in: rotating first
        // left a failed download with this device silently deactivated.
        await session.rotateCurrentDeviceId();
        await session.claimCurrentDevice(force: true);
        await session.refresh();
      });
      if (!mounted) return;
      await _reloadProfileState();
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      _showTransferSnack('Your account\'s save is on this device now.');
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
                GrainLoader(size: 18, color: _accent),
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
                  title: switch (data?.titles.worn) {
                    final id? => ProfileTitles.nameOf(id),
                    null => null,
                  },
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
                      _cosmeticsSection(faction, data, palette, accent),

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
                        label: 'FRIENDS',
                        palette: palette,
                        children: [
                          FriendsPanel(
                            palette: palette,
                            accent: accent,
                            onSignIn: _signInAccount,
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
                                'essence cinematics for slower phones',
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
                            title: 'ESSENCE',
                            description: 'When a chamber of essence is full',
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
                            context.watch<CloudAutosaveService>(),
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
                        label: 'ABOUT',
                        palette: palette,
                        children: [
                          _Row(
                            title: 'PRIVACY POLICY',
                            description: 'What the game stores and why',
                            palette: palette,
                            trailing: _QuietButton(
                              label: 'OPEN',
                              palette: palette,
                              accent: accent,
                              onTap: _openPrivacyPolicy,
                            ),
                          ),
                        ],
                      ),

                      // Every debug or profile build; in a release build only
                      // a developer's account (DebugSettingsService).
                      if (DebugSettingsService.toolsAllowed)
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

  /// The earned titles (achievements' and the Athanor's) this save can
  /// wear, by id with their words, in the catalogue's order.
  List<(String, String)> _titleChoices(_ProfileData? data) => [
    if (data != null)
      for (final id in ProfileTitles.earnable())
        if (data.titles.owned.contains(id) || data.titles.earned.contains(id))
          if (ProfileTitles.nameOf(id) case final name?) (id, name),
  ];

  /// Everything worn for the whole game, first under the header: the title,
  /// the dock and the fusion. Each row shows even with nothing owned yet,
  /// so the player learns where these are chosen and where they come from.
  Widget _cosmeticsSection(
    FactionId? faction,
    _ProfileData? data,
    BracketPalette palette,
    Color accent,
  ) {
    final titles = _titleChoices(data);
    final hasFusionStyles =
        context.watch<CosmeticWearService?>()?.ownedFusionStyles.isNotEmpty ??
        false;
    const strip = EdgeInsets.symmetric(horizontal: _kRowInset);
    return _Section(
      label: 'COSMETICS',
      palette: palette,
      children: [
        _Row(
          title: 'TITLE',
          description: switch (data?.titles.worn) {
            final id? => ProfileTitles.nameOf(id) ?? '',
            null => 'None. Make one from a color and a word.',
          },
          palette: palette,
          trailing: _QuietButton(
            label: 'CHANGE',
            height: 34,
            enabled: data != null,
            palette: palette,
            accent: accent,
            onTap: () => _chooseTitle(titles),
          ),
        ),
        if (faction != null)
          _Row(
            title: 'DOCK',
            description:
                "The Let the dock's icons are drawn with. More are sold in "
                'the shop or come from the Furnace.',
            palette: palette,
            bleed: true,
            below: _DockSetChoice(
              palette: palette,
              accent: accent,
              padding: strip,
            ),
          ),
        _Row(
          title: 'FUSION',
          description: hasFusionStyles
              ? 'How every fusion plays. Styles come from the Furnace.'
              : 'None yet. Fusion styles come from the Furnace.',
          palette: palette,
          bleed: true,
          below: hasFusionStyles
              ? FusionStyleChoice(
                  palette: palette,
                  accent: accent,
                  padding: strip,
                )
              : null,
        ),
      ],
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
    final ownedElsewhere = _ownedElsewhere(account);
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
            value: !session.state.initialized
                ? 'Checking…'
                : activeHere
                ? 'Active · saving to your account'
                : ownedElsewhere
                ? 'Not active · this game belongs to another account'
                : 'Not active · the account is on another device',
            palette: palette,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Each as wide as its word: a wrap would stretch them.
              for (final button in [
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
    CloudAutosaveService autosave,
    BracketPalette palette,
    Color accent,
  ) {
    if (!account.isSignedIn) {
      return _Row(
        title: 'CLOUD SAVE',
        description:
            'Sign in to keep your game saved to an account, for a lost phone '
            'or a new one.',
        palette: palette,
      );
    }
    if (!session.state.initialized) {
      return _Row(
        title: 'CLOUD SAVE',
        description: 'Checking your account…',
        palette: palette,
      );
    }
    final ownedElsewhere = _ownedElsewhere(account);
    if (ownedElsewhere || !session.state.activeOnThisDevice) {
      return _Row(
        title: 'CLOUD SAVE',
        description: ownedElsewhere
            ? 'The game on this device belongs to a different account, so it '
                  'doesn\'t save to this one. Restore brings this account\'s '
                  'save here and replaces it.'
            : 'Your account is playing on another device, so progress here '
                  'doesn\'t save to it. Restore brings the account\'s latest '
                  'save here and replaces this game.',
        palette: palette,
        below: BracketButton(
          label: _saveTransferBusy ? 'WORKING…' : 'RESTORE',
          height: 40,
          enabled: !_saveTransferBusy && account.isConfigured,
          palette: palette,
          accent: accent,
          onTap: _importSave,
        ),
      );
    }
    final savedAt = autosave.savedAt;
    final error = autosave.saving ? null : autosave.error;
    return _Row(
      title: 'CLOUD SAVE',
      description: 'Your game saves to your account when you leave the app.',
      palette: palette,
      below: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Reading(
            label: 'LAST SAVED',
            value: autosave.saving
                ? 'Saving…'
                : savedAt == null
                ? 'Not yet'
                : _savedAgo(savedAt),
            palette: palette,
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(error, style: _prose(context, _kDanger)),
          ],
          const SizedBox(height: 12),
          IntrinsicWidth(
            child: _QuietButton(
              label: 'SAVE NOW',
              enabled: !autosave.saving,
              palette: palette,
              accent: accent,
              onTap: _saveNow,
            ),
          ),
        ],
      ),
    );
  }

  /// 99 → full → empty → 99: the meter's three useful states, in turn.
  Future<void> _cycleMutationMeter() async {
    final dao = context.read<AlchemonsDatabase>().settingsDao;
    final now = await dao.getMutationMeter();
    final next = now >= kMutationMeterNotches
        ? 0
        : now == kMutationMeterNotches - 1
        ? kMutationMeterNotches
        : kMutationMeterNotches - 1;
    await dao.setMutationMeter(next);
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text('Mutation meter: $next / $kMutationMeterNotches')),
    );
  }

  List<_DebugAction> _debugActions() => [
    _DebugAction(
      'MUTATION METER',
      'Set the meter to one short of full, so the next wild fusion has 10%; '
          'tap again to fill it, then to empty it. Needs its node',
      'CYCLE',
      _cycleMutationMeter,
    ),
    _DebugAction(
      'BATTLE',
      'Fight the computer, two at a time from four: tap specials, call in '
          'the bench, two swaps',
      'OPEN',
      _openBattle,
    ),
    _DebugAction(
      'TRIALS',
      'Open the Trials with your space party, without flying there',
      'OPEN',
      _openStadium,
    ),
    _DebugAction(
      'ALCHEMY',
      'Fusion puzzles in levels, chapter by chapter through the realms',
      'OPEN',
      _openAltars,
    ),
    _DebugAction(
      'ABILITY LAB',
      'Test every Alchemon\'s attacks and special in the practice arena, '
          'at any stat band',
      'OPEN',
      _openAbilityLab,
    ),
    _DebugAction(
      'FIRST DESCENT',
      'Play the first descent\'s cinematic again: the realms fall away '
          'over a random planet, with your space party. Not saved',
      'PLAY',
      _playFirstDescent,
    ),
    _DebugAction(
      'FINALE',
      'Play the ending after the Blood Ring again: your space party\'s '
          'first Alchemon remade, the credits over your census. Not saved',
      'PLAY',
      _playFinale,
    ),
    _DebugAction(
      'BLOODBORN VIAL',
      'Your space party\'s first Alchemon as a Bloodborn Vial in its '
          'chamber, at four stages, and its extraction. Not saved',
      'OPEN',
      _openBloodbornVial,
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
    this.title,
    required this.field,
    required this.realmKey,
    required this.realmIn,
    required this.reveal,
    required this.palette,
    required this.accent,
  });

  final FactionId faction;
  final int? discovered;

  /// The title worn, under the name; null for none.
  final String? title;
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
                      if (title case final title?) ...[
                        const SizedBox(height: 10),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cinzel(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: palette.ink,
                            letterSpacing: 1,
                            shadows: shadow,
                          ),
                        ),
                      ],
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
    this.bleed = false,
  });

  final String title;
  final String? description;
  final BracketPalette palette;
  final Widget? trailing;
  final Widget? below;

  /// [below] runs to the panel's edges (a strip that scrolls sideways and
  /// keeps the row's margin as its own padding, [_kRowInset]).
  final bool bleed;

  @override
  Widget build(BuildContext context) {
    const inset = EdgeInsets.symmetric(horizontal: _kRowInset);
    final head = Row(
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
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: inset, child: head),
          if (below != null) ...[
            const SizedBox(height: 12),
            if (bleed) below! else Padding(padding: inset, child: below!),
          ],
        ],
      ),
    );
  }
}

/// A row's margin either side.
const double _kRowInset = 14;

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

/// The title popup: the title as it will read, then a color and a word
/// side by side (every one open from the start), then the titles earned.
/// Nothing is worn until WEAR; NO TITLE clears the choice. Choosing a color
/// keeps the word last chosen with one (and the other way round), so one
/// tap changes one half. Pops `(id: ...)`, or nothing when closed.
class _TitleDialog extends StatefulWidget {
  const _TitleDialog({
    required this.earned,
    required this.worn,
    required this.lastMade,
  });

  /// The earned titles that can be worn, by id, with their words.
  final List<(String, String)> earned;
  final String? worn;

  /// The colour and word last worn together, if any.
  final MadeTitle? lastMade;

  @override
  State<_TitleDialog> createState() => _TitleDialogState();
}

class _TitleDialogState extends State<_TitleDialog> {
  late String? _pick = widget.worn;
  late MadeTitle _base =
      MadeTitle.fromId(widget.worn) ??
      widget.lastMade ??
      const MadeTitle(TitleColour.red, TitleWord.alchemy);

  /// How each color is drawn: readable on the dialog's black.
  static const Map<TitleColour, Color> _ink = {
    TitleColour.red: Color(0xFFE0675A),
    TitleColour.blue: Color(0xFF5E9BE0),
    TitleColour.green: Color(0xFF6DB86F),
    TitleColour.brown: Color(0xFFB4865C),
    TitleColour.yellow: Color(0xFFE3C453),
  };

  void _choose(String? id) {
    if (id == _pick) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pick = id;
      _base = MadeTitle.fromId(id) ?? _base;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final palette = BracketPalette.fromTheme(theme);
    final accent = bracketReadableAccent(theme);
    final made = MadeTitle.fromId(_pick);
    final words = switch (_pick) {
      final id? => ProfileTitles.nameOf(id),
      null => null,
    };

    Widget chip({
      required bool selected,
      required String label,
      required VoidCallback onTap,
      Color? color,
      bool fill = false,
    }) => _ChoiceCell(
      selected: selected,
      palette: palette,
      accent: color ?? accent,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      fill: fill,
      onTap: onTap,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _mono(
          11,
          color == null
              ? (selected ? palette.ink : palette.muted)
              : color.withValues(alpha: selected ? 1 : 0.72),
        ),
      ),
    );

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: _mono(9.5, palette.muted).copyWith(letterSpacing: 2),
      ),
    );

    /// One half of a made title, top to bottom.
    Widget half(String text, List<Widget> cells) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label(text),
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          cells[i],
        ],
      ],
    );

    return _DialogShell(
      title: 'TITLE',
      children: [
        // The title as it will read under the division's name.
        Container(
          height: 64,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: palette.bg0,
          child: Text(
            words ?? 'No title',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: words == null
                ? _prose(
                    context,
                    palette.muted,
                    size: 15,
                  ).copyWith(fontStyle: FontStyle.italic)
                : GoogleFonts.cinzel(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                    letterSpacing: 1,
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // A color from one column and a word from the other.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: half('COLOR', [
                        for (final c in TitleColour.values)
                          chip(
                            selected: made?.colour == c,
                            label: c.word.toUpperCase(),
                            color: _ink[c],
                            fill: true,
                            onTap: () => _choose(MadeTitle(c, _base.word).id),
                          ),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: half('WORD', [
                        for (final w in TitleWord.values)
                          chip(
                            selected: made?.word == w,
                            label: w.word.toUpperCase(),
                            fill: true,
                            onTap: () => _choose(MadeTitle(_base.colour, w).id),
                          ),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                label('EARNED'),
                if (widget.earned.isEmpty)
                  Text(
                    'None yet. Collect a family achievement or draw one '
                    'from the Furnace.',
                    style: _prose(context, palette.muted),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (id, name) in widget.earned)
                        chip(
                          selected: id == _pick,
                          label: name.toUpperCase(),
                          onTap: () => _choose(id),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _QuietButton(
                label: 'NO TITLE',
                height: 42,
                enabled: _pick != null,
                palette: palette,
                accent: accent,
                onTap: () => _choose(null),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BracketButton(
                label: 'WEAR',
                height: 42,
                palette: palette,
                accent: accent,
                onTap: () => Navigator.of(context).pop((id: _pick)),
              ),
            ),
          ],
        ),
      ],
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

/// Every dock set owned, each its Let in Home's archway, the one on the dock
/// lit from below; a strip that scrolls sideways.
class _DockSetChoice extends StatefulWidget {
  const _DockSetChoice({
    required this.palette,
    required this.accent,
    this.padding = EdgeInsets.zero,
  });

  final BracketPalette palette;
  final Color accent;
  final EdgeInsets padding;

  @override
  State<_DockSetChoice> createState() => _DockSetChoiceState();
}

class _DockSetChoiceState extends State<_DockSetChoice> {
  BracketPalette get palette => widget.palette;
  Color get accent => widget.accent;

  @override
  void initState() {
    super.initState();
    // A set drawn from the Athanor is owned by its settings row; read them
    // again, so it shows here (and can be worn) whatever the faction.
    context.read<FactionService>().reloadDockSets();
  }

  @override
  Widget build(BuildContext context) {
    final factions = context.watch<FactionService>();
    final worn = factions.dockSet;
    final owned = [
      for (final set in kDockSets)
        if (factions.ownsDockSet(set)) set,
    ];
    return ChoiceStrip(
      selected: owned.indexOf(worn),
      padding: widget.padding,
      children: [
        for (final set in owned)
          GestureDetector(
            key: ValueKey('dock-set-${set.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: context.soundAction(() {
              if (set == worn) return;
              HapticFeedback.selectionClick();
              factions.wearDockSet(set);
            }),
            child: CustomPaint(
              foregroundPainter: BracketFramePainter(
                color: set == worn ? accent : palette.line,
                strokeWidth: 1.2,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 76,
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                color: set == worn
                    ? palette.accentWash(accent, darkAlpha: 0.18)
                    : palette.bg0,
                child: Column(
                  children: [
                    NavEmblem(kind: NavEmblemKind.home, dockSet: set, size: 54),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        set.name.toUpperCase(),
                        maxLines: 1,
                        style: _mono(
                          9.5,
                          set == worn ? palette.ink : palette.muted,
                        ),
                      ),
                    ),
                  ],
                ),
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
  final ProfileTitleState titles;
  const _ProfileData(
    this.faction,
    this.discoveredCount,
    this.cosmicHints,
    this.titles,
  );

  _ProfileData withTitles(ProfileTitleState titles) =>
      _ProfileData(faction, discoveredCount, cosmicHints, titles);
}

/// Email and password, checked before it closes: a wrong password, or
/// anything else that goes wrong, shows under the fields and the dialog
/// stays for another try. Pops true once [submit] has worked.
class _CredentialDialog extends StatefulWidget {
  const _CredentialDialog({
    required this.title,
    required this.submitLabel,
    required this.submit,
    this.message,
    this.warning,
    this.includeDisplayName = false,
  });

  final String title;
  final String submitLabel;
  final String? message;
  final String? warning;
  final bool includeDisplayName;

  /// Null when it worked; otherwise what to show.
  final Future<String?> Function(_CredentialDialogResult result) submit;

  @override
  State<_CredentialDialog> createState() => _CredentialDialogState();
}

class _CredentialDialogState extends State<_CredentialDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.submit(
      _CredentialDialogResult(
        email: _email.text.trim(),
        password: _password.text,
        displayName: _name.text.trim(),
      ),
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final palette = BracketPalette.fromTheme(theme);
    final accent = bracketReadableAccent(theme);
    return PopScope(
      canPop: !_busy,
      child: _DialogShell(
        title: widget.title,
        children: [
          if (widget.message != null) ...[
            Text(
              widget.message!,
              style: _prose(context, palette.ink, size: 13.5),
            ),
            const SizedBox(height: 10),
          ],
          if (widget.warning != null) ...[
            Text(widget.warning!, style: _prose(context, _kDanger, size: 13)),
            const SizedBox(height: 14),
          ],
          if (widget.includeDisplayName) ...[
            _FormField(controller: _name, hint: 'Account name'),
            const SizedBox(height: 10),
          ],
          _FormField(
            controller: _email,
            hint: 'Email',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          _FormField(controller: _password, hint: 'Password', secret: true),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: _prose(context, _kDanger, size: 13)),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _QuietButton(
                  label: 'CANCEL',
                  height: 42,
                  enabled: !_busy,
                  palette: palette,
                  accent: accent,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BracketButton(
                  label: _busy ? 'WORKING…' : widget.submitLabel,
                  height: 42,
                  enabled: !_busy,
                  palette: palette,
                  accent: accent,
                  onTap: _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
