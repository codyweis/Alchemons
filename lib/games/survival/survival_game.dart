import 'dart:math' as math;
import 'dart:ui';

import 'package:alchemons/games/boss/attack_animations.dart';
import 'package:alchemons/games/survival/survival_creature_sprite.dart';
import 'package:alchemons/games/survival/survival_engine.dart';
import 'package:alchemons/services/gameengines/boss_battle_engine_service.dart';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// Survival mode with formations, ranged/melee AI, and particle enemies
class SurvivalGame extends FlameGame
    with PanDetector, ScaleDetector, TapDetector {
  final List<PartyMember> party;

  bool _gameOverShown = false;
  GameOverOverlay? _gameOverOverlay;

  bool _usedInitialDelay = false;
  static const initialWaveDelay = 3.0;

  SurvivalEngine? _engine;
  SurvivalEngine? get engine => _engine;
  SurvivalWave? _currentWave;

  late CameraComponent gameCamera;
  late World gameWorld;

  double _roundTimer = 0;
  final double _roundInterval = 0.15;

  final Map<String, SurvivalCreatureSprite> _playerSprites = {};
  final Map<String, EnemyParticleSprite> _enemySprites = {};

  static const worldWidth = 1800.0;
  static const worldHeight = 2600.0;

  double _baseZoom = 0.5;
  Vector2? _lastPanPosition;

  static const minZoom = 0.4;
  static const maxZoom = 1.3;

  // Formation positioning
  static const formationFrontY = worldHeight * 0.68;
  static const formationBackY = worldHeight * 0.78;
  static const formationLeftX = worldWidth * 0.35;
  static const formationRightX = worldWidth * 0.65;

  static const enemySpawnYTop = -150.0;
  static const enemySpawnYSides = worldHeight * 0.3;
  static const enemyFormationY = worldHeight * 0.25;

  static const rangedAttackDistance = 400.0;
  static const meleeEngageDistance = 180.0;

  bool _waveTransitioning = false;
  bool _battleActive = false;

  double _waveStartDelay = 0;

  late SurvivalUIOverlay uiOverlay;

  SurvivalGame({required this.party});
  SurvivalGame.godTeam() : party = DebugTeams.makeGodTeam();

  @override
  Color backgroundColor() => const Color(0xFF0a0a14);

  @override
  void onTapUp(TapUpInfo info) {
    super.onTapUp(info);

    if (_gameOverOverlay != null) {
      final handled = _gameOverOverlay!.handleTap(info.eventPosition.global);
      if (handled) return;
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    gameWorld = World();
    await add(gameWorld);

    gameCamera = CameraComponent(world: gameWorld)
      ..viewfinder.anchor = Anchor.center;
    await add(gameCamera);

    gameCamera.viewfinder.zoom = _baseZoom;
    gameCamera.viewfinder.position = Vector2(worldWidth / 2, worldHeight * 0.5);

    _createStarField();

    _engine = SurvivalEngine(party: party);
    _currentWave = _engine!.startNextWave();

    for (final member in _engine!.state.party) {
      final c = member.combatant;
      print(
        'PLAYER: ${c.name} [${member.position}] lvl=${c.level} hp=${c.maxHp} '
        'atk=${c.physAtk}/${c.elemAtk} def=${c.physDef}/${c.elemDef}',
      );
    }

    uiOverlay = SurvivalUIOverlay();
    add(uiOverlay);

    _layoutField();
  }

  void _createStarField() {
    final random = math.Random();
    for (var i = 0; i < 500; i++) {
      gameWorld.add(
        StarComponent(
          position: Vector2(
            random.nextDouble() * worldWidth,
            random.nextDouble() * worldHeight,
          ),
          starSize: random.nextDouble() * 2.5 + 0.4,
          brightness: random.nextDouble() * 0.7 + 0.2,
        ),
      );
    }
  }

  void _layoutField() {
    if (_currentWave == null) return;

    // Remove ONLY enemy sprites between waves
    gameWorld.children.whereType<EnemyParticleSprite>().toList().forEach(
      (s) => s.removeFromParent(),
    );
    _enemySprites.clear();

    _roundTimer = 0;

    final waveNumber = _engine?.state.waveNumber ?? 1;

    if (!_usedInitialDelay && waveNumber == 1) {
      _battleActive = false;
      _waveStartDelay = initialWaveDelay;
    } else {
      _battleActive = true;
      _waveStartDelay = 0;
    }

    if (_playerSprites.isEmpty) {
      _layoutPlayerFormation();
    } else {
      for (final sprite in _playerSprites.values) {
        if (!sprite.combatant.isDead) {
          sprite.returnToFormation(forced: true);
        }
      }
    }

    _spawnEnemyWave();
  }

  void _layoutPlayerFormation() {
    final partyMembers = _engine?.state.party ?? party;

    for (var i = 0; i < partyMembers.length; i++) {
      final member = partyMembers[i];
      final combatant = member.combatant;

      if (!combatant.isAlive) continue;

      // Map formation position to screen coordinates
      final homePos = _getFormationScreenPosition(member.position);

      final sprite =
          SurvivalCreatureSprite(
              combatant: combatant,
              isPlayer: true,
              homePosition: homePos,
              formationIndex: i,
            )
            ..position = homePos + Vector2(0, 150)
            ..anchor = Anchor.center;

      _playerSprites[combatant.id] = sprite;
      gameWorld.add(sprite);
      sprite.playSpawnAnimation();
    }
  }

  Vector2 _getFormationScreenPosition(FormationPosition position) {
    switch (position) {
      case FormationPosition.frontLeft:
        return Vector2(formationLeftX, formationFrontY);
      case FormationPosition.frontRight:
        return Vector2(formationRightX, formationFrontY);
      case FormationPosition.backLeft:
        return Vector2(formationLeftX, formationBackY);
      case FormationPosition.backRight:
        return Vector2(formationRightX, formationBackY);
    }
  }

  void _spawnEnemyWave() {
    final enemies = _currentWave!.enemies;
    final enemiesPerRow = math.min(enemies.length, 8);

    for (var i = 0; i < enemies.length; i++) {
      final enemy = enemies[i];
      final row = i ~/ enemiesPerRow;
      final col = i % enemiesPerRow;

      final spawnFromSide = math.Random().nextDouble() < 0.3;

      Vector2 spawnPos, targetPos;

      if (spawnFromSide && (col < 2 || col >= enemiesPerRow - 2)) {
        final isLeft = col < enemiesPerRow / 2;
        spawnPos = Vector2(
          isLeft ? -100 : worldWidth + 100,
          enemySpawnYSides + row * 100,
        );
        targetPos = Vector2(
          isLeft ? 250 : worldWidth - 250,
          enemyFormationY + row * 80,
        );
      } else {
        final spacing = math.min(180.0, (worldWidth * 0.85) / enemiesPerRow);
        final startX = (worldWidth - (enemiesPerRow - 1) * spacing) / 2;
        spawnPos = Vector2(
          startX + col * spacing + (math.Random().nextDouble() * 40 - 20),
          enemySpawnYTop,
        );
        targetPos = Vector2(
          startX + col * spacing + (math.Random().nextDouble() * 30 - 15),
          enemyFormationY + row * 80,
        );
      }

      final sprite =
          EnemyParticleSprite(
              combatant: enemy,
              homePosition: targetPos,
              formationIndex: i,
            )
            ..position = spawnPos
            ..anchor = Anchor.center;

      _enemySprites[enemy.id] = sprite;
      gameWorld.add(sprite);

      sprite.add(
        MoveEffect.to(
          targetPos,
          EffectController(
            duration: 2.0 + math.Random().nextDouble() * 0.5,
            curve: Curves.easeInOut,
          ),
        ),
      );
      sprite.playSpawnAnimation();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_engine == null || _currentWave == null) return;

    if (_engine!.isGameOver) {
      if (!_gameOverShown) {
        _gameOverShown = true;
        _onGameOver();
      }
      return;
    }

    _engine!.addTimeElapsed(Duration(milliseconds: (dt * 1000).round()));

    if (_waveTransitioning) return;

    // Live HUD values
    final state = _engine!.state;
    final enemiesAlive = _currentWave!.enemies.where((e) => e.isAlive).length;
    final enemiesTotal = _currentWave!.enemies.length;
    final killsThisWave = enemiesTotal - enemiesAlive;
    final totalKillsLive = state.totalKills + killsThisWave;

    if (!_battleActive) {
      _waveStartDelay -= dt;

      uiOverlay.updateStats(
        wave: state.waveNumber,
        score: state.score,
        kills: totalKillsLive,
        enemiesAlive: enemiesAlive,
        enemiesTotal: enemiesTotal,
        countdown: _waveStartDelay > 0 ? _waveStartDelay : null,
      );

      if (_waveStartDelay <= 0) {
        _battleActive = true;
        _usedInitialDelay = true;
      }
      return;
    }

    uiOverlay.updateStats(
      wave: state.waveNumber,
      score: state.score,
      kills: totalKillsLive,
      enemiesAlive: enemiesAlive,
      enemiesTotal: enemiesTotal,
      countdown: null,
    );

    final allSprites = <CombatSprite>[
      ..._playerSprites.values,
      ..._enemySprites.values,
    ];
    for (final sprite in allSprites) {
      sprite.updateCombatAI(allSprites, dt);
    }

    _roundTimer += dt;
    if (_roundTimer >= _roundInterval) {
      _roundTimer = 0;

      final events = _engine!.runRealtimeTick(
        _currentWave!,
        maxActionsPerTick: 3,
      );

      for (final ev in events) {
        _handleBattleEvent(ev);
      }

      if (_currentWave!.allEnemiesDefeated && !_waveTransitioning) {
        _onWaveComplete();
      }
    }
  }

  void _handleBattleEvent(BattleEvent ev) {
    final attackerSprite = _getSprite(ev.action.actor.id);
    final targetSprite = _getSprite(ev.action.target.id);

    if (targetSprite == null) return;

    if (ev.result.damage > 0) {
      targetSprite.showDamage(ev.result.damage, ev.result.typeMultiplier);

      final element = ev.action.actor.types.isNotEmpty
          ? ev.action.actor.types.first
          : 'Generic';
      final animation = AttackAnimations.getAnimation(ev.action.move, element);

      if (attackerSprite != null && _isRangedMove(ev.action.move)) {
        _createProjectile(attackerSprite, targetSprite, animation, element);
      } else {
        gameWorld.add(
          animation.createEffect(targetSprite.absoluteCenter.clone()),
        );
      }
    }

    attackerSprite?.updateStatusIcons();
    targetSprite.updateStatusIcons();

    if (ev.action.target.isDead && !targetSprite.isDying) {
      targetSprite.playDeathAnimation();
    }
  }

  CombatSprite? _getSprite(String id) =>
      _playerSprites[id] ?? _enemySprites[id];

  bool _isRangedMove(BattleMove move) {
    return move.type == MoveType.elemental;
  }

  void _createProjectile(
    CombatSprite attacker,
    CombatSprite target,
    AttackAnimation animation,
    String element,
  ) {
    final startPos = attacker.absoluteCenter.clone();
    final endPos = target.absoluteCenter.clone();
    final color = _getElementColor(element);

    final projectile = CircleComponent(
      radius: 10,
      position: startPos,
      paint: Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      anchor: Anchor.center,
    );

    projectile.add(
      CircleComponent(
        radius: 15,
        position: Vector2.zero(),
        paint: Paint()
          ..color = color.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        anchor: Anchor.center,
      ),
    );

    gameWorld.add(projectile);

    projectile.add(
      SequenceEffect([
        MoveEffect.to(
          endPos,
          EffectController(duration: 0.4, curve: Curves.linear),
          onComplete: () {
            gameWorld.add(animation.createEffect(endPos));
          },
        ),
        RemoveEffect(),
      ]),
    );

    projectile.add(
      RotateEffect.by(math.pi * 4, EffectController(duration: 0.4)),
    );
  }

  Color _getElementColor(String element) {
    const colors = {
      'Fire': Colors.orange,
      'Water': Colors.blue,
      'Earth': Colors.brown,
      'Air': Colors.white70,
      'Ice': Colors.cyan,
      'Lightning': Colors.yellow,
      'Plant': Colors.green,
      'Poison': Colors.purple,
      'Steam': Colors.grey,
      'Lava': Colors.deepOrange,
      'Dust': Colors.brown,
      'Spirit': Colors.white,
      'Light': Colors.yellowAccent,
    };
    return colors[element] ?? Colors.white;
  }

  void _onWaveComplete() {
    _waveTransitioning = true;
    _engine!.completeWave(_currentWave!);
    _engine!.state.recoverBetweenWaves(healPercent: 0.30);

    for (final sprite in _playerSprites.values) {
      sprite.returnToFormation(forced: true);
    }

    if (_engine != null && !_engine!.isGameOver) {
      _currentWave = _engine!.startNextWave();
      _layoutField();
    }

    _waveTransitioning = false;
  }

  void _onGameOver() {
    _battleActive = false;
    _waveTransitioning = false;

    print('=== GAME OVER ===');
    print(
      'Score: ${_engine!.state.score}, '
      'Waves: ${_engine!.state.waveNumber - 1}, '
      'Kills: ${_engine!.state.totalKills}',
    );

    _gameOverOverlay = GameOverOverlay(
      finalState: _engine!.state,
      onExit: () {
        final ctx = buildContext;
        if (ctx != null) {
          Navigator.of(ctx).pop();
        }
      },
    );

    add(_gameOverOverlay!);
  }

  @override
  void onPanStart(DragStartInfo info) =>
      _lastPanPosition = info.eventPosition.global;

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (_lastPanPosition == null) return;

    final delta = info.eventPosition.global - _lastPanPosition!;
    _lastPanPosition = info.eventPosition.global;

    final newPos =
        gameCamera.viewfinder.position - (delta / gameCamera.viewfinder.zoom);
    final halfW = (size.x / 2) / gameCamera.viewfinder.zoom;
    final halfH = (size.y / 2) / gameCamera.viewfinder.zoom;

    gameCamera.viewfinder.position = Vector2(
      newPos.x.clamp(halfW, worldWidth - halfW),
      newPos.y.clamp(halfH, worldHeight - halfH),
    );
  }

  @override
  void onPanEnd(DragEndInfo info) => _lastPanPosition = null;

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    final scale = info.scale.global is Vector2
        ? (info.scale.global as Vector2).x
        : (info.scale.global as num).toDouble();
    gameCamera.viewfinder.zoom = (_baseZoom * scale).clamp(minZoom, maxZoom);
  }

  @override
  void onScaleEnd(ScaleEndInfo info) => _baseZoom = gameCamera.viewfinder.zoom;
}

