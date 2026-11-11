// lib/screens/debug/ability_reel_screen.dart
//
// DEVELOPER TOOL — every Alchemon ability, one after another.
//
// The ability lab opens one species at a time. This plays them all in one
// arena: each family and element's special is cast in turn on the practice
// ring (the real Survival game, waves held back), held a few seconds, and
// the next one comes in. Pause, step back and forth, cast again, filter to a
// family, choose the stat band, or tap the title to jump to any of them.
// Every one is built the lab's way ([abilityLabMember]): level 10, one
// Potential in every stat, from a species of that family and element.
//
// Nothing here writes to the save.

import 'dart:async';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/screens/ability_preview_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/widgets/creature_detail/battle_tab.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

const _kFamilies = [
  'Horn',
  'Wing',
  'Let',
  'Pip',
  'Mane',
  'Mask',
  'Kin',
  'Mystic',
];

/// The order the reel walks the elements in, kin next to kin.
const _kElementOrder = [
  'Fire',
  'Lava',
  'Lightning',
  'Water',
  'Ice',
  'Steam',
  'Earth',
  'Mud',
  'Dust',
  'Crystal',
  'Air',
  'Plant',
  'Poison',
  'Spirit',
  'Dark',
  'Light',
  'Blood',
];

/// A stat band every ability is built at (the lab's).
class _Band {
  const _Band(this.label, this.potential, [this.enhancement = 0]);
  final String label;
  final int potential;
  final int enhancement;
}

const _kBands = [
  _Band('P50', 50),
  _Band('P70', 70),
  _Band('P100', 100),
  _Band('P100 E10', 100, 10),
];

/// One family and element's special, and the species that shows it.
class _Subject {
  const _Subject(this.family, this.element, this.creature);
  final String family;
  final String element;
  final Creature creature;
  String get special => cosmicSpecialAbilityName(family, element);
}

/// Every family and element pair a species exists for, in family order and
/// then element order; the first species of each by name shows it.
List<_Subject> _subjectsFrom(CreatureCatalog catalog) {
  final byPair = <(String, String), Creature>{};
  final species = [
    for (final c in catalog.creatures)
      if (_kFamilies.contains(c.mutationFamily) && c.types.isNotEmpty) c,
  ]..sort((a, b) => a.name.compareTo(b.name));
  for (final c in species) {
    byPair.putIfAbsent((c.mutationFamily!, c.types.first), () => c);
  }
  int rank(List<String> order, String v) {
    final i = order.indexOf(v);
    return i < 0 ? order.length : i;
  }

  return [
    for (final e in byPair.entries) _Subject(e.key.$1, e.key.$2, e.value),
  ]..sort((a, b) {
    final f = rank(_kFamilies, a.family).compareTo(rank(_kFamilies, b.family));
    if (f != 0) return f;
    final e = rank(
      _kElementOrder,
      a.element,
    ).compareTo(rank(_kElementOrder, b.element));
    return e != 0 ? e : a.element.compareTo(b.element);
  });
}

class AbilityReelScreen extends StatefulWidget {
  const AbilityReelScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => const AbilityReelScreen()));

  @override
  State<AbilityReelScreen> createState() => _AbilityReelScreenState();
}

class _AbilityReelScreenState extends State<AbilityReelScreen> {
  /// How long after an ability's arena is up its special is cast, and how
  /// long it is watched after that before the next one comes in.
  static const double _castAt = 0.9;
  static const List<double> _holds = [3.0, 4.5, 7.0];

  late final List<_Subject> _all = _subjectsFrom(
    context.read<CreatureCatalog>(),
  );
  String? _family;
  _Band _band = _kBands[1];
  int _index = 0;
  bool _playing = true;
  double _hold = _holds[1];

  AbilityPreviewGame? _game;
  int _gameId = 0;
  double _clock = 0;
  bool _cast = false;
  Timer? _timer;

  List<_Subject> get _shown => _family == null
      ? _all
      : [
          for (final s in _all)
            if (s.family == _family) s,
        ];

  _Subject? get _subject {
    final shown = _shown;
    if (shown.isEmpty) return null;
    return shown[_index.clamp(0, shown.length - 1)];
  }

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Builds a fresh arena for the current ability.
  void _load() {
    final s = _subject;
    _gameId++;
    _clock = 0;
    _cast = false;
    _game = s == null
        ? null
        : AbilityPreviewGame(
            member: abilityLabMember(
              creature: s.creature,
              potential: _band.potential,
              enhancementRank: _band.enhancement,
            ),
          );
  }

  void _tick() {
    if (!mounted) return;
    final game = _game;
    if (game != null && game.isLoaded && _playing) {
      _clock += 0.1;
      if (!_cast && _clock >= _castAt) {
        _cast = true;
        game.castSpecial();
      }
      if (_clock >= _castAt + _hold) {
        _step(1);
        return;
      }
    }
    setState(() {});
  }

  void _step(int by) {
    final n = _shown.length;
    if (n == 0) return;
    setState(() {
      _index = (_index + by) % n;
      if (_index < 0) _index += n;
      _load();
    });
  }

  void _jumpTo(int index) => setState(() {
    _index = index;
    _load();
  });

