import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:alchemons/services/family_mastery_service.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const _background = Color(0xFF080A0E);
const _panel = Color(0xFF141820);
const _panelRaised = Color(0xFF1C2230);
const _border = Color(0xFF252D3A);
const _text = Color(0xFFE8DCC8);
const _muted = Color(0xFF8A7B6A);
const _dim = Color(0xFF4A3F35);
const _silver = Color(0xFFC0C0C0);
const _gold = Color(0xFFFFC94A);

class FamilyMasteryPanel extends StatefulWidget {
  const FamilyMasteryPanel({
    super.key,
    required this.silverBalance,
    required this.goldBalance,
    required this.onCurrencyChanged,
  });

  final int silverBalance;
  final int goldBalance;
  final Future<void> Function() onCurrencyChanged;

  @override
  State<FamilyMasteryPanel> createState() => _FamilyMasteryPanelState();
}

class _FamilyMasteryPanelState extends State<FamilyMasteryPanel> {
  CreatureFamily _family = CreatureFamily.mane;
  final Map<CreatureFamily, String> _focusedNodes = {};
  String? _busyNodeId;
  String? _busyPathId;

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
    final focusedId = _focusedNodes[_family] ?? _defaultFocus(tree, owned);
    final focused = FamilyMasteryCatalog.entryForNode(focusedId)?.node;