class EnemyParticleSprite extends CombatSprite {
  final int formationIndex;
  late List<CircleComponent> particles;
  final math.Random _rng = math.Random();

  EnemyParticleSprite({
    required super.combatant,
    required super.homePosition,
    required this.formationIndex,
  }) : super(isPlayer: false, size: Vector2(80, 80));

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    BattleEngine.isSurvivalMode = true;

    final element = combatant.types.isNotEmpty
        ? combatant.types.first
        : 'Generic';
    final color = _getElementColor(element);
    final tier = _getEnemyTier();

    particles = _createParticleCluster(color, tier);
    for (final p in particles) {
      add(p);
    }
    _startParticleAnimation();
  }

  int _getEnemyTier() {
    if (combatant.level <= 3) return 1;
    if (combatant.level <= 6) return 2;
    if (combatant.level <= 10) return 3;
    if (combatant.level <= 15) return 4;
    return 5;
  }

  List<CircleComponent> _createParticleCluster(Color color, int tier) {
    final particles = <CircleComponent>[];
    final particleCount = 3 + tier * 2;
    final baseRadius = 3.0 + tier * 2;

    for (var i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * math.pi * 2;
      final distance = 15 + tier * 5;

      particles.add(
        CircleComponent(
          radius: baseRadius + _rng.nextDouble() * 2,
          position: Vector2(
            math.cos(angle) * distance,
            math.sin(angle) * distance,
          ),
          paint: Paint()
            ..color = color.withOpacity(0.7 + _rng.nextDouble() * 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          anchor: Anchor.center,
        ),
      );
    }

    particles.add(
      CircleComponent(
        radius: baseRadius * 1.5,
        position: Vector2.zero(),
        paint: Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        anchor: Anchor.center,
      ),
    );

    return particles;
  }

  void _startParticleAnimation() {
    for (var i = 0; i < particles.length - 1; i++) {
      final particle = particles[i];
      particle.add(
        RotateEffect.by(
          math.pi * 2,
          EffectController(
            duration: 2.0 + _rng.nextDouble() * 2,
            infinite: true,
          ),
        ),
      );
      particle.add(
        SequenceEffect([
          ScaleEffect.to(Vector2.all(1.2), EffectController(duration: 0.5)),
          ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.5)),
        ], infinite: true),
      );
    }
  }

  Color _getElementColor(String element) {
    const colors = {
      'Fire': Colors.orange,
      'Water': Colors.blue,
      'Earth': Colors.brown,
      'Ice': Colors.cyan,
      'Lightning': Colors.yellow,
      'Plant': Colors.green,
      'Poison': Colors.purple,
      'Steam': Colors.grey,
      'Lava': Colors.deepOrange,
      'Dark': Colors.deepPurple,
      'Light': Colors.yellowAccent,
      'Blood': Colors.redAccent,
    };
    return colors[element] ?? Colors.white;
  }

  @override
  void playSpawnAnimation() {
    position.y += 50;
    scale = Vector2.zero();
    add(
      MoveEffect.by(
        Vector2(0, -50),
        EffectController(duration: 0.5, curve: Curves.easeOut),
      ),
    );
    add(
      SequenceEffect([
        ScaleEffect.to(Vector2.all(1.1), EffectController(duration: 0.3)),
        ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.2)),
      ]),
    );
  }

  @override
  void playDeathAnimation() {
    if (isDying) return;
    isDying = true;

    for (final particle in particles) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final distance = 80 + _rng.nextDouble() * 120;
      particle.add(
        MoveEffect.by(
          Vector2(math.cos(angle) * distance, math.sin(angle) * distance),
          EffectController(duration: 0.8, curve: Curves.easeOut),
        ),
      );
      particle.add(
        ScaleEffect.to(
          Vector2.zero(),
          EffectController(duration: 0.8, curve: Curves.easeIn),
        ),
      );
    }

    add(
      SequenceEffect([
        ScaleEffect.to(Vector2.all(1.5), EffectController(duration: 0.15)),
        ScaleEffect.to(
          Vector2.zero(),
          EffectController(duration: 0.6, curve: Curves.easeIn),
        ),
        RemoveEffect(),
      ]),
    );
  }

  @override
  void showDamage(int damage, double typeMultiplier) {
    if (combatant.isDead || isDying) return;

    final color = typeMultiplier > 1.0
        ? Colors.orange
        : (typeMultiplier < 1.0 ? Colors.grey : Colors.white);

    final text = TextComponent(
      text: '-$damage',
      anchor: Anchor.center,
      position: absoluteCenter + Vector2(0, -50),
      textRenderer: TextPaint(
        style: TextStyle(
          color: color,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(blurRadius: 8, color: Colors.black)],
        ),
      ),
    );

    gameRef.add(text);

    text.add(
      SequenceEffect([
        MoveEffect.by(
          Vector2(_rng.nextDouble() * 30 - 15, -60),
          EffectController(duration: 1.0, curve: Curves.easeOut),
        ),
        RemoveEffect(),
      ]),
    );

    text.add(
      ScaleEffect.to(
        Vector2.zero(),
        EffectController(duration: 0.3, startDelay: 0.7),
      ),
    );

    for (final particle in particles) {
      particle.add(
        SequenceEffect(
          List.generate(
            3,
            (_) => MoveEffect.by(
              Vector2(_rng.nextDouble() * 10 - 5, _rng.nextDouble() * 10 - 5),
              EffectController(duration: 0.04, reverseDuration: 0.04),
            ),
          ),
        ),
      );
    }
  }
}

