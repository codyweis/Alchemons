import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:alchemons/services/family_mastery_service.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_frame.dart' show BracketFramePainter;
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

// Everything on this screen is static between purchases: the tree is one
// CustomPaint behind a RepaintBoundary, nothing loops, and glows are layered
// translucent strokes rather than MaskFilter.blur. The only animation is the
// one-shot flourish that plays when a node is bought.
//
// The chrome around the tree is the app's bare look: tags, headings and
// buttons are flat fills with no frame. Only two things are lit from below:
// the node in focus and the button that buys it. Everything else that is
// "chosen" (the family, the equipped branch) says so with color alone, so
// the eye has one place to go. Progress is drawn once, on the tree itself:
// filled, checked gems and the sap running up to them.

const _background = Color(0xFF09090B);
const _rail = Color(0xFF0F0C0A);
const _border = Color(0xFF26262B);
const _panel = Color(0xFF151518);
const _text = Color(0xFFE6E2DA);
const _muted = Color(0xFF85827C);
const _dim = Color(0xFF46454A);
const _gold = Color(0xFFFFC94A);
const _danger = Color(0xFFC0574A);
const _selection = Color(0xFFFFE7B0);
const _bark = Color(0xFF211A13);
const _barkLight = Color(0xFF3B2F22);
const _barkGroove = Color(0xFF0E0B08);

const _nodeLabelWidth = 112.0;

const Map<CreatureFamily, String> _familyPortraits = {
  CreatureFamily.let: 'assets/images/creatures/common/LET02_waterlet.png',
  CreatureFamily.horn: 'assets/images/creatures/rare/HOR13_poisonhorn.png',
  CreatureFamily.kin: 'assets/images/creatures/legendary/KIN16_lightkin.png',
  CreatureFamily.mane: 'assets/images/creatures/uncommon/MAN03_earthmane.png',
  CreatureFamily.mask: 'assets/images/creatures/rare/MSK01_firemask.png',
  CreatureFamily.pip: 'assets/images/creatures/uncommon/PIP06_lavapip.png',
  CreatureFamily.wing: 'assets/images/creatures/legendary/WNG03_earthwing.png',
  CreatureFamily.mystic:
      'assets/images/creatures/mystic/MYS14_spiritmystic.png',
};

/// A family's survival mastery tree, bought with that family's own mastery
/// points (earned by clearing waves with it fielded), so the balance and the
/// prices come from [FamilyMasteryService] rather than the wallet.
class FamilyMasteryPanel extends StatefulWidget {
  const FamilyMasteryPanel({super.key, this.initialFamily});

  /// The family whose tree is shown first. Mane when not given.
  final CreatureFamily? initialFamily;

  @override
  State<FamilyMasteryPanel> createState() => _FamilyMasteryPanelState();
}

class _FamilyMasteryPanelState extends State<FamilyMasteryPanel>
    with SingleTickerProviderStateMixin {
  late CreatureFamily _family = widget.initialFamily ?? CreatureFamily.mane;
  final Map<CreatureFamily, String> _focusedNodes = {};
  String? _busyNodeId;
  String? _busyPathId;

  /// First tap on UPGRADE arms the node; the second tap buys it.
  String? _armedNodeId;
  Timer? _disarmTimer;

  String? _celebratedNodeId;
  late final AnimationController _celebration = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  bool get _busy => _busyNodeId != null || _busyPathId != null;

  @override
  void dispose() {
    _disarmTimer?.cancel();
    _celebration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyMasteryService>(
      builder: (context, mastery, _) {
        if (!mastery.isLoaded) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFFA726)),
          );
        }
        return _buildContent(mastery);
      },
    );
  }

  Widget _buildContent(FamilyMasteryService mastery) {
    final tree = FamilyMasteryCatalog.treeFor(_family);
    final owned = mastery.purchasedNodes(_family);
    final selectedPathId = mastery.selectedPathForFamily(_family);
    final focusedId =
        _focusedNodes[_family] ?? _defaultFocus(tree, owned, selectedPathId);
    final focused = FamilyMasteryCatalog.entryForNode(focusedId)!;
    final points = mastery.pointsFor(_family);
    bool canAfford(FamilyMasteryNodeDef node) => points >= node.cost;

    return ColoredBox(
      color: _background,
      child: Column(
        children: [
          _FamilyRail(
            key: const ValueKey('mastery-family-selector'),
            selected: _family,
            chassis: tree.chassis,
            points: points,
            progress: {
              for (final family in CreatureFamily.values)
                family:
                    mastery.purchasedNodes(family).length /
                    _nodeCount(FamilyMasteryCatalog.treeFor(family)),
            },
            onSelect: _selectFamily,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final layout = _TreeLayout.fit(
                  constraints.biggest,
                  tree.paths.length,
                );
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox.fromSize(
                    size: layout.size,
                    child: _MasteryTreeStage(
                      layout: layout,
                      tree: tree,
                      owned: owned,
                      selectedPathId: selectedPathId,
                      focusedNodeId: focusedId,
                      canAfford: canAfford,
                      celebration: _celebration,
                      celebratedNodeId: _celebratedNodeId,
                      busyPathId: _busyPathId,
                      onNodeTap: _focusNode,
                      onEquip: (path) => _selectPath(mastery, path),
                    ),
                  ),
                );
              },
            ),
          ),
          _UpgradeDock(
            key: const ValueKey('mastery-node-inspector'),
            family: _family,
            path: focused.path,
            node: focused.node,
            owned: owned,
            points: points,
            canAfford: canAfford(focused.node),
            armed: _armedNodeId == focused.node.id,
            purchasing: _busyNodeId == focused.node.id,
            blocked: _busy,
            onUpgrade: () => _onUpgradePressed(mastery, focused.node),
          ),
        ],
      ),
    );
  }

  /// Opens on the next thing worth buying: the equipped branch first, then
  /// any branch with an available node.
  String _defaultFocus(
    FamilyMasteryTreeDef tree,
    Set<String> owned,
    String? selectedPathId,
  ) {
    final ordered = [
      ...tree.paths.where((path) => path.id == selectedPathId),
      ...tree.paths.where((path) => path.id != selectedPathId),
    ];
    for (final path in ordered) {
      for (final node in path.nodes) {
        if (!owned.contains(node.id)) return node.id;
      }
    }
    return (ordered.first.nodes.last).id;
  }

  void _selectFamily(CreatureFamily family) {
    if (family == _family) return;
    setState(() {
      _family = family;
      _disarm();
    });
  }

  void _focusNode(FamilyMasteryNodeDef node) {
    setState(() {
      _focusedNodes[_family] = node.id;
      if (_armedNodeId != node.id) _disarm();
    });
  }

  void _disarm() {
    _disarmTimer?.cancel();
    _disarmTimer = null;
    _armedNodeId = null;
  }

  void _onUpgradePressed(
    FamilyMasteryService mastery,
    FamilyMasteryNodeDef node,
  ) {
    if (_busy) return;
    if (_armedNodeId != node.id) {
      setState(() {
        _disarm();
        _armedNodeId = node.id;
        _disarmTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(_disarm);
        });
      });
      return;
    }
    _purchaseNode(mastery, node);
  }

  Future<void> _purchaseNode(
    FamilyMasteryService mastery,
    FamilyMasteryNodeDef node,
  ) async {
    final family = _family;
    setState(() {
      _disarm();
      _busyNodeId = node.id;
    });
    final result = await mastery.purchaseNode(family: family, nodeId: node.id);
    if (!mounted) return;
    setState(() => _busyNodeId = null);

    if (result != FamilyMasteryPurchaseResult.purchased) {
      _showResult(_purchaseMessage(result, family), false);
      return;
    }

    // Like a tower upgrade: the flourish plays on the bought node and the
    // dock moves straight on to the next tier.
    final path = FamilyMasteryCatalog.entryForNode(node.id)!.path;
    final index = path.nodes.indexWhere((candidate) => candidate.id == node.id);
    setState(() {
      _celebratedNodeId = node.id;
      if (index + 1 < path.nodes.length && _family == family) {
        _focusedNodes[family] = path.nodes[index + 1].id;
      }
    });
    _celebration.forward(from: 0);
  }

  Future<void> _selectPath(
    FamilyMasteryService mastery,
    FamilyMasteryPathDef path,
  ) async {
    if (_busy) return;
    setState(() {
      _disarm();
      _busyPathId = path.id;
    });
    final result = await mastery.selectPath(family: _family, pathId: path.id);
    if (!mounted) return;
    setState(() => _busyPathId = null);
    _showResult(
      result == FamilyMasteryEquipResult.equipped
          ? '${path.name} is now active for every ${_family.displayName}.'
          : _equipMessage(result),
      result == FamilyMasteryEquipResult.equipped,
    );
  }

  void _showResult(String message, bool success) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success
              ? const Color(0xFF315C3B)
              : const Color(0xFF8B2D27),
        ),
      );
  }
}

