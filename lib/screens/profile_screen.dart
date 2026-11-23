// lib/screens/profile_screen.dart
//
// The profile: who you are and who you know.
//
//   Your division, as the realm you chose it by — its living grains across
//   the top, the starter orb, the name, the title worn and its creed — then
//   the cosmetics worn for the whole game (title, dock, fusion), its perks,
//   friends and the journal.
//
// How the game is set up (display, sound, notifications, the account and
// its save, a fresh start, the developer switches) is SETTINGS, behind the
// gear in the top bar: settings_screen.dart, a part of this library, so it
// shares the rows, buttons and dialogs here.
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
import 'package:alchemons/screens/debug/ability_reel_screen.dart';
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

part 'settings_screen.dart';

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
  int _cosmicHintPage = 0;

  @override
  void initState() {
    super.initState();
    // Arriving earns the task; collecting it happens in the journal.
    OnboardingTaskService.recordArrival(context, 'profile');
    _cosmicHintsController = PageController();
    _loadProfileData();
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
    if (mounted) {
      setState(() {
        _data = data;
        _lastMadeTitle ??= data.titles.wornMade;
      });
    }
  }

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

  Future<void> _openEncyclopedia() async {
    HapticFeedback.mediumImpact();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const AlchemicalEncyclopediaScreen()),
    );
  }

  /// SETTINGS; back from it, the profile reads its save again, since a
  /// restore, a sign-in or a reset there can change what it shows.
  Future<void> _openSettings() async {
    HapticFeedback.mediumImpact();
    await Navigator.push<void>(context, SettingsScreen.route());
    if (mounted) await _loadProfileData();
  }

  /// FRIENDS' sign-in, when signed out: SETTINGS' own dialog.
  Future<void> _signInAccount() async {
    final done = await _signInWithDialog(context);
    if (done == null || !mounted) return;
    if (done.result == SignInResult.restored) await _loadProfileData();
    if (!mounted) return;
    showAppSnack(_signedInText(done.result), fallbackContext: context);
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

  // ───────────────────────────── build ────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final factionTheme = context.watch<FactionTheme>();
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
                  onSettings: _openSettings,
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
              onSettings: _openSettings,
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
              ? null
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
    required this.onSettings,
  });

  final ScrollController scroll;
  final GlobalKey dockKey;
  final BracketPalette palette;
  final Color accent;
  final VoidCallback onBack;
  final VoidCallback onEncyclopedia;
  final VoidCallback onSettings;

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
          const SizedBox(width: 8),
          BracketIconButton(
            icon: AppIcons.settings_rounded,
            onTap: onSettings,
            palette: palette,
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
    required this.onSettings,
  });

  final BracketPalette palette;
  final VoidCallback onBack;
  final VoidCallback onEncyclopedia;
  final VoidCallback onSettings;

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
          const SizedBox(width: 8),
          BracketIconButton(
            icon: AppIcons.settings_rounded,
            onTap: onSettings,
            palette: palette,
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
