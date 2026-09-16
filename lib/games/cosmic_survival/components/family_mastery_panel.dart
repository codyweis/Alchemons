import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:alchemons/services/creature_repository.dart';
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
  final Map<CreatureFamily, String> _selectedInstances = {};
  Future<List<CreatureInstance>>? _instances;
  String? _busyNodeId;
  String? _busyPathId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _instances ??= context
        .read<AlchemonsDatabase>()
        .creatureDao
        .getAllInstances();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyMasteryService>(
      builder: (context, mastery, _) {
        return FutureBuilder<List<CreatureInstance>>(
          future: _instances,
          builder: (context, snapshot) {
            if (!snapshot.hasData || !mastery.isLoaded) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFA726)),
              );
            }
            return _buildContent(mastery, snapshot.data!);
          },
        );
      },
    );
  }

  Widget _buildContent(
    FamilyMasteryService mastery,
    List<CreatureInstance> allInstances,
  ) {
    final tree = FamilyMasteryCatalog.treeFor(_family);
    final owned = mastery.purchasedNodes(_family);
    final familyInstances =
        allInstances
            .where(
              (instance) =>
                  creatureFamilyFromBaseId(instance.baseId) == _family,
            )
            .toList()
          ..sort((a, b) => _nameFor(a).compareTo(_nameFor(b)));
    final requestedId = _selectedInstances[_family];
    final selected = familyInstances.cast<CreatureInstance?>().firstWhere(
      (instance) => instance?.instanceId == requestedId,
      orElse: () => familyInstances.isEmpty ? null : familyInstances.first,
    );

    return ColoredBox(
      color: _background,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildFamilyRail()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            sliver: SliverList.list(
              children: [
                _buildTreeHeader(tree, owned.length),
                const SizedBox(height: 14),
                _buildCreaturePicker(familyInstances, selected),
                const SizedBox(height: 18),
                for (final path in tree.paths) ...[
                  _PathCard(
                    path: path,
                    familyColor: _family.color,
                    owned: owned,
                    isEquipped:
                        selected != null &&
                        mastery.selectedPathFor(selected.instanceId) == path.id,
                    busyNodeId: _busyNodeId,
                    busyPathId: _busyPathId,
                    silverBalance: widget.silverBalance,
                    goldBalance: widget.goldBalance,
                    hasCreature: selected != null,
                    onBuy: (node) => _purchaseNode(mastery, selected, node),
                    onEquip: () => _equipPath(mastery, selected, path),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ],
      ),
    );
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

  Widget _buildTreeHeader(FamilyMasteryTreeDef tree, int purchasedCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_family.color.withValues(alpha: 0.18), _panel],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _family.color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.account_tree_rounded,
                color: _family.color,
                size: 20,
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
              Text(
                '$purchasedCount / 12',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: _family.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tree.chassis,
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: purchasedCount / 12,
              minHeight: 3,
              backgroundColor: _border,
              color: _family.color,
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'Unlocks are shared by the family. The equipped path belongs to the selected creature.',
            style: TextStyle(color: _dim, fontSize: 10, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildCreaturePicker(
    List<CreatureInstance> instances,
    CreatureInstance? selected,
  ) {
    if (instances.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Icon(AppIcons.lock_rounded, color: _family.color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Discover a ${_family.displayName} creature to purchase and equip this tree.',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 8, 10, 8),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(AppIcons.person_rounded, color: _family.color, size: 18),
          const SizedBox(width: 10),
          const Text(
            'EQUIP FOR',
            style: TextStyle(
              fontFamily: 'monospace',
              color: _dim,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: const ValueKey('mastery-creature-picker'),
                value: selected!.instanceId,
                isExpanded: true,
                dropdownColor: _panelRaised,
                iconEnabledColor: _family.color,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: _text,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
                items: [
                  for (final instance in instances)
                    DropdownMenuItem(
                      value: instance.instanceId,
                      child: Text(
                        '${_nameFor(instance)}  ·  LV ${instance.level}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (id) {
                  if (id == null) return;
                  setState(() => _selectedInstances[_family] = id);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _nameFor(CreatureInstance instance) {
    final species = context.read<CreatureCatalog>().getCreatureById(
      instance.baseId,
    );
    return instance.nickname ?? species?.name ?? instance.baseId;
  }

  Future<void> _purchaseNode(
    FamilyMasteryService mastery,
    CreatureInstance? instance,
    FamilyMasteryNodeDef node,
  ) async {
    if (instance == null || _busyNodeId != null || _busyPathId != null) return;
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
          'Spend ${_formatNumber(node.cost)} $currencyName? This unlock applies to every ${_family.displayName} creature.',
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
    final result = await mastery.purchaseNode(
      instanceId: instance.instanceId,
      nodeId: node.id,
    );
    await widget.onCurrencyChanged();
    if (!mounted) return;
    setState(() => _busyNodeId = null);
    _showResult(
      _purchaseMessage(result),
      result == FamilyMasteryPurchaseResult.purchased,
    );
  }

  Future<void> _equipPath(
    FamilyMasteryService mastery,
    CreatureInstance? instance,
    FamilyMasteryPathDef path,
  ) async {
    if (instance == null || _busyNodeId != null || _busyPathId != null) return;
    setState(() => _busyPathId = path.id);
    final result = await mastery.equipPath(
      instanceId: instance.instanceId,
      family: _family,
      pathId: path.id,
    );
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

class _PathCard extends StatelessWidget {
  const _PathCard({
    required this.path,
    required this.familyColor,
    required this.owned,
    required this.isEquipped,
    required this.busyNodeId,
    required this.busyPathId,
    required this.silverBalance,
    required this.goldBalance,
    required this.hasCreature,
    required this.onBuy,
    required this.onEquip,
  });

  final FamilyMasteryPathDef path;
  final Color familyColor;
  final Set<String> owned;
  final bool isEquipped;
  final String? busyNodeId;
  final String? busyPathId;
  final int silverBalance;
  final int goldBalance;
  final bool hasCreature;
  final ValueChanged<FamilyMasteryNodeDef> onBuy;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    final pathUnlocked = owned.contains(path.nodes.first.id);
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isEquipped ? familyColor.withValues(alpha: 0.8) : _border,
          width: isEquipped ? 1.5 : 1,
        ),
        boxShadow: isEquipped
            ? [
                BoxShadow(
                  color: familyColor.withValues(alpha: 0.08),
                  blurRadius: 18,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: familyColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: familyColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(_pathIcon(path.id), color: familyColor, size: 20),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        path.name.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: _text,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        path.role,
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                if (isEquipped)
                  _StatusPill(label: 'EQUIPPED', color: familyColor)
                else if (pathUnlocked)
                  TextButton(
                    key: ValueKey('equip-${path.id}'),
                    onPressed: hasCreature && busyPathId == null
                        ? onEquip
                        : null,
                    style: TextButton.styleFrom(
                      foregroundColor: familyColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      side: BorderSide(
                        color: familyColor.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    child: busyPathId == path.id
                        ? SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: familyColor,
                            ),
                          )
                        : const Text(
                            'EQUIP',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: Column(
              children: [
                for (var i = 0; i < path.nodes.length; i++) ...[
                  _MasteryNode(
                    node: path.nodes[i],
                    color: familyColor,
                    purchased: owned.contains(path.nodes[i].id),
                    prerequisiteMet:
                        i == 0 || owned.contains(path.nodes[i - 1].id),
                    canAfford:
                        path.nodes[i].currency == FamilyMasteryCurrency.gold
                        ? goldBalance >= path.nodes[i].cost
                        : silverBalance >= path.nodes[i].cost,
                    purchasing: busyNodeId == path.nodes[i].id,
                    blockedByPurchase: busyNodeId != null || busyPathId != null,
                    hasCreature: hasCreature,
                    onBuy: () => onBuy(path.nodes[i]),
                  ),
                  if (i != path.nodes.length - 1)
                    Container(
                      width: 2,
                      height: 9,
                      color: owned.contains(path.nodes[i].id)
                          ? familyColor.withValues(alpha: 0.55)
                          : _border,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MasteryNode extends StatelessWidget {
  const _MasteryNode({
    required this.node,
    required this.color,
    required this.purchased,
    required this.prerequisiteMet,
    required this.canAfford,
    required this.purchasing,
    required this.blockedByPurchase,
    required this.hasCreature,
    required this.onBuy,
  });

  final FamilyMasteryNodeDef node;
  final Color color;
  final bool purchased;
  final bool prerequisiteMet;
  final bool canAfford;
  final bool purchasing;
  final bool blockedByPurchase;
  final bool hasCreature;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final available = prerequisiteMet && !purchased;
    final currencyColor = node.currency == FamilyMasteryCurrency.gold
        ? _gold
        : _silver;
    return AnimatedContainer(
      key: ValueKey('mastery-node-${node.id}'),
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: purchased
            ? color.withValues(alpha: 0.09)
            : available
            ? _panelRaised
            : const Color(0xFF101319),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: purchased ? color.withValues(alpha: 0.5) : _border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: purchased ? color.withValues(alpha: 0.2) : _background,
              border: Border.all(
                color: purchased
                    ? color
                    : available
                    ? _muted
                    : _border,
              ),
            ),
            child: purchased
                ? Icon(AppIcons.check_rounded, color: color, size: 17)
                : available
                ? Text(
                    '${node.tier}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : const Icon(AppIcons.lock_rounded, color: _dim, size: 14),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        node.name.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: purchased || available ? _text : _dim,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    if (node.isCapstone) ...[
                      const SizedBox(width: 6),
                      const _StatusPill(label: 'CAPSTONE', color: _gold),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  node.description,
                  style: TextStyle(
                    color: purchased || available ? _muted : _dim,
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (purchased)
            const Text(
              'OWNED',
              style: TextStyle(
                fontFamily: 'monospace',
                color: _dim,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            )
          else if (available)
            TextButton(
              onPressed: hasCreature && canAfford && !blockedByPurchase
                  ? onBuy
                  : null,
              style: TextButton.styleFrom(
                foregroundColor: currencyColor,
                disabledForegroundColor: _dim,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: const Size(0, 34),
                backgroundColor: currencyColor.withValues(alpha: 0.06),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              child: purchasing
                  ? SizedBox(
                      width: 13,
                      height: 13,
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
                          size: 13,
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
  FamilyMasteryPurchaseResult.creatureNotFound =>
    'That creature is no longer available.',
  FamilyMasteryPurchaseResult.wrongFamily =>
    'That mastery belongs to another family.',
  FamilyMasteryPurchaseResult.invalidNode => 'That mastery could not be found.',
};

String _equipMessage(FamilyMasteryEquipResult result) => switch (result) {
  FamilyMasteryEquipResult.equipped => 'Path equipped for this creature.',
  FamilyMasteryEquipResult.cleared => 'Mastery path cleared.',
  FamilyMasteryEquipResult.pathNotUnlocked =>
    'Unlock the first tier of this path before equipping it.',
  FamilyMasteryEquipResult.creatureNotFound =>
    'That creature is no longer available.',
  FamilyMasteryEquipResult.wrongFamily =>
    'That path belongs to another family.',
  FamilyMasteryEquipResult.invalidPath => 'That path could not be found.',
};
