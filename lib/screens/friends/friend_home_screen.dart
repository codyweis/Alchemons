// lib/screens/friends/friend_home_screen.dart
//
// A friend's home biome, visited: the field they made under their planet,
// as they last left it (lib/models/friend_home.dart), with their Alchemons
// living in it as they do at home — strolling, sleeping at night, going to
// their keepsakes. Nothing here can be changed. A tap on one of them plays
// its essence and names its species; the field pans and pinches as at home.
//
// Two ways to see it: the window in the portal drawn round their planet on
// their page (FriendHomeWindow, small and drifting, not touchable), and the
// visit itself down through that window (FriendHomeScreen, landscape).

import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/cosmetic_wear.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/models/home_biome.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/providers/audio_provider.dart' show AudioController;
import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/screens/home_biome/home_sky_source.dart';
import 'package:alchemons/screens/home_biome/home_biome_screen.dart'
    show homeFormSite, hydrateResident, showHomeMarks, standHomePieces;
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// The field's HUD sits over a sky — always the dark palette.
const _palette = BracketPalette.dark;

/// [home] made ready to stand in a field: each resident's look as the field
/// draws it, and the layout without anyone whose species this build does
/// not know.
(HomeBiomeLayout, Map<String, (Creature, CreatureInstance)>) hydrateFriendHome(
  FriendHome home,
  CreatureCatalog catalog,
) {
  final looks = <String, (Creature, CreatureInstance)>{};
  for (final r in home.layout.residents) {
    final look = home.looks[r.instanceId];
    if (look == null) continue;
    final inst = look.instance(r.instanceId);
    final creature = hydrateResident(inst, catalog);
    if (creature != null) looks[r.instanceId] = (creature, inst);
  }
  final layout = home.layout.copyWith(
    residents: [
      for (final r in home.layout.residents)
        if (looks.containsKey(r.instanceId)) r,
    ],
  );
  return (layout, looks);
}

/// The field [home] shows, before anyone stands in it.
SceneGame friendHomeGame(FriendHome home, HomeBiomeLayout layout) {
  final mood = layout.mood;
  final game = SceneGame(scene: layout.scene(home.floats), showcase: true)
    ..fieldHourOverride = layout.hour
    ..fieldWeather = mood.weather
    ..fieldAftermath = mood.aftermath
    ..fieldStage = mood.stage
    ..lively = true
    // Their sky — their planet, their constellations, their season.
    ..homeSky = homeSkyLookOf(
      layout.sky,
      HomeSkySources(planet: home.planet, constellations: home.constellations),
    )
    ..fieldSeason = layout.sky.seasonAt(DateTime.now())
    // Their trails and their ambience, as they wear them.
    ..trailOf = ((id) => TrailStyle.byId(home.looks[id]?.trail))
    ..ambience = HomeAmbience.byId(home.ambience);
  // What their residents have made of their ground, and of the land.
  showHomeMarks(game, layout);
  final (form, deep) = homeFormOf(
    layout,
    DateTime.now().millisecondsSinceEpoch,
  );
  game
    ..fieldForm = form
    ..fieldFormDeep = deep
    ..formSite = form == null ? null : homeFormSite(layout);
  return game;
}

/// Stands everyone and everything of [layout] in [game], once it has
/// loaded; resolves when they are all there (or [alive] says to stop).
Future<void> standFriendHome(
  SceneGame game,
  HomeBiomeLayout layout,
  Map<String, (Creature, CreatureInstance)> looks,
  CreatureCatalog catalog,
  bool Function() alive,
) async {
  await game.loaded;
  if (!alive()) return;
  // The view they framed of it, if they framed one.
  if (layout.frame case final f?) game.viewAt(f.x, f.zoom);
  for (final r in layout.residents) {
    final look = looks[r.instanceId];
    if (look == null) continue;
    await game.showResident(
      r.spawnId,
      look.$1,
      instance: look.$2,
      flip: r.flip,
    );
    if (!alive()) return;
  }
  standHomePieces(game, layout, catalog);
  await game.residentsLoaded().timeout(
    const Duration(seconds: 3),
    onTimeout: () => const [],
  );
}

/// Goes down into [home] (landscape there, portrait back) and resolves when
/// the player comes back up. [from] is the window drawn round their planet:
/// it lifts off as sand and comes undone into the field; [back] is where
/// the field's sand pours when it is left.
Future<void> visitFriendHome(
  BuildContext context, {
  required FriendHome home,
  required String name,
  required SandSource from,
  SandLanding Function(String element)? back,
}) async {
  final ready = ValueNotifier<bool>(false);
  final element = home.layout.realm.portalElement;
  await VoidPortal.pushThroughSand<void>(
    context,
    page: FriendHomeScreen(home: home, name: name, revealReady: ready),
    from: from,
    title: name,
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
    back: back?.call(element) ?? SandLanding(element: element),
  );
}

// ── The window ──────────────────────────────────────────────────────────────

/// A friend's home, live and small, for the portal round their planet: laid
/// out at the phone's landscape size and scaled down into the hole, the view
/// drifting slowly along. Paused while [active] is false.
class FriendHomeWindow extends StatefulWidget {
  const FriendHomeWindow({
    super.key,
    required this.home,
    required this.active,
    this.onReady,
  });

  final FriendHome home;
  final bool active;
  final VoidCallback? onReady;

  @override
  State<FriendHomeWindow> createState() => _FriendHomeWindowState();
}