class StarComponent extends PositionComponent {
  final double brightness, starSize;

  StarComponent({
    required Vector2 position,
    required this.starSize,
    required this.brightness,
  }) : super(position: position, size: Vector2.all(starSize));

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      starSize / 2,
      Paint()..color = Colors.white.withOpacity(brightness),
    );
  }
}

class SurvivalUIOverlay extends Component {
  int wave = 1;
  int score = 0;
  int kills = 0;
  int enemiesAlive = 0;
  int enemiesTotal = 0;
  double? countdown;

  void updateStats({
    required int wave,
    required int score,
    required int kills,
    required int enemiesAlive,
    required int enemiesTotal,
    double? countdown,
  }) {
    this.wave = wave;
    this.score = score;
    this.kills = kills;
    this.enemiesAlive = enemiesAlive;
    this.enemiesTotal = enemiesTotal;
    this.countdown = countdown;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final bannerHeight = 80.0;
    final bannerRect = Rect.fromLTWH(0, 0, 400, bannerHeight);

    final bgPaint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(bannerRect, const Radius.circular(8)),
      bgPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bannerRect, const Radius.circular(8)),
      borderPaint,
    );

    final titleStyle = TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.bold,
      shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4)],
    );

    final valueStyle = TextStyle(
      color: Colors.amber,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4)],
    );

    final smallStyle = TextStyle(
      color: Colors.white70,
      fontSize: 13,
      shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4)],
    );

    _drawText(canvas, 'WAVE $wave', 20, 15, titleStyle);

    if (countdown != null && countdown! > 0) {
      final countdownText = 'Starting in ${countdown!.ceil()}...';
      _drawText(
        canvas,
        countdownText,
        20,
        38,
        TextStyle(
          color: Colors.yellow,
          fontSize: 15,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4),
          ],
        ),
      );
    } else {
      _drawText(canvas, 'Score: $score', 20, 38, smallStyle);
    }

    _drawText(canvas, 'Kills: $kills', 20, 56, smallStyle);

    final enemyText = '$enemiesAlive/$enemiesTotal';
    _drawText(canvas, 'Enemies', 250, 15, smallStyle);
    _drawText(canvas, enemyText, 250, 35, valueStyle);
  }

  void _drawText(
    Canvas canvas,
    String text,
    double x,
    double y,
    TextStyle style,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(x, y));
  }
}

