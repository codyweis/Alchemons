// lib/widgets/creature_actions.dart
//
// Short animations a creature plays once over its idle (a hop, for now), and
// the widget that asks for one every few seconds.
import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/models/celebration_costume.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/fx/mutation_sheets.dart';
import 'package:alchemons/widgets/fx/variant_look.dart' show speciesOfSheet;
import 'package:flame/cache.dart' show Images;
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/widgets.dart';

/// Something a creature does once, then goes back to its idle.
enum CreatureAction { hop, sleep, fire }

/// One action's sheet: a grid of square frames, each held for its own time.
class ActionSheet {
  final String path;
  final int frames;
  final int cols;
  final List<double> stepTimes;

  /// Played round and round until it is stopped (sleep), not once.
  final bool loop;

  /// One frame's side in the sheet, in pixels; 0 when it was not asked for.
  final double frameSize;

  /// Which action it is.
  final CreatureAction action;

  /// The frame index a costume is given for [frame] of this sheet, so it
  /// rides the head through the action (`costumeActionFrame`).
  int costumeFrame(int frame) => costumeActionFrame(action.index, frame);

  const ActionSheet({
    required this.action,
    required this.path,
    required this.frames,
    required this.cols,
    required this.stepTimes,
    this.loop = false,
    this.frameSize = 0,
  });

  /// The sheet as a [SpriteSheetDef]: hand it to `mutatedSheet` or
  /// `sheetForVisuals` for the copy an albino, a mutated creature or a
  /// palette-swapped variant wears, and load that with `loadCreatureSheet`.
  SpriteSheetDef get def => SpriteSheetDef(
    path: path,
    totalFrames: frames,
    rows: (frames + cols - 1) ~/ cols,
    frameSize: Vector2.all(frameSize),
    stepTime: stepTimes.first,
  );
}

/// The hop: a crouch, the jump, the landing and its wobble, in 16 frames.
const List<double> _hopSteps = [
  0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, //
  0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.10,
];

/// The species with a hop sheet beside their idle sheet (`…_hop.png`).
const Set<String> kHopSpecies = {
  // GENERATED: hop species
  'HOR01', 'HOR02', 'HOR03', 'HOR04', 'HOR05', 'HOR06',
  'HOR07', 'HOR08', 'HOR09', 'HOR10', 'HOR11', 'HOR12',
  'HOR13', 'HOR14', 'HOR15', 'HOR16', 'HOR17', 'LET01',
  'LET02', 'LET03', 'LET04', 'LET05', 'LET06', 'LET07',
  'LET08', 'LET09', 'LET10', 'LET11', 'LET12', 'LET13',
  'LET14', 'LET15', 'LET16', 'LET17', 'MAN01', 'MAN02',
  'MAN03', 'MAN04', 'MAN05', 'MAN06', 'MAN07', 'MAN08',
  'MAN09', 'MAN10', 'MAN11', 'MAN12', 'MAN13', 'MAN14',
  'MAN15', 'MAN16', 'MAN17', 'MAN18', 'PIP01', 'PIP02',
  'PIP03', 'PIP04', 'PIP05', 'PIP06', 'PIP07', 'PIP08',
  'PIP09', 'PIP10', 'PIP11', 'PIP12', 'PIP13', 'PIP14',
  'PIP15', 'PIP16', 'PIP17', 'WNG01', 'WNG02', 'WNG03',
  'WNG04', 'WNG05', 'WNG06', 'WNG07', 'WNG08', 'WNG09',
  'WNG10', 'WNG11', 'WNG12', 'WNG13', 'WNG14', 'WNG15',
  'WNG16', 'WNG17',
  // END GENERATED: hop
};

/// Asleep: slumped, eyes shut, one slow breath in 8 frames.
const List<double> _sleepSteps = [0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3];

