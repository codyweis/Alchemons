// lib/games/constellations/constellation_game.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Map<ConstellationTree, List<String>> kTreeStoryFragments = {
  ConstellationTree.breeder: [
    'Before there were labs, there was only warmth and watching.',
    'A single egg floated in the dark, dreaming of feathers and teeth.',
    'Hands you do not remember cupped it like a fragile star.',
    'Tiny hearts answered from inside, beating out a secret code.',
    'The shell learned your scent, the way dust learns to fall.',
    'You whispered a promise you had no power to keep.',
    'In reply, the egg shifted closer to your voice.',
    'Old instincts woke: nest-building, danger-smelling, name-weaving.',
    'You braided straw, data, and starlight into a cradle.',
    'The hatchery accepted you as one of its own.',
    'Cracks formed, not from weakness, but from arrival.',
    'When the shell finally broke, the world gained a new axis.',
    'The newborn blinked once, as if approving the architecture.',
    'Every future bond began in that first uncertain touch.',
    'Care stopped being optional and became infrastructure.',
    'From then on, nothing truly alone stayed that way for long.',
  ],
  ConstellationTree.combat: [
    'They built the arena in a place sound refused to cross.',
    'No cheers, no drums, only breath and impact.',
    'Your first step inside felt heavier than gravity allowed.',
    'Old scars in the floor traced obsolete strategies.',
    'You stood where legends once evaporated into statistics.',
    'A single light followed you like an accusing star.',
    'Your partner waited, muscles coiled, eyes full of questions.',
    'You answered with a gesture: not command, but invitation.',
    'The opening move drew a new constellation of motion.',
    'Every dodge rewrote your understanding of survival.',
    'Victory arrived not as triumph, but as continued existence.',
    'Outside, the world kept turning, indifferent but available.',
    'You left the ring marked—less by wounds than by clarity.',
    'Protection, you realized, is just violence with better boundaries.',
    'From then on, every fight was a negotiation with fate.',
    'The arena stayed silent, but the sky learned your name.',
  ],
  ConstellationTree.extraction: [
    'The first heartbeat',
    'or waking breath,',
    'the moment marking',
    'flesh and life,',
    'a flicker in the night,',
    'the light grows,',
    'the light flickers,',
    'then fades,',
    'can you remember',
    'the glow?',
  ],
};

class ConstellationGame extends FlameGame with ScaleDetector {
  ConstellationTree selectedTree;
  final Set<String> unlockedSkills;
  final Function(ConstellationSkill) onSkillTapped;
  final Color primaryColor;
  final Color secondaryColor;

  final Map<String, SkillNode> _nodes = {};
  final Map<String, ConnectionLine> _connections = {};

  final Map<ConstellationTree, Vector2> _treePositions = {
    ConstellationTree.breeder: Vector2(0, -600),
    ConstellationTree.combat: Vector2(-700, 400),
    ConstellationTree.extraction: Vector2(700, 400),
  };

  double _baseScaleForGesture = 1.0;
  static const double _minScale = 0.2;
  static const double _maxScale = 2.0;

  bool _isTransitioning = false;
  Vector2? _lastFocalPoint;

  bool _finaleTriggered = false;
  bool _isPlayingFinale = false;
  SpriteComponent? _constellationImage;
  StarfieldBackground? _starfield;

  // Screen shake state (smooth, frame-based)
  double _shakeTime = 0.0;
  double _shakeDuration = 0.0;
  double _shakeIntensity = 0.0;
  Vector2? _shakeOriginalPosition;