class _FriendHomeWindowState extends State<FriendHomeWindow> {
  SceneGame? _game;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant FriendHomeWindow old) {
    super.didUpdateWidget(old);
    final game = _game;
    if (game == null || old.active == widget.active) return;
    widget.active ? game.resumeEngine() : game.pauseEngine();
  }

  Future<void> _load() async {
    final catalog = context.read<CreatureCatalog>();
    final (layout, looks) = hydrateFriendHome(widget.home, catalog);
    final game = friendHomeGame(widget.home, layout)..panDrift = 16;
    if (!widget.active) game.pauseEngine();
    setState(() => _game = game);
    await standFriendHome(
      game,
      layout,
      looks,
      catalog,
      () => mounted && _game == game,
    );
    if (!mounted || _game != game) return;
    widget.onReady?.call();
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    if (game == null) return const SizedBox.expand();
    final screen = MediaQuery.sizeOf(context);
    final wide = Size(
      math.max(screen.width, screen.height),
      math.min(screen.width, screen.height),
    );
    return IgnorePointer(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox.fromSize(
          size: wide,
          child: GameWidget(game: game),
        ),
      ),
    );
  }
}

// ── The visit ───────────────────────────────────────────────────────────────

class FriendHomeScreen extends StatefulWidget {
  const FriendHomeScreen({
    super.key,
    required this.home,
    required this.name,
    this.revealReady,
  });

  final FriendHome home;

  /// Whose home it is.
  final String name;

  /// Flipped once the field is built, for the passage covering this page.
  final ValueNotifier<bool>? revealReady;

  @override
  State<FriendHomeScreen> createState() => _FriendHomeScreenState();
}

class _FriendHomeScreenState extends State<FriendHomeScreen> {
  SceneGame? _game;
  HomeBiomeLayout _layout = const HomeBiomeLayout();
  Map<String, (Creature, CreatureInstance)> _looks = const {};
  bool _ready = false;
  late final RevealWhenReady _reveal;

  /// The species of the one last tapped, named along the bottom a while.
  String? _named;
  Timer? _nameTimer;

  @override
  void initState() {
    super.initState();
    _reveal = RevealWhenReady(widget.revealReady, () => mounted && _ready);
    unawaited(_load());
  }

  @override
  void dispose() {
    _nameTimer?.cancel();
    _reveal.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final catalog = context.read<CreatureCatalog>();
    final (layout, looks) = hydrateFriendHome(widget.home, catalog);
    _layout = layout;
    _looks = looks;
    final game = friendHomeGame(widget.home, layout)
      ..onSound = _play
      ..onResidentTap = _onTap;
    setState(() => _game = game);
    unawaited(
      context.read<AudioController?>()?.playWildMusicForScene(
            layout.realm.sceneId,
          ) ??
          Future<void>.value(),
    );
    await standFriendHome(
      game,
      layout,
      looks,
      catalog,
      () => mounted && _game == game,
    );
    if (!mounted || _game != game) return;
    setState(() => _ready = true);
  }

  void _play(SoundCue cue) {
    if (!mounted) return;
    unawaited(
      context.read<AudioController?>()?.playSound(cue) ?? Future<void>.value(),
    );
  }

  /// Looking is all there is: a tap plays its essence and names it.
  void _onTap(String spawnId) {
    final r = _layout.resident(spawnId);
    if (r == null) return;
    HapticFeedback.lightImpact();
    _game?.playEssence(spawnId);
    _nameTimer?.cancel();
    setState(() => _named = _looks[r.instanceId]?.$1.name);
    _nameTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _named = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    final String? note =
        _named ??
        (_ready && _layout.residents.isEmpty
            ? 'No Alchemons live here yet.'
            : null);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (game != null) Positioned.fill(child: GameWidget(game: game)),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _ready ? 0 : 1,
                duration: const Duration(milliseconds: 520),
                child: const ColoredBox(color: Colors.black),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ExitButton(
                        // Back up through the window it came down, as sand.
                        onTap: () => VoidPortal.leaveThroughSand<void>(context),
                      ),
                      const SizedBox(width: 10),
                      _Slip(text: "${widget.name.toUpperCase()}'S HOME"),
                    ],
                  ),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    child: note == null
                        ? const SizedBox.shrink()
                        : Center(
                            key: ValueKey(note),
                            child: _Slip(text: note, quiet: true),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// EXIT, as the home biome has it.
class _ExitButton extends StatelessWidget {
  const _ExitButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = ForgeTokens(factionThemeFor(null)).danger;
    return GestureDetector(
      onTap: context.soundTap(onTap),
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: BracketFramePainter(
          color: accent.withValues(alpha: 0.8),
          bracketSize: 8,
          strokeWidth: 1.1,
        ),
        child: Container(
          constraints: const BoxConstraints(minWidth: 66, minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: _palette.surfaceFill(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(AppIcons.exit_to_app_rounded, color: accent, size: 20),
              const SizedBox(height: 5),
              Text(
                'Exit',
                style: bracketText(
                  context,
                  10.5,
                  _palette.ink,
                  weight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A few words on a slip of the HUD's dark, so they read over a bright sky:
/// a flat fill, unlit (nothing here is chosen), as the home biome's notes.
class _Slip extends StatelessWidget {
  const _Slip({required this.text, this.quiet = false});

  final String text;
  final bool quiet;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    color: _palette.surfaceFill(),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: bracketText(
        context,
        quiet ? 12 : 11.5,
        _palette.ink.withValues(alpha: 0.9),
        weight: quiet ? FontWeight.w600 : FontWeight.w800,
        letterSpacing: quiet ? 0.3 : 1.2,
      ),
    ),
  );
}