class GameOverOverlay extends Component with HasGameRef<SurvivalGame> {
  final SurvivalRunState finalState;
  final VoidCallback? onExit;

  GameOverOverlay({required this.finalState, this.onExit});

  Rect _computeExitButtonRect(Size screenSize) {
    const cardWidth = 360.0;
    const cardHeight = 260.0;

    final cardLeft = (screenSize.width - cardWidth) / 2;
    final cardTop = (screenSize.height - cardHeight) / 2;
    final cardRight = cardLeft + cardWidth;
    final cardBottom = cardTop + cardHeight;

    final cardRect = Rect.fromLTRB(cardLeft, cardTop, cardRight, cardBottom);

    const btnWidth = 140.0;
    const btnHeight = 40.0;

    final btnLeft = cardRect.center.dx - btnWidth / 2;
    final btnTop = cardBottom - 60;
    return Rect.fromLTWH(btnLeft, btnTop, btnWidth, btnHeight);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final size = gameRef.size;
    final screenSize = size.toSize();

    final bgPaint = Paint()..color = Colors.black.withOpacity(0.75);
    canvas.drawRect(Offset.zero & screenSize, bgPaint);

    const cardWidth = 360.0;
    const cardHeight = 260.0;

    final cardLeft = (screenSize.width - cardWidth) / 2;
    final cardTop = (screenSize.height - cardHeight) / 2;
    final cardRight = cardLeft + cardWidth;
    final cardBottom = cardTop + cardHeight;

    final cardRRect = RRect.fromLTRBR(
      cardLeft,
      cardTop,
      cardRight,
      cardBottom,
      const Radius.circular(16),
    );

    final cardPaint = Paint()..color = const Color(0xFF141428);
    final borderPaint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(cardRRect, cardPaint);
    canvas.drawRRect(cardRRect, borderPaint);

    const titleStyle = TextStyle(
      color: Colors.white,
      fontSize: 24,
      fontWeight: FontWeight.bold,
      shadows: [Shadow(color: Colors.black, blurRadius: 6)],
    );

    const subtitleStyle = TextStyle(
      color: Colors.white70,
      fontSize: 14,
      fontStyle: FontStyle.italic,
      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
    );

    const labelStyle = TextStyle(
      color: Colors.white70,
      fontSize: 15,
      shadows: [Shadow(color: Colors.black, blurRadius: 3)],
    );

    const valueStyle = TextStyle(
      color: Colors.amber,
      fontSize: 17,
      fontWeight: FontWeight.w600,
      shadows: [Shadow(color: Colors.black, blurRadius: 3)],
    );

    const buttonTextStyle = TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.bold,
    );