  ConstellationGame({
    required this.selectedTree,
    required this.unlockedSkills,
    required this.onSkillTapped,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.center;

    final starfield = StarfieldBackground(
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
    );
    _starfield = starfield;
    await world.add(starfield);

    await _buildAllSkillTrees();
    camera.viewfinder.position = _treePositions[selectedTree]!;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Smooth screen shake in update loop
    if (_shakeDuration > 0 && _shakeOriginalPosition != null) {
      _shakeTime += dt;

      if (_shakeTime >= _shakeDuration) {
        camera.viewfinder.position = _shakeOriginalPosition!;
        _shakeDuration = 0.0;
        _shakeOriginalPosition = null;
      } else {
        // Perlin-like smooth noise using multiple sine waves
        final progress = _shakeTime / _shakeDuration;
        final decay = 1.0 - Curves.easeOut.transform(progress);
        final intensity = _shakeIntensity * decay;

        // Multiple frequencies for organic feel
        final offsetX =
            intensity *
            (math.sin(_shakeTime * 45) * 0.5 +
                math.sin(_shakeTime * 23 + 1.3) * 0.3 +
                math.sin(_shakeTime * 67 + 2.7) * 0.2);
        final offsetY =
            intensity *
            (math.sin(_shakeTime * 37 + 0.7) * 0.5 +
                math.sin(_shakeTime * 53 + 1.9) * 0.3 +
                math.sin(_shakeTime * 71 + 3.1) * 0.2);

        camera.viewfinder.position =
            _shakeOriginalPosition! + Vector2(offsetX, offsetY);
      }
    }
  }

  Future<void> _buildAllSkillTrees() async {
    for (final tree in ConstellationTree.values) {
      await _buildSkillTree(tree);
    }
  }

  Future<void> _buildSkillTree(ConstellationTree tree) async {
    final skills = ConstellationCatalog.forTree(tree);
    final treeOffset = _treePositions[tree]!;

    if (tree == ConstellationTree.combat) {
      await _buildCombatAlchemyTree(skills, treeOffset);
      return;
    }

    final tierMap = ConstellationCatalog.byTierForTree(tree);
    final maxTier = tierMap.keys.reduce(math.max);
    final verticalSpacing = 180.0;
    final baseY = (maxTier * verticalSpacing) / 2;

    final tempNodes = <String, SkillNode>{};
    for (final tier in tierMap.keys) {
      final skillsInTier = tierMap[tier]!;
      final horizontalSpacing = skillsInTier.length > 1 ? 220.0 : 0.0;
      final totalWidth = (skillsInTier.length - 1) * horizontalSpacing;
      final startX = -totalWidth / 2;

      for (int i = 0; i < skillsInTier.length; i++) {
        final skill = skillsInTier[i];
        final x = startX + (i * horizontalSpacing);
        final y = baseY - (tier * verticalSpacing);

        final isUnlocked = unlockedSkills.contains(skill.id);
        final canUnlock = skill.canUnlock(unlockedSkills) && !isUnlocked;

        final node = SkillNode(
          skill: skill,
          position: treeOffset + Vector2(x, y),
          isUnlocked: isUnlocked,
          canUnlock: canUnlock,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          onTap: () => onSkillTapped(skill),
          isRootNode: tier == 1,
        );

        tempNodes[skill.id] = node;
      }
    }

    int connectionIndex = 0;
    for (final skill in skills) {
      for (final prereqId in skill.prerequisites) {
        final fromNode = tempNodes[prereqId];
        final toNode = tempNodes[skill.id];

        if (fromNode != null && toNode != null) {
          final isUnlocked = unlockedSkills.contains(skill.id);
          final canUnlock = skill.canUnlock(unlockedSkills) && !isUnlocked;

          final connectionKey = '${prereqId}_${skill.id}';
          final connection = ConnectionLine(
            from: fromNode,
            to: toNode,
            isActive: isUnlocked,
            canActivate: canUnlock,
            primaryColor: primaryColor,
            connectionIndex: connectionIndex,
            storyText: _storyFragmentForConnection(tree, connectionIndex),
          );

          connectionIndex++;
          _connections[connectionKey] = connection;
          await world.add(connection);
        }
      }
    }

    for (final entry in tempNodes.entries) {
      _nodes[entry.key] = entry.value;
      await world.add(entry.value);
    }
  }

  String? _storyFragmentForConnection(
    ConstellationTree tree,
    int connectionIndex,
  ) {
    final fragments = kTreeStoryFragments[tree];
    if (fragments == null || fragments.isEmpty) return null;
    if (connectionIndex >= fragments.length) return null;
    return fragments[connectionIndex];
  }

  Future<void> _buildCombatAlchemyTree(
    List<ConstellationSkill> skills,
    Vector2 treeOffset,
  ) async {
    final tempNodes = <String, SkillNode>{};
    const double ringSpacing = 150.0;

    double angleForSkill(ConstellationSkill skill) {
      final id = skill.id;
      if (id.startsWith('combat_atk_')) return -math.pi / 2;
      if (id.startsWith('combat_int_')) return 0.0;
      if (id.startsWith('combat_beauty_')) return math.pi / 2;
      if (id.startsWith('combat_speed_')) return math.pi;
      return -math.pi / 2;
    }

    for (final skill in skills) {
      final angle = angleForSkill(skill);
      final radius = skill.tier * ringSpacing;
      final localPos = Vector2(
        math.cos(angle) * radius,
        math.sin(angle) * radius,
      );
      final worldPos = treeOffset + localPos;

      final isUnlocked = unlockedSkills.contains(skill.id);
      final canUnlock = skill.canUnlock(unlockedSkills) && !isUnlocked;

      final node = SkillNode(
        skill: skill,
        position: worldPos,
        isUnlocked: isUnlocked,
        canUnlock: canUnlock,
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
        onTap: () => onSkillTapped(skill),
        isRootNode: skill.tier == 1,
      );

      tempNodes[skill.id] = node;
    }

    int connectionIndex = 0;
    for (final skill in skills) {
      for (final prereqId in skill.prerequisites) {
        final fromNode = tempNodes[prereqId];
        final toNode = tempNodes[skill.id];

        if (fromNode != null && toNode != null) {
          final isUnlocked = unlockedSkills.contains(skill.id);
          final canUnlock = skill.canUnlock(unlockedSkills) && !isUnlocked;

          final connectionKey = '${prereqId}_${skill.id}';
          final connection = ConnectionLine(
            from: fromNode,
            to: toNode,
            isActive: isUnlocked,
            canActivate: canUnlock,
            primaryColor: primaryColor,
            connectionIndex: connectionIndex,
            storyText: _storyFragmentForConnection(
              ConstellationTree.combat,
              connectionIndex,
            ),
          );

          connectionIndex++;
          _connections[connectionKey] = connection;
          await world.add(connection);
        }
      }
    }

    for (final entry in tempNodes.entries) {
      _nodes[entry.key] = entry.value;
      await world.add(entry.value);
    }
  }

  Future<void> transitionToTree(ConstellationTree tree) async {
    if (_isTransitioning || tree == selectedTree) return;

    _isTransitioning = true;
    selectedTree = tree;

    final targetPosition = _treePositions[tree]!;

    camera.viewfinder.add(
      MoveEffect.to(
        targetPosition,
        EffectController(duration: 0.8, curve: Curves.easeInOutCubic),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 800));
    _isTransitioning = false;
  }

  @override
  void onScaleStart(ScaleStartInfo info) {
    if (_isTransitioning || _isPlayingFinale) return;
    _baseScaleForGesture = camera.viewfinder.zoom;
    _lastFocalPoint = info.eventPosition.global;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    if (_isTransitioning || _isPlayingFinale) return;

    final currentFocalPoint = info.eventPosition.global;

    if (_lastFocalPoint != null) {
      final delta = currentFocalPoint - _lastFocalPoint!;
      final newPosition =
          camera.viewfinder.position - (delta / camera.viewfinder.zoom);
      camera.viewfinder.position = Vector2(
        newPosition.x.clamp(-1200.0, 1200.0),
        newPosition.y.clamp(-1000.0, 800.0),
      );
    }
    _lastFocalPoint = currentFocalPoint.clone();

    final rawScale = info.raw.scale;
    final newScale = (_baseScaleForGesture * rawScale).clamp(
      _minScale,
      _maxScale,
    );
    camera.viewfinder.zoom = newScale;
  }

  @override
  void onScaleEnd(ScaleEndInfo info) {
    _lastFocalPoint = null;
  }

  void updateUnlockedSkills(Set<String> newUnlockedSkills) {
    final newlyUnlocked = newUnlockedSkills.difference(unlockedSkills);

    for (final entry in _nodes.entries) {
      final node = entry.value;
      final skill = node.skill;

      final isUnlocked = newUnlockedSkills.contains(skill.id);
      final canUnlock = skill.canUnlock(newUnlockedSkills) && !isUnlocked;

      node.updateState(isUnlocked: isUnlocked, canUnlock: canUnlock);
    }

    for (final skillId in newlyUnlocked) {
      final skill = ConstellationCatalog.byId(skillId);
      if (skill != null) {
        for (final prereqId in skill.prerequisites) {
          final connectionKey = '${prereqId}_$skillId';
          final connection = _connections[connectionKey];
          if (connection != null) {
            connection.animateActivation();
          }
        }
      }
    }
  }

  Future<void> triggerFinale() async {
    if (_finaleTriggered || _isPlayingFinale) return;

    _finaleTriggered = true;
    _isPlayingFinale = true;

    // Smooth screen shake (handled in update loop)
    _startScreenShake(intensity: 12.0, duration: 1.5);
    await Future.delayed(const Duration(milliseconds: 1500));

    _starfield?.startRapidBlink();
    await Future.delayed(const Duration(milliseconds: 1000));

    await _zoomOut();
    await Future.delayed(const Duration(milliseconds: 1000));

    await _fadeInConstellation();
    _starfield?.restoreNormalTwinkling();

    _isPlayingFinale = false;
  }

  void _startScreenShake({
    required double intensity,
    required double duration,
  }) {
    _shakeTime = 0.0;
    _shakeDuration = duration;
    _shakeIntensity = intensity;
    _shakeOriginalPosition = camera.viewfinder.position.clone();
  }

  Future<void> showFinaleEndState() async {
    if (_constellationImage != null) return;

    _finaleTriggered = true;

    final centerX =
        (_treePositions[ConstellationTree.breeder]!.x +
            _treePositions[ConstellationTree.combat]!.x +
            _treePositions[ConstellationTree.extraction]!.x) /
        3;
    final centerY =
        (_treePositions[ConstellationTree.breeder]!.y +
            _treePositions[ConstellationTree.combat]!.y +
            _treePositions[ConstellationTree.extraction]!.y) /
        3;
    final centerPosition = Vector2(centerX, centerY);

    camera.viewfinder.position = centerPosition;
    camera.viewfinder.zoom = 0.4;

    final sprite = await Sprite.load('ui/constellationbackgroundimg.png');
    final originalWidth = sprite.originalSize.x;
    final originalHeight = sprite.originalSize.y;
    final targetSize = 1500.0;

    final Vector2 imageSize;
    if (originalWidth > originalHeight) {
      imageSize = Vector2(
        targetSize,
        targetSize * (originalHeight / originalWidth),
      );
    } else {
      imageSize = Vector2(
        targetSize * (originalWidth / originalHeight),
        targetSize,
      );
    }

    _constellationImage = SpriteComponent(
      sprite: sprite,
      size: imageSize,
      anchor: Anchor.center,
      position: Vector2(0, 0),
      priority: -5,
    );
    _constellationImage!.opacity = 0.1;

    await world.add(_constellationImage!);
    _starfield?.restoreNormalTwinkling();
  }

  Future<void> _zoomOut() async {
    final centerX =
        (_treePositions[ConstellationTree.breeder]!.x +
            _treePositions[ConstellationTree.combat]!.x +
            _treePositions[ConstellationTree.extraction]!.x) /
        3;
    final centerY =
        (_treePositions[ConstellationTree.breeder]!.y +
            _treePositions[ConstellationTree.combat]!.y +
            _treePositions[ConstellationTree.extraction]!.y) /
        3;
    final centerPosition = Vector2(centerX, centerY);

    camera.viewfinder.add(
      ScaleEffect.to(
        Vector2.all(0.4),
        EffectController(duration: 2.0, curve: Curves.easeInOutCubic),
      ),
    );

    camera.viewfinder.add(
      MoveEffect.to(
        centerPosition,
        EffectController(duration: 2.0, curve: Curves.easeInOutCubic),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 2000));
  }

  Future<void> _fadeInConstellation() async {
    final sprite = await Sprite.load('ui/constellationbackgroundimg.png');
    final originalWidth = sprite.originalSize.x;
    final originalHeight = sprite.originalSize.y;
    final targetSize = 1500.0;

    final Vector2 imageSize;
    if (originalWidth > originalHeight) {
      imageSize = Vector2(
        targetSize,
        targetSize * (originalHeight / originalWidth),
      );
    } else {
      imageSize = Vector2(
        targetSize * (originalWidth / originalHeight),
        targetSize,
      );
    }

    _constellationImage = SpriteComponent(
      sprite: sprite,
      size: imageSize,
      anchor: Anchor.center,
      position: Vector2(0, 0),
      priority: -5,
    );
    _constellationImage!.opacity = 0.0;

    await world.add(_constellationImage!);

    _constellationImage!.add(
      OpacityEffect.to(
        0.1,
        EffectController(duration: 3.0, curve: Curves.easeOutCubic),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 3000));
  }
}

/// Individual skill node with improved particle system
class SkillNode extends PositionComponent with TapCallbacks {
  final ConstellationSkill skill;
  final Color primaryColor;
  final Color secondaryColor;
  final VoidCallback onTap;
  final bool isRootNode;

