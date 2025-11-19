// lib/games/constellations/constellation_game.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Map<ConstellationTree, List<String>> kTreeStoryFragments = {
  ConstellationTree.breeder: [
    // BREEDER STORY – "The First Hatchery"
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
    // COMBAT STORY – "The Silent Arena"
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
    // EXTRACTION STORY – "Miners of Starlight"
    'They told you the veins were empty centuries ago.',
    'Yet the rock still sang if you pressed your ear close.',
    'You followed the song into a shaft no map admitted.',
    'Dust glittered, undecided between mundane and sacred.',
    'Your tools were simple; your equations were not.',
    'Each strike released a gasp of bottled radiance.',
    'The light tried to flee; you offered it purpose instead.',
    'Careful conduits turned chaos into circulation.',
    'On your schematics, the mine looked like a nervous system.',
    'In truth, it was a conversation with buried history.',
    'You left the deepest caverns brighter than you found them.',
    'Starlight, once lost, now flowed where it was needed most.',
    'The surface felt different, as if standing on a healed bruise.',
    'You logged the yield; the world logged the mercy.',
    'Extraction became less about taking, more about translation.',
    'The planet did not thank you, but it stopped protesting.',
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

  // Tree positions in a triangle formation
  final Map<ConstellationTree, Vector2> _treePositions = {
    ConstellationTree.breeder: Vector2(0, -600), // Top
    ConstellationTree.combat: Vector2(-700, 400), // Bottom left
    ConstellationTree.extraction: Vector2(700, 400), // Bottom right
  };

  double _currentScale = 1.0;
  double _baseScaleForGesture = 1.0; // Scale at start of gesture
  static const double _minScale = 0.2;
  static const double _maxScale = 2.0;

  bool _isTransitioning = false;

  // Track if this is a pan vs pinch gesture
  Vector2? _lastFocalPoint;

  // Finale sequence state
  bool _finaleTriggered = false;
  bool _isPlayingFinale = false;
  SpriteComponent? _constellationImage;
  StarfieldBackground? _starfield;

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

    // Use the built-in camera - just configure it
    camera.viewfinder.anchor = Anchor.center;

    // Add starfield background
    final starfield = StarfieldBackground(
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
    );
    _starfield = starfield;
    await world.add(starfield);

    // Build all three skill trees
    await _buildAllSkillTrees();

    // Center camera on the selected tree
    camera.viewfinder.position = _treePositions[selectedTree]!;
  }

  Future<void> _buildAllSkillTrees() async {
    // Build all three trees
    for (final tree in ConstellationTree.values) {
      await _buildSkillTree(tree);
    }
  }

  Future<void> _buildSkillTree(ConstellationTree tree) async {
    final skills = ConstellationCatalog.forTree(tree);
    final treeOffset = _treePositions[tree]!;

    // SPECIAL CASE: combat tree uses alchemy-circle layout
    if (tree == ConstellationTree.combat) {
      await _buildCombatAlchemyTree(skills, treeOffset);
      return;
    }

    // --- existing vertical/tier layout for other trees ---
    final tierMap = ConstellationCatalog.byTierForTree(tree);

    final maxTier = tierMap.keys.reduce(math.max);
    final verticalSpacing = 180.0;
    final baseY = (maxTier * verticalSpacing) / 2;

    // First pass: create all nodes
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
          isRootNode: tier == 1, // Mark tier 1 skills as root nodes
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

    // Third pass: add nodes (so they render on top)
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

    // If you want a strict one-time linear story, you can just:
    if (connectionIndex >= fragments.length) return null;
    return fragments[connectionIndex];
  }

  Future<void> _buildCombatAlchemyTree(
    List<ConstellationSkill> skills,
    Vector2 treeOffset,
  ) async {
    final tempNodes = <String, SkillNode>{};

    // How far each ring sits from the center
    const double ringSpacing = 150.0;

    double _angleForSkill(ConstellationSkill skill) {
      final id = skill.id;

      if (id.startsWith('combat_atk_')) {
        // Fire / Strength – top
        return -math.pi / 2; // -90°
      } else if (id.startsWith('combat_int_')) {
        // Air / Int – right
        return 0.0; // 0°
      } else if (id.startsWith('combat_beauty_')) {
        // Water / Beauty – bottom
        return math.pi / 2; // 90°
      } else if (id.startsWith('combat_speed_')) {
        // Earth / Speed – left
        return math.pi; // 180°
      }

      // Fallback: put unknowns near the center top-ish
      return -math.pi / 2;
    }

    // 1) Create nodes arranged in a circle / cross
    for (final skill in skills) {
      final angle = _angleForSkill(skill);
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
        isRootNode: skill.tier == 1, // Mark tier 1 skills as root nodes
      );

      tempNodes[skill.id] = node;
    }

    // 2) Create connections (same logic as default builder)
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

    // 3) Add nodes so they render on top of lines
    for (final entry in tempNodes.entries) {
      _nodes[entry.key] = entry.value;
      await world.add(entry.value);
    }
  }

  /// Smoothly transition camera to a different tree
  Future<void> transitionToTree(ConstellationTree tree) async {
    if (_isTransitioning || tree == selectedTree) return;

    _isTransitioning = true;
    selectedTree = tree;

    final targetPosition = _treePositions[tree]!;

    // Smooth camera pan
    camera.viewfinder.add(
      MoveEffect.to(
        targetPosition,
        EffectController(duration: 1.0, curve: Curves.easeInOut),
      ),
    );

    // Wait for transition to complete
    await Future.delayed(const Duration(milliseconds: 1000));
    _isTransitioning = false;
  }

  @override
  void onScaleStart(ScaleStartInfo info) {
    if (_isTransitioning || _isPlayingFinale) return;

    // Capture the current zoom at the start of this gesture
    _baseScaleForGesture = camera.viewfinder.zoom;
    _lastFocalPoint = info.eventPosition.global;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    if (_isTransitioning || _isPlayingFinale) return;

    final currentFocalPoint = info.eventPosition.global;

    // Handle panning (when scale is ~1.0, it's just a drag)
    if (_lastFocalPoint != null) {
      final delta = currentFocalPoint - _lastFocalPoint!;
      final newPosition =
          camera.viewfinder.position - (delta / camera.viewfinder.zoom);

      // Clamp camera position to reasonable bounds
      camera.viewfinder.position = Vector2(
        newPosition.x.clamp(-1200.0, 1200.0),
        newPosition.y.clamp(-1000.0, 800.0),
      );
    }

    _lastFocalPoint = currentFocalPoint;

    // Handle zooming (pinch gesture)
    // info.scale.global gives us the cumulative scale since gesture start
    if (info.scale.global.x != 1.0) {
      final newScale = (_baseScaleForGesture * info.scale.global.x).clamp(
        _minScale,
        _maxScale,
      );

      camera.viewfinder.zoom = newScale;
    }
  }

  @override
  void onScaleEnd(ScaleEndInfo info) {
    // Store the final scale for next time
    _currentScale = camera.viewfinder.zoom;
    _lastFocalPoint = null;
  }

  /// Refresh nodes when unlocks change
  void updateUnlockedSkills(Set<String> newUnlockedSkills) {
    final newlyUnlocked = newUnlockedSkills.difference(unlockedSkills);

    for (final entry in _nodes.entries) {
      final node = entry.value;
      final skill = node.skill;

      final isUnlocked = newUnlockedSkills.contains(skill.id);
      final canUnlock = skill.canUnlock(newUnlockedSkills) && !isUnlocked;

      node.updateState(isUnlocked: isUnlocked, canUnlock: canUnlock);
    }

    // Animate new connections for newly unlocked skills
    for (final skillId in newlyUnlocked) {
      final skill = ConstellationCatalog.byId(skillId);
      if (skill != null) {
        for (final prereqId in skill.prerequisites) {
          final connectionKey = '${prereqId}_${skillId}';
          final connection = _connections[connectionKey];
          if (connection != null) {
            connection.animateActivation();
          }
        }
      }
    }
  }

  /// Epic finale sequence when all constellations are unlocked
  Future<void> triggerFinale() async {
    if (_finaleTriggered || _isPlayingFinale) return;

    _finaleTriggered = true;
    _isPlayingFinale = true;

    // 1. Screen shake (0.5s)
    await _screenShake();

    // 2. Make stars blink rapidly (1s)
    _starfield?.startRapidBlink();
    await Future.delayed(const Duration(milliseconds: 1000));

    // 3. Zoom out to see all three trees (2s)
    await _zoomOut();

    await Future.delayed(const Duration(milliseconds: 1000));

    // 4. Fade in constellation image behind everything (2s)
    await _fadeInConstellation();

    // 5. Restore normal star twinkling on top
    _starfield?.restoreNormalTwinkling();

    _isPlayingFinale = false;
  }

  /// Jump directly to the finale end state (for when user has already seen it)
  Future<void> showFinaleEndState() async {
    if (_constellationImage != null) return; // Already showing

    _finaleTriggered = true;

    // Calculate the center point between all three trees
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

    // Set camera to zoomed out position immediately
    camera.viewfinder.position = centerPosition;
    camera.viewfinder.zoom = 0.4;
    _currentScale = 0.4;

    // Load and display the constellation image at full opacity
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

    // Set opacity after construction
    _constellationImage!.opacity = 0.1;

    await world.add(_constellationImage!);

    // Make sure stars are in normal twinkling mode
    _starfield?.restoreNormalTwinkling();
  }

  Future<void> _screenShake() async {
    final originalPosition = camera.viewfinder.position.clone();
    final random = math.Random();
    const shakeIntensity = 15.0;
    const shakeDuration = 2000; // milliseconds
    const shakeInterval = 50; // milliseconds
    final shakeCount = shakeDuration ~/ shakeInterval;

    for (int i = 0; i < shakeCount; i++) {
      final offsetX = (random.nextDouble() - 0.5) * shakeIntensity;
      final offsetY = (random.nextDouble() - 0.5) * shakeIntensity;
      camera.viewfinder.position = originalPosition + Vector2(offsetX, offsetY);
      await Future.delayed(Duration(milliseconds: shakeInterval));
    }

    // Return to original position
    camera.viewfinder.position = originalPosition;
  }

  Future<void> _zoomOut() async {
    // Calculate the center point between all three trees
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

    // Zoom out to 0.4 to see all three trees
    final zoomController = EffectController(
      duration: 2.0,
      curve: Curves.easeInOut,
    );

    camera.viewfinder.add(ScaleEffect.to(Vector2.all(0.4), zoomController));

    camera.viewfinder.add(
      MoveEffect.to(
        centerPosition,
        EffectController(duration: 2.0, curve: Curves.easeInOut),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 2000));
    _currentScale = 0.4;
  }

  Future<void> _fadeInConstellation() async {
    // Load the constellation image
    final sprite = await Sprite.load('ui/constellationbackgroundimg.png');

    // Get the original image dimensions
    final originalWidth = sprite.originalSize.x;
    final originalHeight = sprite.originalSize.y;

    // Calculate the size that fits the view without stretching
    // We want it to cover the three trees nicely
    final targetSize = 1500.0; // Adjust this to make it bigger/smaller

    // Calculate aspect-ratio-preserving size
    final Vector2 imageSize;
    if (originalWidth > originalHeight) {
      // Landscape image
      imageSize = Vector2(
        targetSize,
        targetSize * (originalHeight / originalWidth),
      );
    } else {
      // Portrait or square image
      imageSize = Vector2(
        targetSize * (originalWidth / originalHeight),
        targetSize,
      );
    }

    _constellationImage = SpriteComponent(
      sprite: sprite,
      size: imageSize,
      anchor: Anchor.center,
      position: Vector2(0, 0), // Center of the world
      priority: -5,
    );

    // Start invisible
    _constellationImage!.opacity = 0.0;

    await world.add(_constellationImage!);

    // Fade in over 2 seconds
    _constellationImage!.add(
      OpacityEffect.to(
        .1, // Full opacity for transparent constellation lines
        EffectController(duration: 4.0, curve: Curves.easeIn),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 4000));
  }
}