    final centerX = screenSize.width / 2;
    var y = cardTop + 28;

    _drawCenteredText(canvas, 'GAME OVER', centerX, y, titleStyle);
    y += 28;

    _drawCenteredText(canvas, 'Run summary', centerX, y, subtitleStyle);
    y += 32;

    final wavesCleared = (finalState.waveNumber - 1).clamp(0, 9999);

    y = _drawRow(
      canvas,
      cardLeft + 26,
      cardRight - 26,
      y,
      'Waves cleared',
      '$wavesCleared',
      labelStyle,
      valueStyle,
    );
    y = _drawRow(
      canvas,
      cardLeft + 26,
      cardRight - 26,
      y + 6,
      'Score',
      '${finalState.score}',
      labelStyle,
      valueStyle,
    );
    y = _drawRow(
      canvas,
      cardLeft + 26,
      cardRight - 26,
      y + 6,
      'Total kills',
      '${finalState.totalKills}',
      labelStyle,
      valueStyle,
    );

    final secs = finalState.timeElapsed.inSeconds;
    final minutes = secs ~/ 60;
    final remSecs = secs % 60;
    final timeText = '${minutes}m ${remSecs}s';

    _drawRow(
      canvas,
      cardLeft + 26,
      cardRight - 26,
      y + 6,
      'Time survived',
      timeText,
      labelStyle,
      valueStyle,
    );