// ── Family rail ────────────────────────────────────────────────────────────

/// The eight families, and under them the one in view: its name, what its
/// attack does, and the mastery it has to spend. Each medallion's ring is how
/// much of that family's tree is bought.
class _FamilyRail extends StatelessWidget {
  const _FamilyRail({
    super.key,
    required this.selected,
    required this.chassis,
    required this.points,
    required this.progress,
    required this.onSelect,
  });

  final CreatureFamily selected;
  final String chassis;

  /// [selected]'s mastery points to spend.
  final int points;
  final Map<CreatureFamily, double> progress;
  final ValueChanged<CreatureFamily> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: const BoxDecoration(
        color: _rail,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 60,
            child: Row(
              children: [
                for (final family in CreatureFamily.values)
                  Expanded(
                    child: _FamilyMedallion(
                      family: family,
                      selected: family == selected,
                      fraction: progress[family] ?? 0,
                      onTap: () => onSelect(family),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(child: _caption(context)),
                const SizedBox(width: 12),
                // What the family has to spend, up where the family is
                // chosen (the dock repeats it beside the price).
                // One line no taller than the caption's, so the tree below
                // keeps all its room.
                Text.rich(
                  key: const ValueKey('mastery-points-top'),
                  TextSpan(
                    children: [
                      TextSpan(
                        text: _formatNumber(points),
                        style: TextStyle(color: selected.color),
                      ),
                      const TextSpan(
                        text: ' MASTERY',
                        style: TextStyle(color: _muted, fontSize: 8.5),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: _text,
                    fontSize: 11.5,
                    height: 1.3,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _caption(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final base = DefaultTextStyle.of(context).style.merge(_captionStyle);
      // Room for the longest family's line at this width, so
      // switching families never moves the tree.
      return SizedBox(
        height: _roomFor(
          'caption',
          [
            for (final tree in kFamilyMasteryTrees)
              TextSpan(
                style: base,
                children: [_captionSpan(tree.family, tree.chassis)],
              ),
          ],
          width: constraints.maxWidth,
          scaler: MediaQuery.textScalerOf(context),
          maxLines: 2,
        ),
        child: Center(
          child: Text.rich(
            key: const ValueKey('mastery-family-caption'),
            _captionSpan(selected, chassis),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: _captionStyle,
          ),
        ),
      );
    },
  );
}

const _captionStyle = TextStyle(color: _muted, fontSize: 11.5, height: 1.3);

TextSpan _captionSpan(CreatureFamily family, String chassis) => TextSpan(
  children: [
    TextSpan(
      text: family.displayName.toUpperCase(),
      style: TextStyle(
        fontFamily: 'monospace',
        color: family.color,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.4,
      ),
    ),
    const TextSpan(text: '   '),
    TextSpan(text: chassis),
  ],
);

class _FamilyMedallion extends StatelessWidget {
  const _FamilyMedallion({
    required this.family,
    required this.selected,
    required this.fraction,
    required this.onTap,
  });

  final CreatureFamily family;
  final bool selected;
  final double fraction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = family.color;
    return Semantics(
      button: true,
      selected: selected,
      label: '${family.displayName} family mastery',
      child: GestureDetector(
        key: ValueKey('mastery-family-${family.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // The family in view is in full color; the rest are dimmed.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CustomPaint(
                painter: _ProgressRingPainter(
                  color: color,
                  fraction: fraction,
                  selected: selected,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          color.withValues(alpha: selected ? 0.42 : 0.14),
                          const Color(0xFF131316),
                        ],
                      ),
                    ),
                    child: _FamilyPortrait(
                      family: family,
                      dimmed: !selected,
                      padding: 3,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              family.code,
              style: TextStyle(
                fontFamily: 'monospace',
                color: selected ? color : _muted,
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilyPortrait extends StatelessWidget {
  const _FamilyPortrait({
    required this.family,
    required this.dimmed,
    required this.padding,
  });

  final CreatureFamily family;
  final bool dimmed;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final image = Padding(
      padding: EdgeInsets.all(padding),
      child: Image.asset(
        _familyPortraits[family]!,
        cacheWidth: 128,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) =>
            Icon(AppIcons.pets_rounded, color: family.color, size: 18),
      ),
    );
    if (!dimmed) return image;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.45, 0.25, 0.08, 0, 0, //
        0.18, 0.45, 0.08, 0, 0, //
        0.15, 0.2, 0.35, 0, 0, //
        0, 0, 0, 0.85, 0,
      ]),
      child: image,
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({
    required this.color,
    required this.fraction,
    required this.selected,
  });

  final Color color;
  final double fraction;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 1.5;
    if (selected) {
      canvas.drawCircle(
        center,
        radius + 1,
        Paint()..color = color.withValues(alpha: 0.12),
      );
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = selected ? const Color(0xFF3F3327) : const Color(0xFF272018),
    );
    if (fraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 2 * fraction.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: selected ? 1 : 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter old) =>
      old.color != color ||
      old.fraction != fraction ||
      old.selected != selected;
}

// ── Tree ───────────────────────────────────────────────────────────────────
//
// One stage holds the whole tree. A short trunk drops from the family rail
// and forks into one bough per branch; each bough passes behind its branch's
// heading and runs down through tiers I–III to the capstone. The rows space
// themselves to the room there is, so on a phone the capstones are on screen
// with everything else, and only a short screen scrolls.

/// Evenly spaced column centres, one per branch: sixths for three branches,
/// quarters for Mystic's two.
List<double> _columnsFor(double width, int count) => [
  for (var i = 0; i < count; i++) width * (2 * i + 1) / (2 * count),
];

List<int> _ownedTierCounts(FamilyMasteryTreeDef tree, Set<String> owned) => [
  for (final path in tree.paths)
    path.nodes.takeWhile((node) => owned.contains(node.id)).length,
];

int _nodeCount(FamilyMasteryTreeDef tree) =>
    tree.paths.fold(0, (sum, path) => sum + path.nodes.length);

class _TreeLayout {
  _TreeLayout._(this.size, this.columns, this.rows);

  /// Spaces the four tiers down [available]. When even the tightest spacing
  /// does not fit, the stage grows past it and scrolls.
  factory _TreeLayout.fit(Size available, int pathCount) {
    final step = ((available.height - _firstRow - _capstoneFoot) / 3)
        .clamp(_minRowStep, _maxRowStep)
        .toDouble();
    return _TreeLayout._(
      Size(
        available.width,
        math.max(available.height, _firstRow + step * 3 + _capstoneFoot),
      ),
      _columnsFor(available.width, pathCount),
      [for (var tier = 0; tier < 4; tier++) _firstRow + step * tier],
    );
  }

  static const forkY = 10.0;
  static const headTop = 16.0;
  static const headHeight = 34.0;
  static const headBottom = headTop + headHeight;

  /// Centre of the tier I gems: a gem's radius clear of the headings.
  static const _firstRow = headBottom + 16 + 25;

  /// From the capstone's centre to the stage's foot: half the star, then its
  /// price and its name.
  static const _capstoneFoot = 68.0;

  /// A gem, its price and its name, with a little air before the next gem.
  static const _minRowStep = 80.0;
  static const _maxRowStep = 124.0;

  final Size size;
  final List<double> columns;
  final List<double> rows;

  double get headWidth => math.min(size.width / columns.length - 10, 150);

  Offset get fork => Offset(size.width / 2, forkY);

  Offset node(int path, int tierIndex) =>
      Offset(columns[path], rows[tierIndex]);

  Path trunk() => Path()
    ..moveTo(fork.dx, 0)
    ..lineTo(fork.dx, fork.dy);

  /// From the fork out to [path]'s column and down behind its heading.
  Path bough(int path) {
    final x = columns[path];
    if ((x - fork.dx).abs() < 1) {
      return Path()
        ..moveTo(fork.dx, fork.dy)
        ..lineTo(x, headBottom);
    }
    final outward = x < fork.dx ? -1.0 : 1.0;
    return Path()
      ..moveTo(fork.dx, fork.dy)
      ..cubicTo(
        fork.dx + outward * 60,
        fork.dy + 1,
        x,
        fork.dy + 2,
        x,
        headTop + 12,
      )
      ..lineTo(x, headBottom);
  }

  /// The bough segment that leads INTO [tier] (1-based) of [path].
  Path segment(int path, int tier) {
    final end = node(path, tier - 1);
    if (tier == 1) {
      return Path()
        ..moveTo(end.dx, headBottom)
        ..lineTo(end.dx, end.dy);
    }
    final start = node(path, tier - 2);
    final drop = end.dy - start.dy;
    // A bough right of the middle sways mirror-wise to the ones beside it.
    final mirror = end.dx > size.width / 2 + 1 ? -1.0 : 1.0;
    final sway = (tier.isEven ? 9.0 : -9.0) * mirror;
    return Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        start.dx + sway,
        start.dy + drop * 0.35,
        end.dx - sway,
        end.dy - drop * 0.35,
        end.dx,
        end.dy,
      );
  }
}

class _MasteryTreeStage extends StatelessWidget {
  const _MasteryTreeStage({
    required this.layout,
    required this.tree,
    required this.owned,
    required this.selectedPathId,
    required this.focusedNodeId,
    required this.canAfford,
    required this.celebration,
    required this.celebratedNodeId,
    required this.busyPathId,
    required this.onNodeTap,
    required this.onEquip,
  });

  final _TreeLayout layout;
  final FamilyMasteryTreeDef tree;
  final Set<String> owned;
  final String? selectedPathId;
  final String focusedNodeId;
  final bool Function(FamilyMasteryNodeDef node) canAfford;
  final Animation<double> celebration;
  final String? celebratedNodeId;
  final String? busyPathId;
  final ValueChanged<FamilyMasteryNodeDef> onNodeTap;
  final ValueChanged<FamilyMasteryPathDef> onEquip;

  @override
  Widget build(BuildContext context) {
    final color = tree.family.color;
    final ownedTiers = _ownedTierCounts(tree, owned);
    final activeIndex = tree.paths.indexWhere(
      (path) => path.id == selectedPathId,
    );
    int? celebratedPath;
    int? celebratedTier;
    for (var p = 0; p < tree.paths.length; p++) {
      final index = tree.paths[p].nodes.indexWhere(
        (node) => node.id == celebratedNodeId,
      );
      if (index >= 0) {
        celebratedPath = p;
        celebratedTier = index + 1;
      }
    }

    return Stack(
      key: const ValueKey('family-skill-tree'),
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _TreePainter(
                layout: layout,
                family: tree.family,
                ownedTiers: ownedTiers,
                activeIndex: activeIndex < 0 ? null : activeIndex,
                celebration: celebration,
                celebratedPath: celebratedPath,
                celebratedTier: celebratedTier,
              ),
            ),
          ),
        ),
        for (var p = 0; p < tree.paths.length; p++)
          Positioned(
            left: layout.columns[p] - layout.headWidth / 2,
            top: _TreeLayout.headTop,
            width: layout.headWidth,
            height: _TreeLayout.headHeight,
            child: _BranchHead(
              path: tree.paths[p],
              color: color,
              unlocked: ownedTiers[p] > 0,
              active: p == activeIndex,
              equipping: busyPathId == tree.paths[p].id,
              // Brings the branch's next node into the dock and, when the
              // branch is bought but not worn, equips it.
              onTap: () {
                onNodeTap(
                  tree.paths[p].nodes[math.min(
                    ownedTiers[p],
                    tree.paths[p].nodes.length - 1,
                  )],
                );
                if (ownedTiers[p] > 0 && p != activeIndex) {
                  onEquip(tree.paths[p]);
                }
              },
            ),
          ),
        for (var p = 0; p < tree.paths.length; p++)
          for (var t = 0; t < tree.paths[p].nodes.length; t++)
            _positionedNode(
              tree.paths[p].nodes[t],
              layout.node(p, t),
              color: color,
              state: t < ownedTiers[p]
                  ? _NodeState.owned
                  : t == ownedTiers[p]
                  ? _NodeState.available
                  : _NodeState.locked,
              activeBranch: p == activeIndex,
            ),
      ],
    );
  }

  Widget _positionedNode(
    FamilyMasteryNodeDef node,
    Offset center, {
    required Color color,
    required _NodeState state,
    required bool activeBranch,
  }) {
    final size = _MasteryNode.gemSize(node);
    return Positioned(
      left: center.dx - _nodeLabelWidth / 2,
      top: center.dy - size / 2,
      width: _nodeLabelWidth,
      child: _MasteryNode(
        node: node,
        color: color,
        state: state,
        focused: node.id == focusedNodeId,
        affordable: canAfford(node),
        activeBranch: activeBranch,
        celebration: node.id == celebratedNodeId ? celebration : null,
        onTap: () => onNodeTap(node),
      ),
    );
  }
}

class _TreePainter extends CustomPainter {
  _TreePainter({
    required this.layout,
    required this.family,
    required this.ownedTiers,
    required this.activeIndex,
    required this.celebration,
    required this.celebratedPath,
    required this.celebratedTier,
  }) : super(repaint: celebration);

  final _TreeLayout layout;
  final CreatureFamily family;
  final List<int> ownedTiers;
  final int? activeIndex;
  final Animation<double> celebration;
  final int? celebratedPath;
  final int? celebratedTier;

  @override
  void paint(Canvas canvas, Size size) {
    final color = family.color;
    // The trunk runs up into the family rail; its rounded end and the fork's
    // glow stop at the stage's top edge rather than painting over the rail.
    canvas.clipRect(Offset.zero & size);

    final fork = layout.fork;
    final glowRadius = size.width * 0.5;
    canvas.drawCircle(
      fork,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: fork, radius: glowRadius)),
    );
    if (activeIndex != null) {
      final crown = layout.node(activeIndex!, 3);
      canvas.drawCircle(
        crown,
        110,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: 0.13), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: crown, radius: 110)),
      );
    }
    _paintDust(canvas, size, family.index * 31 + 7, 56);