/// Individual skill node
class SkillNode extends PositionComponent with TapCallbacks {
  final ConstellationSkill skill;
  final Color primaryColor;
  final Color secondaryColor;
  final VoidCallback onTap;
  final bool isRootNode; // Mark if this is a tier 1 root node

  bool isUnlocked;
  bool canUnlock;

  // Visual components
  late CircleComponent _outerRing;
  late CircleComponent _innerCore;
  late TextComponent _costText;
  ParticleSystemComponent? _particles;

  SkillNode({
    required this.skill,
    required Vector2 position,
    required this.isUnlocked,
    required this.canUnlock,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onTap,
    this.isRootNode = false, // Default to false
  }) : super(
         position: position,
         size: Vector2.all(80),
         anchor: Anchor.center,
         priority: 0, // Nodes on top
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Create hexagonal alchemical node instead of circle
    _outerRing = CircleComponent(
      radius: 35,
      position: size / 2,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.transparent, // We'll custom render this
    );
    await add(_outerRing);

    // Inner core with mystical glow
    _innerCore = CircleComponent(
      radius: 28,
      position: size / 2,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.transparent, // We'll custom render this
    );
    await add(_innerCore);

    // Cost text (hidden once unlocked)
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

    // Particles for unlocked nodes
    if (isUnlocked) {
      await _addParticles();
    }

    // Pulsing animation for available nodes
    if (canUnlock) {
      _addPulseEffect();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final center = size / 2;
    final ringColor = _getRingColor();
    final coreColor = _getCoreColor();

    // Draw hexagonal outer ring (alchemical symbol)
    final hexPath = _createHexagon(center.toOffset(), 35);

    // Outer glow for unlocked/available nodes
    if (isUnlocked || canUnlock) {
      final glowPaint = Paint()
        ..color = primaryColor.withOpacity(isUnlocked ? 0.8 : 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isUnlocked ? 1.0 : 3.0;
      canvas.drawPath(hexPath, glowPaint);
    }

    // Main hexagon border - thicker for root nodes
    final borderWidth = isRootNode ? 13.0 : 1.0;
    final borderPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.x, center.y - 35),
        Offset(center.x, center.y + 35),
        [ringColor, ringColor.withOpacity(0.6)],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawPath(hexPath, borderPaint);

    // Inner hexagonal core (smaller)
    final coreHexPath = _createHexagon(center.toOffset(), 28);
    final corePaint = Paint()
      ..shader = ui.Gradient.radial(
        center.toOffset(),
        28,
        [
          coreColor.withOpacity(0.6),
          coreColor.withOpacity(0.2),
          coreColor.withOpacity(0.35),
        ],
        [0.0, 0.5, 1.0],
      )
      ..style = PaintingStyle.fill;

    if (isUnlocked) {
      canvas.drawPath(coreHexPath, corePaint);
    }

    // Add alchemical corner accents for unlocked nodes
    if (isUnlocked) {
      _drawAlchemicalAccents(canvas, center.toOffset(), 35);
    }
  }

  Path _createHexagon(Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 6; // Start from flat top
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
    // Draw small diamond accents at hexagon corners
    final paint = Paint()
      ..color = secondaryColor.withOpacity(0.7)
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
    if (canUnlock) return primaryColor.withOpacity(0.8);
    return primaryColor.withOpacity(0.3);
  }

  Color _getCoreColor() {
    if (isUnlocked) return primaryColor.withOpacity(0.4);
    if (canUnlock) return primaryColor.withOpacity(0.15);
    return Colors.black.withOpacity(0.6);
  }

  Future<void> _addParticles() async {
    // Alchemical energy particles - floating symbols and energy wisps
    final particles = ParticleSystemComponent(
      particle: Particle.generate(
        count: 15,
        lifespan: 3,
        generator: (i) {
          final angle =
              (i / 15) * math.pi * 2 + (math.Random().nextDouble() * 0.5);
          final distance = 40.0 + math.Random().nextDouble() * 20.0;
          final floatSpeed = 15.0 + math.Random().nextDouble() * 10.0;

          // Starting position in a circle around the node
          final startOffset = Vector2(
            math.cos(angle) * distance,
            math.sin(angle) * distance,
          );

          // Floating upward and spiraling outward
          return AcceleratedParticle(
            speed: Vector2(
              math.cos(angle) * floatSpeed,
              -30.0, // Float upward
            ),
            acceleration: Vector2(0, -5.0), // Gentle upward acceleration
            child: ComputedParticle(
              lifespan: 3,
              renderer: (canvas, particle) {
                final life = particle.progress;
                final opacity = (1.0 - life) * 0.7;

                // Draw diamond/crystal shape
                final size = 3.0 + (1.0 - life) * 2.0;
                final paint = Paint()
                  ..color = primaryColor.withOpacity(opacity)
                  ..style = PaintingStyle.fill;

                final path = Path()
                  ..moveTo(0, -size)
                  ..lineTo(size * 0.6, 0)
                  ..lineTo(0, size)
                  ..lineTo(-size * 0.6, 0)
                  ..close();

                canvas.drawPath(path, paint);

                // Inner glow
                final glowPaint = Paint()
                  ..color = secondaryColor.withOpacity(opacity * 0.5)
                  ..style = PaintingStyle.fill;
                canvas.drawPath(
                  Path()
                    ..moveTo(0, -size * 0.5)
                    ..lineTo(size * 0.3, 0)
                    ..lineTo(0, size * 0.5)
                    ..lineTo(-size * 0.3, 0)
                    ..close(),
                  glowPaint,
                );
              },
            ),
            position: startOffset,
          );
        },
      ),
      position: size / 2,
    );

    _particles = particles;
    await add(particles);
  }

  void _addPulseEffect() {
    // Apply pulse to the outer ring instead of the whole node
    _outerRing.add(
      OpacityEffect.to(
        0.4,
        EffectController(duration: 1.5, infinite: true, reverseDuration: 1.5),
      ),
    );
  }

  void updateState({required bool isUnlocked, required bool canUnlock}) {
    this.isUnlocked = isUnlocked;
    this.canUnlock = canUnlock;

    // Hide cost text once unlocked (no checkmark)
    _costText.text = isUnlocked ? '' : '${skill.pointsCost}';
    _costText.textRenderer = TextPaint(
      style: TextStyle(
        color: primaryColor,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );

    // Add particles if newly unlocked
    if (isUnlocked && _particles == null) {
      _addParticles();
    }

    // Add pulse if newly available
    if (canUnlock && _outerRing.children.whereType<OpacityEffect>().isEmpty) {
      _addPulseEffect();
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    onTap();
  }
}

/// Connection line between nodes with animated activation
class ConnectionLine extends Component {
  final SkillNode from;
  final SkillNode to;
  bool isActive;
  bool canActivate;
  final Color primaryColor;
  final int connectionIndex;

  final String? storyText;

  double _animationProgress = 1.0; // 1.0 = fully drawn
  double _glowIntensity = 0.0;
  bool _isAnimating = false;
  double _animationTime = 0.0;
  double _storyGlitchProgress = 0.0;
  static const double _drawDuration = 2.0;
  static const double _glowDuration = 1.0;
  static const double _storyGlitchDuration = 0.5;
  static const double _totalDuration = 3.5;

  // Glitch effect variables
  final List<Offset> _glitchOffsets = [];
  double _glitchTime = 0.0;

  ConnectionLine({
    required this.from,
    required this.to,
    required this.isActive,
    required this.canActivate,
    required this.primaryColor,
    required this.connectionIndex,
    this.storyText,
  }) : super(priority: -1); // Behind nodes but above background

  /// Trigger the constellation connection animation
  void animateActivation() {
    if (_isAnimating || isActive) return;

    _isAnimating = true;
    isActive = true;
    _animationProgress = 0.0;
    _glowIntensity = 0.0;
    _animationTime = 0.0;
    _storyGlitchProgress = 0.0;

    // Pre-generate glitch offsets for the quote animation
    final random = math.Random();
    _glitchOffsets.clear();
    for (int i = 0; i < 10; i++) {
      _glitchOffsets.add(
        Offset(random.nextDouble() * 6 - 3, random.nextDouble() * 6 - 3),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!_isAnimating) return;

    _animationTime += dt;
    _glitchTime += dt * 20;

    if (_animationTime < _drawDuration) {
      _animationProgress = (_animationTime / _drawDuration).clamp(0.0, 1.0);
    } else if (_animationTime < _drawDuration + _glowDuration) {
      _animationProgress = 1.0;
      final glowProgress = (_animationTime - _drawDuration) / _glowDuration;
      _glowIntensity = glowProgress < 0.5
          ? glowProgress * 2.0
          : (1.0 - glowProgress) * 2.0;
    } else if (_animationTime < _totalDuration) {
      _animationProgress = 1.0;
      _glowIntensity = 0.0;
      final storyProgress =
          (_animationTime - _drawDuration - _glowDuration) /
          _storyGlitchDuration;
      _storyGlitchProgress = storyProgress.clamp(0.0, 1.0);
    } else {
      _animationProgress = 1.0;
      _glowIntensity = 0.0;
      _storyGlitchProgress = 1.0;
      _isAnimating = false;
    }
  }

  @override
  void render(Canvas canvas) {
    final fromPos = from.position;
    final toPos = to.position;

    // Only draw if unlocked or can be unlocked (dimmed)
    if (!isActive && !canActivate) return;

    // Calculate current end point based on animation progress
    final currentEnd = _isAnimating
        ? fromPos + (toPos - fromPos) * _animationProgress
        : toPos;

    final direction = (toPos - fromPos).normalized();

    // Base opacity - dimmed if not active
    final baseOpacity = isActive ? 0.8 : 0.25;
    final glowBoost = _glowIntensity * 0.2;

    // Draw straight white glowing line
    final paint = Paint()
      ..color = Colors.white.withOpacity(baseOpacity + glowBoost)
      ..strokeWidth = 2.0 + (_glowIntensity * 4.0)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(fromPos.toOffset(), currentEnd.toOffset(), paint);

    // Outer glow
    if (isActive) {
      final glowPaint = Paint()
        ..color = Colors.white.withOpacity((0.3 + glowBoost) * 0.5)
        ..strokeWidth = 8.0 + (_glowIntensity * 8.0)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);

      canvas.drawLine(fromPos.toOffset(), currentEnd.toOffset(), glowPaint);
    }

    // Draw story snippet when animation reaches that phase
    if (_storyGlitchProgress > 0) {
      _drawGlitchingStory(canvas, fromPos, toPos);
    }
  }

  void _drawGlitchingStory(Canvas canvas, Vector2 from, Vector2 to) {
    if (storyText == null || storyText!.isEmpty) return;

    final midPoint = (from + to) / 2;
    final direction = (to - from).normalized();
    final perpendicular = Vector2(-direction.y, direction.x);

    // How far away from the line you want the text
    const sideDistance = 160.0;

    // Calculate the horizontal and vertical distances to detect forks
    final deltaX = (to.x - from.x).abs();
    final deltaY = (to.y - from.y).abs();

    // Determine if this is part of a fork
    // A fork is when multiple connections share the same 'from' node
    // and branch out horizontally or at angles
    final isFork =
        deltaX > 100; // Significant horizontal spread indicates a fork

    bool isRightSide;

    if (isFork) {
      // For forks, place text on the outside based on which side the branch goes
      if (to.x > from.x) {
        // Branch goes to the right -> text on right
        isRightSide = true;
      } else {
        // Branch goes to the left -> text on left
        isRightSide = false;
      }
    } else {
      // Normal alternating pattern for non-fork connections
      isRightSide = connectionIndex % 2 == 0;
    }

    final sideOffset =
        perpendicular * (isRightSide ? sideDistance : -sideDistance);
    final alongOffsetVec = direction;

    final storyPos = midPoint + sideOffset + alongOffsetVec;

    // During glitch phase, jitter the text
    final glitchOffset = _storyGlitchProgress < 1.0
        ? _glitchOffsets[(_glitchTime % _glitchOffsets.length).floor()]
        : Offset.zero;

    final opacity = _storyGlitchProgress.clamp(0.0, 1.0);

    // Glitchy ghost copies
    if (_storyGlitchProgress < 1.0) {
      for (int i = 0; i < 3; i++) {
        final off = _glitchOffsets[i % _glitchOffsets.length];
        final glitchPosVec = storyPos + Vector2(off.dx, off.dy);
        final glitchPaint = TextPaint(
          style: TextStyle(
            color: Colors.white.withOpacity(opacity * 0.25),
            fontSize: 12,
            fontWeight: FontWeight.w300,
          ),
        );
        glitchPaint.render(
          canvas,
          storyText!,
          glitchPosVec,
          anchor: Anchor.center,
        );
      }
    }

    // Main story text
    final mainPaint = TextPaint(
      style: GoogleFonts.imFellGreatPrimer(
        color: Colors.white.withOpacity(opacity * 0.95),
        fontSize: 12,
      ),
    );

    final finalPosVec = storyPos + Vector2(glitchOffset.dx, glitchOffset.dy);
    mainPaint.render(canvas, storyText!, finalPosVec, anchor: Anchor.center);
  }
}

/// Animated starfield background
class StarfieldBackground extends Component {
  final Color primaryColor;
  final Color secondaryColor;
  final List<Star> stars = [];
  bool _rapidBlinkMode = false;

  StarfieldBackground({
    required this.primaryColor,
    required this.secondaryColor,
  }) : super(priority: -10); // Way behind everything

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Generate random stars across a large area to cover all three trees
    final random = math.Random();
    for (int i = 0; i < 10000; i++) {
      stars.add(
        Star(
          position: Vector2(
            random.nextDouble() * 6000 - 3000,
            random.nextDouble() * 6000 - 3000,
          ),
          size: random.nextDouble() * 2 + 1,
          opacity: random.nextDouble() * 0.5 + 0.3,
          twinkleSpeed: random.nextDouble() * 2 + 1,
        ),
      );
    }
  }

  void startRapidBlink() {
    _rapidBlinkMode = true;
    for (final star in stars) {
      star.startRapidBlink();
    }
  }

  void restoreNormalTwinkling() {
    _rapidBlinkMode = false;
    for (final star in stars) {
      star.restoreNormalTwinkle();
    }
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = primaryColor;

    for (final star in stars) {
      paint.color = primaryColor.withOpacity(star.currentOpacity);
      canvas.drawCircle(star.position.toOffset(), star.size, paint);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    for (final star in stars) {
      star.update(dt);
    }
  }
}

class Star {
  final Vector2 position;
  final double size;
  final double opacity;
  final double twinkleSpeed;
  double _time = 0;
  bool _rapidBlink = false;
  double _rapidBlinkSpeed = 20.0;

  Star({
    required this.position,
    required this.size,
    required this.opacity,
    required this.twinkleSpeed,
  });

  double get currentOpacity {
    if (_rapidBlink) {
      // Rapid blinking effect
      return opacity * (0.3 + 0.7 * (math.sin(_time * _rapidBlinkSpeed).abs()));
    }
    return opacity * (0.5 + 0.5 * math.sin(_time * twinkleSpeed));
  }

  void startRapidBlink() {
    _rapidBlink = true;
  }

  void restoreNormalTwinkle() {
    _rapidBlink = false;
  }

  void update(double dt) {
    _time += dt;
  }
}