/// The species with a sleep sheet beside their idle sheet (`…_sleep.png`).
const Set<String> kSleepSpecies = {
  // GENERATED: sleep species
  'HOR01', 'HOR02', 'HOR03', 'HOR04', 'HOR05', 'HOR06',
  'HOR07', 'HOR08', 'HOR09', 'HOR10', 'HOR11', 'HOR12',
  'HOR13', 'HOR14', 'HOR15', 'HOR16', 'HOR17', 'LET01',
  'LET02', 'LET03', 'LET04', 'LET05', 'LET06', 'LET07',
  'LET08', 'LET09', 'LET10', 'LET11', 'LET12', 'LET13',
  'LET14', 'LET16', 'LET17', 'MAN01', 'MAN02', 'MAN03',
  'MAN04', 'MAN05', 'MAN06', 'MAN07', 'MAN08', 'MAN09',
  'MAN10', 'MAN11', 'MAN12', 'MAN13', 'MAN14', 'MAN15',
  'MAN16', 'MAN17', 'MAN18', 'PIP01', 'PIP02', 'PIP03',
  'PIP04', 'PIP05', 'PIP06', 'PIP07', 'PIP08', 'PIP09',
  'PIP10', 'PIP11', 'PIP12', 'PIP13', 'PIP14', 'PIP15',
  'PIP16', 'PIP17', 'WNG01', 'WNG02', 'WNG03', 'WNG04',
  'WNG05', 'WNG06', 'WNG07', 'WNG08', 'WNG09', 'WNG10',
  'WNG11', 'WNG12', 'WNG13', 'WNG14', 'WNG15', 'WNG16',
  'WNG17',
  // END GENERATED: sleep
};

/// Firing its special: a quick gather, the snap, the recoil, in 10 frames.
/// Short, because the ability itself goes off the moment it is cast.
const List<double> _fireSteps = [
  0.02, 0.05, 0.05, 0.06, 0.05, 0.06, 0.06, 0.06, 0.07, 0.08, //
];

/// The species with a fire sheet beside their idle sheet (`…_fire.png`).
const Set<String> kFireSpecies = {
  // GENERATED: fire species
  'HOR01', 'HOR02', 'HOR03', 'HOR04', 'HOR05', 'HOR06',
  'HOR07', 'HOR08', 'HOR09', 'HOR10', 'HOR11', 'HOR12',
  'HOR13', 'HOR14', 'HOR15', 'HOR16', 'HOR17', 'LET01',
  'LET02', 'LET03', 'LET04', 'LET05', 'LET06', 'LET07',
  'LET08', 'LET09', 'LET10', 'LET11', 'LET12', 'LET13',
  'LET14', 'LET16', 'LET17', 'MAN01', 'MAN02', 'MAN03',
  'MAN04', 'MAN05', 'MAN06', 'MAN07', 'MAN08', 'MAN09',
  'MAN10', 'MAN11', 'MAN12', 'MAN13', 'MAN14', 'MAN15',
  'MAN16', 'MAN17', 'MAN18', 'PIP01', 'PIP02', 'PIP03',
  'PIP04', 'PIP05', 'PIP06', 'PIP07', 'PIP08', 'PIP09',
  'PIP10', 'PIP11', 'PIP12', 'PIP13', 'PIP14', 'PIP15',
  'PIP16', 'PIP17', 'WNG01', 'WNG02', 'WNG03', 'WNG04',
  'WNG05', 'WNG06', 'WNG07', 'WNG08', 'WNG09', 'WNG10',
  'WNG11', 'WNG12', 'WNG13', 'WNG14', 'WNG15', 'WNG16',
  'WNG17',
  // END GENERATED: fire
};