  void _recast() {
    HapticFeedback.selectionClick();
    setState(() {
      _clock = _castAt;
      _cast = true;
      _game?.castSpecial();
    });
  }

  void _setFamily(String? family) => setState(() {
    final current = _subject;
    _family = family;
    // Stay on the same ability when it is still shown.
    final shown = _shown;
    final keep = current == null ? -1 : shown.indexOf(current);
    _index = keep < 0 ? 0 : keep;
    _load();
  });

  void _setBand(_Band band) => setState(() {
    _band = band;
    _load();
  });

  Future<void> _openJumpList() async {
    final shown = _shown;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: _P.bg1,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: shown.length,
            itemBuilder: (context, i) {
              final s = shown[i];
              final accent = kElementColors[s.element] ?? _P.amber;
              final here = i == _index;
              return InkWell(
                onTap: () => Navigator.pop(context, i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: here ? _P.amber.withValues(alpha: 0.12) : null,
                  child: Row(
                    children: [
                      Container(width: 3, height: 26, color: accent),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 34,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: _P.parchmentDim,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${s.family.toUpperCase()} · '
                          '${s.element.toUpperCase()}   ${s.special}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: here ? _P.amberBright : _P.parchment,
                            fontSize: 12,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    if (picked != null && mounted) _jumpTo(picked);
  }

  @override
  Widget build(BuildContext context) {
    final s = _subject;
    final game = _game;
    final shown = _shown;
    final accent = s == null
        ? _P.amber
        : (kElementColors[s.element] ?? _P.amber);
    final progress = game != null && game.isLoaded
        ? (_clock / (_castAt + _hold)).clamp(0.0, 1.0)
        : 0.0;
    return Scaffold(
      backgroundColor: _P.bg0,
      body: SafeArea(
        child: Column(
          children: [
            // Title: what is playing. Tap to jump to any ability.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: shown.isEmpty ? null : _openJumpList,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s == null
                                ? 'NO ABILITIES'
                                : '${s.family.toUpperCase()}  ·  '
                                      '${s.element.toUpperCase()}',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.8,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            s?.special ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _P.parchment,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s == null
                                ? ''
                                : '${s.creature.name}  ·  LV 10  ·  '
                                      '${_band.label}  ·  '
                                      '${_index + 1} / ${shown.length}  ▾',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: _P.parchmentDim,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: _P.parchmentDim),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: accent.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: game == null
                        ? const SizedBox.expand()
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              IgnorePointer(
                                child: GameWidget(
                                  key: ValueKey(_gameId),
                                  game: game,
                                ),
                              ),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onScaleStart: (_) => game.beginCameraGesture(),
                                onScaleUpdate: (d) => game.cameraGesture(
                                  panDelta: d.focalPointDelta,
                                  scale: d.scale,
                                ),
                                onDoubleTap: game.resetView,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            // How far through this ability's turn the reel is.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: _P.line,
                  valueColor: AlwaysStoppedAnimation(accent),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ReelButton(
                    icon: Icons.skip_previous,
                    label: 'BACK',
                    onTap: () => _step(-1),
                  ),
                  _ReelButton(
                    icon: _playing ? Icons.pause : Icons.play_arrow,
                    label: _playing ? 'PAUSE' : 'PLAY',
                    onTap: () => setState(() => _playing = !_playing),
                  ),
                  _ReelButton(
                    icon: Icons.replay,
                    label: 'CAST',
                    onTap: _recast,
                  ),
                  _ReelButton(
                    icon: Icons.skip_next,
                    label: 'NEXT',
                    onTap: () => _step(1),
                  ),
                  _ReelButton(
                    icon: Icons.timer_outlined,
                    label: '${_hold.toStringAsFixed(_hold % 1 == 0 ? 0 : 1)} S',
                    onTap: () => setState(() {
                      final i = _holds.indexOf(_hold);
                      _hold = _holds[(i + 1) % _holds.length];
                    }),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final b in _kBands)
                    _Chip(
                      label: b.label,
                      selected: identical(b, _band),
                      onTap: () => _setBand(b),
                    ),
                  const SizedBox(width: 12),
                  _Chip(
                    label: 'ALL ${_all.length}',
                    selected: _family == null,
                    onTap: () => _setFamily(null),
                  ),
                  for (final f in _kFamilies)
                    _Chip(
                      label:
                          '${f.toUpperCase()} '
                          '${_all.where((s) => s.family == f).length}',
                      selected: _family == f,
                      onTap: () => _setFamily(f),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

// ── Palette (the ability preview's: the survival HUD's tokens) ─────────────

class _P {
  static const bg0 = Color(0xFF080808);
  static const bg1 = Color(0xFF111111);
  static const bg2 = Color(0xFF181614);
  static const amber = Color(0xFFC4A35A);
  static const amberBright = Color(0xFFE4C16A);
  static const parchment = Color(0xFFE8DFC8);
  static const parchmentDim = Color(0xFF9C9382);
  static const line = Color(0xFF2E2A24);
}

class _ReelButton extends StatelessWidget {
  const _ReelButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _P.parchment, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: _P.parchmentDim,
                fontSize: 10,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, top: 6, bottom: 6),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _P.amber.withValues(alpha: 0.18) : _P.bg2,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: selected ? _P.amber : _P.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              color: selected ? _P.amberBright : _P.parchmentDim,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