    final btnRect = _computeExitButtonRect(screenSize);

    final btnPaint = Paint()..color = Colors.redAccent.withOpacity(0.9);
    final btnBorder = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final btnRRect = RRect.fromRectAndRadius(
      btnRect,
      const Radius.circular(10),
    );

    canvas.drawRRect(btnRRect, btnPaint);
    canvas.drawRRect(btnRRect, btnBorder);

    _drawCenteredText(
      canvas,
      'Exit',
      btnRect.center.dx,
      btnRect.center.dy - 10,
      buttonTextStyle,
    );
  }

  double _drawRow(
    Canvas canvas,
    double left,
    double right,
    double y,
    String label,
    String value,
    TextStyle labelStyle,
    TextStyle valueStyle,
  ) {
    final labelPainter = TextPainter(
      text: TextSpan(text: label, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final valuePainter = TextPainter(
      text: TextSpan(text: value, style: valueStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final labelOffset = Offset(left, y);
    final valueOffset = Offset(right - valuePainter.width, y);

    labelPainter.paint(canvas, labelOffset);
    valuePainter.paint(canvas, valueOffset);

    return y + labelPainter.height + 4;
  }

  void _drawCenteredText(
    Canvas canvas,
    String text,
    double centerX,
    double y,
    TextStyle style,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset(centerX - tp.width / 2, y));
  }

  bool handleTap(Vector2 gamePos) {
    final screenSize = gameRef.size.toSize();
    final btnRect = _computeExitButtonRect(screenSize);

    if (btnRect.contains(Offset(gamePos.x, gamePos.y))) {
      onExit?.call();
      return true;
    }
    return false;
  }
}