/// The sheet [action] plays for the creature whose idle sheet is
/// [idleSheetPath], or null when it has none.
///
/// [idleFrame] is the idle's frame side in pixels: with it the sheet knows
/// its own frame size (a 1200 px species' actions are drawn at half that; the
/// rest at the idle's size), which a baked look needs.
ActionSheet? actionSheetFor(
  String idleSheetPath,
  CreatureAction action, {
  double? idleFrame,
}) {
  const suffix = '_spritesheet.png';
  if (!idleSheetPath.endsWith(suffix)) return null;
  final species = speciesOfSheet(idleSheetPath);
  final side = idleFrame == null
      ? 0.0
      : idleFrame >= 1000
      ? idleFrame / 2
      : idleFrame;
  switch (action) {
    case CreatureAction.hop:
      if (species == null || !kHopSpecies.contains(species)) return null;
      return ActionSheet(
        action: action,
        path:
            '${idleSheetPath.substring(0, idleSheetPath.length - suffix.length)}_hop.png',
        frames: 16,
        cols: 4,
        stepTimes: _hopSteps,
        frameSize: side,
      );
    case CreatureAction.sleep:
      if (species == null || !kSleepSpecies.contains(species)) return null;
      return ActionSheet(
        action: action,
        path:
            '${idleSheetPath.substring(0, idleSheetPath.length - suffix.length)}_sleep.png',
        frames: 8,
        cols: 4,
        stepTimes: _sleepSteps,
        loop: true,
        frameSize: side,
      );
    case CreatureAction.fire:
      if (species == null || !kFireSpecies.contains(species)) return null;
      return ActionSheet(
        action: action,
        path:
            '${idleSheetPath.substring(0, idleSheetPath.length - suffix.length)}_fire.png',
        frames: 10,
        cols: 4,
        stepTimes: _fireSteps,
        frameSize: side,
      );
  }
}

/// Who is drawing which action sheet, in which image cache: the last one to
/// finish lets the sheet go, so a hop does not leave 20 MB behind it. A baked
/// one (an albino's, a mutation's) is kept a little longer — the last few —
/// so it is not baked again every five seconds.
abstract final class ActionSheetCache {
  static final Map<String, int> _users = {};
  static final List<(Images, String)> _resting = [];
  static const int _keepBaked = 3;

  static String _key(Images images, String path) =>
      '${identityHashCode(images)}|$path';

  /// Before loading [path] into [images].
  static void retain(Images images, String path) {
    final key = _key(images, path);
    _users[key] = (_users[key] ?? 0) + 1;
    _resting.removeWhere((e) => identical(e.$1, images) && e.$2 == path);
  }

  /// When done with it (or it never loaded).
  static void release(Images images, String path) {
    final key = _key(images, path);
    final left = (_users[key] ?? 1) - 1;
    if (left > 0) {
      _users[key] = left;
      return;
    }
    _users.remove(key);
    if (isMutatedSheetPath(path)) {
      _resting.add((images, path));
      while (_resting.length > _keepBaked) {
        final (i, p) = _resting.removeAt(0);
        _drop(i, p);
      }
      return;
    }
    _drop(images, path);
  }

  static void _drop(Images images, String path) {
    if (images.containsKey(path)) images.clear(path);
    if (isMutatedSheetPath(path)) forgetBakedSheet(path);
  }
}

/// Hand one to a `CreatureSprite` (or an `InstanceSprite`) and call [play]:
/// the sprite plays the action once if it can, and ignores it if it cannot
/// (no sheet for it, already playing one, or a look its frames do not carry).
class CreatureActionController extends ChangeNotifier {
  CreatureAction? _asked;

  void play(CreatureAction action) {
    _asked = action;
    notifyListeners();
  }

  /// The action asked for, once.
  CreatureAction? take() {
    final a = _asked;
    _asked = null;
    return a;
  }
}

/// Has the creature it builds hop now and then: once [first] after it
/// appears, then at a random moment between [minGap] and [maxGap], for as
/// long as it is on screen.
class IdleHops extends StatefulWidget {
  const IdleHops({
    super.key,
    required this.builder,
    this.first = const Duration(milliseconds: 2500),
    this.minGap = const Duration(seconds: 4),
    this.maxGap = const Duration(seconds: 7),
  });

  final Widget Function(BuildContext context, CreatureActionController actions)
  builder;
  final Duration first;
  final Duration minGap;
  final Duration maxGap;

  @override
  State<IdleHops> createState() => _IdleHopsState();
}

class _IdleHopsState extends State<IdleHops> {
  final CreatureActionController _actions = CreatureActionController();
  final math.Random _random = math.Random();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.first, _hop);
  }

  void _hop() {
    if (!mounted) return;
    // Not while the route is covered or the app's tickers are off.
    if (TickerMode.valuesOf(context).enabled) _actions.play(CreatureAction.hop);
    final span = widget.maxGap - widget.minGap;
    _timer = Timer(
      widget.minGap +
          Duration(
            milliseconds: (span.inMilliseconds * _random.nextDouble()).round(),
          ),
      _hop,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _actions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _actions);
}
