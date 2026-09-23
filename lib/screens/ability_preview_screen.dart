import 'dart:async';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// What the Battle tab hands the preview: the summoned form of one creature
/// and the words already used to describe its two attacks.
class AbilityPreviewSubject {
  const AbilityPreviewSubject({
    required this.member,
    required this.autoAttackName,
    required this.autoAttackDescription,
    required this.autoAttackIcon,
    required this.specialName,
    required this.specialSubtitle,
    required this.specialDescription,
    required this.specialIcon,
    required this.accent,
  });

  final CosmicPartyMember member;
  final String autoAttackName;
  final String autoAttackDescription;
  final IconData autoAttackIcon;
  final String specialName;
  final String specialSubtitle;
  final String specialDescription;
  final IconData specialIcon;
  final Color accent;

  bool get specialIsPassive =>
      isPassiveOnlyCosmicAbility(member.family, member.element);
}

/// A live look at one Alchemon fighting: the real Survival game with the
/// waves held back, a ring of practice bodies, and the special on a button.
class AbilityPreviewScreen extends StatefulWidget {
  const AbilityPreviewScreen({super.key, required this.subject});

  final AbilityPreviewSubject subject;

  static Future<void> open(BuildContext context, AbilityPreviewSubject s) =>
      Navigator.of(context, rootNavigator: true).push(
        PageRouteBuilder<void>(
          opaque: true,
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, __, ___) => AbilityPreviewScreen(subject: s),
          transitionsBuilder: (_, anim, __, child) {
            final curved = CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween(begin: 0.97, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
        ),
      );

  @override
  State<AbilityPreviewScreen> createState() => _AbilityPreviewScreenState();
}

class _AbilityPreviewScreenState extends State<AbilityPreviewScreen> {
  late final AbilityPreviewGame _game = AbilityPreviewGame(
    member: widget.subject.member,
  );

  @visibleForTesting
  AbilityPreviewGame get debugGame => _game;
  Timer? _hudTimer;

  @override
  void initState() {
    super.initState();
    // The cooldown ring is read off the game, not animated on its own.
    _hudTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _hudTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.subject;
    final accent = s.accent;
    return Scaffold(
      backgroundColor: _P.bg0,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              title: s.member.displayName,
              subtitle:
                  '${s.member.family.toUpperCase()}  ·  ${s.member.element.toUpperCase()}  ·  LV ${s.member.level}',
              accent: accent,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: _ArenaFrame(
                  accent: accent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // The game's own pan detector steers the ship, which
                        // is parked here, so every gesture goes to the camera.
                        IgnorePointer(child: GameWidget(game: _game)),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onScaleStart: (_) => _game.beginCameraGesture(),
                          onScaleUpdate: (d) => _game.cameraGesture(
                            panDelta: d.focalPointDelta,
                            scale: d.scale,
                          ),
                          onDoubleTap: () {
                            HapticFeedback.selectionClick();
                            _game.resetView();
                          },
                        ),
                        const Positioned(
                          right: 10,
                          bottom: 8,
                          child: IgnorePointer(child: _GestureHint()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _ControlPanel(subject: s, game: _game),
          ],
        ),
      ),
    );
  }
}

// ── Palette (the survival HUD's tokens) ─────────────────────────────────────

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

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.accent,
  });
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).maybePop();
            },
            icon: const Icon(AppIcons.arrow_back_ios_new_rounded, size: 18),
            color: _P.parchment,
            tooltip: 'Back',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _P.parchment,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: accent.withValues(alpha: 0.9),
                    fontSize: 10.5,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: _P.amber.withValues(alpha: 0.55)),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text(
              'PREVIEW',
              style: TextStyle(
                fontFamily: 'monospace',
                color: _P.amber,
                fontSize: 9.5,
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bracketed frame with corner sigils around the arena.
class _ArenaFrame extends StatelessWidget {
  const _ArenaFrame({required this.child, required this.accent});
  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            color: _P.bg1,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _P.line),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.10),
                blurRadius: 24,
                spreadRadius: -6,
              ),
            ],
          ),
          child: child,
        ),
        IgnorePointer(
          child: CustomPaint(painter: _CornerSigilPainter(accent: accent)),
        ),
      ],
    );
  }
}

class _CornerSigilPainter extends CustomPainter {
  const _CornerSigilPainter({required this.accent});
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    const len = 16.0;
    const inset = 6.0;
    void corner(Offset o, double sx, double sy) {
      canvas.drawLine(o, o + Offset(len * sx, 0), paint);
      canvas.drawLine(o, o + Offset(0, len * sy), paint);
      canvas.drawCircle(o + Offset(4 * sx, 4 * sy), 1.4, paint);
    }