    return ColoredBox(
      color: _background,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildFamilyRail()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 32),
            sliver: SliverList.list(
              children: [
                _buildTreeHeader(tree, owned.length, selectedPathId),
                const SizedBox(height: 14),
                if (focused != null)
                  _NodeInspector(
                    node: focused,
                    family: _family,
                    purchased: owned.contains(focused.id),
                    prerequisiteMet: _prerequisiteMet(tree, owned, focused.id),
                    canAfford: focused.currency == FamilyMasteryCurrency.gold
                        ? widget.goldBalance >= focused.cost
                        : widget.silverBalance >= focused.cost,
                    purchasing: _busyNodeId == focused.id,
                    blocked: _busyNodeId != null || _busyPathId != null,
                    onUnlock: () => _purchaseNode(mastery, focused),
                  ),
                const SizedBox(height: 18),
                _FamilySkillTree(
                  tree: tree,
                  owned: owned,
                  selectedPathId: selectedPathId,
                  focusedNodeId: focusedId,
                  busyPathId: _busyPathId,
                  onNodeTap: (node) =>
                      setState(() => _focusedNodes[_family] = node.id),
                  onPathSelect: (path) => _selectPath(mastery, path),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Only the highlighted branch is active in Survival. Every creature in this family uses it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _dim, fontSize: 10, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _defaultFocus(FamilyMasteryTreeDef tree, Set<String> owned) {
    for (final path in tree.paths) {
      for (final node in path.nodes) {
        if (!owned.contains(node.id) &&
            _prerequisiteMet(tree, owned, node.id)) {
          return node.id;
        }
      }
    }
    return tree.paths.first.nodes.first.id;
  }

  bool _prerequisiteMet(
    FamilyMasteryTreeDef tree,
    Set<String> owned,
    String nodeId,
  ) {
    for (final path in tree.paths) {
      final index = path.nodes.indexWhere((node) => node.id == nodeId);
      if (index < 0) continue;
      return index == 0 || owned.contains(path.nodes[index - 1].id);
    }
    return false;
  }

  Widget _buildFamilyRail() {
    return Container(
      height: 82,
      decoration: const BoxDecoration(
        color: Color(0xFF0E1117),
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: CreatureFamily.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final family = CreatureFamily.values[index];
          final selected = family == _family;
          return Semantics(
            button: true,
            selected: selected,
            label: '${family.displayName} family mastery',
            child: InkWell(
              key: ValueKey('mastery-family-${family.name}'),
              onTap: () => setState(() => _family = family),
              borderRadius: BorderRadius.circular(5),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 68,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: selected
                      ? family.color.withValues(alpha: 0.13)
                      : _panel,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: selected
                        ? family.color.withValues(alpha: 0.8)
                        : _border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      family.iconPath,
                      width: 25,
                      height: 25,
                      errorBuilder: (_, _, _) => Icon(
                        AppIcons.pets_rounded,
                        size: 23,
                        color: selected ? family.color : _muted,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      family.code,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: selected ? family.color : _muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTreeHeader(
    FamilyMasteryTreeDef tree,
    int purchasedCount,
    String? selectedPathId,
  ) {
    final selectedPath = selectedPathId == null
        ? null
        : FamilyMasteryCatalog.pathFor(_family, selectedPathId);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_family.color.withValues(alpha: 0.2), _panel],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _family.color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.account_tree_rounded,
                color: _family.color,
                size: 21,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '${_family.displayName.toUpperCase()} MASTERY',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: _text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.7,
                  ),
                ),
              ),
              _StatusPill(
                label: 'ALL ${_family.displayName.toUpperCase()}S',
                color: _family.color,
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            tree.chassis,
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: purchasedCount / 12,
                    minHeight: 3,
                    backgroundColor: _border,
                    color: _family.color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$purchasedCount / 12',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: _family.color,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            selectedPath == null
                ? 'NO ACTIVE BRANCH'
                : 'ACTIVE BRANCH  ·  ${selectedPath.name.toUpperCase()}',
            style: TextStyle(
              fontFamily: 'monospace',
              color: selectedPath == null ? _dim : _family.color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _purchaseNode(
    FamilyMasteryService mastery,
    FamilyMasteryNodeDef node,
  ) async {
    if (_busyNodeId != null || _busyPathId != null) return;
    final currencyName = node.currency == FamilyMasteryCurrency.gold
        ? 'gold'
        : 'silver';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0E1117),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: _family.color.withValues(alpha: 0.55)),
        ),
        title: Text(
          'UNLOCK ${node.name.toUpperCase()}?',
          style: const TextStyle(
            fontFamily: 'monospace',
            color: _text,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          'Spend ${_formatNumber(node.cost)} $currencyName? Every ${_family.displayName} will gain this node whenever its branch is active.',
          style: const TextStyle(color: _muted, fontSize: 12, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL', style: TextStyle(color: _dim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('UNLOCK', style: TextStyle(color: _family.color)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyNodeId = node.id);
    final result = await mastery.purchaseNode(family: _family, nodeId: node.id);
    await widget.onCurrencyChanged();
    if (!mounted) return;
    setState(() => _busyNodeId = null);
    _showResult(
      _purchaseMessage(result),
      result == FamilyMasteryPurchaseResult.purchased,
    );
  }

  Future<void> _selectPath(
    FamilyMasteryService mastery,
    FamilyMasteryPathDef path,
  ) async {
    if (_busyNodeId != null || _busyPathId != null) return;
    setState(() => _busyPathId = path.id);
    final result = await mastery.selectPath(family: _family, pathId: path.id);
    if (!mounted) return;
    setState(() => _busyPathId = null);
    _showResult(
      _equipMessage(result),
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

class _NodeInspector extends StatelessWidget {
  const _NodeInspector({
    required this.node,
    required this.family,
    required this.purchased,
    required this.prerequisiteMet,
    required this.canAfford,
    required this.purchasing,
    required this.blocked,
    required this.onUnlock,
  });

  final FamilyMasteryNodeDef node;
  final CreatureFamily family;
  final bool purchased;
  final bool prerequisiteMet;
  final bool canAfford;
  final bool purchasing;
  final bool blocked;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final currencyColor = node.currency == FamilyMasteryCurrency.gold
        ? _gold
        : _silver;
    return Container(
      key: const ValueKey('mastery-node-inspector'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panelRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: purchased ? family.color.withValues(alpha: 0.6) : _border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: purchased
                  ? family.color.withValues(alpha: 0.18)
                  : _background,
              border: Border.all(
                color: purchased ? family.color : _muted,
                width: 1.5,
              ),
            ),
            child: purchased
                ? Icon(AppIcons.check_rounded, color: family.color, size: 20)
                : Text(
                    '${node.tier}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: family.color,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        node.name.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: _text,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    if (node.isCapstone) ...[
                      const SizedBox(width: 6),
                      const _StatusPill(label: 'CAPSTONE', color: _gold),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  node.description,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 10,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (purchased)
            const _StatusPill(label: 'OWNED', color: _silver)
          else
            TextButton(
              key: ValueKey('unlock-${node.id}'),
              onPressed: prerequisiteMet && canAfford && !blocked
                  ? onUnlock
                  : null,
              style: TextButton.styleFrom(
                foregroundColor: currencyColor,
                disabledForegroundColor: _dim,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                backgroundColor: currencyColor.withValues(alpha: 0.06),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              child: purchasing
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: currencyColor,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CoinIcon(
                          kind: node.currency == FamilyMasteryCurrency.gold
                              ? CoinKind.gold
                              : CoinKind.silver,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _compactNumber(node.cost),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
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

class _FamilySkillTree extends StatelessWidget {
  const _FamilySkillTree({
    required this.tree,
    required this.owned,
    required this.selectedPathId,
    required this.focusedNodeId,
    required this.busyPathId,
    required this.onNodeTap,
    required this.onPathSelect,
  });

  final FamilyMasteryTreeDef tree;
  final Set<String> owned;
  final String? selectedPathId;
  final String focusedNodeId;
  final String? busyPathId;
  final ValueChanged<FamilyMasteryNodeDef> onNodeTap;
  final ValueChanged<FamilyMasteryPathDef> onPathSelect;

  @override
  Widget build(BuildContext context) {
    final color = tree.family.color;
    return Container(
      key: const ValueKey('family-skill-tree'),
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1016),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          _RootNode(family: tree.family),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: CustomPaint(painter: _BranchConnectorPainter(color: color)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final path in tree.paths)
                Expanded(
                  child: _BranchColumn(
                    path: path,
                    color: color,
                    owned: owned,
                    active: selectedPathId == path.id,
                    hasActivePath: selectedPathId != null,
                    focusedNodeId: focusedNodeId,
                    selecting: busyPathId == path.id,
                    onNodeTap: onNodeTap,
                    onSelect: () => onPathSelect(path),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RootNode extends StatelessWidget {
  const _RootNode({required this.family});

  final CreatureFamily family;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [family.color.withValues(alpha: 0.34), _panel],
            ),
            border: Border.all(color: family.color, width: 2),
            boxShadow: [
              BoxShadow(
                color: family.color.withValues(alpha: 0.2),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Image.asset(
            family.iconPath,
            errorBuilder: (_, _, _) =>
                Icon(AppIcons.pets_rounded, color: family.color, size: 30),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '${family.displayName.toUpperCase()} CORE',
          style: TextStyle(
            fontFamily: 'monospace',
            color: family.color,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _BranchColumn extends StatelessWidget {
  const _BranchColumn({
    required this.path,
    required this.color,
    required this.owned,
    required this.active,
    required this.hasActivePath,
    required this.focusedNodeId,
    required this.selecting,
    required this.onNodeTap,
    required this.onSelect,
  });

  final FamilyMasteryPathDef path;
  final Color color;
  final Set<String> owned;
  final bool active;
  final bool hasActivePath;
  final String focusedNodeId;
  final bool selecting;
  final ValueChanged<FamilyMasteryNodeDef> onNodeTap;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final unlocked = owned.contains(path.nodes.first.id);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: active || !hasActivePath ? 1 : 0.62,
      child: Column(
        children: [
          Icon(_pathIcon(path.id), color: active ? color : _muted, size: 19),
          const SizedBox(height: 5),
          SizedBox(
            height: 28,
            child: Text(
              path.name.toUpperCase(),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'monospace',
                color: active ? color : _text,
                fontSize: 9,
                height: 1.2,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ),
          SizedBox(
            height: 38,
            child: Text(
              path.role,
              maxLines: 3,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _dim, fontSize: 8, height: 1.25),
            ),
          ),
          const SizedBox(height: 5),
          if (active)
            _StatusPill(label: 'ACTIVE', color: color)
          else
            SizedBox(
              height: 25,
              child: TextButton(
                key: ValueKey('select-${path.id}'),
                onPressed: unlocked && !selecting ? onSelect : null,
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  disabledForegroundColor: _dim,
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  minimumSize: const Size(0, 25),
                  side: BorderSide(
                    color: unlocked ? color.withValues(alpha: 0.5) : _border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                child: selecting
                    ? SizedBox(
                        width: 11,
                        height: 11,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      )
                    : const Text(
                        'SELECT',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          const SizedBox(height: 10),
          for (var index = 0; index < path.nodes.length; index++) ...[
            _TreeNode(
              node: path.nodes[index],
              color: color,
              purchased: owned.contains(path.nodes[index].id),
              available: index == 0 || owned.contains(path.nodes[index - 1].id),
              focused: focusedNodeId == path.nodes[index].id,
              activeBranch: active,
              onTap: () => onNodeTap(path.nodes[index]),
            ),
            if (index != path.nodes.length - 1)
              Container(
                width: active ? 3 : 2,
                height: 24,
                decoration: BoxDecoration(
                  color: owned.contains(path.nodes[index].id)
                      ? color.withValues(alpha: active ? 0.9 : 0.45)
                      : _border,
                  boxShadow: active && owned.contains(path.nodes[index].id)
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.45),
                            blurRadius: 7,
                          ),
                        ]
                      : null,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TreeNode extends StatelessWidget {
  const _TreeNode({
    required this.node,
    required this.color,
    required this.purchased,
    required this.available,
    required this.focused,
    required this.activeBranch,
    required this.onTap,
  });

  final FamilyMasteryNodeDef node;
  final Color color;
  final bool purchased;
  final bool available;
  final bool focused;
  final bool activeBranch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nodeColor = node.isCapstone ? _gold : color;
    return Semantics(
      button: true,
      label: '${node.name}, tier ${node.tier}',
      child: InkWell(
        key: ValueKey('mastery-node-${node.id}'),
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: node.isCapstone ? 66 : 58,
              height: node.isCapstone ? 66 : 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: purchased
                    ? nodeColor.withValues(alpha: 0.2)
                    : available
                    ? _panelRaised
                    : const Color(0xFF101319),
                border: Border.all(
                  color: focused
                      ? nodeColor
                      : purchased
                      ? nodeColor.withValues(alpha: 0.75)
                      : available
                      ? _muted
                      : _border,
                  width: focused
                      ? 3
                      : purchased
                      ? 2
                      : 1,
                ),
                boxShadow: purchased && activeBranch
                    ? [
                        BoxShadow(
                          color: nodeColor.withValues(alpha: 0.28),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: purchased
                  ? Icon(
                      node.isCapstone
                          ? AppIcons.auto_awesome_rounded
                          : AppIcons.check_rounded,
                      color: nodeColor,
                      size: node.isCapstone ? 25 : 20,
                    )
                  : available
                  ? Text(
                      '${node.tier}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: nodeColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : const Icon(AppIcons.lock_rounded, color: _dim, size: 16),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 26,
              child: Text(
                node.name.toUpperCase(),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: purchased || available ? _muted : _dim,
                  fontSize: 8,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (!purchased)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CoinIcon(
                    kind: node.currency == FamilyMasteryCurrency.gold
                        ? CoinKind.gold
                        : CoinKind.silver,
                    size: 10,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _compactNumber(node.cost),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: node.currency == FamilyMasteryCurrency.gold
                          ? _gold
                          : _silver,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              )
            else
              const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _BranchConnectorPainter extends CustomPainter {
  const _BranchConnectorPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final center = size.width / 2;
    final branchY = size.height * 0.52;
    final targets = [size.width / 6, center, size.width * 5 / 6];
    final path = Path()
      ..moveTo(center, 0)
      ..lineTo(center, branchY)
      ..moveTo(targets.first, branchY)
      ..lineTo(targets.last, branchY);
    for (final target in targets) {
      path
        ..moveTo(target, branchY)
        ..lineTo(target, size.height);
    }
    canvas.drawPath(path, paint);

    final glow = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..strokeWidth = 7
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, glow);
  }

  @override
  bool shouldRepaint(covariant _BranchConnectorPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

IconData _pathIcon(String pathId) {
  if (pathId.endsWith('.assault')) return AppIcons.bolt_rounded;
  if (pathId.endsWith('.control')) return AppIcons.hub_rounded;
  return AppIcons.auto_awesome_rounded;
}

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