    final trunk = layout.trunk();
    _paintBark(canvas, trunk, 14);
    if (ownedTiers.any((tiers) => tiers > 0)) {
      _paintSap(canvas, trunk, color, 1);
    }

    for (var p = 0; p < ownedTiers.length; p++) {
      final strength = activeIndex == null || p == activeIndex ? 1.0 : 0.42;
      final bough = layout.bough(p);
      _paintBark(canvas, bough, 12);
      if (ownedTiers[p] > 0) {
        _paintSap(canvas, bough, color, strength);
      } else {
        _paintDotted(canvas, bough, color.withValues(alpha: 0.35));
      }
      for (var tier = 1; tier <= 4; tier++) {
        final segment = layout.segment(p, tier);
        final lit = tier <= ownedTiers[p];
        _paintBark(canvas, segment, const [12.0, 10.0, 8.5, 7.5][tier - 1]);
        final sapColor = tier == 4 ? _gold : color;
        if (lit) {
          var fraction = 1.0;
          if (p == celebratedPath && tier == celebratedTier) {
            fraction = Curves.easeOutCubic.transform(
              (celebration.value / 0.55).clamp(0.0, 1.0),
            );
          }
          _paintSap(canvas, segment, sapColor, strength, fraction: fraction);
        } else if (tier == ownedTiers[p] + 1) {
          _paintDotted(canvas, segment, sapColor.withValues(alpha: 0.35));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TreePainter old) =>
      old.layout.size != layout.size ||
      old.family != family ||
      old.activeIndex != activeIndex ||
      old.celebratedPath != celebratedPath ||
      old.celebratedTier != celebratedTier ||
      !_sameList(old.ownedTiers, ownedTiers);
}

/// Deterministic star dust, so the sky does not shimmer between rebuilds.
void _paintDust(Canvas canvas, Size size, int seed, int count) {
  final random = math.Random(seed);
  final dust = Paint();
  for (var i = 0; i < count; i++) {
    final position = Offset(
      random.nextDouble() * size.width,
      random.nextDouble() * size.height,
    );
    dust.color = _text.withValues(alpha: 0.04 + random.nextDouble() * 0.16);
    canvas.drawCircle(position, 0.5 + random.nextDouble() * 0.9, dust);
  }
}

void _paintBark(Canvas canvas, Path path, double width) {
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  canvas.drawPath(
    path,
    paint
      ..color = _bark
      ..strokeWidth = width,
  );
  canvas.drawPath(
    path,
    paint
      ..color = _barkLight
      ..strokeWidth = width * 0.5,
  );
  canvas.drawPath(
    path,
    paint
      ..color = _barkGroove
      ..strokeWidth = width * 0.18,
  );
}

void _paintSap(
  Canvas canvas,
  Path path,
  Color color,
  double strength, {
  double fraction = 1,
}) {
  var lit = path;
  if (fraction < 1) {
    if (fraction <= 0) return;
    lit = Path();
    for (final metric in path.computeMetrics()) {
      lit.addPath(metric.extractPath(0, metric.length * fraction), Offset.zero);
    }
  }
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  canvas.drawPath(
    lit,
    paint
      ..strokeWidth = 12
      ..color = color.withValues(alpha: 0.09 * strength),
  );
  canvas.drawPath(
    lit,
    paint
      ..strokeWidth = 6
      ..color = color.withValues(alpha: 0.34 * strength),
  );
  canvas.drawPath(
    lit,
    paint
      ..strokeWidth = 2.2
      ..color = Color.lerp(
        color,
        Colors.white,
        0.45,
      )!.withValues(alpha: 0.95 * strength),
  );
}

void _paintDotted(Canvas canvas, Path path, Color color, {double gap = 6}) {
  final paint = Paint()..color = color;
  for (final metric in path.computeMetrics()) {
    for (var d = gap; d < metric.length - gap / 2; d += gap) {
      final tangent = metric.getTangentForOffset(d);
      if (tangent != null) canvas.drawCircle(tangent.position, 1.1, paint);
    }
  }
}

bool _sameList(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ── Branch heading ─────────────────────────────────────────────────────────

/// A branch's name over its bough, and where it is equipped: the equipped
/// branch says ACTIVE, a bought one that is not worn offers EQUIP, and a
/// locked one has only its name. A tap on any heading also brings that
/// branch's next node into the dock.
class _BranchHead extends StatelessWidget {
  const _BranchHead({
    required this.path,
    required this.color,
    required this.unlocked,
    required this.active,
    required this.equipping,
    required this.onTap,
  });

  final FamilyMasteryPathDef path;
  final Color color;
  final bool unlocked;
  final bool active;
  final bool equipping;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final equippable = unlocked && !active;
    const stateStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 7.5,
      height: 1,
      fontWeight: FontWeight.w900,
      letterSpacing: 1,
    );
    return Semantics(
      button: true,
      selected: active,
      label: active
          ? '${path.name}, active'
          : equippable
          ? 'Equip ${path.name}'
          : path.name,
      child: GestureDetector(
        key: ValueKey('branch-head-${path.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // A flat ink tag over the bough. The equipped branch is washed in the
        // family's color and says so, but it is not lit: the light belongs to
        // the node in focus and the button that buys it.
        child: Container(
          color: active
              ? Color.alphaBlend(color.withValues(alpha: 0.16), _panel)
              : _panel,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  path.name.toUpperCase(),
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: active
                        ? _text
                        : unlocked
                        ? const Color(0xFFB9AD99)
                        : _muted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              // The same height on every heading, empty on a locked one, so
              // every branch name sits at the same height.
              SizedBox(
                height: 12,
                child: active
                    ? Center(
                        child: Text(
                          'ACTIVE',
                          style: stateStyle.copyWith(color: color),
                        ),
                      )
                    : equippable
                    // A quiet wash in the family's color: something to
                    // press, but not the thing lit on this screen.
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          color: color.withValues(alpha: 0.18),
                          child: equipping
                              ? SizedBox(
                                  width: 8,
                                  height: 8,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: color,
                                  ),
                                )
                              : Text(
                                  'EQUIP',
                                  style: stateStyle.copyWith(color: color),
                                ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Nodes ──────────────────────────────────────────────────────────────────

enum _NodeState { owned, available, locked }

class _MasteryNode extends StatelessWidget {
  const _MasteryNode({
    required this.node,
    required this.color,
    required this.state,
    required this.focused,
    required this.affordable,
    required this.activeBranch,
    required this.celebration,
    required this.onTap,
  });

  final FamilyMasteryNodeDef node;
  final Color color;
  final _NodeState state;
  final bool focused;
  final bool affordable;
  final bool activeBranch;
  final Animation<double>? celebration;
  final VoidCallback onTap;

  static double gemSize(FamilyMasteryNodeDef node) => node.isCapstone ? 60 : 50;

  @override
  Widget build(BuildContext context) {
    final size = gemSize(node);
    final owned = state == _NodeState.owned;
    final gem = _Gem(
      node: node,
      color: color,
      state: state,
      focused: focused,
      affordable: affordable,
      activeBranch: activeBranch,
      size: size,
    );
    final animation = celebration;

    return Semantics(
      button: true,
      selected: focused,
      label: '${node.name}, tier ${node.tier}',
      child: GestureDetector(
        key: ValueKey('mastery-node-${node.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            SizedBox(
              width: size,
              height: size,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (animation == null)
                    gem
                  else
                    AnimatedBuilder(
                      animation: animation,
                      child: gem,
                      builder: (context, child) {
                        final t = animation.value;
                        final pop = t < 0.5 || t >= 1
                            ? 1.0
                            : 1 + 0.22 * math.sin((t - 0.5) / 0.5 * math.pi);
                        return CustomPaint(
                          foregroundPainter: _BurstPainter(
                            progress: ((t - 0.5) / 0.5).clamp(0.0, 1.0),
                            color: node.isCapstone ? _gold : color,
                          ),
                          child: Transform.scale(scale: pop, child: child),
                        );
                      },
                    ),
                  // Set a little clear of the rim: with no dark ring of its
                  // own, the badge would otherwise run into it.
                  if (owned)
                    Positioned(
                      top: -5,
                      right: -6,
                      child: _CheckBadge(
                        color: node.isCapstone ? _gold : color,
                      ),
                    ),
                ],
              ),
            ),
            // Only the next node to buy in a branch shows its price: a bought
            // node has its check and a locked one is simply dim. The slot is
            // kept either way, so names line up along a row.
            Transform.translate(
              offset: const Offset(0, -7),
              child: SizedBox(
                height: 15,
                child: state == _NodeState.available
                    ? Center(
                        child: _PriceTag(
                          node: node,
                          color: color,
                          affordable: affordable,
                        ),
                      )
                    : null,
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -4),
              // The node in focus has its name lit from below.
              child: CustomPaint(
                foregroundPainter: focused
                    ? BracketFramePainter(
                        color: node.isCapstone ? _gold : color,
                        strokeWidth: 1.6,
                      )
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  color: focused
                      ? Color.alphaBlend(
                          (node.isCapstone ? _gold : color).withValues(
                            alpha: 0.16,
                          ),
                          _background,
                        ).withValues(alpha: 0.9)
                      : _background.withValues(alpha: 0.82),
                  child: Text(
                    node.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: focused
                          ? _selection
                          : state == _NodeState.locked
                          ? _dim
                          : const Color(0xFFB9AD99),
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Gem extends StatelessWidget {
  const _Gem({
    required this.node,
    required this.color,
    required this.state,
    required this.focused,
    required this.affordable,
    required this.activeBranch,
    required this.size,
  });

  final FamilyMasteryNodeDef node;
  final Color color;
  final _NodeState state;
  final bool focused;
  final bool affordable;
  final bool activeBranch;
  final double size;

  @override
  Widget build(BuildContext context) {
    final gemColor = node.isCapstone ? _gold : color;
    final iconColor = switch (state) {
      _NodeState.owned => const Color(0xFFFFF6E6),
      _NodeState.available =>
        affordable ? gemColor : gemColor.withValues(alpha: 0.5),
      _NodeState.locked => const Color(0xFF3A404C),
    };
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GemPainter(
          color: gemColor,
          capstone: node.isCapstone,
          state: state,
          focused: focused,
          bright: affordable,
          glowing: state == _NodeState.owned && activeBranch,
        ),
        child: Center(
          child: Icon(
            _nodeIcon(node.id),
            size: node.isCapstone ? 24 : 20,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}

class _GemPainter extends CustomPainter {
  const _GemPainter({
    required this.color,
    required this.capstone,
    required this.state,
    required this.focused,
    required this.bright,
    required this.glowing,
  });

  final Color color;
  final bool capstone;
  final _NodeState state;
  final bool focused;
  final bool bright;
  final bool glowing;

  List<Offset> _vertices(Offset center, double radius) {
    if (capstone) {
      // Eight-pointed star: alternate outer and inner radii.
      return [
        for (var i = 0; i < 16; i++)
          center +
              Offset(
                    math.cos(-math.pi / 2 + i * math.pi / 8),
                    math.sin(-math.pi / 2 + i * math.pi / 8),
                  ) *
                  (i.isEven ? radius : radius * 0.8),
      ];
    }
    return [
      for (var i = 0; i < 6; i++)
        center +
            Offset(
                  math.cos(-math.pi / 2 + i * math.pi / 3),
                  math.sin(-math.pi / 2 + i * math.pi / 3),
                ) *
                radius,
    ];
  }

  Path _shape(List<Offset> points) => Path()..addPolygon(points, true);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 1;
    final outer = _vertices(center, radius);
    final shape = _shape(outer);
    final rect = Offset.zero & size;

    if (focused) _paintFocusLight(canvas, center, radius);

    if (glowing) {
      canvas.drawCircle(
        center,
        radius * 1.5,
        Paint()..color = color.withValues(alpha: 0.06),
      );
      canvas.drawCircle(
        center,
        radius * 1.22,
        Paint()..color = color.withValues(alpha: 0.12),
      );
    }

    final fill = Paint();
    switch (state) {
      case _NodeState.owned:
        fill.shader = RadialGradient(
          center: const Alignment(0, -0.35),
          radius: 0.8,
          colors: [
            Color.lerp(color, Colors.white, 0.18)!,
            Color.lerp(color, Colors.black, 0.25)!,
            Color.lerp(color, Colors.black, 0.62)!,
          ],
          stops: const [0, 0.5, 1],
        ).createShader(rect);
      case _NodeState.available:
        fill.shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2B231B), Color(0xFF110E0B)],
        ).createShader(rect);
      case _NodeState.locked:
        fill.color = const Color(0xFF110D0A);
    }
    canvas.drawPath(shape, fill);

    if (state != _NodeState.locked) {
      // Facets from the centre to each corner, plus a lit upper-left face.
      final facet = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.white.withValues(
          alpha: state == _NodeState.owned ? 0.16 : 0.05,
        );
      final step = capstone ? 2 : 1;
      for (var i = 0; i < outer.length; i += step) {
        canvas.drawLine(center, outer[i], facet);
      }
      final lastIndex = outer.length - step;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(outer[lastIndex].dx, outer[lastIndex].dy)
          ..lineTo(outer[0].dx, outer[0].dy)
          ..close(),
        Paint()
          ..color = Colors.white.withValues(
            alpha: state == _NodeState.owned ? 0.12 : 0.04,
          ),
      );
    }

    canvas.drawPath(
      _shape(_vertices(center, radius * 0.8)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.05),
    );

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    switch (state) {
      case _NodeState.owned:
        rim
          ..strokeWidth = 2.2
          ..color = Color.lerp(color, Colors.white, 0.35)!;
      case _NodeState.available:
        rim
          ..strokeWidth = 2
          ..color = color.withValues(alpha: bright ? 0.95 : 0.42);
      case _NodeState.locked:
        rim
          ..strokeWidth = 1.3
          ..color = capstone
              ? color.withValues(alpha: 0.32)
              : const Color(0xFF382D23);
    }
    canvas.drawPath(shape, rim);
  }

  /// The node in focus stands in its own light: a flattened pool on the
  /// ground beneath the gem and a glow rising off it behind the gem. Both
  /// are radial-gradient fills, no strokes and no blur.
  void _paintFocusLight(Canvas canvas, Offset center, double radius) {
    final hot = Color.lerp(color, Colors.white, 0.35)!;
    final foot = center + Offset(0, radius * 0.92);

    // The glow rising off the pool, brightest at the foot.
    final rise = radius * 1.9;
    canvas.drawCircle(
      foot,
      rise,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.34),
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(Rect.fromCircle(center: foot, radius: rise)),
    );

    // The pool itself, squashed flat onto the ground.
    final pool = radius * 2.1;
    canvas.save();
    canvas.translate(foot.dx, foot.dy);
    canvas.scale(1, 0.3);
    canvas.drawCircle(
      Offset.zero,
      pool,
      Paint()
        ..shader = RadialGradient(
          colors: [
            hot.withValues(alpha: 0.75),
            color.withValues(alpha: 0.32),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: pool)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GemPainter old) =>
      old.color != color ||
      old.capstone != capstone ||
      old.state != state ||
      old.focused != focused ||
      old.bright != bright ||
      old.glowing != glowing;
}

class _BurstPainter extends CustomPainter {
  const _BurstPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = size.center(Offset.zero);
    final fade = 1 - progress;
    final radius = size.width / 2 * (1 + progress * 1.1);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * fade + 0.5
        ..color = color.withValues(alpha: fade),
    );
    final spark = Paint()..color = color.withValues(alpha: fade);
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 + math.pi / 8;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * radius * 1.12,
        2 * fade + 0.5,
        spark,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) =>
      old.progress != progress || old.color != color;
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: const Icon(AppIcons.check_rounded, size: 9, color: _background),
    );
  }
}

/// A node's price in its family's mastery points, in the family's color —
/// one currency per tree, so no coin beside it.
class _PriceTag extends StatelessWidget {
  const _PriceTag({
    required this.node,
    required this.color,
    required this.affordable,
  });

  final FamilyMasteryNodeDef node;
  final Color color;
  final bool affordable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 2, 5, 2),
      color: Color.alphaBlend(
        color.withValues(alpha: affordable ? 0.12 : 0.05),
        _background,
      ),
      child: Text(
        _masteryPrice(node.cost),
        style: TextStyle(
          fontFamily: 'monospace',
          color: affordable ? color : _danger,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// ── Upgrade dock ───────────────────────────────────────────────────────────
//
// What the node in focus does and the way to buy it. The node itself is lit
// on the tree just above, so the dock repeats none of it: no gem, no tier
// track. Its height is fixed (room is kept for the longest description) so
// the tree above never moves as the focus does.

const _descriptionStyle = TextStyle(color: _muted, fontSize: 12, height: 1.3);

class _UpgradeDock extends StatelessWidget {
  const _UpgradeDock({
    super.key,
    required this.family,
    required this.path,
    required this.node,
    required this.owned,
    required this.points,
    required this.canAfford,
    required this.armed,
    required this.purchasing,
    required this.blocked,
    required this.onUpgrade,
  });

  final CreatureFamily family;
  final FamilyMasteryPathDef path;
  final FamilyMasteryNodeDef node;
  final Set<String> owned;

  /// The family's mastery points to spend.
  final int points;
  final bool canAfford;
  final bool armed;
  final bool purchasing;
  final bool blocked;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final color = family.color;
    final index = path.nodes.indexOf(node);
    final purchased = owned.contains(node.id);
    final previous = index > 0 ? path.nodes[index - 1] : null;
    final prerequisiteMet = previous == null || owned.contains(previous.id);
    final state = purchasing
        ? _UpgradeState.busy
        : purchased
        ? _UpgradeState.owned
        : !prerequisiteMet
        ? _UpgradeState.locked
        : !canAfford
        ? _UpgradeState.unaffordable
        : armed
        ? _UpgradeState.armed
        : _UpgradeState.ready;

    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        14,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(_rail, color, 0.1)!, _rail],
        ),
        border: Border(top: BorderSide(color: color.withValues(alpha: 0.3))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${path.name.toUpperCase()}  ·  ${path.role}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // What the family has to spend, beside what it is spent on.
              Text.rich(
                key: const ValueKey('mastery-points-balance'),
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${family.displayName.toUpperCase()} MASTERY ',
                    ),
                    TextSpan(
                      text: _formatNumber(points),
                      style: TextStyle(color: color),
                    ),
                  ],
                ),
                maxLines: 1,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: _muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Flexible(
                child: Text(
                  node.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: _text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (node.isCapstone) ...[
                const SizedBox(width: 6),
                const _StatusPill(label: 'CAPSTONE', color: _gold),
              ],
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final base = DefaultTextStyle.of(
                context,
              ).style.merge(_descriptionStyle);
              return SizedBox(
                height: _roomFor(
                  'description',
                  [
                    for (final tree in kFamilyMasteryTrees)
                      for (final path in tree.paths)
                        for (final node in path.nodes)
                          TextSpan(text: node.description, style: base),
                  ],
                  width: constraints.maxWidth,
                  scaler: MediaQuery.textScalerOf(context),
                  maxLines: 3,
                ),
                child: Text(
                  node.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: _descriptionStyle,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _UpgradeButton(
            key: ValueKey('unlock-${node.id}'),
            node: node,
            color: node.isCapstone ? _gold : color,
            state: state,
            prerequisiteName: previous?.name,
            onPressed:
                !blocked &&
                    (state == _UpgradeState.ready ||
                        state == _UpgradeState.armed)
                ? onUpgrade
                : null,
          ),
        ],
      ),
    );
  }
}

enum _UpgradeState { ready, armed, unaffordable, locked, owned, busy }

class _UpgradeButton extends StatelessWidget {
  const _UpgradeButton({
    super.key,
    required this.node,
    required this.color,
    required this.state,
    required this.prerequisiteName,
    required this.onPressed,
  });

  final FamilyMasteryNodeDef node;
  final Color color;
  final _UpgradeState state;
  final String? prerequisiteName;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // A square wash with no frame. While it is the thing to do (ready,
    // confirming, buying) it is lit from below; confirming burns brighter
    // and paler, its light rising up the whole face. The other states are
    // quiet, dim fills.
    final armed = state == _UpgradeState.armed;
    final (Color fill, Color? light, Color foreground) = switch (state) {
      _UpgradeState.ready => (color.withValues(alpha: 0.2), color, _text),
      _UpgradeState.armed => (
        color.withValues(alpha: 0.24),
        _selection,
        _selection,
      ),
      _UpgradeState.unaffordable => (
        _danger.withValues(alpha: 0.08),
        null,
        _danger,
      ),
      _UpgradeState.locked => (_panel, null, _dim),
      _UpgradeState.owned => (color.withValues(alpha: 0.1), null, color),
      _UpgradeState.busy => (color.withValues(alpha: 0.18), color, color),
    };

    final label = switch (state) {
      _UpgradeState.ready => 'UPGRADE',
      _UpgradeState.armed => 'TAP TO CONFIRM',
      _UpgradeState.unaffordable => 'NEED',
      _UpgradeState.locked => 'REQUIRES ${prerequisiteName?.toUpperCase()}',
      _UpgradeState.owned => 'UNLOCKED',
      _UpgradeState.busy => '',
    };
    final showPrice =
        state == _UpgradeState.ready ||
        state == _UpgradeState.armed ||
        state == _UpgradeState.unaffordable;

    final textStyle = TextStyle(
      fontFamily: 'monospace',
      color: foreground,
      fontSize: 13,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.3,
    );

    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: CustomPaint(
          foregroundPainter: light == null
              ? null
              : BracketFramePainter(
                  color: light,
                  strokeWidth: state == _UpgradeState.armed ? 1.6 : 1.3,
                ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: armed ? null : fill,
              gradient: armed
                  ? LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Color.lerp(
                          color,
                          _selection,
                          0.45,
                        )!.withValues(alpha: 0.55),
                        fill,
                      ],
                    )
                  : null,
            ),
            child: state == _UpgradeState.busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (state == _UpgradeState.locked) ...[
                            Icon(
                              AppIcons.lock_rounded,
                              size: 14,
                              color: foreground,
                            ),
                            const SizedBox(width: 6),
                          ] else if (state == _UpgradeState.owned) ...[
                            Icon(
                              AppIcons.check_rounded,
                              size: 15,
                              color: foreground,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(label, style: textStyle),
                          if (showPrice) ...[
                            const SizedBox(width: 12),
                            Text(
                              _masteryPrice(node.cost),
                              style: textStyle.copyWith(
                                fontSize: 15,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      color: color.withValues(alpha: 0.14),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          color: color,
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

// ── Icons & formatting ─────────────────────────────────────────────────────

IconData _nodeIcon(String nodeId) =>
    kFamilyMasteryNodeIcons[nodeId] ?? PhosphorIconsBold.sparkle;

/// One glyph per mastery node. Keyed by node id; a missing id falls back to a
/// sparkle, and a test pins that every catalog node has an entry.
@visibleForTesting
const Map<String, IconData> kFamilyMasteryNodeIcons = {
  // Mane
  'mane.assault.honed_pair': PhosphorIconsBold.sword,
  'mane.assault.crosscut': PhosphorIconsBold.scissors,
  'mane.assault.predator_step': PhosphorIconsBold.pawPrint,
  'mane.assault.blade_dance': PhosphorIconsBold.spiral,
  'mane.resonance.measured_cuts': PhosphorIconsBold.metronome,
  'mane.resonance.tempest_ring': PhosphorIconsBold.hurricane,
  'mane.resonance.crescendo': PhosphorIconsBold.musicNotes,
  'mane.resonance.encore': PhosphorIconsBold.starFour,
  'mane.limitless.far_throw': PhosphorIconsBold.arrowsOutSimple,
  'mane.limitless.overdraw': PhosphorIconsBold.trendUp,
  'mane.limitless.no_horizon': PhosphorIconsBold.infinity,
  'mane.limitless.endless_circuit': PhosphorIconsBold.circleDashed,
  // Let
  'let.assault.dense_core': PhosphorIconsBold.sphere,
  'let.assault.cratermaker': PhosphorIconsBold.hammer,
  'let.assault.dead_weight': PhosphorIconsBold.barbell,
  'let.assault.extinction_event': PhosphorIconsBold.meteor,
  'let.bombardment.deadfall': PhosphorIconsBold.arrowFatLinesDown,
  'let.bombardment.heavy_ordnance': PhosphorIconsBold.circlesThree,
  'let.bombardment.ranging_shots': PhosphorIconsBold.binoculars,
  'let.bombardment.skyreach': PhosphorIconsBold.globeHemisphereWest,
  'let.ground_zero.sighted': PhosphorIconsBold.eye,
  'let.ground_zero.walking_fire': PhosphorIconsBold.footprints,
  'let.ground_zero.called_shot': PhosphorIconsBold.megaphone,
  'let.ground_zero.fire_for_effect': PhosphorIconsBold.crosshair,
  // Pip
  'pip.assault.tight_grouping': PhosphorIconsBold.crosshair,
  'pip.assault.pin_cushion': PhosphorIconsBold.pushPin,
  'pip.assault.pluck_the_pins': PhosphorIconsBold.needle,
  'pip.assault.thousand_cuts': PhosphorIconsBold.asterisk,
  'pip.control.wide_spray': PhosphorIconsBold.arrowsOutLineHorizontal,
  'pip.control.three_fronts': PhosphorIconsBold.arrowsSplit,
  'pip.control.fourth_barrel': PhosphorIconsBold.plusCircle,
  'pip.control.scatter_storm': PhosphorIconsBold.polygon,
  'pip.salvo.spare_needle': PhosphorIconsBold.needle,
  'pip.salvo.double_load': PhosphorIconsBold.copySimple,
  'pip.salvo.full_quiver': PhosphorIconsBold.stack,
  'pip.salvo.perfect_salvo': PhosphorIconsBold.asteriskSimple,
  // Mask
  'mask.deathmask.grave_goods': PhosphorIconsBold.treasureChest,
  'mask.deathmask.open_grave': PhosphorIconsBold.shovel,
  'mask.deathmask.cold_ground': PhosphorIconsBold.snowflake,
  'mask.deathmask.necropolis': PhosphorIconsBold.buildings,
  'mask.rearm.spring_again': PhosphorIconsBold.arrowCounterClockwise,
  'mask.rearm.hair_trigger': PhosphorIconsBold.lightning,
  'mask.rearm.snap_shut': PhosphorIconsBold.scissors,
  'mask.rearm.held_ground': PhosphorIconsBold.anchor,
  'mask.contagion.carrier': PhosphorIconsBold.virus,
  'mask.contagion.spread': PhosphorIconsBold.shareNetwork,
  'mask.contagion.virulence': PhosphorIconsBold.flask,
  'mask.contagion.plague': PhosphorIconsBold.skull,
  // Horn
  'horn.bulwark.ironhead': PhosphorIconsBold.barbell,
  'horn.bulwark.weight_behind_it': PhosphorIconsBold.scales,
  'horn.bulwark.braced': PhosphorIconsBold.heartbeat,
  'horn.bulwark.anvil': PhosphorIconsBold.hammer,
  'horn.bastion.guarded_shot': PhosphorIconsBold.shield,
  'horn.bastion.bodyguard': PhosphorIconsBold.shieldChevron,
  'horn.bastion.shield_wall': PhosphorIconsBold.wall,
  'horn.bastion.last_stand': PhosphorIconsBold.shieldStar,
  'horn.juggernaut.second_effort': PhosphorIconsBold.arrowsClockwise,
  'horn.juggernaut.full_weight': PhosphorIconsBold.castleTurret,
  'horn.juggernaut.relentless': PhosphorIconsBold.rocketLaunch,
  'horn.juggernaut.second_front': PhosphorIconsBold.arrowsOutCardinal,
  // Wing
  'wing.burn_through.bore': PhosphorIconsBold.drop,
  'wing.burn_through.deeper': PhosphorIconsBold.arrowLineDown,
  'wing.burn_through.no_reprieve': PhosphorIconsBold.hourglass,
  'wing.burn_through.carry_through': PhosphorIconsBold.arrowsLeftRight,
  'wing.longshot.rangefinder': PhosphorIconsBold.crosshair,
  'wing.longshot.long_lens': PhosphorIconsBold.binoculars,
  'wing.longshot.standoff': PhosphorIconsBold.arrowsOutLineHorizontal,
  'wing.longshot.horizon': PhosphorIconsBold.sun,
  'wing.tracer.tracer_rounds': PhosphorIconsBold.scan,
  'wing.tracer.ranging_shots': PhosphorIconsBold.ruler,
  'wing.tracer.hot_barrel': PhosphorIconsBold.thermometerHot,
  'wing.tracer.live_feed': PhosphorIconsBold.broadcast,
  // Kin
  'kin.longline.extended_coil': PhosphorIconsBold.arrowsOutLineHorizontal,
  'kin.longline.full_span': PhosphorIconsBold.ruler,
  'kin.longline.deep_line': PhosphorIconsBold.chartLineUp,
  'kin.longline.crossfire': PhosphorIconsBold.arrowsHorizontal,
  'kin.conduction.live_current': PhosphorIconsBold.lightning,
  'kin.conduction.lifeline': PhosphorIconsBold.heartbeat,
  'kin.conduction.grounding': PhosphorIconsBold.plugs,
  'kin.conduction.transfusion': PhosphorIconsBold.drop,
  'kin.benediction.devotion': PhosphorIconsBold.hourglass,
  'kin.benediction.deep_reserves': PhosphorIconsBold.batteryFull,
  'kin.benediction.unbroken': PhosphorIconsBold.infinity,
  'kin.benediction.communion': PhosphorIconsBold.usersThree,
  // Mystic
  'mystic.quickening.quickening': PhosphorIconsBold.clockClockwise,
  'mystic.quickening.first_light': PhosphorIconsBold.sunHorizon,
  'mystic.quickening.weight_of_heaven': PhosphorIconsBold.scales,
  'mystic.quickening.relentless_sky': PhosphorIconsBold.cloudLightning,
  'mystic.firmament.native_air': PhosphorIconsBold.shieldCheck,
  'mystic.firmament.home_ground': PhosphorIconsBold.house,
  'mystic.firmament.tended': PhosphorIconsBold.plant,
  'mystic.firmament.sanctum': PhosphorIconsBold.sparkle,
};

/// The height the tallest of [spans] needs at [width]: the room to keep so
/// the text can change (another node, another family) without anything
/// around it moving. Remembered per width, since every rebuild asks again.
double _roomFor(
  String kind,
  Iterable<InlineSpan> spans, {
  required double width,
  required TextScaler scaler,
  required int maxLines,
}) {
  return _roomCache.putIfAbsent((kind, width, scaler), () {
    var tallest = 0.0;
    for (final span in spans) {
      final painter = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: maxLines,
      )..layout(maxWidth: width);
      tallest = math.max(tallest, painter.height);
      painter.dispose();
    }
    return tallest.ceilToDouble();
  });
}

final _roomCache = <(String, double, TextScaler), double>{};

/// A price in mastery points, in plain words: "75 MASTERY".
String _masteryPrice(int cost) => '${_formatNumber(cost)} MASTERY';

String _formatNumber(int value) {
  final source = value.toString();
  final result = StringBuffer();
  for (var i = 0; i < source.length; i++) {
    if (i > 0 && (source.length - i) % 3 == 0) result.write(',');
    result.write(source[i]);
  }
  return result.toString();
}

String _purchaseMessage(
  FamilyMasteryPurchaseResult result,
  CreatureFamily family,
) => switch (result) {
  FamilyMasteryPurchaseResult.purchased =>
    'Mastery unlocked for the entire family.',
  FamilyMasteryPurchaseResult.alreadyOwned =>
    'That mastery is already unlocked.',
  FamilyMasteryPurchaseResult.prerequisiteMissing =>
    'Unlock the previous tier first.',
  FamilyMasteryPurchaseResult.insufficientPoints =>
    'Not enough ${family.displayName} mastery.',
  FamilyMasteryPurchaseResult.wrongFamily =>
    'That mastery belongs to another family.',
  FamilyMasteryPurchaseResult.invalidNode => 'That mastery could not be found.',
};

String _equipMessage(FamilyMasteryEquipResult result) => switch (result) {
  FamilyMasteryEquipResult.equipped =>
    'This branch is now active for the entire family.',
  FamilyMasteryEquipResult.cleared => 'Family mastery branch cleared.',
  FamilyMasteryEquipResult.pathNotUnlocked =>
    'Unlock the first node before selecting this branch.',
  FamilyMasteryEquipResult.invalidPath => 'That branch could not be found.',
};