    corner(const Offset(inset, inset), 1, 1);
    corner(Offset(size.width - inset, inset), -1, 1);
    corner(Offset(inset, size.height - inset), 1, -1);
    corner(Offset(size.width - inset, size.height - inset), -1, -1);
  }

  @override
  bool shouldRepaint(_CornerSigilPainter old) => old.accent != accent;
}

class _GestureHint extends StatelessWidget {
  const _GestureHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _P.bg0.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _P.line),
      ),
      child: const Text(
        'DRAG · PINCH · DOUBLE-TAP RESETS',
        style: TextStyle(
          fontFamily: 'monospace',
          color: _P.parchmentDim,
          fontSize: 8.5,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({required this.subject, required this.game});
  final AbilityPreviewSubject subject;
  final AbilityPreviewGame game;

  @override
  Widget build(BuildContext context) {
    final s = subject;
    final progress = game.specialProgress;
    final ready = game.specialReady;
    final passive = s.specialIsPassive;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AttackCard(
            label: 'AUTO ATTACK',
            title: s.autoAttackName,
            body: s.autoAttackDescription,
            accent: _P.amber,
          ),
          const SizedBox(height: 8),
          _AttackCard(
            label: passive ? 'SPECIAL · PASSIVE' : 'SPECIAL ABILITY',
            title: s.specialName,
            body: s.specialSubtitle,
            detail: s.specialDescription,
            accent: s.accent,
            featured: true,
            trailing: passive
                ? null
                : _CastButton(
                    accent: s.accent,
                    progress: progress,
                    ready: ready,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      game.castSpecial();
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AttackCard extends StatelessWidget {
  const _AttackCard({
    required this.label,
    required this.title,
    required this.body,
    required this.accent,
    this.detail,
    this.featured = false,
    this.trailing,
  });
  final String label;
  final String title;
  final String body;
  final String? detail;
  final Color accent;
  final bool featured;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: featured ? _P.bg2 : _P.bg1,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: featured ? accent.withValues(alpha: 0.55) : _P.line,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: accent.withValues(alpha: 0.85),
                    fontSize: 9.5,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _P.parchment,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  maxLines: detail == null ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: detail == null ? _P.parchmentDim : accent,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail!,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _P.parchmentDim,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

/// The cast button: a sigil ring that fills as the cooldown returns.
class _CastButton extends StatelessWidget {
  const _CastButton({
    required this.accent,
    required this.progress,
    required this.ready,
    required this.onTap,
  });
  final Color accent;
  final double progress;
  final bool ready;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 58,
        height: 58,
        child: CustomPaint(
          painter: _CooldownRingPainter(
            accent: accent,
            progress: progress,
            ready: ready,
          ),
          child: Center(
            child: Icon(
              AppIcons.play_arrow_rounded,
              size: 20,
              color: ready ? _P.amberBright : accent.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }
}

class _CooldownRingPainter extends CustomPainter {
  const _CooldownRingPainter({
    required this.accent,
    required this.progress,
    required this.ready,
  });
  final Color accent;
  final double progress;
  final bool ready;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 3;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = accent.withValues(alpha: ready ? 0.16 : 0.08)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = _P.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -pi / 2,
      2 * pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = ready ? _P.amberBright : accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    if (ready) {
      // Four small ticks: the ring is charged.
      final tick = Paint()
        ..color = _P.amberBright.withValues(alpha: 0.9)
        ..strokeWidth = 1.4;
      for (var i = 0; i < 4; i++) {
        final a = i * pi / 2 + pi / 4;
        canvas.drawLine(
          c + Offset(cos(a), sin(a)) * (r + 1),
          c + Offset(cos(a), sin(a)) * (r + 4),
          tick,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CooldownRingPainter old) =>
      old.progress != progress || old.ready != ready || old.accent != accent;
}

// ── The game ────────────────────────────────────────────────────────────────

/// The real Survival game with the waves held back. One companion, a ring of
/// practice bodies that hold their posts and come back when they fall, a
/// trickle of runners that walk in from the edge and die on whatever is in
/// their way, the ship parked and silent (and hidden unless the special
/// involves it), the meter never filling. Every attack and effect is the
/// real one, drawn by the real renderer.
class AbilityPreviewGame extends CosmicSurvivalGame {
  AbilityPreviewGame({required CosmicPartyMember member})
    : super(
        party: [
          CosmicPartyMember(
            instanceId: member.instanceId,
            baseId: member.baseId,
            displayName: member.displayName,
            imagePath: member.imagePath,
            element: member.element,
            family: member.family,
            level: member.level,
            statSpeed: member.statSpeed,
            statIntelligence: member.statIntelligence,
            statStrength: member.statStrength,
            statBeauty: member.statBeauty,
            statSpeedPotential: member.statSpeedPotential,
            statIntelligencePotential: member.statIntelligencePotential,
            statStrengthPotential: member.statStrengthPotential,
            statBeautyPotential: member.statBeautyPotential,
            slotIndex: 0,
            staminaBars: 3,
            staminaMax: 3,
            spriteSheet: member.spriteSheet,
            spriteVisuals: member.spriteVisuals,
            visualVariant: member.visualVariant,
          ),
        ],
        random: Random(7),
        onGameOver: () {},
        visualQuality: SurvivalVisualQuality.balanced,
      );

  static const int _ringCount = 8;
  static const double _ringRadius = 200;
  static const double _outerRadius = 290;
  static const double _runnerSpawnRadius = 520;
  static const double _runnerInterval = 1.1;
  static const int _runnerCap = 10;
  static const double _homeZoom = 0.75;

  @override
  double get cameraZoomMax => 1.6;

  /// Kin specials that act on or through the ship. For these the ship is
  /// drawn and seated below the orb; for everything else it is hidden, and
  /// sits on the orb so the camera (which follows it) is centred there.
  static const _shipInvolvedKin = {
    'Light', 'Water', 'Crystal', 'Air', 'Mud', 'Lava', //
    'Dark', 'Lightning', 'Steam', 'Blood',
  };
  late final bool shipInvolved =
      party.first.family.toLowerCase() == 'kin' &&
      _shipInvolvedKin.contains(party.first.element);
  late final Offset _shipSeat = shipInvolved
      ? const Offset(0, 130)
      : Offset.zero;

  Offset _userPan = Offset.zero;
  double _runnerTimer = 0.4;
  final Set<CosmicSurvivalEnemy> _runners = Set.identity();
  static const double _respawnDelay = 1.6;

  final Set<CosmicSurvivalEnemy> _mine = Set.identity();
  final Map<int, double> _respawnTimers = {};
  final Map<int, CosmicSurvivalEnemy?> _slots = {};
  final Map<CosmicSurvivalEnemy, Offset> _posts = Map.identity();
  double _lastCastCooldown = 1;
  final Random _dummyRng = Random(3);

  static const _dummyElements = [
    'Fire', 'Water', 'Earth', 'Air', 'Dark', 'Light', 'Ice', 'Plant', //
    'Lightning', 'Poison',
  ];

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    startGame();
    renderShip = shipInvolved;
    resetView();
    summonCompanion(0);
    clearCompanionTether();
    ship.position = orb.position + _shipSeat;
    for (var i = 0; i < _ringCount + 2; i++) {
      _spawnDummy(i);
    }
  }

  int _atk() {
    final comp = activeCompanions[0];
    return comp == null ? 30 : max(comp.abilityAtk, 10);
  }

  /// Posts take many basic hits to fall, so the ring is standing most of the
  /// time; a good special still clears a few.
  double _dummyHp() => _atk() * 6.0;

  /// Runners fall to a few basic hits: they are here to die on the way in.
  double _runnerHp() => _atk() * 2.2;

  void _spawnRunner() {
    final angle = _dummyRng.nextDouble() * 2 * pi;
    final hp = _runnerHp();
    final body = CosmicSurvivalEnemy(
      position:
          orb.position + Offset(cos(angle), sin(angle)) * _runnerSpawnRadius,
      hp: hp,
      maxHp: hp,
      speed: tierBaseSpeed(EnemyTier.wisp) * 0.55,
      damage: 1,
      radius: tierRadius(EnemyTier.wisp),
      tier: EnemyTier.wisp,
      element: _dummyElements[_dummyRng.nextInt(_dummyElements.length)],
      conduct: EnemyConduct.charge,
      target: CosmicEnemyTarget.orb,
      retargetTimer: 99999,
    );
    enemies.add(body);
    _mine.add(body);
    _runners.add(body);
  }

  // ── Camera ──────────────────────────────────────────────────────────────

  @override
  void cameraGesture({
    required Offset panDelta,
    required double scale,
    Offset? focalPoint,
  }) {
    final zoom = (cameraGestureStartZoom * scale).clamp(
      cameraZoomMin,
      cameraZoomMax,
    );
    setCameraZoom(zoom);
    _userPan -= panDelta / zoom;
    _userPan = clampCameraCentre(orb.position + _userPan) - orb.position;
    _applyCamera();
  }

  @override
  void recenterCamera() => resetView();

  void resetView() {
    _userPan = Offset.zero;
    setCameraZoom(_homeZoom);
    _applyCamera();
  }

  /// The camera follows the ship; this keeps the orb in the centre of the
  /// frame regardless of where the ship is seated, plus the user's pan.
  void _applyCamera() {
    cameraPanOffset = _userPan - _shipSeat;
  }

  /// Where every practice body stands, for the preview harness.
  @visibleForTesting
  String debugDescribeField() {
    final parts = <String>[];
    for (final e in enemies) {
      final d = (e.position - orb.position).distance;
      parts.add('${e.tier.name}@${d.round()}${e.isDead ? 'x' : ''}');
    }
    return 'bodies=${parts.join(' ')}';
  }

  void _spawnDummy(int slot) {
    final outer = slot >= _ringCount;
    final angle = outer
        ? (slot - _ringCount) * pi + pi / 2 + _dummyRng.nextDouble() * 0.5
        : slot * (2 * pi / _ringCount) + _dummyRng.nextDouble() * 0.25;
    final radius = outer ? _outerRadius : _ringRadius;
    final tier = outer ? EnemyTier.sentinel : EnemyTier.drone;
    final hp = _dummyHp() * (outer ? 1.6 : 1.0);
    final body = CosmicSurvivalEnemy(
      position: orb.position + Offset(cos(angle), sin(angle)) * radius,
      hp: hp,
      maxHp: hp,
      speed: 0,
      damage: 0,
      radius: tierRadius(tier),
      tier: tier,
      element: _dummyElements[slot % _dummyElements.length],
      conduct: EnemyConduct.charge,
      target: CosmicEnemyTarget.orb,
      retargetTimer: 99999,
    );
    enemies.add(body);
    _mine.add(body);
    _posts[body] = body.position;
    _slots[slot] = body;
    _respawnTimers.remove(slot);
  }

  /// Fire the special now.
  void castSpecial() {
    final comp = activeCompanions[0];
    if (comp == null) return;
    comp.specialCooldown = 0;
  }

  bool get specialReady {
    final comp = activeCompanions[0];
    return comp != null && comp.specialCooldown <= 0.05;
  }

  /// 0 just after a cast, 1 when the special is ready again.
  double get specialProgress {
    final comp = activeCompanions[0];
    if (comp == null) return 0;
    if (comp.specialCooldown <= 0) return 1;
    if (comp.specialCooldown.isInfinite) return 0;
    return (1 - comp.specialCooldown / _lastCastCooldown).clamp(0.0, 1.0);
  }

  @override
  void update(double dt) {
    if (isLoaded) {
      // Nothing that interrupts: no draft, no pause, no losing.
      alchemicalMeter = 0;
      showingPowerUpSelection = false;
      gamePaused = false;
      isGameOver = false;
      orb.currentHp = orb.maxHp;
      ship.currentHp = ship.maxHp;
      ship.isDead = false;
      // Parked: the ship would otherwise drift into its idle orbit and take
      // the camera with it.
      ship.position = orb.position + _shipSeat;
      // The ship's own gun stays holstered: this is the Alchemon's show.
      ship.fireTimer = double.negativeInfinity;
      final comp = activeCompanions[0];
      if (comp != null) {
        comp.currentHp = comp.maxHp;
        if (comp.specialCooldown > _lastCastCooldown &&
            !comp.specialCooldown.isInfinite) {
          _lastCastCooldown = comp.specialCooldown;
        }
      }
    }
    super.update(dt);
    if (!isLoaded) return;
    // Waves still try to arrive; they are not this scene's business.
    enemies.removeWhere((e) => !_mine.contains(e));
    activeBoss = null;
    extraBosses.clear();
    _applyCamera();
    // Runners: a trickle from the edge, walking at the orb through whatever
    // the special has put in the way, dying on it or on the orb.
    for (final r in _runners.toList()) {
      if (r.isDead) {
        _runners.remove(r);
        _mine.remove(r);
      }
    }
    _runnerTimer -= dt;
    if (_runnerTimer <= 0 && _runners.length < _runnerCap) {
      _runnerTimer = _runnerInterval;
      _spawnRunner();
    }
    // Practice bodies hold their posts. Crowd pressure and the pull of the
    // orb walk them in even at zero speed, so they are sprung back: a pull
    // or a knockback still reads as a shove, then they settle again.
    final settle = (dt * 6).clamp(0.0, 1.0);
    for (final e in enemies) {
      final post = _posts[e];
      if (post == null || e.isDead) continue;
      e.position = Offset.lerp(e.position, post, settle)!;
    }
    // Fallen practice bodies come back after a beat.
    for (final entry in _slots.entries.toList()) {
      final body = entry.value;
      if (body == null) continue;
      if (body.isDead) {
        _mine.remove(body);
        _posts.remove(body);
        _slots[entry.key] = null;
        _respawnTimers[entry.key] = _respawnDelay;
      }
    }
    for (final slot in _respawnTimers.keys.toList()) {
      final t = _respawnTimers[slot]! - dt;
      if (t <= 0) {
        _spawnDummy(slot);
      } else {
        _respawnTimers[slot] = t;
      }
    }
  }
}
