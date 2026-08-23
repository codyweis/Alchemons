// lib/games/constellations/constellation_game.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Map<ConstellationTree, List<String>> kTreeStoryBeats = {
  ConstellationTree.breeder: [
    'In the hush before barter,',
    'The first heartbeat\nor waking breath,',
    'the moment marking\nflesh and life,',
  ],
  ConstellationTree.combat: [],
  ConstellationTree.extraction: [
    'The loneliness of the night.',
    'Stands before me.',
    'Silence is the only thing.',
    'To be heard.',
  ],
};

const Map<ConstellationTree, List<String>> kTreeCodaSegments = {
  ConstellationTree.breeder: [
    'a flicker in the night,',
    'the light grows,\nthe light flickers,\nthen fades.',
    'can you remember\nthe glow?',
  ],
  ConstellationTree.extraction: [
    'My thoughts are released,',
    'and now are set free.',
    'But silence is still present.',
    'For thoughts are not words.',
  ],
};

const Map<ConstellationTree, List<String>> kTreeCodaProgressionSkillIds = {
  ConstellationTree.breeder: [
    'breeder_potential_analyzer',
    'breeder_accelerated_gestation',
    'breeder_accelerated_gestation2',
    'breeder_accelerated_gestation3',
    'breeder_harvesting_wilderness_specimens',
    'breeder_harvesting_wilderness_specimens2',
    'breeder_harvesting_wilderness_specimens3',
  ],
  ConstellationTree.extraction: [
    'extraction_all_day_market',
    'extraction_sale_boost_1',
    'extraction_sale_boost_2',
    'extraction_sale_boost_3',
    'exraction_xp_boost_1',
    'exraction_xp_boost_2',
    'exraction_xp_boost_3',
  ],
};

const List<List<String>> kExtractionCodaRevealPairs = [
  ['extraction_sale_boost_1', 'exraction_xp_boost_1'],
  ['extraction_sale_boost_2', 'exraction_xp_boost_2'],
  ['extraction_sale_boost_3', 'exraction_xp_boost_3'],
];

const List<String> kExtractionCodaStoryIds = [
  'extraction_coda_0',
  'extraction_coda_1',
  'extraction_coda_2',
  'extraction_coda_3',
];

const List<String> kBreederCodaStoryIds = [
  'breeder_coda_0',
  'breeder_coda_1',
  'breeder_coda_2',
];

const List<String> kCombatStoryLines = [
  'They built the arena',
  'where sound refused to cross.',
  'No cheers.',
  'No drums.',
  'Only breath and impact.',
  'The opening move',
  'drew a constellation of motion.',
  'The sky learned your name.',
];

const Color _kStoryIvory = Color(0xFFE8DFC8);
const Color _kStoryIvoryMuted = Color(0xFFB5A98A);

RRect _storyBubbleRRect(Rect rect) =>
    RRect.fromRectAndRadius(rect, const Radius.circular(10));

void _drawStoryBracketFrame(
  Canvas canvas,
  Rect rect, {
  required Color borderColor,
  double bracketLength = 12,
  double strokeWidth = 1.0,
}) {
  final paint = Paint()
    ..color = borderColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth;
  final l = bracketLength;
  final path = Path()
    ..moveTo(rect.left, rect.top + l)
    ..lineTo(rect.left, rect.top)
    ..lineTo(rect.left + l, rect.top)
    ..moveTo(rect.right - l, rect.top)
    ..lineTo(rect.right, rect.top)
    ..lineTo(rect.right, rect.top + l)
    ..moveTo(rect.left, rect.bottom - l)
    ..lineTo(rect.left, rect.bottom)
    ..lineTo(rect.left + l, rect.bottom)
    ..moveTo(rect.right - l, rect.bottom)
    ..lineTo(rect.right, rect.bottom)
    ..lineTo(rect.right, rect.bottom - l);
  canvas.drawPath(path, paint);
}

class ConstellationGame extends FlameGame with ScaleDetector {
  ConstellationTree selectedTree;
  Set<String> _unlockedSkills;
  Set<ConstellationTree> _visibleTrees;
  final Function(ConstellationSkill) onSkillTapped;
  final Color primaryColor;
  final Color secondaryColor;
  bool tutorialLocked;

  final Map<String, SkillNode> _nodes = {};
  final Map<String, ConnectionLine> _connections = {};
  final List<TreeStoryBlock> _storyBlocks = [];

  final Map<ConstellationTree, Vector2> _treePositions = {
    ConstellationTree.breeder: Vector2(0, -600),
    ConstellationTree.combat: Vector2(-700, 400),
    ConstellationTree.extraction: Vector2(700, 400),
  };

  double _baseScaleForGesture = 1.0;
  // Was 0.2, which clipped the combat tree: its horizontal arms span ~2100
  // world units with padding, needing ~0.15 to fit the narrowest phone. A
  // floor above the framing zoom would also mean the view the screen opens on
  // is one the player could never pinch back out to.
  static const double _minScale = 0.15;
  static const double _maxScale = 2.0;

  /// Fallback framing when there is nothing measurable to fit. The finale
  /// uses this fixed value for its reveal.
  static const double _overviewZoom = 0.4;

  /// World-space breathing room left around the nodes when framing them.
  static const double _overviewPadding = 220.0;

  /// Framing never goes below this, even when the tree does not fit.
  ///
  /// Combat is a cross whose horizontal arms are about three times breeder's
  /// width; fitting them whole put it at 0.17, where the nodes are specks.
  /// Better to open it readable and let the arms run off the sides — they are
  /// a straight line of nodes, and panning along them is easy.
  static const double _minFramingZoom = 0.34;

  /// The pinch-out limit, exposed so the default framing can be asserted to
  /// sit inside the range a player can reach by hand.
  @visibleForTesting
  static double get minZoom => _minScale;

  @visibleForTesting
  static double get minFramingZoom => _minFramingZoom;

  /// World-space bounds of a tree's nodes, so a test can assert the framing
  /// actually contains them.
  @visibleForTesting
  Rect? treeBoundsForTest(ConstellationTree tree) {
    final nodes = _nodes.values.where((n) => n.tree == tree);
    if (nodes.isEmpty) return null;
    var minX = double.infinity;
    var maxX = -double.infinity;
    var minY = double.infinity;
    var maxY = -double.infinity;
    for (final n in nodes) {
      final half = n.size.x / 2;
      minX = math.min(minX, n.position.x - half);
      maxX = math.max(maxX, n.position.x + half);
      minY = math.min(minY, n.position.y - half);
      maxY = math.max(maxY, n.position.y + half);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Zoom used when a single tree is chosen — the old entry zoom.
  static const double _treeZoom = 1.0;

  /// The midpoint of the three trees.
  Vector2 get _constellationCentre {
    final b = _treePositions[ConstellationTree.breeder]!;
    final c = _treePositions[ConstellationTree.combat]!;
    final e = _treePositions[ConstellationTree.extraction]!;
    return Vector2((b.x + c.x + e.x) / 3, (b.y + c.y + e.y) / 3);
  }

  bool _isTransitioning = false;
  ConstellationTree? _queuedTree;
  Vector2? _lastFocalPoint;
  String? _pendingFocusSkillId;
  double? _pendingFocusZoom;

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
    required Set<String> unlockedSkills,
    required Set<ConstellationTree> visibleTrees,
    required this.onSkillTapped,
    required this.primaryColor,
    required this.secondaryColor,
    this.tutorialLocked = false,
  }) : _unlockedSkills = Set<String>.from(unlockedSkills),
       _visibleTrees = Set<ConstellationTree>.from(visibleTrees);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.center;

    final nebula = NebulaBackground();
    await world.add(nebula);

    final starfield = StarfieldBackground(
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
    );
    _starfield = starfield;
    await world.add(starfield);

    await _buildAllSkillTrees();
    if (_pendingFocusSkillId != null) {
      // A deep link or the first-unlock tutorial asked for a specific node.
      _applyPendingFocus();
    } else {
      frameTree(selectedTree);
    }
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

        final isUnlocked = _unlockedSkills.contains(skill.id);
        final canUnlock = skill.canUnlock(_unlockedSkills) && !isUnlocked;

