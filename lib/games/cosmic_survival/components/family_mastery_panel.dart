import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:alchemons/services/family_mastery_service.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

// Everything on this screen is static between purchases: the tree is one
// CustomPaint behind a RepaintBoundary, nothing loops, and glows are layered
// translucent strokes rather than MaskFilter.blur. The only animation is the
// one-shot flourish that plays when a node is bought.

const _background = Color(0xFF080A0E);
const _rail = Color(0xFF0B0D12);
const _border = Color(0xFF252D3A);
const _text = Color(0xFFE8DCC8);
const _muted = Color(0xFF8A7B6A);
const _dim = Color(0xFF4A3F35);
const _silver = Color(0xFFC0C0C0);
const _gold = Color(0xFFFFC94A);
const _danger = Color(0xFFC0574A);
const _selection = Color(0xFFFFE7B0);
const _bark = Color(0xFF211A13);
const _barkLight = Color(0xFF3B2F22);
const _barkGroove = Color(0xFF0E0B08);

// The tree is always taller than its viewport. Base Command collapses its
// header when this tab scrolls, and a tree that fit its (now larger) viewport
// could no longer scroll back up to reveal it.
const _minStageHeight = 440.0;
const _maxStageHeight = 760.0;
const _minScrollExtent = 80.0;
const _bannerHeight = 56.0;
const _nodeLabelWidth = 112.0;

const _tierNumerals = ['I', 'II', 'III'];

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

class FamilyMasteryPanel extends StatefulWidget {
  const FamilyMasteryPanel({
    super.key,
    required this.silverBalance,
    required this.goldBalance,
    required this.onCurrencyChanged,
    this.compact = false,
    this.initialFamily,
  });

  final int silverBalance;
  final int goldBalance;
  final Future<void> Function() onCurrencyChanged;

  /// Set while the host has scrolled its own chrome away: the family selector
  /// tucks away with it, leaving the docked tree crown at the top.
  final bool compact;

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

    return ColoredBox(
      color: _background,
      child: Column(
        children: [
          _CollapsibleSection(
            key: const ValueKey('mastery-family-selector'),
            visible: !widget.compact,
            child: _FamilySelector(
              selected: _family,
              progress: {
                for (final family in CreatureFamily.values)
                  family: mastery.purchasedNodes(family).length,
              },
              onSelect: _selectFamily,
            ),
          ),
          _TreeCrown(
            tree: tree,
            owned: owned,
            selectedPathId: selectedPathId,
            busyPathId: _busyPathId,
            onBannerFocus: _focusNode,
            onPathSelect: (path) => _selectPath(mastery, path),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stageHeight = math.max(
                  (constraints.maxWidth * 1.15).clamp(
                    _minStageHeight,
                    _maxStageHeight,
                  ),
                  constraints.maxHeight + _minScrollExtent,
                );
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                    height: stageHeight,
                    child: _MasteryTreeStage(
                      tree: tree,
                      owned: owned,
                      selectedPathId: selectedPathId,
                      focusedNodeId: focusedId,
                      canAfford: _canAfford,
                      celebration: _celebration,
                      celebratedNodeId: _celebratedNodeId,
                      onNodeTap: _focusNode,
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
            activePath: selectedPathId == focused.path.id,
            canAfford: _canAfford(focused.node),
            armed: _armedNodeId == focused.node.id,
            purchasing: _busyNodeId == focused.node.id,
            selectingPath: _busyPathId == focused.path.id,
            blocked: _busy,
            onUpgrade: () => _onUpgradePressed(mastery, focused.node),
            onEquip: () => _selectPath(mastery, focused.path),
          ),
        ],
      ),
    );
  }

  bool _canAfford(FamilyMasteryNodeDef node) =>
      node.currency == FamilyMasteryCurrency.gold
      ? widget.goldBalance >= node.cost
      : widget.silverBalance >= node.cost;

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
    await widget.onCurrencyChanged();
    if (!mounted) return;
    setState(() => _busyNodeId = null);

    if (result != FamilyMasteryPurchaseResult.purchased) {
      _showResult(_purchaseMessage(result), false);
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

// ── Family selector ────────────────────────────────────────────────────────

class _FamilySelector extends StatelessWidget {
  const _FamilySelector({
    required this.selected,
    required this.progress,
    required this.onSelect,
  });

  final CreatureFamily selected;
  final Map<CreatureFamily, int> progress;
  final ValueChanged<CreatureFamily> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: _rail,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          for (final family in CreatureFamily.values)
            Expanded(
              child: _FamilyMedallion(
                family: family,
                selected: family == selected,
                owned: progress[family] ?? 0,
                onTap: () => onSelect(family),
              ),
            ),
        ],
      ),
    );
  }
}

class _FamilyMedallion extends StatelessWidget {
  const _FamilyMedallion({
    required this.family,
    required this.selected,
    required this.owned,
    required this.onTap,
  });