  bool isUnlocked;
  bool canUnlock;

  late CircleComponent _outerRing;
  late CircleComponent _innerCore;
  late TextComponent _costText;

  // Improved particle system - persistent particles with pooling
  final List<_NodeParticle> _particles = [];
  static const int _maxParticles = 12;

  // Pulse animation state
  double _pulseTime = 0.0;

  SkillNode({
    required this.skill,
    required Vector2 position,
    required this.isUnlocked,
    required this.canUnlock,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onTap,
    this.isRootNode = false,
  }) : super(
         position: position,
         size: Vector2.all(80),
         anchor: Anchor.center,
         priority: 0,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _outerRing = CircleComponent(
      radius: 35,
      position: size / 2,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.transparent,
    );
    await add(_outerRing);

    _innerCore = CircleComponent(
      radius: 28,
      position: size / 2,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.transparent,
    );
    await add(_innerCore);

    _costText = TextComponent(
      text: isUnlocked ? '' : '${skill.pointsCost}',
      textRenderer: TextPaint(
        style: TextStyle(
          color: primaryColor,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      anchor: Anchor.center,
      position: size / 2,
    );
    await add(_costText);

    // Initialize particle pool
    if (isUnlocked) {
      _initializeParticles();
    }
  }

  void _initializeParticles() {
    final random = math.Random();
    for (int i = 0; i < _maxParticles; i++) {
      _particles.add(
        _NodeParticle(
          angle: (i / _maxParticles) * math.pi * 2,
          distance: 35.0 + random.nextDouble() * 15.0,
          speed: 0.3 + random.nextDouble() * 0.4,
          size: 2.0 + random.nextDouble() * 2.0,
          phase: random.nextDouble() * math.pi * 2,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Update pulse animation
    if (canUnlock) {
      _pulseTime += dt;
    }

    // Update particles
    if (isUnlocked) {
      for (final particle in _particles) {
        particle.update(dt);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final center = size / 2;
    final ringColor = _getRingColor();
    final coreColor = _getCoreColor();

    final hexPath = _createHexagon(center.toOffset(), 35);

    // Animated glow for available nodes
    if (canUnlock) {
      final pulseValue = (math.sin(_pulseTime * 2.5) + 1) / 2; // 0 to 1
      final glowOpacity = (0.1 + pulseValue * 0.25).clamp(0.0, 1.0);
      final glowSize = 3.0 + pulseValue * 4.0;

      final glowPaint = Paint()
        ..color = primaryColor.withValues(alpha: glowOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = glowSize
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          6.0 + pulseValue * 4.0,
        );
      canvas.drawPath(hexPath, glowPaint);
    }

    // Outer glow for unlocked nodes
    if (isUnlocked) {
      final glowPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
      canvas.drawPath(hexPath, glowPaint);
    }

    // Main hexagon border
    final borderWidth = isRootNode ? 4.0 : 2.0;
    final borderPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.x, center.y - 35),
        Offset(center.x, center.y + 35),
        [ringColor, ringColor.withValues(alpha: 0.6)],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawPath(hexPath, borderPaint);

    // Inner hexagonal core
    final coreHexPath = _createHexagon(center.toOffset(), 28);
    final corePaint = Paint()
      ..shader = ui.Gradient.radial(
        center.toOffset(),
        28,
        [
          coreColor.withValues(alpha: 0.6),
          coreColor.withValues(alpha: 0.2),
          coreColor.withValues(alpha: 0.35),
        ],
        [0.0, 0.5, 1.0],
      )
      ..style = PaintingStyle.fill;

    if (isUnlocked) {
      canvas.drawPath(coreHexPath, corePaint);
    }

    // Alchemical accents for unlocked nodes
    if (isUnlocked) {
      _drawAlchemicalAccents(canvas, center.toOffset(), 35);
      _renderParticles(canvas, center);
    }
  }

  void _renderParticles(Canvas canvas, Vector2 center) {
    for (final particle in _particles) {
      final pos = particle.getPosition(center);
      final opacity = particle.getOpacity().clamp(0.0, 1.0);

      // Diamond shape
      final size = particle.size;
      final paint = Paint()
        ..color = primaryColor.withValues(
          alpha: (opacity * 0.8).clamp(0.0, 1.0),
        )
        ..style = PaintingStyle.fill;

      final path = Path()
        ..moveTo(pos.x, pos.y - size)
        ..lineTo(pos.x + size * 0.6, pos.y)
        ..lineTo(pos.x, pos.y + size)
        ..lineTo(pos.x - size * 0.6, pos.y)
        ..close();

      canvas.drawPath(path, paint);

      // Inner glow
      final glowPaint = Paint()
        ..color = secondaryColor.withValues(
          alpha: (opacity * 0.4).clamp(0.0, 1.0),
        )
        ..style = PaintingStyle.fill;
      final glowPath = Path()
        ..moveTo(pos.x, pos.y - size * 0.5)
        ..lineTo(pos.x + size * 0.3, pos.y)
        ..lineTo(pos.x, pos.y + size * 0.5)
        ..lineTo(pos.x - size * 0.3, pos.y)
        ..close();
      canvas.drawPath(glowPath, glowPaint);
    }
  }

  Path _createHexagon(Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 6;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  void _drawAlchemicalAccents(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = secondaryColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 6;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      final accentSize = 3.0;
      final accentPath = Path()
        ..moveTo(x, y - accentSize)
        ..lineTo(x + accentSize * 0.6, y)
        ..lineTo(x, y + accentSize)
        ..lineTo(x - accentSize * 0.6, y)
        ..close();

      canvas.drawPath(accentPath, paint);
    }
  }

  Color _getRingColor() {
    if (isUnlocked) return primaryColor;
    if (canUnlock) return primaryColor.withValues(alpha: 0.8);
    return primaryColor.withValues(alpha: 0.3);
  }

  Color _getCoreColor() {
    if (isUnlocked) return primaryColor.withValues(alpha: 0.4);
    if (canUnlock) return primaryColor.withValues(alpha: 0.15);
    return Colors.black.withValues(alpha: 0.6);
  }

  void updateState({required bool isUnlocked, required bool canUnlock}) {
    final wasLocked = !this.isUnlocked;
    this.isUnlocked = isUnlocked;
    this.canUnlock = canUnlock;

    _costText.text = isUnlocked ? '' : '${skill.pointsCost}';
    _costText.textRenderer = TextPaint(
      style: TextStyle(
        color: primaryColor,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );

    // Add particles if newly unlocked
    if (isUnlocked && wasLocked && _particles.isEmpty) {
      _initializeParticles();
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    onTap();
  }
}

/// Lightweight particle for skill nodes
class _NodeParticle {
  double angle;
  double distance;
  double speed;
  double size;
  double phase;
  double _time = 0.0;

  _NodeParticle({
    required this.angle,
    required this.distance,
    required this.speed,
    required this.size,
    required this.phase,
  });

  void update(double dt) {
    _time += dt * speed;
    angle += dt * 0.3; // Slow rotation
  }

  Vector2 getPosition(Vector2 center) {
    // Gentle floating motion
    final floatOffset = math.sin(_time * 2 + phase) * 8.0;
    final currentDistance = distance + floatOffset;

    return Vector2(
      center.x + math.cos(angle) * currentDistance,
      center.y +
          math.sin(angle) * currentDistance -
          math.sin(_time * 1.5 + phase) * 5.0,
    );
  }

  double getOpacity() {
    // Gentle pulsing - clamp to valid range
    return (0.4 + math.sin(_time * 2 + phase) * 0.3).clamp(0.0, 1.0);
  }
}

/// Connection line with smoother animations
class ConnectionLine extends Component {
  final SkillNode from;
  final SkillNode to;
  bool isActive;
  bool canActivate;
  final Color primaryColor;
  final int connectionIndex;
  final String? storyText;

  double _animationProgress = 1.0;
  double _glowIntensity = 0.0;
  bool _isAnimating = false;
  double _animationTime = 0.0;
  double _storyOpacity = 0.0;

  // Smoother timing
  static const double _drawDuration = 1.05;
  static const double _glowFadeTime = 0.95;
  static const double _storyFadeInTime = 0.8;

  // Traveling energy pulse
  double _energyPulsePosition = 0.0;
  bool _showEnergyPulse = false;
  double _storyFloatOffset = 10.0;

  late final String _wrappedStoryText;
  late final List<String> _wrappedStoryLines;
  TextPaint? _storyTextPaint;
  double _storyPaintAlpha = -1.0;

  final Paint _linePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _glowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
  final Paint _pulsePaint = Paint()..style = PaintingStyle.fill;
  final Paint _pulseGlowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
  final Paint _storyBackdropPaint = Paint()..style = PaintingStyle.fill;
  final Paint _storyBorderPaint = Paint()..style = PaintingStyle.stroke;

  ConnectionLine({
    required this.from,
    required this.to,
    required this.isActive,
    required this.canActivate,
    required this.primaryColor,
    required this.connectionIndex,
    this.storyText,
  }) : super(priority: -1) {
    _wrappedStoryText = _wrapStoryText(storyText);
    _wrappedStoryLines = _wrappedStoryText.isEmpty
        ? const <String>[]
        : _wrappedStoryText.split('\n');
  }

  static String _wrapStoryText(String? text, {int maxCharsPerLine = 26}) {
    if (text == null) return '';
    final clean = text.trim();
    if (clean.isEmpty) return '';

    final wrappedLines = <String>[];
    for (final paragraph in clean.split('\n')) {
      final p = paragraph.trim();
      if (p.isEmpty) continue;

      final words = p.split(RegExp(r'\s+'));
      var currentLine = '';

      for (final word in words) {
        if (currentLine.isEmpty) {
          currentLine = word;
          continue;
        }
        final candidate = '$currentLine $word';
        if (candidate.length <= maxCharsPerLine) {
          currentLine = candidate;
        } else {
          wrappedLines.add(currentLine);
          currentLine = word;
        }
      }

      if (currentLine.isNotEmpty) {
        wrappedLines.add(currentLine);
      }
    }

    return wrappedLines.join('\n');
  }

  void animateActivation() {
    if (_isAnimating || isActive) return;

    _isAnimating = true;
    isActive = true;
    _animationProgress = 0.0;
    _glowIntensity = 0.0;
    _animationTime = 0.0;
    _storyOpacity = 0.0;
    _energyPulsePosition = 0.0;
    _showEnergyPulse = true;
    _storyFloatOffset = 10.0;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!_isAnimating) return;

    final frameDt = math.min(dt, 1 / 30);
    _animationTime += frameDt;

    // Line drawing with a smoother acceleration/deceleration curve.
    if (_animationTime < _drawDuration) {
      final t = (_animationTime / _drawDuration).clamp(0.0, 1.0);
      _animationProgress = Curves.easeInOutCubic.transform(t);
      _energyPulsePosition = Curves.easeOutCubic.transform(t);
    } else {
      _animationProgress = 1.0;
      _showEnergyPulse = false;
    }

    // Glow animation - smooth rise and fall
    final glowStartTime = _drawDuration * 0.3;
    final glowEndTime = _drawDuration + _glowFadeTime;

    if (_animationTime > glowStartTime && _animationTime < glowEndTime) {
      final glowT =
          ((_animationTime - glowStartTime) / (glowEndTime - glowStartTime))
              .clamp(0.0, 1.0);
      final bell = math.sin(glowT * math.pi).clamp(0.0, 1.0);
      _glowIntensity = math.pow(bell, 1.2).toDouble() * 0.85;
    } else {
      _glowIntensity = (_glowIntensity - frameDt * 2).clamp(0.0, 1.0);
    }

    // Story text fades in while drifting into place.
    final storyStartTime = _drawDuration * 0.72;
    if (_animationTime > storyStartTime) {
      final storyT = ((_animationTime - storyStartTime) / _storyFadeInTime)
          .clamp(0.0, 1.0);
      _storyOpacity = Curves.easeOutCubic.transform(storyT);
      _storyFloatOffset = (1.0 - storyT) * 10.0;
    }

    // End animation
    if (_animationTime >
        _drawDuration + _glowFadeTime + _storyFadeInTime + 0.7) {
      _isAnimating = false;
      _storyOpacity = 1.0;
      _storyFloatOffset = 0.0;
    }
  }

  @override
  void render(Canvas canvas) {
    final fromPos = from.position;
    final toPos = to.position;

    if (!isActive && !canActivate) return;

    final currentEnd = _isAnimating
        ? fromPos + (toPos - fromPos) * _animationProgress
        : toPos;

    final baseOpacity = isActive ? 0.8 : 0.25;
    final glowBoost = (_glowIntensity * 0.3).clamp(0.0, 0.5);

    // Main line
    _linePaint
      ..color = Colors.white.withValues(
        alpha: (baseOpacity + glowBoost).clamp(0.0, 1.0),
      )
      ..strokeWidth = 2.0 + (_glowIntensity * 2.0)
      ..maskFilter = null;

    canvas.drawLine(fromPos.toOffset(), currentEnd.toOffset(), _linePaint);

    // Outer glow
    if (isActive) {
      _glowPaint
        ..color = Colors.white.withValues(
          alpha: ((0.2 + glowBoost) * 0.6).clamp(0.0, 1.0),
        )
        ..strokeWidth = 6.0 + (_glowIntensity * 6.0);

      canvas.drawLine(fromPos.toOffset(), currentEnd.toOffset(), _glowPaint);
    }

    // Energy pulse traveling along the line
    if (_showEnergyPulse && _animationProgress > 0.05) {
      final pulsePos = fromPos + (toPos - fromPos) * _energyPulsePosition;
      _pulsePaint.color = primaryColor.withValues(alpha: 0.9);

      canvas.drawCircle(
        pulsePos.toOffset(),
        4.0 + _glowIntensity * 3.0,
        _pulsePaint,
      );

      // Pulse glow
      _pulseGlowPaint.color = primaryColor.withValues(alpha: 0.4);
      canvas.drawCircle(pulsePos.toOffset(), 8.0, _pulseGlowPaint);
    }

    // Story text
    if (_storyOpacity > 0 && storyText != null) {
      _drawStoryText(canvas, fromPos, toPos);
    }
  }

  void _drawStoryText(Canvas canvas, Vector2 from, Vector2 to) {
    if (_wrappedStoryText.isEmpty) return;

    final midPoint = (from + to) / 2;
    final path = to - from;
    final lineLength = path.length;
    if (lineLength <= 0.001) return;

    final direction = path / lineLength;
    final perpendicular = Vector2(-direction.y, direction.x);

    final longestLineChars = _wrappedStoryLines.fold<int>(
      0,
      (max, line) => math.max(max, line.length),
    );
    final textWidth = (longestLineChars * 7.0 + 30.0).clamp(110.0, 320.0);
    final textHeight = (_wrappedStoryLines.length * 16.0 + 16.0).clamp(
      34.0,
      140.0,
    );

    final baseDistance = (lineLength * 0.42).clamp(130.0, 230.0);
    final safeDistance = baseDistance + (textHeight * 0.35);

    final rightCandidate = midPoint + perpendicular * safeDistance;
    final leftCandidate = midPoint - perpendicular * safeDistance;
    final rightDist2 =
        rightCandidate.x * rightCandidate.x +
        rightCandidate.y * rightCandidate.y;
    final leftDist2 =
        leftCandidate.x * leftCandidate.x + leftCandidate.y * leftCandidate.y;

    double sideSign = rightDist2 >= leftDist2 ? 1.0 : -1.0;
    if ((rightDist2 - leftDist2).abs() < 8000) {
      sideSign = connectionIndex.isEven ? 1.0 : -1.0;
    }

    final lane = (connectionIndex % 3) - 1;
    final alongOffset = direction * (lane * 22.0);
    final storyPos =
        midPoint +
        perpendicular * (safeDistance * sideSign) +
        alongOffset +
        Vector2(0, -_storyFloatOffset);

    final alpha = (_storyOpacity * 0.85).clamp(0.0, 1.0);
    if (_storyTextPaint == null || (alpha - _storyPaintAlpha).abs() > 0.02) {
      _storyPaintAlpha = alpha;
      _storyTextPaint = TextPaint(
        style: GoogleFonts.imFellGreatPrimer(
          color: Colors.white.withValues(alpha: alpha),
          fontSize: 12,
          height: 1.15,
        ),
      );
    }

    final rect = Rect.fromCenter(
      center: storyPos.toOffset(),
      width: textWidth,
      height: textHeight,
    );
    final bubble = RRect.fromRectAndRadius(rect, const Radius.circular(10));

    _storyBackdropPaint.color = Colors.black.withValues(
      alpha: (_storyOpacity * 0.62).clamp(0.0, 1.0),
    );
    canvas.drawRRect(bubble, _storyBackdropPaint);

    _storyBorderPaint
      ..color = primaryColor.withValues(
        alpha: (_storyOpacity * 0.3).clamp(0.0, 1.0),
      )
      ..strokeWidth = 1.0;
    canvas.drawRRect(bubble, _storyBorderPaint);

    _storyTextPaint!.render(
      canvas,
      _wrappedStoryText,
      storyPos,
      anchor: Anchor.center,
    );
  }
}

/// Starfield with improved twinkling
class StarfieldBackground extends Component
    with HasGameReference<ConstellationGame> {
  final Color primaryColor;
  final Color secondaryColor;
  final List<Star> stars = [];
  double _time = 0.0;

  static const int _farLayerCount = 2600;
  static const int _midLayerCount = 1900;
  static const int _nearLayerCount = 400;

  StarfieldBackground({
    required this.primaryColor,
    required this.secondaryColor,
  }) : super(priority: -10);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final random = math.Random();

    // Layered stars for depth
    // Far layer - small, dim, slow
    for (int i = 0; i < _farLayerCount; i++) {
      stars.add(
        Star(
          position: Vector2(
            random.nextDouble() * 6000 - 3000,
            random.nextDouble() * 6000 - 3000,
          ),
          size: 0.5 + random.nextDouble() * 1.0,
          baseOpacity: 0.15 + random.nextDouble() * 0.2,
          twinkleSpeed: 0.3 + random.nextDouble() * 0.5,
          twinklePhase: random.nextDouble() * math.pi * 2,
        ),
      );
    }

    // Mid layer - medium
    for (int i = 0; i < _midLayerCount; i++) {
      stars.add(
        Star(
          position: Vector2(
            random.nextDouble() * 6000 - 3000,
            random.nextDouble() * 6000 - 3000,
          ),
          size: 1.0 + random.nextDouble() * 1.5,
          baseOpacity: 0.3 + random.nextDouble() * 0.3,
          twinkleSpeed: 0.5 + random.nextDouble() * 1.0,
          twinklePhase: random.nextDouble() * math.pi * 2,
        ),
      );
    }

    // Near layer - bright, fast twinkle
    for (int i = 0; i < _nearLayerCount; i++) {
      stars.add(
        Star(
          position: Vector2(
            random.nextDouble() * 6000 - 3000,
            random.nextDouble() * 6000 - 3000,
          ),
          size: 2.0 + random.nextDouble() * 1.5,
          baseOpacity: 0.5 + random.nextDouble() * 0.4,
          twinkleSpeed: 1.0 + random.nextDouble() * 2.0,
          twinklePhase: random.nextDouble() * math.pi * 2,
        ),
      );
    }
  }

  void startRapidBlink() {
    for (final star in stars) {
      star.startRapidBlink();
    }
  }

  void restoreNormalTwinkling() {
    for (final star in stars) {
      star.restoreNormalTwinkle();
    }
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint();
    final zoom = game.camera.viewfinder.zoom;
    final viewCenter = game.camera.viewfinder.position;

    // Render only stars near the visible region (+margin) for better frame-time.
    final worldWidth = game.size.x / zoom;
    final worldHeight = game.size.y / zoom;
    final marginX = worldWidth * 0.4;
    final marginY = worldHeight * 0.4;
    final minX = viewCenter.x - worldWidth / 2 - marginX;
    final maxX = viewCenter.x + worldWidth / 2 + marginX;
    final minY = viewCenter.y - worldHeight / 2 - marginY;
    final maxY = viewCenter.y + worldHeight / 2 + marginY;

    for (final star in stars) {
      final p = star.position;
      if (p.x < minX || p.x > maxX || p.y < minY || p.y > maxY) continue;

      paint.color = primaryColor.withValues(
        alpha: star.currentOpacityAt(_time),
      );
      canvas.drawCircle(star.position.toOffset(), star.size, paint);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }
}

class Star {
  final Vector2 position;
  final double size;
  final double baseOpacity;
  final double twinkleSpeed;
  final double twinklePhase;
  bool _rapidBlink = false;

  Star({
    required this.position,
    required this.size,
    required this.baseOpacity,
    required this.twinkleSpeed,
    required this.twinklePhase,
  });

  double currentOpacityAt(double time) {
    if (_rapidBlink) {
      // More organic rapid blink with multiple frequencies
      final blink =
          (math.sin(time * 15 + twinklePhase) +
              math.sin(time * 23 + twinklePhase * 1.3) * 0.5) /
          1.5;
      return (baseOpacity * (0.2 + 0.8 * ((blink + 1) / 2))).clamp(0.0, 1.0);
    }

    // Smooth twinkling with slight variation
    final twinkle = math.sin(time * twinkleSpeed + twinklePhase);
    final variation =
        math.sin(time * twinkleSpeed * 0.7 + twinklePhase + 1.0) * 0.3;
    final combined = ((twinkle + variation).clamp(-1.0, 1.0) + 1) / 2;
    return (baseOpacity * (0.6 + 0.4 * combined)).clamp(0.0, 1.0);
  }

  void startRapidBlink() {
    _rapidBlink = true;
  }

  void restoreNormalTwinkle() {
    _rapidBlink = false;
  }
}