        final node = SkillNode(
          tree: tree,
          skill: skill,
          position: treeOffset + Vector2(x, y),
          isUnlocked: isUnlocked,
          canUnlock: canUnlock,
          isTreeVisible: _visibleTrees.contains(tree),
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
          final isUnlocked = _unlockedSkills.contains(skill.id);
          final canUnlock = skill.canUnlock(_unlockedSkills) && !isUnlocked;

          final connectionKey = '${prereqId}_${skill.id}';
          final connection = ConnectionLine(
            tree: tree,
            from: fromNode,
            to: toNode,
            isActive: isUnlocked,
            canActivate: canUnlock,
            isTreeVisible: _visibleTrees.contains(tree),
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

    await _maybeAddTreeCodaBlock(tree, treeOffset, baseY);
  }

  String? _storyFragmentForConnection(
    ConstellationTree tree,
    int connectionIndex,
  ) {
    final beats = kTreeStoryBeats[tree];
    if (beats == null || connectionIndex >= beats.length) return null;
    return beats[connectionIndex];
  }

  Future<void> _buildCombatAlchemyTree(
    List<ConstellationSkill> skills,
    Vector2 treeOffset,
  ) async {
    final tempNodes = <String, SkillNode>{};
    const double ringSpacing = 180.0;

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

      final isUnlocked = _unlockedSkills.contains(skill.id);
      final canUnlock = skill.canUnlock(_unlockedSkills) && !isUnlocked;

      final node = SkillNode(
        tree: ConstellationTree.combat,
        skill: skill,
        position: worldPos,
        isUnlocked: isUnlocked,
        canUnlock: canUnlock,
        isTreeVisible: _visibleTrees.contains(ConstellationTree.combat),
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
        onTap: () => onSkillTapped(skill),
        isRootNode: skill.tier == 1,
      );

      tempNodes[skill.id] = node;
    }

    // Sort skills by tier so story fragments read outward ring-by-ring
    // instead of following one branch all the way out before the next.
    final sortedSkills = List<ConstellationSkill>.from(skills)
      ..sort((a, b) => a.tier.compareTo(b.tier));

    int connectionIndex = 0;
    for (final skill in sortedSkills) {
      for (final prereqId in skill.prerequisites) {
        final fromNode = tempNodes[prereqId];
        final toNode = tempNodes[skill.id];

        if (fromNode != null && toNode != null) {
          final isUnlocked = _unlockedSkills.contains(skill.id);
          final canUnlock = skill.canUnlock(_unlockedSkills) && !isUnlocked;

          final connectionKey = '${prereqId}_${skill.id}';
          final connection = ConnectionLine(
            tree: ConstellationTree.combat,
            from: fromNode,
            to: toNode,
            isActive: isUnlocked,
            canActivate: canUnlock,
            isTreeVisible: _visibleTrees.contains(ConstellationTree.combat),
            primaryColor: primaryColor,
            connectionIndex: connectionIndex,
            storyText: null,
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

    final combatPoem = TreeStoryBlock(
      tree: ConstellationTree.combat,
      position: treeOffset,
      isTreeVisible: _visibleTrees.contains(ConstellationTree.combat),
      primaryColor: primaryColor,
      text: '',
      progressiveLines: kCombatStoryLines,
      revealedLineCount: _combatRevealedLineCount(_unlockedSkills),
      maxWidth: 260,
      alignment: TextAlign.center,
      revealUnlocked: true,
    );
    _storyBlocks.add(combatPoem);
    await world.add(combatPoem);
  }

  Future<void> _maybeAddTreeCodaBlock(
    ConstellationTree tree,
    Vector2 treeOffset,
    double baseY,
  ) async {
    final coda = kTreeCodaSegments[tree];
    if (coda == null || coda.isEmpty) return;

    if (tree == ConstellationTree.breeder) {
      final positions = <Vector2>[
        Vector2(0.0, baseY - (5 * 180.0)),
        Vector2(0.0, baseY - (6 * 180.0)),
        Vector2(0.0, baseY - (7 * 180.0)),
      ];

      for (int i = 0; i < coda.length && i < positions.length; i++) {
        final block = TreeStoryBlock(
          storyId: kBreederCodaStoryIds[i],
          tree: tree,
          position: treeOffset + positions[i],
          isTreeVisible: _visibleTrees.contains(tree),
          primaryColor: primaryColor,
          text: coda[i],
          maxWidth: 190,
          alignment: TextAlign.center,
          revealUnlocked: _isBreederStoryBlockUnlocked(
            kBreederCodaStoryIds[i],
            _unlockedSkills,
          ),
        );
        _storyBlocks.add(block);
        await world.add(block);
      }
      return;
    }

    if (tree == ConstellationTree.extraction) {
      final tierYs = <double>[
        baseY - (5.5 * 180.0),
        baseY - (7 * 180.0),
        baseY - (8 * 180.0),
        baseY - (9 * 180.0),
      ];

      for (int i = 0; i < coda.length && i < tierYs.length; i++) {
        final xOffset = i == 0 ? -120.0 : 0.0;
        final block = TreeStoryBlock(
          storyId: kExtractionCodaStoryIds[i],
          tree: tree,
          position: treeOffset + Vector2(xOffset, tierYs[i]),
          isTreeVisible: _visibleTrees.contains(tree),
          primaryColor: primaryColor,
          text: coda[i],
          maxWidth: 210,
          alignment: TextAlign.center,
          revealUnlocked: _isExtractionStoryBlockUnlocked(
            kExtractionCodaStoryIds[i],
            _unlockedSkills,
          ),
        );
        _storyBlocks.add(block);
        await world.add(block);
      }
      return;
    }

    final block = TreeStoryBlock(
      tree: tree,
      position: treeOffset + Vector2(0, -(baseY - 180.0)),
      isTreeVisible: _visibleTrees.contains(tree),
      primaryColor: primaryColor,
      text: '',
      progressiveLines: coda,
      revealedLineCount: _treeCodaRevealedLineCount(tree, _unlockedSkills),
      maxWidth: 220,
      alignment: TextAlign.center,
      revealUnlocked: _treeCodaRevealedLineCount(tree, _unlockedSkills) > 0,
    );
    _storyBlocks.add(block);
    await world.add(block);
  }

  int _treeCodaProgressCount(
    ConstellationTree tree,
    Set<String> unlockedSkills,
  ) {
    final skillIds = kTreeCodaProgressionSkillIds[tree];
    if (skillIds == null || skillIds.isEmpty) return 0;
    return skillIds.where(unlockedSkills.contains).length;
  }

  int _treeCodaRevealedLineCount(
    ConstellationTree tree,
    Set<String> unlockedSkills,
  ) {
    final lines = kTreeCodaSegments[tree];
    if (lines == null || lines.isEmpty) {
      return tree == ConstellationTree.combat ? kCombatStoryLines.length : 0;
    }

    if (tree == ConstellationTree.extraction) {
      return kExtractionCodaRevealPairs
          .where(
            (pair) => pair.every((skillId) => unlockedSkills.contains(skillId)),
          )
          .length
          .clamp(0, lines.length);
    }

    final skillIds = kTreeCodaProgressionSkillIds[tree];
    if (skillIds == null || skillIds.isEmpty) {
      return 0;
    }

    final unlockedCount = _treeCodaProgressCount(tree, unlockedSkills);
    if (unlockedCount <= 0) return 0;

    return ((unlockedCount / skillIds.length) * lines.length).ceil().clamp(
      0,
      lines.length,
    );
  }

  bool _isExtractionStoryBlockUnlocked(
    String storyId,
    Set<String> unlockedSkills,
  ) {
    switch (storyId) {
      case 'extraction_coda_0':
        return unlockedSkills.contains('extraction_all_day_market');
      case 'extraction_coda_1':
        return kExtractionCodaRevealPairs[0].every(unlockedSkills.contains);
      case 'extraction_coda_2':
        return kExtractionCodaRevealPairs[1].every(unlockedSkills.contains);
      case 'extraction_coda_3':
        return kExtractionCodaRevealPairs[2].every(unlockedSkills.contains);
      default:
        return false;
    }
  }

  bool _isBreederStoryBlockUnlocked(
    String storyId,
    Set<String> unlockedSkills,
  ) {
    switch (storyId) {
      case 'breeder_coda_0':
        return unlockedSkills.contains('breeder_accelerated_gestation') &&
            unlockedSkills.contains('breeder_harvesting_wilderness_specimens');
      case 'breeder_coda_1':
        return unlockedSkills.contains('breeder_accelerated_gestation2') &&
            unlockedSkills.contains('breeder_harvesting_wilderness_specimens2');
      case 'breeder_coda_2':
        return unlockedSkills.contains('breeder_accelerated_gestation3') &&
            unlockedSkills.contains('breeder_harvesting_wilderness_specimens3');
      default:
        return false;
    }
  }

  int _combatUnlockedCount(Set<String> unlockedSkills) {
    return ConstellationCatalog.forTree(
      ConstellationTree.combat,
    ).where((skill) => unlockedSkills.contains(skill.id)).length;
  }

  int _combatRevealedLineCount(Set<String> unlockedSkills) {
    final unlockedCount = _combatUnlockedCount(unlockedSkills);
    return unlockedCount.clamp(0, kCombatStoryLines.length);
  }


  /// Frame [tree] so the whole of it is on screen, rather than dropping the
  /// camera into the middle of it at full zoom.
  ///
  /// The zoom is measured from the tree's own nodes instead of fixed: the
  /// branches are different sizes, and a constant that shows all of one shows
  /// only part of another.
  void frameTree(ConstellationTree tree) {
    final nodes = _nodes.values.where((n) => n.tree == tree).toList();
    if (nodes.isEmpty) {
      camera.viewfinder.position = _treePositions[tree] ?? _constellationCentre;
      camera.viewfinder.zoom = _treeZoom;
      return;
    }

    var minX = double.infinity;
    var maxX = -double.infinity;
    var minY = double.infinity;
    var maxY = -double.infinity;
    for (final n in nodes) {
      final half = n.size.x / 2;
      final c = n.position;
      if (c.x - half < minX) minX = c.x - half;
      if (c.x + half > maxX) maxX = c.x + half;
      if (c.y - half < minY) minY = c.y - half;
      if (c.y + half > maxY) maxY = c.y + half;
    }

    final width = (maxX - minX) + _overviewPadding;
    final height = (maxY - minY) + _overviewPadding;
    final viewport = camera.viewport.size;
    if (width <= 0 || height <= 0 || viewport.x <= 0 || viewport.y <= 0) {
      camera.viewfinder.position = _treePositions[tree] ?? _constellationCentre;
      camera.viewfinder.zoom = _treeZoom;
      return;
    }

    camera.viewfinder.position = Vector2((minX + maxX) / 2, (minY + maxY) / 2);
    // Whichever axis is tighter decides, floored so a very wide tree stays
    // readable rather than fitting at any cost.
    camera.viewfinder.zoom = math
        .min(viewport.x / width, viewport.y / height)
        .clamp(_minFramingZoom, _treeZoom);
  }

  /// The zoom that would frame [tree] — used so a transition lands on the
  /// same framing the screen opens with.
  double _fitZoomFor(ConstellationTree tree) {
    final before = camera.viewfinder.zoom;
    final beforePos = camera.viewfinder.position.clone();
    frameTree(tree);
    final fitted = camera.viewfinder.zoom;
    camera.viewfinder.zoom = before;
    camera.viewfinder.position = beforePos;
    return fitted;
  }

  Future<void> transitionToTree(ConstellationTree tree) async {
    if (tutorialLocked) return;
    if (!_visibleTrees.contains(tree)) return;
    if (_isTransitioning) {
      _queuedTree = tree;
      return;
    }
    if (tree == selectedTree) return;

    _isTransitioning = true;
    _queuedTree = null;
    selectedTree = tree;

    final targetPosition = _treePositions[tree]!;
    EffectController controller() =>
        EffectController(duration: 0.8, curve: Curves.easeInOutCubic);

    camera.viewfinder.add(MoveEffect.to(targetPosition, controller()));
    // Land on the same framing the screen opens with, so switching trees and
    // arriving on one look identical.
    final targetZoom = _fitZoomFor(tree);
    if ((camera.viewfinder.zoom - targetZoom).abs() > 0.01) {
      camera.viewfinder.add(
        ScaleEffect.to(Vector2.all(targetZoom), controller()),
      );
    }

    await Future.delayed(const Duration(milliseconds: 800));
    _isTransitioning = false;

    final queuedTree = _queuedTree;
    _queuedTree = null;
    if (queuedTree != null && queuedTree != selectedTree) {
      await transitionToTree(queuedTree);
    }
  }

  void focusOnSkill(String skillId, {double? zoom}) {
    final node = _nodes[skillId];
    if (node == null) {
      _pendingFocusSkillId = skillId;
      _pendingFocusZoom = zoom;
      return;
    }

    selectedTree = node.tree;
    camera.viewfinder.position = node.position.clone();
    if (zoom != null) {
      camera.viewfinder.zoom = zoom.clamp(_minScale, _maxScale);
    }

    _pendingFocusSkillId = null;
    _pendingFocusZoom = null;
  }

  void _applyPendingFocus() {
    final skillId = _pendingFocusSkillId;
    if (skillId == null) return;
    focusOnSkill(skillId, zoom: _pendingFocusZoom);
  }

  @override
  void onScaleStart(ScaleStartInfo info) {
    if (_isTransitioning || _isPlayingFinale || tutorialLocked) return;
    _baseScaleForGesture = camera.viewfinder.zoom;
    _lastFocalPoint = info.eventPosition.global;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    if (_isTransitioning || _isPlayingFinale || tutorialLocked) return;

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
    if (tutorialLocked) return;
    _lastFocalPoint = null;
  }

  void updateUnlockedSkills(Set<String> newUnlockedSkills) {
    final priorUnlockedSkills = _unlockedSkills;
    final newlyUnlocked = newUnlockedSkills.difference(priorUnlockedSkills);
    _unlockedSkills = Set<String>.from(newUnlockedSkills);

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

    for (final block in _storyBlocks) {
      if (block.tree == ConstellationTree.combat) {
        block.updateRevealState(true);
        block.updateRevealedLineCount(
          _combatRevealedLineCount(_unlockedSkills),
        );
      } else if (block.tree == ConstellationTree.breeder &&
          block.storyId != null) {
        block.updateRevealState(
          _isBreederStoryBlockUnlocked(block.storyId!, _unlockedSkills),
        );
      } else if (block.tree == ConstellationTree.extraction &&
          block.storyId != null) {
        block.updateRevealState(
          _isExtractionStoryBlockUnlocked(block.storyId!, _unlockedSkills),
        );
      } else {
        final revealedLineCount = _treeCodaRevealedLineCount(
          block.tree,
          _unlockedSkills,
        );
        block.updateRevealState(revealedLineCount > 0);
        block.updateRevealedLineCount(revealedLineCount);
      }
    }

    if (_pendingFocusSkillId != null) {
      _applyPendingFocus();
    }
  }

  void setVisibleTrees(Set<ConstellationTree> trees) {
    // Called from the screen's build, so it runs on every stream tick. The
    // sweep below touches every node, connection and story block; doing that
    // when nothing changed is pure waste.
    if (_visibleTrees.length == trees.length &&
        _visibleTrees.containsAll(trees)) {
      return;
    }
    _visibleTrees = Set<ConstellationTree>.from(trees);

    for (final node in _nodes.values) {
      node.setTreeVisible(_visibleTrees.contains(node.tree));
    }

    for (final connection in _connections.values) {
      connection.setTreeVisible(_visibleTrees.contains(connection.tree));
    }

    for (final block in _storyBlocks) {
      block.setTreeVisible(_visibleTrees.contains(block.tree));
    }

    if (!_visibleTrees.contains(selectedTree)) {
      selectedTree = ConstellationTree.breeder;
      frameTree(selectedTree);
    }
  }

  Future<void> playTreeRevealSequence(ConstellationTree tree) async {
    if (!_visibleTrees.contains(tree)) return;
    _startScreenShake(intensity: 8.0, duration: 0.85);
    await Future.delayed(const Duration(milliseconds: 850));
    await transitionToTree(tree);
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

    final centerPosition = _constellationCentre;

    camera.viewfinder.position = centerPosition;
    camera.viewfinder.zoom = _overviewZoom;

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

class CombatStoryColumn extends PositionComponent {
  final Color primaryColor;
  final Color secondaryColor;
  final int totalCombatSkills;
  final List<String> segments;

  bool isTreeVisible;
  int unlockedCombatSkills;

  late final List<String> _wrappedSegments;
  late final List<List<String>> _wrappedSegmentLines;
  late final List<int> _thresholds;
  TextPaint? _textPaint;

  final Paint _backdropPaint = Paint()..style = PaintingStyle.fill;
  final Paint _borderPaint = Paint()..style = PaintingStyle.stroke;

  static const double _bubbleWidth = 240.0;
  static const double _lineHeight = 17.0;
  static const double _bubblePadding = 18.0;
  static const double _bubbleGap = 14.0;

  CombatStoryColumn({
    required Vector2 position,
    required this.isTreeVisible,
    required this.primaryColor,
    required this.secondaryColor,
    required this.totalCombatSkills,
    required this.unlockedCombatSkills,
    required this.segments,
  }) : super(position: position, anchor: Anchor.bottomCenter, priority: 2) {
    _wrappedSegments = segments
        .map(
          (segment) =>
              ConnectionLine.wrapStoryText(segment, maxCharsPerLine: 30),
        )
        .toList();
    _wrappedSegmentLines = _wrappedSegments
        .map(
          (segment) => segment.isEmpty ? const <String>[] : segment.split('\n'),
        )
        .toList();
    _thresholds = _buildThresholds(totalCombatSkills, segments.length);
  }

  static List<int> _buildThresholds(int totalSkills, int segmentCount) {
    if (segmentCount <= 0) return const <int>[];
    if (segmentCount == 1) return [totalSkills];
    if (totalSkills <= 1) {
      return List<int>.generate(segmentCount, (_) => 1);
    }

    final thresholds = <int>[];
    final span = totalSkills - 1;
    for (int i = 0; i < segmentCount - 1; i++) {
      final t = (1 + ((span * i) / (segmentCount - 1)).floor()).clamp(
        1,
        totalSkills,
      );
      thresholds.add(t);
    }
    thresholds.add(totalSkills);
    return thresholds;
  }

  void updateUnlockedCombatSkills(int count) {
    unlockedCombatSkills = count;
  }

  void setTreeVisible(bool visible) {
    isTreeVisible = visible;
  }

  @override
  void render(Canvas canvas) {
    if (!isTreeVisible) return;
    final revealedCount = _thresholds
        .where((t) => unlockedCombatSkills >= t)
        .length;
    if (revealedCount <= 0) return;

    _textPaint ??= TextPaint(
      style: GoogleFonts.imFellGreatPrimer(
        color: _kStoryIvory.withValues(alpha: 0.92),
        fontSize: 13,
        height: 1.28,
      ),
    );

    double yOffset = 0.0;
    for (int i = 0; i < revealedCount; i++) {
      final lines = _wrappedSegmentLines[i];
      final bubbleHeight = (lines.length * _lineHeight) + _bubblePadding;
      final xOffset = (i.isEven ? -1.0 : 1.0) * (18.0 + (i % 3) * 8.0);
      final rect = Rect.fromCenter(
        center: Offset(xOffset, -(yOffset + bubbleHeight / 2)),
        width: _bubbleWidth,
        height: bubbleHeight,
      );
      final bubble = _storyBubbleRRect(rect);

      final alpha = i == revealedCount - 1 ? 0.78 : 0.66;
      _backdropPaint.color = Colors.black.withValues(alpha: alpha);
      canvas.drawRRect(bubble, _backdropPaint);

      _borderPaint
        ..color = _kStoryIvoryMuted.withValues(
          alpha: i == revealedCount - 1 ? 0.42 : 0.28,
        )
        ..strokeWidth = 0.8;
      canvas.drawRRect(bubble, _borderPaint);
      _drawStoryBracketFrame(
        canvas,
        rect,
        borderColor: _kStoryIvoryMuted.withValues(
          alpha: i == revealedCount - 1 ? 0.55 : 0.36,
        ),
        bracketLength: 10,
        strokeWidth: 1.0,
      );

      _textPaint!.render(
        canvas,
        _wrappedSegments[i],
        Vector2(xOffset, -(yOffset + bubbleHeight / 2)),
        anchor: Anchor.center,
      );

      yOffset += bubbleHeight + _bubbleGap;
    }
  }
}

class TreeStoryBlock extends PositionComponent {
  final String? storyId;
  final ConstellationTree tree;
  final Color primaryColor;
  final String text;
  final List<String>? progressiveLines;
  final double maxWidth;
  final TextAlign alignment;

  bool isTreeVisible;
  bool revealUnlocked;
  int revealedLineCount;

  TextPainter? _textPainter;
  String _laidOutText = '';
  final Paint _backdropPaint = Paint()..style = PaintingStyle.fill;
  final Paint _borderPaint = Paint()..style = PaintingStyle.stroke;

  TreeStoryBlock({
    this.storyId,
    required this.tree,
    required Vector2 position,
    required this.isTreeVisible,
    required this.primaryColor,
    required this.text,
    this.progressiveLines,
    this.revealedLineCount = 0,
    required this.maxWidth,
    required this.alignment,
    required this.revealUnlocked,
  }) : super(position: position, anchor: Anchor.center, priority: 3);

  void setTreeVisible(bool visible) {
    isTreeVisible = visible;
  }

  void updateRevealState(bool unlocked) {
    if (tree == ConstellationTree.combat) {
      revealUnlocked = true;
      return;
    }
    revealUnlocked = unlocked;
  }

  void updateRevealedLineCount(int count) {
    final lines = progressiveLines;
    if (lines == null) return;
    final next = count.clamp(0, lines.length);
    if (next == revealedLineCount) return;
    revealedLineCount = next;
    _textPainter = null;
    _laidOutText = '';
  }

  @override
  void render(Canvas canvas) {
    if (!isTreeVisible || !revealUnlocked) return;

    final displayText = progressiveLines == null
        ? text.trim()
        : progressiveLines!.take(revealedLineCount).join('\n').trim();
    if (displayText.isEmpty) return;

    if (_textPainter == null || _laidOutText != displayText) {
      _laidOutText = displayText;
      _textPainter = TextPainter(
        text: TextSpan(
          text: displayText,
          style: GoogleFonts.imFellGreatPrimer(
            color: _kStoryIvory.withValues(alpha: 0.9),
            fontSize: 14,
            height: 1.34,
          ),
        ),
        textAlign: alignment,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);
    }

    final width = _textPainter!.width + 34.0;
    final height = _textPainter!.height + 28.0;
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: height,
    );
    final bubble = _storyBubbleRRect(rect);

    _backdropPaint.color = Colors.black.withValues(alpha: 0.74);
    canvas.drawRRect(bubble, _backdropPaint);

    _borderPaint
      ..color = _kStoryIvoryMuted.withValues(alpha: 0.28)
      ..strokeWidth = 0.8;
    canvas.drawRRect(bubble, _borderPaint);
    _drawStoryBracketFrame(
      canvas,
      rect,
      borderColor: _kStoryIvoryMuted.withValues(alpha: 0.4),
      bracketLength: 10,
      strokeWidth: 1.0,
    );

    final dx = alignment == TextAlign.left
        ? rect.left + 18.0
        : rect.left + ((rect.width - _textPainter!.width) / 2);
    _textPainter!.paint(
      canvas,
      Offset(dx, rect.top + ((rect.height - _textPainter!.height) / 2)),
    );
  }
}

/// Individual skill node with improved particle system
class SkillNode extends PositionComponent with TapCallbacks {
  final ConstellationTree tree;
  final ConstellationSkill skill;
  final Color primaryColor;
  final Color secondaryColor;
  final VoidCallback onTap;
  final bool isRootNode;

  bool isUnlocked;
  bool canUnlock;
  bool isTreeVisible;

  late String _costLabel;
  TextPaint? _costTextPaint;
  TextPaint? _iconTextPaint;
  late final IconData _identityIcon = skill.identityIcon;

  // Improved particle system - persistent particles with pooling
  final List<_NodeParticle> _particles = [];
  static const int _maxParticles = 12;

  // Pulse animation state
  double _pulseTime = 0.0;

  // Unlock celebration burst — negative when inactive, 0..1 when playing.
  double _unlockBurstT = -1.0;
  static const double _unlockBurstDuration = 0.85;

  // ---- Cached geometry + paints ----
  // These depend only on locked/unlocked state, not on per-frame animation,
  // so we build them once (and rebuild on state change) instead of allocating
  // fresh gradient shaders every frame in render().
  // Every node is Vector2.all(80), so its centre is (40,40) and all of this
  // geometry is byte-identical across the 43 instances. Building it per node
  // dominated the screen's mount cost — 43 hexagon paths and 86 radial
  // gradient shaders, all the same. Shared, keyed by colour where colour
  // matters.
  static final Map<double, Path> _sharedHexes = {};
  static Paint? _sharedOrbit;
  static final Map<int, Paint> _sharedGlow = {};
  static final Map<int, Paint> _sharedAura = {};

  Path? _hexPath;
  Path? _coreHexPath;
  Path? _keystoneHexPath;
  Paint? _glowPaint;
  Paint? _auraPaint;
  Paint? _orbitPaint;
  Paint? _keystonePaint;
  Paint? _borderPaint;
  Paint? _corePaint;
  Paint? _readyPaint;
  Paint? _readyOuterPaint;

  /// The six alchemical accent diamonds never move relative to the node, so
  /// they are one static path built once — not six Paths and a Paint rebuilt
  /// from trig every frame.
  Path? _accentPath;
  Paint? _accentPaint;

  /// Particle diamonds are batched into a handful of alpha buckets and drawn
  /// through reused Path/Paint objects. Twelve particles used to mean 24 fresh
  /// Path + 24 fresh Paint allocations per node per frame; across a filled
  /// tree that was over two thousand allocations a frame, which is what the
  /// stutter actually was.
  static const int _particleAlphaBuckets = 4;
  List<Path>? _particlePaths;
  List<Paint>? _particlePaints;

  void _rebuildVisualPaints() {
    final center = (size / 2).toOffset();
    _hexPath ??= _hexFor(center, 35);
    _coreHexPath ??= _hexFor(center, 28);

    final ringColor = _getRingColor();
    final coreColor = _getCoreColor();
    final availableColor = _getAvailableAccentColor();

    if (isUnlocked) {
      // Identical for every node — the white glow takes no colour at all, and
      // the aura only varies by the game's primary.
      _glowPaint = _sharedGlow.putIfAbsent(
        0,
        () => Paint()
          ..shader = ui.Gradient.radial(
            center,
            55.0,
            [
              Colors.white.withValues(alpha: 0.42),
              Colors.white.withValues(alpha: 0.16),
              Colors.transparent,
            ],
            [0.55, 0.78, 1.0],
          ),
      );
      _auraPaint = _sharedAura.putIfAbsent(
        primaryColor.toARGB32(),
        () => Paint()
          ..shader = ui.Gradient.radial(
            center,
            62.0,
            [
              primaryColor.withValues(alpha: 0.32),
              primaryColor.withValues(alpha: 0.10),
              Colors.transparent,
            ],
            [0.0, 0.6, 1.0],
          ),
      );
      _orbitPaint = _sharedOrbit ??= (Paint()
        ..color = Colors.white.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0);
    } else {
      _glowPaint = null;
      _auraPaint = null;
      _orbitPaint = null;
    }

    if (isRootNode) {
      _keystoneHexPath ??= _hexFor(center, 46);
      _keystonePaint = Paint()
        ..color =
            (isUnlocked
                    ? Color.lerp(primaryColor, Colors.white, 0.4) ?? primaryColor
                    : ringColor)
                .withValues(alpha: isUnlocked ? 0.9 : 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
    }

    _borderPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx, center.dy - 35),
        Offset(center.dx, center.dy + 35),
        [ringColor, ringColor.withValues(alpha: 0.6)],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = isRootNode ? 4.0 : 2.0;

    if (isUnlocked || canUnlock) {
      _corePaint = Paint()
        ..shader = ui.Gradient.radial(
          center,
          28.0,
          [
            coreColor.withValues(alpha: isUnlocked ? 0.82 : 0.52),
            coreColor.withValues(alpha: isUnlocked ? 0.38 : 0.18),
            (canUnlock ? availableColor : coreColor).withValues(
              alpha: isUnlocked ? 0.44 : 0.26,
            ),
          ],
          [0.0, 0.5, 1.0],
        )
        ..style = PaintingStyle.fill;
    } else {
      _corePaint = null;
    }

    if (canUnlock && !isUnlocked) {
      // Was a MaskFilter.blur stroke. Blur is a GPU filter pass per draw and
      // its first use pays pipeline creation, which lands on the frame the
      // screen appears — and no widget test can see it, because tests never
      // rasterise. Two plain strokes read the same at this size.
      _readyOuterPaint = Paint()
        ..color = availableColor.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7.0;
      _readyPaint = Paint()
        ..color = availableColor.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
    } else {
      _readyPaint = null;
      _readyOuterPaint = null;
    }
  }

  SkillNode({
    required this.tree,
    required this.skill,
    required Vector2 position,
    required this.isUnlocked,
    required this.canUnlock,
    required this.isTreeVisible,
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
    _syncCostLabel();
    _rebuildVisualPaints();

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

    if (!isTreeVisible) return;

    // Update pulse animation (used by canUnlock breathing halo)
    if (canUnlock && !isUnlocked) {
      _pulseTime += dt;
    }

    // Advance unlock celebration burst.
    if (_unlockBurstT >= 0.0) {
      _unlockBurstT += dt / _unlockBurstDuration;
      if (_unlockBurstT >= 1.0) _unlockBurstT = -1.0;
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
    if (!isTreeVisible) return;
    super.render(canvas);

    final center = size / 2;
    final centerOffset = center.toOffset();

    // Animated glow for available nodes — strong, breathing, "click me".
    // The halo pulses every frame (so its shader is rebuilt here), but it
    // only applies to the handful of currently-unlockable nodes.
    if (canUnlock && !isUnlocked) {
      final pulseValue = (math.sin(_pulseTime * 2.5) + 1) / 2; // 0..1
      final accent = _getAvailableAccentColor();

      final haloOuter = 60.0 + pulseValue * 8.0;
      final haloAlpha = (0.22 + pulseValue * 0.30).clamp(0.0, 1.0);
      final haloPaint = Paint()
        ..shader = ui.Gradient.radial(
          centerOffset,
          haloOuter,
          [
            accent.withValues(alpha: haloAlpha * 0.85),
            accent.withValues(alpha: haloAlpha * 0.35),
            Colors.transparent,
          ],
          [0.45, 0.7, 1.0],
        );
      canvas.drawCircle(centerOffset, haloOuter, haloPaint);

      // Inner crisp pulse ring on the hex itself
      final ringPaint = Paint()
        ..color = accent.withValues(
          alpha: (0.55 + pulseValue * 0.35).clamp(0.0, 1.0),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawPath(_hexPath!, ringPaint);
    }

    // Outer glow + ambient orbit ring for unlocked nodes (cached paints).
    if (isUnlocked) {
      canvas.drawCircle(centerOffset, 55.0, _glowPaint!);
      canvas.drawCircle(centerOffset, 62.0, _auraPaint!);
      canvas.drawCircle(centerOffset, 48, _orbitPaint!);
    }

    // Root/keystone halo — outer double-ring marker (cached)
    if (isRootNode) {
      canvas.drawPath(_keystoneHexPath!, _keystonePaint!);
    }

    // Main hexagon border (cached)
    canvas.drawPath(_hexPath!, _borderPaint!);

    // Inner hexagonal core (cached)
    if (isUnlocked || canUnlock) {
      canvas.drawPath(_coreHexPath!, _corePaint!);
    }

    if (canUnlock && !isUnlocked) {
      canvas.drawPath(_coreHexPath!, _readyOuterPaint!);
      canvas.drawPath(_coreHexPath!, _readyPaint!);
    }

    // Identity icon — centered when unlocked (the cost is hidden); stacked
    // above the cost label when locked or unlockable.
    if (_iconTextPaint != null) {
      final iconGlyph = String.fromCharCode(_identityIcon.codePoint);
      final iconCenter = isUnlocked ? center : center + Vector2(0, -10);
      _iconTextPaint!.render(
        canvas,
        iconGlyph,
        iconCenter,
        anchor: Anchor.center,
      );
    }

    if (_costLabel.isNotEmpty && _costTextPaint != null) {
      _costTextPaint!.render(
        canvas,
        _costLabel,
        center + Vector2(0, 11),
        anchor: Anchor.center,
      );
    }

    // Alchemical accents for unlocked nodes
    if (isUnlocked) {
      _drawAlchemicalAccents(canvas, center.toOffset(), 35);
      _renderParticles(canvas, center);
    }

    // Unlock celebration burst — expanding ring + center flash
    if (_unlockBurstT >= 0.0 && _unlockBurstT <= 1.0) {
      final t = _unlockBurstT;
      final eased = Curves.easeOutCubic.transform(t);
      final fade = (1.0 - t).clamp(0.0, 1.0);

      // Expanding ring
      final ringRadius = 30.0 + eased * 90.0;
      final ringPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.30 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (3.0 * fade + 1.0) * 2.6;
      canvas.drawCircle(center.toOffset(), ringRadius, ringPaint);
      ringPaint
        ..color = Colors.white.withValues(alpha: 0.85 * fade)
        ..strokeWidth = 3.0 * fade + 1.0;
      canvas.drawCircle(center.toOffset(), ringRadius, ringPaint);

      // Color-tinted secondary ring trailing slightly behind
      final trailRadius = 18.0 + eased * 70.0;
      final trailPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.25 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0;
      canvas.drawCircle(center.toOffset(), trailRadius, trailPaint);
      trailPaint
        ..color = primaryColor.withValues(alpha: 0.7 * fade)
        ..strokeWidth = 2.0;
      canvas.drawCircle(center.toOffset(), trailRadius, trailPaint);

      // Bright center flash — quick fade
      final flashFade = math.max(0.0, 1.0 - t * 2.2);
      if (flashFade > 0) {
        final flashPaint = Paint()
          ..shader = ui.Gradient.radial(
            center.toOffset(),
            32,
            [
              Colors.white.withValues(alpha: 0.9 * flashFade),
              Colors.white.withValues(alpha: 0.25 * flashFade),
              Colors.transparent,
            ],
            [0.0, 0.5, 1.0],
          );
        canvas.drawCircle(center.toOffset(), 32, flashPaint);
      }
    }
  }

  /// Particles are bucketed by opacity and batched into one path per bucket,
  /// through Path/Paint objects that are reused frame to frame. Twelve
  /// particles used to cost 24 Path + 24 Paint allocations per node per frame.
  ///
  /// The inner-glow diamond is folded into the same batch as a second, smaller
  /// diamond in the bucket path rather than a separate draw with its own
  /// colour — at these sizes the two read as one soft mote either way.
  void _renderParticles(Canvas canvas, Vector2 center) {
    if (_particles.isEmpty) return;
    final paths =
        _particlePaths ??= List.generate(
          _particleAlphaBuckets,
          (_) => Path(),
          growable: false,
        );
    final paints =
        _particlePaints ??= List.generate(_particleAlphaBuckets, (i) {
          // Bucket i represents the midpoint of its opacity band.
          final band = (i + 0.5) / _particleAlphaBuckets;
          return Paint()
            ..color = Color.lerp(
              primaryColor,
              secondaryColor,
              0.3,
            )!.withValues(alpha: (band * 0.8).clamp(0.0, 1.0))
            ..style = PaintingStyle.fill;
        }, growable: false);

    for (final path in paths) {
      path.reset();
    }

    var any = false;
    for (final particle in _particles) {
      final pos = particle.getPosition(center);
      final opacity = particle.getOpacity().clamp(0.0, 1.0);
      var bucket = (opacity * _particleAlphaBuckets).floor();
      if (bucket >= _particleAlphaBuckets) bucket = _particleAlphaBuckets - 1;
      if (bucket < 0) bucket = 0;
      final size = particle.size;
      paths[bucket]
        ..moveTo(pos.x, pos.y - size)
        ..lineTo(pos.x + size * 0.6, pos.y)
        ..lineTo(pos.x, pos.y + size)
        ..lineTo(pos.x - size * 0.6, pos.y)
        ..close();
      any = true;
    }
    if (!any) return;

    for (var i = 0; i < _particleAlphaBuckets; i++) {
      canvas.drawPath(paths[i], paints[i]);
    }
  }

  /// Keyed by radius, since the centre is the same for every node — they are
  /// all Vector2.all(80). Keying rather than a bare static so a node of a
  /// different size could never silently pick up the wrong path.
  Path _hexFor(Offset center, double radius) =>
      _sharedHexes.putIfAbsent(radius, () => _createHexagon(center, radius));

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

  /// The accents are fixed relative to the node, so the whole six-diamond
  /// figure is one path built once and drawn with one cached paint.
  void _drawAlchemicalAccents(Canvas canvas, Offset center, double radius) {
    var path = _accentPath;
    if (path == null) {
      path = Path();
      const accentSize = 3.0;
      for (int i = 0; i < 6; i++) {
        final angle = (math.pi / 3) * i - math.pi / 6;
        final x = center.dx + radius * math.cos(angle);
        final y = center.dy + radius * math.sin(angle);
        path
          ..moveTo(x, y - accentSize)
          ..lineTo(x + accentSize * 0.6, y)
          ..lineTo(x, y + accentSize)
          ..lineTo(x - accentSize * 0.6, y)
          ..close();
      }
      _accentPath = path;
      _accentPaint = Paint()
        ..color = secondaryColor.withValues(alpha: 0.7)
        ..style = PaintingStyle.fill;
    }
    canvas.drawPath(path, _accentPaint!);
  }

  Color _getRingColor() {
    if (isUnlocked) {
      return Color.lerp(primaryColor, Colors.white, 0.28) ?? primaryColor;
    }
    if (canUnlock) {
      return _getAvailableAccentColor();
    }
    return primaryColor.withValues(alpha: 0.16);
  }

  Color _getCoreColor() {
    if (isUnlocked) {
      return Color.lerp(primaryColor, Colors.white, 0.08) ?? primaryColor;
    }
    if (canUnlock) return _getAvailableAccentColor().withValues(alpha: 0.34);
    return Colors.black.withValues(alpha: 0.6);
  }

  Color _getAvailableAccentColor() {
    return Color.lerp(primaryColor, secondaryColor, 0.35) ?? primaryColor;
  }

  void updateState({required bool isUnlocked, required bool canUnlock}) {
    // The screen calls this for every node on every widget rebuild, and both
    // stream builders above it tick often. Rebuilding unchanged state meant
    // re-allocating radial gradient shaders and TextPaints for all 43 nodes
    // on each of those rebuilds, which is a visible hitch — shaders are not
    // cheap to construct. Only do the work when something actually moved.
    if (this.isUnlocked == isUnlocked && this.canUnlock == canUnlock) return;

    final wasLocked = !this.isUnlocked;
    this.isUnlocked = isUnlocked;
    this.canUnlock = canUnlock;
    _syncCostLabel();
    _rebuildVisualPaints();

    // Newly unlocked: fire celebration burst + spawn particles.
    if (isUnlocked && wasLocked) {
      _unlockBurstT = 0.0;
      if (_particles.isEmpty) _initializeParticles();
    }
  }

  void _syncCostLabel() {
    _costLabel = isUnlocked ? '' : '★ ${skill.pointsCost}';
    _costTextPaint = TextPaint(
      style: TextStyle(
        color: isUnlocked
            ? Colors.transparent
            : canUnlock
            ? Colors.white
            : Colors.white.withValues(alpha: 0.42),
        fontSize: 14,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.4,
        shadows: canUnlock
            ? const [Shadow(color: Colors.black87, blurRadius: 12)]
            : const [Shadow(color: Colors.black87, blurRadius: 6)],
      ),
    );

    // Identity icon — same MaterialIcons font Flutter ships, rendered as
    // a single glyph in Flame's TextPaint.
    final iconColor = isUnlocked
        ? Color.lerp(primaryColor, Colors.white, 0.55) ?? primaryColor
        : canUnlock
        ? Colors.white
        : Colors.white.withValues(alpha: 0.32);
    _iconTextPaint = TextPaint(
      style: TextStyle(
        color: iconColor,
        fontSize: isUnlocked ? 22 : 18,
        fontFamily: _identityIcon.fontFamily,
        package: _identityIcon.fontPackage,
        shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
      ),
    );
  }

  void setTreeVisible(bool visible) {
    isTreeVisible = visible;
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (!isTreeVisible) return;
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
  final ConstellationTree tree;
  final SkillNode from;
  final SkillNode to;
  bool isActive;
  bool canActivate;
  bool isTreeVisible;
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

  // Traveling energy pulse (activation one-shot)
  double _energyPulsePosition = 0.0;
  bool _showEnergyPulse = false;
  double _storyFloatOffset = 10.0;

  // Ambient state — continuous pulse along active lines + breathing for
  // can-activate (preview) lines. Driven every frame from update().
  double _ambientTime = 0.0;

  late final String _normalizedStoryText;
  TextPainter? _storyTextPainter;
  double _storyPaintAlpha = -1.0;
  double _storyLayoutWidth = -1.0;

  final Paint _linePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  // The glow used to be a MaskFilter.blur stroke. Every blurred draw is its
  // own GPU filter pass, and with a filled tree that was ~72 gaussian passes
  // per frame — the single most expensive thing on screen. Two plain
  // translucent strokes of decreasing width read the same at these sizes and
  // cost nothing beyond ordinary fill rate.
  final Paint _glowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _glowOuterPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _pulsePaint = Paint()..style = PaintingStyle.fill;
  final Paint _pulseGlowPaint = Paint()..style = PaintingStyle.fill;
  final Paint _pulseGlowOuterPaint = Paint()..style = PaintingStyle.fill;
  final Paint _storyBackdropPaint = Paint()..style = PaintingStyle.fill;
  final Paint _storyBorderPaint = Paint()..style = PaintingStyle.stroke;

  ConnectionLine({
    required this.tree,
    required this.from,
    required this.to,
    required this.isActive,
    required this.canActivate,
    required this.isTreeVisible,
    required this.primaryColor,
    required this.connectionIndex,
    this.storyText,
  }) : super(priority: -1) {
    _normalizedStoryText = normalizeStoryText(storyText);
  }

  static String normalizeStoryText(String? text) {
    if (text == null) return '';
    return text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');
  }

  static String wrapStoryText(String? text, {int maxCharsPerLine = 26}) {
    final clean = normalizeStoryText(text);
    if (clean.isEmpty) return '';

    final wrappedLines = <String>[];
    for (final paragraph in clean.split('\n')) {
      final words = paragraph.split(RegExp(r'\s+'));
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

    if (!isTreeVisible) return;

    // Ambient pulse drives continuous active/can-activate effects.
    _ambientTime += dt;

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
    if (!isTreeVisible) return;
    final fromPos = from.position;
    final toPos = to.position;

    if (!isActive && !canActivate) return;

    final currentEnd = _isAnimating
        ? fromPos + (toPos - fromPos) * _animationProgress
        : toPos;

    final glowBoost = (_glowIntensity * 0.3).clamp(0.0, 0.5);

    if (canActivate && !isActive) {
      // CAN-ACTIVATE: dim breathing accent line — "this path is open"
      final breath = (math.sin(_ambientTime * 2.2) + 1) * 0.5; // 0..1
      _linePaint
        ..color = primaryColor.withValues(
          alpha: (0.32 + breath * 0.22).clamp(0.0, 1.0),
        )
        ..strokeWidth = 1.6
        ..maskFilter = null;
      canvas.drawLine(fromPos.toOffset(), currentEnd.toOffset(), _linePaint);

      _drawSoftLine(
        canvas,
        fromPos.toOffset(),
        currentEnd.toOffset(),
        primaryColor,
        (0.18 + breath * 0.18).clamp(0.0, 1.0),
        5.0,
      );
    } else {
      // ACTIVE: bright steady line + glow
      _linePaint
        ..color = Colors.white.withValues(
          alpha: (0.85 + glowBoost).clamp(0.0, 1.0),
        )
        ..strokeWidth = 2.0 + (_glowIntensity * 2.0)
        ..maskFilter = null;
      canvas.drawLine(fromPos.toOffset(), currentEnd.toOffset(), _linePaint);

      _drawSoftLine(
        canvas,
        fromPos.toOffset(),
        currentEnd.toOffset(),
        primaryColor,
        (0.35 + glowBoost * 0.5).clamp(0.0, 1.0),
        7.0 + (_glowIntensity * 6.0),
      );
    }

    // Activation one-shot pulse (when line is being drawn)
    if (_showEnergyPulse && _animationProgress > 0.05) {
      final pulsePos = fromPos + (toPos - fromPos) * _energyPulsePosition;
      _pulsePaint.color = primaryColor.withValues(alpha: 0.9);
      canvas.drawCircle(
        pulsePos.toOffset(),
        4.0 + _glowIntensity * 3.0,
        _pulsePaint,
      );
      _drawSoftDot(canvas, pulsePos.toOffset(), primaryColor, 0.4, 8.0);
    }

    // Ambient traveling sparkle on active lines — quiet "energy flowing"
    if (isActive && !_isAnimating) {
      final t = (_ambientTime * 0.18) % 1.0; // ~5.5s loop
      final pulsePos = fromPos + (toPos - fromPos) * t;
      // Fade in/out at the line endpoints so it doesn't pop.
      final edgeFade = math.min(t, 1.0 - t) * 4.0;
      final fade = edgeFade.clamp(0.0, 1.0);
      _pulsePaint.color = primaryColor.withValues(alpha: 0.85 * fade);
      canvas.drawCircle(pulsePos.toOffset(), 2.6, _pulsePaint);
      _drawSoftDot(canvas, pulsePos.toOffset(), primaryColor, 0.38 * fade, 7.0);
    }

    // Story text
    if (_storyOpacity > 0 && storyText != null) {
      _drawStoryText(canvas, fromPos, toPos);
    }
  }


  /// A blur-free soft line: a wide faint stroke under a narrower brighter one.
  /// Replaces a MaskFilter.blur stroke, which cost a GPU filter pass each.
  void _drawSoftLine(
    Canvas canvas,
    Offset a,
    Offset b,
    Color color,
    double alpha,
    double width,
  ) {
    _glowOuterPaint
      ..color = color.withValues(alpha: (alpha * 0.45).clamp(0.0, 1.0))
      ..strokeWidth = width * 1.9;
    canvas.drawLine(a, b, _glowOuterPaint);
    _glowPaint
      ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0))
      ..strokeWidth = width;
    canvas.drawLine(a, b, _glowPaint);
  }

  /// The dot equivalent of [_drawSoftLine].
  void _drawSoftDot(
    Canvas canvas,
    Offset at,
    Color color,
    double alpha,
    double radius,
  ) {
    _pulseGlowOuterPaint.color = color.withValues(
      alpha: (alpha * 0.40).clamp(0.0, 1.0),
    );
    canvas.drawCircle(at, radius * 1.7, _pulseGlowOuterPaint);
    _pulseGlowPaint.color = color.withValues(alpha: alpha.clamp(0.0, 1.0));
    canvas.drawCircle(at, radius, _pulseGlowPaint);
  }

  void _drawStoryText(Canvas canvas, Vector2 from, Vector2 to) {
    if (_normalizedStoryText.isEmpty) return;

    final midPoint = (from + to) / 2;
    final path = to - from;
    final lineLength = path.length;
    if (lineLength <= 0.001) return;

    final direction = path / lineLength;
    var perpendicular = Vector2(-direction.y, direction.x);
    if (perpendicular.length2 <= 0.001) {
      perpendicular = Vector2(1, 0);
    }
    final treeCenter = _treeCenterFor(tree);
    final radial = midPoint - treeCenter;
    if (radial.length2 > 0.001 && radial.dot(perpendicular) < 0) {
      perpendicular = -perpendicular;
    }

    final maxTextWidth = (lineLength * 0.85).clamp(170.0, 240.0);

    final alpha = (_storyOpacity * 0.95).clamp(0.0, 1.0);
    if (_storyTextPainter == null ||
        (alpha - _storyPaintAlpha).abs() > 0.02 ||
        (_storyLayoutWidth - maxTextWidth).abs() > 0.5) {
      _storyPaintAlpha = alpha;
      _storyLayoutWidth = maxTextWidth;
      _storyTextPainter = TextPainter(
        text: TextSpan(
          text: _normalizedStoryText,
          style: GoogleFonts.imFellGreatPrimer(
            color: _kStoryIvory.withValues(alpha: alpha),
            fontSize: 15,
            height: 1.34,
          ),
        ),
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxTextWidth);
    }

    final textPainter = _storyTextPainter!;
    final textWidth = textPainter.width + 32.0;
    final textHeight = textPainter.height + 24.0;

    final sideSign = connectionIndex.isEven ? -1.0 : 1.0;
    final radialOffset = (64.0 + ((connectionIndex % 3) * 22.0)) * sideSign;
    final tangentNudge = ((connectionIndex % 4) - 1.5) * 12.0;
    final storyPos =
        midPoint +
        perpendicular * radialOffset +
        direction * tangentNudge +
        Vector2(0, -_storyFloatOffset);

    final rect = Rect.fromCenter(
      center: storyPos.toOffset(),
      width: textWidth,
      height: textHeight,
    );
    final bubble = _storyBubbleRRect(rect);

    _storyBackdropPaint.color = Colors.black.withValues(
      alpha: (_storyOpacity * 0.82).clamp(0.0, 1.0),
    );
    canvas.drawRRect(bubble, _storyBackdropPaint);

    _storyBorderPaint
      ..color = _kStoryIvoryMuted.withValues(
        alpha: (_storyOpacity * 0.28).clamp(0.0, 1.0),
      )
      ..strokeWidth = 0.8;
    canvas.drawRRect(bubble, _storyBorderPaint);
    _drawStoryBracketFrame(
      canvas,
      rect,
      borderColor: _kStoryIvoryMuted.withValues(
        alpha: (_storyOpacity * 0.44).clamp(0.0, 1.0),
      ),
      bracketLength: 10,
      strokeWidth: 1.0,
    );

    textPainter.paint(
      canvas,
      Offset(
        rect.left + ((rect.width - textPainter.width) / 2),
        rect.top + ((rect.height - textPainter.height) / 2),
      ),
    );
  }

  static Vector2 _treeCenterFor(ConstellationTree tree) {
    switch (tree) {
      case ConstellationTree.breeder:
        return Vector2(0, -600);
      case ConstellationTree.combat:
        return Vector2(-700, 400);
      case ConstellationTree.extraction:
        return Vector2(700, 400);
    }
  }

  void setTreeVisible(bool visible) {
    isTreeVisible = visible;
  }
}

/// Starfield with improved twinkling
/// Soft radial glows positioned at each tree's center — gives each region
/// of space its own "color signature" so the trees feel like distinct
/// nebulae rather than three identical clusters on a flat starfield.
class NebulaBackground extends Component
    with HasGameReference<ConstellationGame> {
  NebulaBackground() : super(priority: -11);

  static const Map<ConstellationTree, Color> _tints = {
    ConstellationTree.combat: Color(0xFFE63946), // crimson
    ConstellationTree.breeder: Color(0xFF4DA3FF), // azure
    ConstellationTree.extraction: Color(0xFF4ADE80), // verdant
  };

  static const double _radius = 900.0;

  // Pre-built (center, paint) pairs — shaders are expensive to construct,
  // and nebula positions/colors never change, so we build them once.
  late final List<(Offset, Paint)> _glows = _tints.entries.map((entry) {
    final center = ConnectionLine._treeCenterFor(entry.key).toOffset();
    final color = entry.value;
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        _radius,
        [
          color.withValues(alpha: 0.18),
          color.withValues(alpha: 0.07),
          Colors.transparent,
        ],
        [0.0, 0.45, 1.0],
      );
    return (center, paint);
  }).toList();

  @override
  void render(Canvas canvas) {
    for (final (center, paint) in _glows) {
      canvas.drawCircle(center, _radius, paint);
    }
  }
}

class StarfieldBackground extends Component
    with HasGameReference<ConstellationGame> {
  final Color primaryColor;
  final Color secondaryColor;
  final List<Star> stars = [];
  double _time = 0.0;

  static const int _farLayerCount = 1664;
  static const int _midLayerCount = 1216;
  static const int _nearLayerCount = 256;

  StarfieldBackground({
    required this.primaryColor,
    required this.secondaryColor,
  }) : super(priority: -10);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final random = math.Random();

    // Layered stars for depth
    // Far layer - small, dim, slow, barely moves with camera
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
          depthFactor: 0.35,
        ),
      );
    }

    // Mid layer - medium, partial parallax
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
          depthFactor: 0.7,
        ),
      );
    }

    // Near layer - bright, fast twinkle, full 1:1 with camera
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
          depthFactor: 1.0,
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

  // ---- Batched drawing ----
  //
  // Three thousand stars used to mean three thousand `drawCircle` calls and
  // three thousand Vector2 allocations per frame, and zooming out (which shows
  // ~25x the area) made it worse exactly when the player was moving. Stars are
  // now bucketed by size and brightness and drawn with `drawRawPoints`, so the
  // whole field costs at most `_sizeBuckets * _alphaBuckets` draw calls
  // regardless of how many stars are on screen.
  static const int _sizeBuckets = 4;
  static const int _alphaBuckets = 6;
  static const int _bucketCount = _sizeBuckets * _alphaBuckets;
  static const double _maxStarSize = 3.5;

  /// Reused per bucket across frames; `_bucketLengths` is the live extent.
  final List<Float32List> _bucketPoints = List.generate(
    _bucketCount,
    (_) => Float32List(512),
    growable: false,
  );
  final Int32List _bucketLengths = Int32List(_bucketCount);
  final List<Paint> _bucketPaints = List.generate(_bucketCount, (i) {
    final sizeIndex = i ~/ _alphaBuckets;
    // Midpoint of each band, so quantisation error is symmetric. (Colour is
    // set per frame in render; only the dot diameter is fixed per bucket.)
    final diameter =
        ((sizeIndex + 0.5) / _sizeBuckets) * _maxStarSize * 2.0;
    return Paint()
      ..strokeWidth = diameter
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
  }, growable: false);

  void _push(int bucket, double x, double y) {
    var buf = _bucketPoints[bucket];
    final n = _bucketLengths[bucket];
    if (n + 2 > buf.length) {
      final grown = Float32List(buf.length * 2);
      grown.setRange(0, n, buf);
      _bucketPoints[bucket] = grown;
      buf = grown;
    }
    buf[n] = x;
    buf[n + 1] = y;
    _bucketLengths[bucket] = n + 2;
  }

  @override
  void render(Canvas canvas) {
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

    // Parallax shift depends only on the layer, so it is hoisted out of the
    // per-star loop (it used to allocate a Vector2 for every star).
    final cx = viewCenter.x;
    final cy = viewCenter.y;

    _bucketLengths.fillRange(0, _bucketCount, 0);

    for (final star in stars) {
      // depthFactor 1.0 = no shift, 0.0 = locked to viewport.
      final inv = 1.0 - star.depthFactor;
      final drawX = star.position.x + cx * inv;
      final drawY = star.position.y + cy * inv;

      if (drawX < minX || drawX > maxX || drawY < minY || drawY > maxY) {
        continue;
      }

      final alpha = star.currentOpacityAt(_time);
      if (alpha <= 0.02) continue;

      var alphaIndex = (alpha * _alphaBuckets).floor();
      if (alphaIndex >= _alphaBuckets) alphaIndex = _alphaBuckets - 1;
      var sizeIndex = ((star.size / _maxStarSize) * _sizeBuckets).floor();
      if (sizeIndex >= _sizeBuckets) sizeIndex = _sizeBuckets - 1;
      if (sizeIndex < 0) sizeIndex = 0;

      _push(sizeIndex * _alphaBuckets + alphaIndex, drawX, drawY);
    }

    for (var i = 0; i < _bucketCount; i++) {
      final n = _bucketLengths[i];
      if (n == 0) continue;
      final alphaIndex = i % _alphaBuckets;
      _bucketPaints[i].color = primaryColor.withValues(
        alpha: ((alphaIndex + 0.5) / _alphaBuckets).clamp(0.0, 1.0),
      );
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(_bucketPoints[i], 0, n),
        _bucketPaints[i],
      );
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

  /// 0.0 = pure background (doesn't move with camera), 1.0 = foreground
  /// (moves 1:1 with the world). Used for parallax depth.
  final double depthFactor;
  bool _rapidBlink = false;

  Star({
    required this.position,
    required this.size,
    required this.baseOpacity,
    required this.twinkleSpeed,
    required this.twinklePhase,
    this.depthFactor = 1.0,
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