  final CreatureFamily family;
  final bool selected;
  final int owned;
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CustomPaint(
                painter: _ProgressRingPainter(
                  color: color,
                  fraction: owned / 12,
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
                          const Color(0xFF0E1117),
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
        ..color = selected ? const Color(0xFF2E3644) : const Color(0xFF1C222C),
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
// The tree is split in two. The crown (family root, title, trunk and the three
// branch banners) is docked above the scroll view. The body (boughs running
// down through tiers I–III to the capstones) scrolls beneath it. Each bough
// leaves the crown at the foot of its banner column, and the body picks it up
// at its top edge, so the two read as one tree.

const _crownHeight = 146.0;

List<double> _columnsFor(double width) => [width / 6, width / 2, width * 5 / 6];

List<int> _ownedTierCounts(FamilyMasteryTreeDef tree, Set<String> owned) => [
  for (final path in tree.paths)
    path.nodes.takeWhile((node) => owned.contains(node.id)).length,
];

class _CrownLayout {
  _CrownLayout(this.width)
    : columns = _columnsFor(width),
      root = Offset(width / 2, rootY),
      fork = Offset(width / 2, forkY);

  static const rootRadius = 26.0;
  static const rootY = 36.0;
  static const forkY = rootY + rootRadius + 12;
  static const bannerTop = forkY + 10;

  final double width;
  final List<double> columns;
  final Offset root;
  final Offset fork;

  Path trunk() => Path()
    ..moveTo(root.dx, root.dy + rootRadius - 3)
    ..lineTo(fork.dx, fork.dy);

  /// From the fork out to [path]'s column and down to the crown's bottom edge.
  Path bough(int path) {
    final x = columns[path];
    if (path == 1) {
      return Path()
        ..moveTo(fork.dx, fork.dy)
        ..lineTo(x, _crownHeight);
    }
    final outward = path == 0 ? -1.0 : 1.0;
    return Path()
      ..moveTo(fork.dx, fork.dy)
      ..cubicTo(
        fork.dx + outward * 60,
        fork.dy + 1,
        x,
        fork.dy + 2,
        x,
        bannerTop + 14,
      )
      ..lineTo(x, _crownHeight);
  }
}

/// Scrolling body geometry: tier rows from the top edge down to the capstones.
class _TreeLayout {
  _TreeLayout(this.size) : columns = _columnsFor(size.width) {
    const first = 54.0;
    final capstone = size.height - 72;
    final step = (capstone - first) / 3;
    rows = [for (var tier = 0; tier < 4; tier++) first + step * tier];
  }

  final Size size;
  final List<double> columns;
  late final List<double> rows;

  Offset node(int path, int tierIndex) =>
      Offset(columns[path], rows[tierIndex]);

  /// The bough segment that leads INTO [tier] (1-based) of [path].
  Path segment(int path, int tier) {
    final end = node(path, tier - 1);
    if (tier == 1) {
      return Path()
        ..moveTo(end.dx, 0)
        ..lineTo(end.dx, end.dy);
    }
    final start = node(path, tier - 2);
    final drop = end.dy - start.dy;
    final sway = (tier.isEven ? 9.0 : -9.0) * (path == 2 ? -1 : 1);
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

class _TreeCrown extends StatelessWidget {
  const _TreeCrown({
    required this.tree,
    required this.owned,
    required this.selectedPathId,
    required this.busyPathId,
    required this.onBannerFocus,
    required this.onPathSelect,
  });

  final FamilyMasteryTreeDef tree;
  final Set<String> owned;
  final String? selectedPathId;
  final String? busyPathId;
  final ValueChanged<FamilyMasteryNodeDef> onBannerFocus;
  final ValueChanged<FamilyMasteryPathDef> onPathSelect;

  @override
  Widget build(BuildContext context) {
    final family = tree.family;
    final color = family.color;
    final ownedTiers = _ownedTierCounts(tree, owned);
    final activeIndex = tree.paths.indexWhere(
      (path) => path.id == selectedPathId,
    );

    return SizedBox(
      key: const ValueKey('family-mastery-crown'),
      height: _crownHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _CrownLayout(constraints.maxWidth);
          final bannerWidth = layout.width / 3 - 10;
          const rootRadius = _CrownLayout.rootRadius;
          final sideWidth = layout.width / 2 - rootRadius - 12;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _CrownPainter(
                      layout: layout,
                      family: family,
                      ownedTiers: ownedTiers,
                      activeIndex: activeIndex < 0 ? null : activeIndex,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: layout.root.dx - rootRadius,
                top: layout.root.dy - rootRadius,
                width: rootRadius * 2,
                height: rootRadius * 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        color.withValues(alpha: 0.4),
                        const Color(0xFF0E1117),
                      ],
                    ),
                    border: Border.all(color: color, width: 2),
                  ),
                  child: ClipOval(
                    child: _FamilyPortrait(
                      family: family,
                      dimmed: false,
                      padding: 4,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                width: sideWidth,
                top: layout.root.dy - 28,
                height: 56,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${family.displayName.toUpperCase()} MASTERY',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: _text,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${owned.length}/12',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: color,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _StatusPill(
                              label: 'ALL ${family.displayName.toUpperCase()}S',
                              color: color,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 0,
                width: sideWidth,
                top: layout.root.dy - 28,
                height: 56,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'BASE ATTACK',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: color.withValues(alpha: 0.85),
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tree.chassis,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 9.5,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              for (var p = 0; p < tree.paths.length; p++)
                Positioned(
                  left: layout.columns[p] - bannerWidth / 2,
                  top: _CrownLayout.bannerTop,
                  width: bannerWidth,
                  height: _bannerHeight,
                  child: _BranchBanner(
                    path: tree.paths[p],
                    color: color,
                    ownedTiers: ownedTiers[p],
                    active: p == activeIndex,
                    selecting: busyPathId == tree.paths[p].id,
                    onEquip: () => onPathSelect(tree.paths[p]),
                    onTap: () {
                      final path = tree.paths[p];
                      onBannerFocus(
                        path.nodes[math.min(
                          ownedTiers[p],
                          path.nodes.length - 1,
                        )],
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MasteryTreeStage extends StatelessWidget {
  const _MasteryTreeStage({
    required this.tree,
    required this.owned,
    required this.selectedPathId,
    required this.focusedNodeId,
    required this.canAfford,
    required this.celebration,
    required this.celebratedNodeId,
    required this.onNodeTap,
  });

  final FamilyMasteryTreeDef tree;
  final Set<String> owned;
  final String? selectedPathId;
  final String focusedNodeId;
  final bool Function(FamilyMasteryNodeDef node) canAfford;
  final Animation<double> celebration;
  final String? celebratedNodeId;
  final ValueChanged<FamilyMasteryNodeDef> onNodeTap;

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

    return LayoutBuilder(
      key: const ValueKey('family-skill-tree'),
      builder: (context, constraints) {
        final layout = _TreeLayout(constraints.biggest);
        return Stack(
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
      },
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

class _CrownPainter extends CustomPainter {
  const _CrownPainter({
    required this.layout,
    required this.family,
    required this.ownedTiers,
    required this.activeIndex,
  });

  final _CrownLayout layout;
  final CreatureFamily family;
  final List<int> ownedTiers;
  final int? activeIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final color = family.color;
    final root = layout.root;

    final glowRadius = size.width * 0.5;
    canvas.drawCircle(
      root,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: root, radius: glowRadius)),
    );
    _paintDust(canvas, size, family.index * 13 + 3, 16);

    // Transmutation circle behind the root.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    ring.color = color.withValues(alpha: 0.26);
    canvas.drawCircle(root, 32, ring);
    ring.color = color.withValues(alpha: 0.13);
    canvas.drawCircle(root, 38, ring);
    for (var i = 0; i < 24; i++) {
      final angle = i * math.pi / 12;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        root + direction * (i.isEven ? 38.0 : 39.5),
        root + direction * 42,
        ring,
      );
    }
    final triangle = Path();
    for (var i = 0; i < 3; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / 3;
      final point = root + Offset(math.cos(angle), math.sin(angle)) * 38;
      i == 0
          ? triangle.moveTo(point.dx, point.dy)
          : triangle.lineTo(point.dx, point.dy);
    }
    ring.color = color.withValues(alpha: 0.09);
    canvas.drawPath(triangle..close(), ring);

    final trunk = layout.trunk();
    _paintBark(canvas, trunk, 14);
    if (ownedTiers.any((tiers) => tiers > 0)) {
      _paintSap(canvas, trunk, color, 1);
    }

    for (var p = 0; p < 3; p++) {
      final bough = layout.bough(p);
      final lit = ownedTiers[p] > 0;
      final strength = activeIndex == null || p == activeIndex ? 1.0 : 0.42;
      _paintBark(canvas, bough, 12);
      if (lit) {
        _paintSap(canvas, bough, color, strength);
      } else {
        _paintDotted(canvas, bough, color.withValues(alpha: 0.35));
      }
    }

    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()..color = _border.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(covariant _CrownPainter old) =>
      old.layout.width != layout.width ||
      old.family != family ||
      old.activeIndex != activeIndex ||
      !_sameList(old.ownedTiers, ownedTiers);
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
    _paintDust(canvas, size, family.index * 31 + 7, 44);

    for (var p = 0; p < 3; p++) {
      final strength = activeIndex == null || p == activeIndex ? 1.0 : 0.42;
      for (var tier = 1; tier <= 4; tier++) {
        final segment = layout.segment(p, tier);
        final lit = tier <= ownedTiers[p];
        _paintBark(canvas, segment, const [12.0, 10.0, 8.5, 7.5][tier - 1]);
        if (tier > 1) {
          _paintTwig(canvas, segment, p, tier, lit ? color : null, strength);
        }
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

void _paintTwig(
  Canvas canvas,
  Path segment,
  int path,
  int tier,
  Color? litColor,
  double strength,
) {
  final metric = segment.computeMetrics().first;
  final tangent = metric.getTangentForOffset(metric.length * 0.52);
  if (tangent == null) return;
  final side = (tier.isEven ? 1.0 : -1.0) * (path == 0 ? -1 : 1);
  final normal = Offset(-tangent.vector.dy, tangent.vector.dx) * side;
  final base = tangent.position;
  final tip = base + normal * 15 + const Offset(0, -7);
  final twig = Path()
    ..moveTo(base.dx, base.dy)
    ..quadraticBezierTo(
      base.dx + normal.dx * 9,
      base.dy + normal.dy * 9 + 2,
      tip.dx,
      tip.dy,
    );
  canvas.drawPath(
    twig,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2
      ..color = _barkLight,
  );
  canvas.save();
  canvas.translate(tip.dx, tip.dy);
  canvas.rotate(math.atan2(tip.dy - base.dy, tip.dx - base.dx));
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(3, 0), width: 11, height: 5),
    Paint()
      ..color = litColor == null
          ? const Color(0xFF26261E)
          : litColor.withValues(alpha: 0.8 * strength),
  );
  canvas.drawLine(
    const Offset(-2, 0),
    const Offset(8, 0),
    Paint()
      ..strokeWidth = 0.8
      ..color = _barkGroove.withValues(alpha: 0.7),
  );
  canvas.restore();
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

class _CollapsibleSection extends StatelessWidget {
  const _CollapsibleSection({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedAlign(
        alignment: Alignment.bottomCenter,
        heightFactor: visible ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: IgnorePointer(
          ignoring: !visible,
          child: ExcludeSemantics(excluding: !visible, child: child),
        ),
      ),
    );
  }
}

// ── Branch banner ──────────────────────────────────────────────────────────

class _BranchBanner extends StatelessWidget {
  const _BranchBanner({
    required this.path,
    required this.color,
    required this.ownedTiers,
    required this.active,
    required this.selecting,
    required this.onEquip,
    required this.onTap,
  });

  final FamilyMasteryPathDef path;
  final Color color;
  final int ownedTiers;
  final bool active;
  final bool selecting;
  final VoidCallback onEquip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unlocked = ownedTiers > 0;
    final equippable = unlocked && !active;
    // The whole banner is the button: an owned, unequipped branch equips on
    // tap; any other banner just focuses its next node.
    return Semantics(
      button: true,
      label: equippable ? 'Equip ${path.name}' : path.name,
      child: GestureDetector(
        key: ValueKey(
          equippable ? 'select-${path.id}' : 'branch-banner-${path.id}',
        ),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          onTap();
          if (equippable && !selecting) onEquip();
        },
        child: CustomPaint(
          painter: _BannerPainter(color: color, active: active),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _pathIcon(path.id),
                      size: 11,
                      color: active ? color : _muted,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          path.name.toUpperCase(),
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: active ? _text : const Color(0xFFB9AD99),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TierDiamonds(owned: ownedTiers, color: color),
                    const SizedBox(width: 6),
                    if (active)
                      _StatusPill(label: 'ACTIVE', color: color)
                    else if (unlocked)
                      _EquipChip(color: color, busy: selecting)
                    else
                      const Text(
                        'LOCKED',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: _dim,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerPainter extends CustomPainter {
  const _BannerPainter({required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const notch = 7.0;
    final shape = Path()
      ..moveTo(4, 0)
      ..lineTo(w - 4, 0)
      ..quadraticBezierTo(w, 0, w, 4)
      ..lineTo(w, h - notch)
      ..lineTo(w / 2 + 9, h - notch)
      ..lineTo(w / 2, h)
      ..lineTo(w / 2 - 9, h - notch)
      ..lineTo(0, h - notch)
      ..lineTo(0, 4)
      ..quadraticBezierTo(0, 0, 4, 0)
      ..close();
    canvas.drawPath(
      shape,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: active
              ? [color.withValues(alpha: 0.3), const Color(0xFF11141B)]
              : const [Color(0xFF181C25), Color(0xFF0E1117)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 1.4 : 1
        ..color = active ? color.withValues(alpha: 0.85) : _border,
    );
    if (active) {
      canvas.drawLine(
        const Offset(6, 1.5),
        Offset(w - 6, 1.5),
        Paint()
          ..strokeWidth = 2
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BannerPainter old) =>
      old.color != color || old.active != active;
}

class _TierDiamonds extends StatelessWidget {
  const _TierDiamonds({required this.owned, required this.color});

  final int owned;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: 5.5,
                height: 5.5,
                decoration: BoxDecoration(
                  color: i < owned ? (i == 3 ? _gold : color) : null,
                  border: Border.all(
                    color: i < owned ? Colors.transparent : _muted,
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EquipChip extends StatelessWidget {
  const _EquipChip({required this.color, required this.busy});

  final Color color;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: busy
          ? SizedBox(
              width: 8,
              height: 8,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
            )
          : Text(
              'EQUIP',
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
                  if (owned)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: _Badge(
                        icon: AppIcons.check_rounded,
                        color: node.isCapstone ? _gold : color,
                        filled: true,
                      ),
                    )
                  else if (state == _NodeState.locked)
                    const Positioned(
                      bottom: 2,
                      right: -3,
                      child: _Badge(
                        icon: AppIcons.lock_rounded,
                        color: _muted,
                        filled: false,
                      ),
                    ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -7),
              child: owned
                  ? _TierTag(node: node, color: color)
                  : _PriceTag(
                      node: node,
                      affordable: affordable,
                      dim: state == _NodeState.locked,
                    ),
            ),
            Transform.translate(
              offset: const Offset(0, -4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: _background.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(3),
                ),
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
    this.iconSize,
  });

  final FamilyMasteryNodeDef node;
  final Color color;
  final _NodeState state;
  final bool focused;
  final bool affordable;
  final bool activeBranch;
  final double size;
  final double? iconSize;

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
            size: iconSize ?? (node.isCapstone ? 24 : 20),
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
          colors: [Color(0xFF1F2532), Color(0xFF0C0F14)],
        ).createShader(rect);
      case _NodeState.locked:
        fill.color = const Color(0xFF0C0E13);
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
              : const Color(0xFF2A303B);
    }
    canvas.drawPath(shape, rim);

    if (focused) {
      // Tower-defense style selection brackets.
      final box = rect.inflate(5);
      final arm = size.width * 0.26;
      final bracket = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.square
        ..color = _selection;
      for (final (corner, dx, dy) in [
        (box.topLeft, 1.0, 1.0),
        (box.topRight, -1.0, 1.0),
        (box.bottomLeft, 1.0, -1.0),
        (box.bottomRight, -1.0, -1.0),
      ]) {
        canvas.drawPath(
          Path()
            ..moveTo(corner.dx + dx * arm, corner.dy)
            ..lineTo(corner.dx, corner.dy)
            ..lineTo(corner.dx, corner.dy + dy * arm),
          bracket,
        );
      }
    }
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

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color, required this.filled});

  final IconData icon;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : const Color(0xFF0B0D12),
        border: Border.all(
          color: filled ? const Color(0xFF0B0D12) : _border,
          width: 1.5,
        ),
      ),
      child: Icon(
        icon,
        size: 9,
        color: filled ? const Color(0xFF0B0D12) : color,
      ),
    );
  }
}

class _PriceTag extends StatelessWidget {
  const _PriceTag({
    required this.node,
    required this.affordable,
    required this.dim,
  });

  final FamilyMasteryNodeDef node;
  final bool affordable;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final gold = node.currency == FamilyMasteryCurrency.gold;
    final currencyColor = gold ? _gold : _silver;
    final textColor = dim
        ? _dim
        : affordable
        ? currencyColor
        : _danger;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 2, 6, 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0C10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: dim
              ? _border
              : currencyColor.withValues(alpha: affordable ? 0.65 : 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: dim ? 0.45 : 1,
            child: CoinIcon(
              kind: gold ? CoinKind.gold : CoinKind.silver,
              size: 9,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            _compactNumber(node.cost),
            style: TextStyle(
              fontFamily: 'monospace',
              color: textColor,
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TierTag extends StatelessWidget {
  const _TierTag({required this.node, required this.color});

  final FamilyMasteryNodeDef node;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tagColor = node.isCapstone ? _gold : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0C10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tagColor.withValues(alpha: 0.55)),
      ),
      child: _TierGlyph(tier: node.tier, color: tagColor, size: 8.5),
    );
  }
}

// ── Upgrade dock ───────────────────────────────────────────────────────────

class _UpgradeDock extends StatelessWidget {
  const _UpgradeDock({
    super.key,
    required this.family,
    required this.path,
    required this.node,
    required this.owned,
    required this.activePath,
    required this.canAfford,
    required this.armed,
    required this.purchasing,
    required this.selectingPath,
    required this.blocked,
    required this.onUpgrade,
    required this.onEquip,
  });

  final CreatureFamily family;
  final FamilyMasteryPathDef path;
  final FamilyMasteryNodeDef node;
  final Set<String> owned;
  final bool activePath;
  final bool canAfford;
  final bool armed;
  final bool purchasing;
  final bool selectingPath;
  final bool blocked;
  final VoidCallback onUpgrade;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    final color = family.color;
    final index = path.nodes.indexOf(node);
    final purchased = owned.contains(node.id);
    final previous = index > 0 ? path.nodes[index - 1] : null;
    final prerequisiteMet = previous == null || owned.contains(previous.id);
    final pathUnlocked = owned.contains(path.nodes.first.id);
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
    final nodeState = purchased
        ? _NodeState.owned
        : prerequisiteMet
        ? _NodeState.available
        : _NodeState.locked;

    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        12,
        14,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(_rail, color, 0.1)!, _rail],
        ),
        border: Border(
          top: BorderSide(color: color.withValues(alpha: 0.55), width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Gem(
                node: node,
                color: color,
                state: nodeState,
                focused: false,
                affordable: canAfford,
                activeBranch: activePath,
                size: 54,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
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
                    _TierTrack(
                      path: path,
                      owned: owned,
                      focusedIndex: index,
                      color: color,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 47,
            child: Text(
              node.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 12, height: 1.3),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (activePath) ...[
                _ActiveCrest(color: color),
                const SizedBox(width: 8),
              ] else if (pathUnlocked) ...[
                _EquipButton(
                  key: ValueKey('equip-${path.id}'),
                  color: color,
                  busy: selectingPath,
                  onTap: blocked ? null : onEquip,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _UpgradeButton(
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TierTrack extends StatelessWidget {
  const _TierTrack({
    required this.path,
    required this.owned,
    required this.focusedIndex,
    required this.color,
  });

  final FamilyMasteryPathDef path;
  final Set<String> owned;
  final int focusedIndex;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < path.nodes.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 15,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: owned.contains(path.nodes[i].id)
                    ? (i == 3 ? _gold : color).withValues(alpha: 0.85)
                    : const Color(0xFF12151B),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: i == focusedIndex ? _selection : _border,
                  width: i == focusedIndex ? 1.5 : 1,
                ),
              ),
              child: _TierGlyph(
                tier: i + 1,
                size: 8,
                color: owned.contains(path.nodes[i].id)
                    ? const Color(0xFF0B0D12)
                    : _muted,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Roman numeral for tiers I–III and a star for the capstone. The star is an
/// icon because the monospace fonts on device do not all carry ★.
class _TierGlyph extends StatelessWidget {
  const _TierGlyph({
    required this.tier,
    required this.color,
    required this.size,
  });

  final int tier;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (tier > _tierNumerals.length) {
      return Icon(PhosphorIconsFill.star, size: size + 2, color: color);
    }
    return Text(
      _tierNumerals[tier - 1],
      style: TextStyle(
        fontFamily: 'monospace',
        color: color,
        fontSize: size,
        height: 1.2,
        fontWeight: FontWeight.w900,
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
    final gold = node.currency == FamilyMasteryCurrency.gold;
    const ink = Color(0xFF120D07);

    final (
      Gradient? gradient,
      Color? fill,
      Color border,
      Color foreground,
    ) = switch (state) {
      _UpgradeState.ready => (
        LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(color, Colors.white, 0.12)!,
            Color.lerp(color, Colors.black, 0.35)!,
          ],
        ),
        null,
        Color.lerp(color, Colors.white, 0.4)!,
        ink,
      ),
      _UpgradeState.armed => (
        const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF7E6), Color(0xFFE9C77E)],
        ),
        null,
        Colors.white,
        ink,
      ),
      _UpgradeState.unaffordable => (
        null,
        const Color(0xFF1A1214),
        _danger.withValues(alpha: 0.5),
        _danger,
      ),
      _UpgradeState.locked => (null, const Color(0xFF12151B), _border, _dim),
      _UpgradeState.owned => (
        null,
        color.withValues(alpha: 0.1),
        color.withValues(alpha: 0.4),
        color,
      ),
      _UpgradeState.busy => (
        null,
        color.withValues(alpha: 0.18),
        color.withValues(alpha: 0.5),
        color,
      ),
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
    final raised = state == _UpgradeState.ready || state == _UpgradeState.armed;

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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 48,
          decoration: BoxDecoration(
            gradient: gradient,
            color: fill,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border, width: raised ? 1.5 : 1),
          ),
          child: Stack(
            children: [
              if (raised) ...[
                Positioned(
                  top: 1,
                  left: 8,
                  right: 8,
                  height: 1.2,
                  child: ColoredBox(
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(5),
                      ),
                    ),
                  ),
                ),
              ],
              Center(
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
                                CoinIcon(
                                  kind: gold ? CoinKind.gold : CoinKind.silver,
                                  size: 17,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _formatNumber(node.cost),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _EquipButton extends StatelessWidget {
  const _EquipButton({
    super.key,
    required this.color,
    required this.busy,
    required this.onTap,
  });

  final Color color;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Equip branch',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: busy ? null : onTap,
        child: Container(
          width: 88,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.7)),
          ),
          child: busy
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Text(
                  'EQUIP\nBRANCH',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: color,
                    fontSize: 10,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ActiveCrest extends StatelessWidget {
  const _ActiveCrest({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIconsBold.sealCheck, size: 14, color: color),
          const SizedBox(height: 1),
          Text(
            'ACTIVE',
            style: TextStyle(
              fontFamily: 'monospace',
              color: color,
              fontSize: 9,
              height: 1.1,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
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
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
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

// ── Roster summary ─────────────────────────────────────────────────────────

/// A compact read of one family's equipped mastery path, for the survival
/// lobby's species roster: which path, how far it has been bought, and — when
/// [expanded] — what each owned node does.
///
/// Uses the tree's own gems and glyphs so a path reads the same in the lobby
/// as it does in Base Command.
class FamilyMasteryRosterSummary extends StatelessWidget {
  const FamilyMasteryRosterSummary({
    super.key,
    required this.family,
    required this.owned,
    required this.selectedPathId,
    this.expanded = false,
    this.onOpenTree,
  });

  final CreatureFamily family;
  final Set<String> owned;
  final String? selectedPathId;
  final bool expanded;

  /// Opens this family's tree in Base Command.
  final VoidCallback? onOpenTree;

  // Text sizes the layout below draws with; the height maths measures the
  // same styles rather than assuming how many lines they take.
  static const double _headerSize = 11;
  static const double _roleSize = 10.5;
  static const double _nextSize = 10;
  static const double _nodeNameSize = 9.5;
  static const double _nodeDescSize = 10;
  static const double _nodeIconColumn = 21;
  static const double _nodeIconMinHeight = 15;
  static const int nodeDescMaxLines = 3;

  /// Measures [text] in the style it is actually drawn in.
  ///
  /// [fontWeight] matters more than it looks: this used to measure every
  /// string at w900 while most of them are drawn at normal weight, and a
  /// different weight resolves to a different face with different metrics.
  /// That alone left the computed height a few pixels short of every line.
  static double _textHeight(
    BuildContext context,
    String text,
    double width,
    double fontSize, {
    int? maxLines,
    double? height,
    String? fontFamily,
    double letterSpacing = 0,
    FontWeight fontWeight = FontWeight.w900,
  }) {
    // Merged onto the ambient default exactly the way `Text` merges it. This
    // is the whole reason the maths used to come up short: the default style
    // carries a line-height multiplier, so a 10px line draws at 14 while a
    // bare TextPainter measured it at 10 — four pixels missing from every
    // line that did not set its own height.
    final style = DefaultTextStyle.of(context).style.merge(
      TextStyle(
        fontSize: fontSize,
        height: height,
        fontFamily: fontFamily,
        letterSpacing: letterSpacing,
        fontWeight: fontWeight,
      ),
    );
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: maxLines,
    )..layout(maxWidth: math.max(20.0, width));
    // Rounded up: a paragraph lays out to whole logical pixels, so measuring
    // 15.4 for a line the renderer gives 16 leaves a shortfall that used to
    // be papered over with a trailing fudge factor.
    return painter.height.ceilToDouble();
  }

  /// The capstone gem is drawn 4 larger than the rest, so it sets the row.
  static const double _capstoneGemBonus = 4;

  /// Tiers I-III draw a numeral, but the capstone is past the end of that list
  /// and falls through to a star `Icon(size + 2)` — half a pixel taller than
  /// the numeral it was assumed to be.
  static const double _tierGlyphHeight = 7.5 + 2;

  static double _gemTrackHeight(double width) =>
      (_gemSizeFor(width) + _capstoneGemBonus + 2 + _tierGlyphHeight)
          .ceilToDouble();

  /// A line inside a [FittedBox] shrinks to fit, so its height depends on the
  /// width it is given. Measured at its natural size, then scaled the way the
  /// box scales it.
  static double _fittedLineHeight(
    BuildContext context,
    String text,
    double available,
    double fontSize, {
    double letterSpacing = 0,
    String? fontFamily,
  }) {
    final style = DefaultTextStyle.of(context).style.merge(
      TextStyle(
        fontSize: fontSize,
        fontFamily: fontFamily,
        letterSpacing: letterSpacing,
        fontWeight: FontWeight.w900,
      ),
    );
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final scale = painter.width <= 0
        ? 1.0
        : math.min(1.0, math.max(20.0, available) / painter.width);
    return (painter.height * scale).ceilToDouble();
  }

  /// The TREE link sits in the role row with 2px of padding above and below.
  static double _treeLinkHeight(BuildContext context) =>
      4 + _textHeight(context, 'TREE', 60, 9, maxLines: 1);

  static double _gemSizeFor(double width) =>
      ((width - 3 * 6.0 - 4) / 4).clamp(18.0, 30.0);

  /// The height this summary needs at [width], so the carousel can size to
  /// it. Everything that wraps is measured in the style it is drawn in.
  static double heightFor(
    BuildContext context, {
    required CreatureFamily family,
    required Set<String> owned,
    required String? selectedPathId,
    required bool expanded,
    required double width,
  }) {
    final path = selectedPathId == null
        ? null
        : FamilyMasteryCatalog.pathFor(family, selectedPathId);
    if (path == null) {
      // The row is a 34px badge, a 10px gap, then the text column.
      final textWidth = width - 34 - 10;
      final title = _fittedLineHeight(
        context,
        'NO MASTERY PATH',
        textWidth,
        _headerSize,
        letterSpacing: 1.1,
        fontFamily: 'monospace',
      );
      final body = _textHeight(
        context,
        'Choose one in Base Command to change how every '
        '${family.displayName} fights.',
        textWidth,
        _roleSize,
        maxLines: 3,
        fontWeight: FontWeight.normal,
      );
      // The badge sets a floor; the vertical padding is 3 either side.
      return math.max(34.0, title + 3 + body) + 6;
    }

    // The header row is a 12px icon beside the path name; whichever is taller
    // sets the row.
    var height =
        math.max(
          12.0,
          _textHeight(
            context,
            path.name.toUpperCase(),
            width - 40,
            _headerSize,
            maxLines: 1,
            letterSpacing: 1.1,
            fontFamily: 'monospace',
          ),
        ) +
        2;
    // The role line shares its row with the TREE link, which is the taller of
    // the two once its padding is counted.
    height += math.max(
      _textHeight(
        context,
        path.role,
        width - 60,
        _roleSize,
        maxLines: 1,
        fontWeight: FontWeight.normal,
      ),
      _treeLinkHeight(context),
    );
    height += 8 + _gemTrackHeight(width) + 6;
    height += _textHeight(
      context,
      'Next',
      width,
      _nextSize,
      maxLines: 1,
      fontWeight: FontWeight.normal,
    );

    final ownedTiers = ownedOnSelectedPath(family, owned, selectedPathId);
    if (expanded && ownedTiers > 0) {
      height += 6;
      for (final node in path.nodes.take(ownedTiers)) {
        height += nodeLineHeight(context, node, width);
      }
    }
    return height;
  }

  /// One expanded node's row: its name, then its description wrapped.
  static double nodeLineHeight(
    BuildContext context,
    FamilyMasteryNodeDef node,
    double width,
  ) {
    final textWidth = width - _nodeIconColumn;
    final text =
        _textHeight(
          context,
          node.name.toUpperCase(),
          textWidth,
          _nodeNameSize,
          maxLines: 1,
          letterSpacing: 0.8,
          fontFamily: 'monospace',
        ) +
        1 +
        _textHeight(
          context,
          node.description,
          textWidth,
          _nodeDescSize,
          maxLines: nodeDescMaxLines,
          height: 1.2,
          fontWeight: FontWeight.normal,
        );
    // The icon sits in a 2px-inset 13px box, so a short node cannot be
    // shorter than that however little text it carries.
    return math.max(text, _nodeIconMinHeight) + 6;
  }

  /// How many nodes of the equipped path are owned.
  static int ownedOnSelectedPath(
    CreatureFamily family,
    Set<String> owned,
    String? selectedPathId,
  ) {
    if (selectedPathId == null) return 0;
    final path = FamilyMasteryCatalog.pathFor(family, selectedPathId);
    if (path == null) return 0;
    return path.nodes.takeWhile((node) => owned.contains(node.id)).length;
  }

  @override
  Widget build(BuildContext context) {
    final path = selectedPathId == null
        ? null
        : FamilyMasteryCatalog.pathFor(family, selectedPathId!);
    if (path == null) return _buildEmpty();

    final color = family.color;
    final ownedTiers = ownedOnSelectedPath(family, owned, path.id);
    final next = ownedTiers < path.nodes.length ? path.nodes[ownedTiers] : null;

    return Column(
      key: ValueKey('roster-mastery-${family.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(_pathIcon(path.id), size: 12, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                path.name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              ownedTiers == path.nodes.length
                  ? 'MASTERED'
                  : '$ownedTiers/${path.nodes.length}',
              style: TextStyle(
                fontFamily: 'monospace',
                color: ownedTiers == path.nodes.length ? _gold : _muted,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Text(
                path.role,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 10.5),
              ),
            ),
            if (onOpenTree != null)
              GestureDetector(
                key: ValueKey('roster-open-tree-${family.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: onOpenTree,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 2, 0, 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'TREE',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      Icon(
                        PhosphorIconsBold.caretRight,
                        size: 11,
                        color: color,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _RosterGemTrack(path: path, ownedTiers: ownedTiers, color: color),
        const SizedBox(height: 6),
        Text(
          next == null
              ? 'Every node on this path is active.'
              : ownedTiers == 0
              ? 'Nothing bought yet — next: ${next.name}'
              : 'Next: ${next.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _muted, fontSize: 10),
        ),
        if (expanded && ownedTiers > 0) ...[
          const SizedBox(height: 6),
          for (final node in path.nodes.take(ownedTiers))
            _RosterNodeLine(node: node, color: color),
        ],
      ],
    );
  }

  Widget _buildEmpty() {
    return GestureDetector(
      key: ValueKey('roster-mastery-empty-${family.name}'),
      behavior: HitTestBehavior.opaque,
      onTap: onOpenTree,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _border, width: 1.2),
              ),
              child: const Icon(
                PhosphorIconsBold.treeStructure,
                size: 16,
                color: _muted,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'NO MASTERY PATH',
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: _text,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Choose one in Base Command to change how every '
                    '${family.displayName} fights.',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 10.5),
                  ),
                ],
              ),
            ),
            if (onOpenTree != null)
              Icon(PhosphorIconsBold.caretRight, size: 14, color: family.color),
          ],
        ),
      ),
    );
  }
}

class _RosterGemTrack extends StatelessWidget {
  const _RosterGemTrack({
    required this.path,
    required this.ownedTiers,
    required this.color,
  });

  final FamilyMasteryPathDef path;
  final int ownedTiers;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Four gems and three short joins; the gems give way on a narrow
        // card rather than the row overflowing.
        return _buildTrack(
          FamilyMasteryRosterSummary._gemSizeFor(constraints.maxWidth),
        );
      },
    );
  }

  Widget _buildTrack(double gemSize) {
    final children = <Widget>[];
    for (var i = 0; i < path.nodes.length; i++) {
      final node = path.nodes[i];
      if (i > 0) {
        final lit = i < ownedTiers;
        children.add(
          Expanded(
            child: Container(
              height: lit ? 2.5 : 1.5,
              margin: const EdgeInsets.only(bottom: 14),
              color: lit
                  ? (i == 3 ? _gold : color).withValues(alpha: 0.85)
                  : _border,
            ),
          ),
        );
      }
      final state = i < ownedTiers
          ? _NodeState.owned
          : i == ownedTiers
          ? _NodeState.available
          : _NodeState.locked;
      children.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Gem(
              node: node,
              color: color,
              state: state,
              focused: false,
              affordable: false,
              activeBranch: true,
              size: node.isCapstone ? gemSize + 4 : gemSize,
              iconSize: gemSize * (node.isCapstone ? 0.5 : 0.44),
            ),
            const SizedBox(height: 2),
            _TierGlyph(
              tier: node.tier,
              size: 7.5,
              color: state == _NodeState.owned
                  ? (node.isCapstone ? _gold : color)
                  : _dim,
            ),
          ],
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }
}

class _RosterNodeLine extends StatelessWidget {
  const _RosterNodeLine({required this.node, required this.color});

  final FamilyMasteryNodeDef node;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final accent = node.isCapstone ? _gold : color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(_nodeIcon(node.id), size: 13, color: accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: accent,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  node.description,
                  maxLines: FamilyMasteryRosterSummary.nodeDescMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB9AD99),
                    fontSize: 10,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Icons & formatting ─────────────────────────────────────────────────────

IconData _pathIcon(String pathId) {
  switch (pathId) {
    case 'mane.limitless':
      return PhosphorIconsBold.infinity;
    case 'let.bombardment':
      return PhosphorIconsBold.arrowFatLinesDown;
    case 'let.ground_zero':
      return PhosphorIconsBold.crosshairSimple;
  }
  if (pathId.endsWith('.assault')) return PhosphorIconsBold.sword;
  if (pathId.endsWith('.control')) return PhosphorIconsBold.shareNetwork;
  return PhosphorIconsBold.waveSine;
}

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
  'mask.assault.long_needle': PhosphorIconsBold.penNibStraight,
  'mask.assault.through_the_veil': PhosphorIconsBold.ghost,
  'mask.assault.chosen_victim': PhosphorIconsBold.crosshairSimple,
  'mask.assault.phantom_lance': PhosphorIconsBold.arrowFatLineRight,
  'mask.control.inscribed_dart': PhosphorIconsBold.penNib,
  'mask.control.binding_script': PhosphorIconsBold.scroll,
  'mask.control.prepared_ground': PhosphorIconsBold.pentagram,
  'mask.control.haunted_ground': PhosphorIconsBold.skull,
  'mask.resonance.false_face': PhosphorIconsBold.maskSad,
  'mask.resonance.applause': PhosphorIconsBold.handsClapping,
  'mask.resonance.curtain_call': PhosphorIconsBold.maskHappy,
  'mask.resonance.grand_masquerade': PhosphorIconsBold.crown,
  // Horn
  'horn.assault.heavy_head': PhosphorIconsBold.barbell,
  'horn.assault.sunder': PhosphorIconsBold.axe,
  'horn.assault.point_blank': PhosphorIconsBold.handFist,
  'horn.assault.siege_horn': PhosphorIconsBold.castleTurret,
  'horn.control.guarded_shot': PhosphorIconsBold.shield,
  'horn.control.hold_the_line': PhosphorIconsBold.wall,
  'horn.control.interposition': PhosphorIconsBold.shieldCheckered,
  'horn.control.countercharge': PhosphorIconsBold.shieldStar,
  'horn.resonance.gather_momentum': PhosphorIconsBold.footprints,
  'horn.resonance.rolling_weight': PhosphorIconsBold.arrowsClockwise,
  'horn.resonance.impact_reserve': PhosphorIconsBold.batteryCharging,
  'horn.resonance.unstoppable': PhosphorIconsBold.rocketLaunch,
  // Wing
  'wing.assault.synchronized_flight': PhosphorIconsBold.feather,
  'wing.assault.rangefinder': PhosphorIconsBold.binoculars,
  'wing.assault.double_tap': PhosphorIconsBold.arrowsMerge,
  'wing.assault.twin_suns': PhosphorIconsBold.sun,
  'wing.control.open_wings': PhosphorIconsBold.bird,
  'wing.control.crosscurrent': PhosphorIconsBold.arrowBendDoubleUpRight,
  'wing.control.elemental_contrails': PhosphorIconsBold.cloudLightning,
  'wing.control.razor_horizon': PhosphorIconsBold.sunHorizon,
  'wing.resonance.sightline': PhosphorIconsBold.eye,
  'wing.resonance.coherent_light': PhosphorIconsBold.lightbulbFilament,
  'wing.resonance.beam_feed': PhosphorIconsBold.flashlight,
  'wing.resonance.continuum': PhosphorIconsBold.infinity,
  // Kin
  'kin.assault.hot_coil': PhosphorIconsBold.thermometerHot,
  'kin.assault.burn_through': PhosphorIconsBold.fire,
  'kin.assault.critical_mass': PhosphorIconsBold.radioactive,
  'kin.assault.judgment_line': PhosphorIconsBold.gavel,
  'kin.control.conductivity': PhosphorIconsBold.plug,
  'kin.control.ground_path': PhosphorIconsBold.path,
  'kin.control.relay_point': PhosphorIconsBold.broadcast,
  'kin.control.living_circuit': PhosphorIconsBold.circuitry,
  'kin.resonance.guard_charge': PhosphorIconsBold.shieldPlus,
  'kin.resonance.shared_current': PhosphorIconsBold.plugsConnected,
  'kin.resonance.blessing_reserve': PhosphorIconsBold.handHeart,
  'kin.resonance.guardian_relay': PhosphorIconsBold.usersThree,
  // Mystic
  'mystic.assault.aligned_stars': PhosphorIconsBold.starFour,
  'mystic.assault.conjunction': PhosphorIconsBold.intersectThree,
  'mystic.assault.falling_sign': PhosphorIconsBold.shootingStar,
  'mystic.assault.the_stars_answer': PhosphorIconsBold.moonStars,
  'mystic.control.seed_the_field': PhosphorIconsBold.plant,
  'mystic.control.local_omen': PhosphorIconsBold.eyes,
  'mystic.control.awakening': PhosphorIconsBold.flowerLotus,
  'mystic.control.living_world': PhosphorIconsBold.tree,
  'mystic.resonance.witness': PhosphorIconsBold.eye,
  'mystic.resonance.shared_vision': PhosphorIconsBold.handEye,
  'mystic.resonance.oath_fulfilled': PhosphorIconsBold.sealCheck,
  'mystic.resonance.worldbond': PhosphorIconsBold.globeHemisphereWest,
};

String _compactNumber(int value) =>
    value >= 1000 ? '${value ~/ 1000}K' : '$value';

String _formatNumber(int value) {
  final source = value.toString();
  final result = StringBuffer();
  for (var i = 0; i < source.length; i++) {
    if (i > 0 && (source.length - i) % 3 == 0) result.write(',');
    result.write(source[i]);
  }
  return result.toString();
}

String _purchaseMessage(FamilyMasteryPurchaseResult result) => switch (result) {
  FamilyMasteryPurchaseResult.purchased =>
    'Mastery unlocked for the entire family.',
  FamilyMasteryPurchaseResult.alreadyOwned =>
    'That mastery is already unlocked.',
  FamilyMasteryPurchaseResult.prerequisiteMissing =>
    'Unlock the previous tier first.',
  FamilyMasteryPurchaseResult.insufficientSilver => 'Not enough silver.',
  FamilyMasteryPurchaseResult.insufficientGold => 'Not enough gold.',
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
