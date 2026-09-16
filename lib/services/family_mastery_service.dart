import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flutter/foundation.dart';

enum FamilyMasteryPurchaseResult {
  purchased,
  invalidNode,
  wrongFamily,
  alreadyOwned,
  prerequisiteMissing,
  insufficientSilver,
  insufficientGold,
}

enum FamilyMasteryEquipResult {
  equipped,
  cleared,
  invalidPath,
  pathNotUnlocked,
}

/// Account-wide Survival mastery configuration.
///
/// Purchases and the active branch belong to a creature family, never an
/// individual creature. Every party member from that family receives the same
/// active nodes when a run snapshot is created.
class FamilyMasteryService extends ChangeNotifier {
  FamilyMasteryService(this._db);

  final AlchemonsDatabase _db;
  final Map<CreatureFamily, Set<String>> _purchases = {};
  final Map<CreatureFamily, String> _selectedPaths = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Set<String> purchasedNodes(CreatureFamily family) =>
      Set<String>.unmodifiable(_purchases[family] ?? const {});

  String? selectedPathForFamily(CreatureFamily family) =>
      _selectedPaths[family];

  bool isNodePurchased(String nodeId) {
    final entry = FamilyMasteryCatalog.entryForNode(nodeId);
    if (entry == null) return false;
    return _purchases[entry.tree.family]?.contains(nodeId) ?? false;
  }

  Future<void> load() async {
    final rows = await _db.familyMasteryDao.getAllFamilyMasteries();
    _purchases.clear();
    _selectedPaths.clear();

    for (final row in rows) {
      final family = creatureFamilyFromStorage(row.familyId);
      if (family == null) continue;
      final owned = FamilyMasteryCatalog.sanitizePurchases(
        family,
        _decodeStringSet(row.purchasedNodeIdsJson),
      );
      _purchases[family] = owned;

      final pathId = row.selectedPathId;
      final path = pathId == null
          ? null
          : FamilyMasteryCatalog.pathFor(family, pathId);
      if (path != null && owned.contains(path.nodes.first.id)) {
        _selectedPaths[family] = path.id;
      }
    }

    _loaded = true;
    notifyListeners();
  }

  Future<FamilyMasteryPurchaseResult> purchaseNode({
    required CreatureFamily family,
    required String nodeId,
  }) async {
    final entry = FamilyMasteryCatalog.entryForNode(nodeId);
    if (entry == null) return FamilyMasteryPurchaseResult.invalidNode;
    if (entry.tree.family != family) {
      return FamilyMasteryPurchaseResult.wrongFamily;
    }

    late FamilyMasteryPurchaseResult result;
    await _db.transaction(() async {
      final stored = await _db.familyMasteryDao.getFamilyMastery(family.name);
      final owned = FamilyMasteryCatalog.sanitizePurchases(
        family,
        _decodeStringSet(stored?.purchasedNodeIdsJson),
      );
      if (owned.contains(nodeId)) {
        result = FamilyMasteryPurchaseResult.alreadyOwned;
        return;
      }

      final nodeIndex = entry.path.nodes.indexWhere(
        (node) => node.id == nodeId,
      );
      if (nodeIndex < 0) {
        result = FamilyMasteryPurchaseResult.invalidNode;
        return;
      }
      if (nodeIndex > 0 &&
          !owned.contains(entry.path.nodes[nodeIndex - 1].id)) {
        result = FamilyMasteryPurchaseResult.prerequisiteMissing;
        return;
      }

      final paid = switch (entry.node.currency) {
        FamilyMasteryCurrency.silver => await _db.currencyDao.spendSilver(
          entry.node.cost,
        ),
        FamilyMasteryCurrency.gold => await _db.currencyDao.spendGold(
          entry.node.cost,
        ),
      };
      if (!paid) {
        result = entry.node.currency == FamilyMasteryCurrency.silver
            ? FamilyMasteryPurchaseResult.insufficientSilver
            : FamilyMasteryPurchaseResult.insufficientGold;
        return;
      }

      owned.add(nodeId);
      var selectedPathId = stored?.selectedPathId;
      final selectedPath = selectedPathId == null
          ? null
          : FamilyMasteryCatalog.pathFor(family, selectedPathId);
      final hasValidSelection =
          selectedPath != null && owned.contains(selectedPath.nodes.first.id);
      if (entry.node.tier == 1 && !hasValidSelection) {
        selectedPathId = entry.path.id;
      }

      await _db.familyMasteryDao.saveFamilyMastery(
        familyId: family.name,
        purchasedNodeIdsJson: _encodeStringSet(owned),
        selectedPathId: selectedPathId,
        updatedAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
      result = FamilyMasteryPurchaseResult.purchased;
    });

    if (result == FamilyMasteryPurchaseResult.purchased) await load();
    return result;
  }

  Future<FamilyMasteryEquipResult> selectPath({
    required CreatureFamily family,
    required String? pathId,
  }) async {
    final stored = await _db.familyMasteryDao.getFamilyMastery(family.name);
    final owned = FamilyMasteryCatalog.sanitizePurchases(
      family,
      _decodeStringSet(stored?.purchasedNodeIdsJson),
    );

    if (pathId == null) {
      await _db.familyMasteryDao.saveFamilyMastery(
        familyId: family.name,
        purchasedNodeIdsJson: _encodeStringSet(owned),
        selectedPathId: null,
        updatedAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
      _purchases[family] = owned;
      _selectedPaths.remove(family);
      notifyListeners();
      return FamilyMasteryEquipResult.cleared;
    }

    final path = FamilyMasteryCatalog.pathFor(family, pathId);
    if (path == null) return FamilyMasteryEquipResult.invalidPath;
    if (!owned.contains(path.nodes.first.id)) {
      return FamilyMasteryEquipResult.pathNotUnlocked;
    }

    await _db.familyMasteryDao.saveFamilyMastery(
      familyId: family.name,
      purchasedNodeIdsJson: _encodeStringSet(owned),
      selectedPathId: path.id,
      updatedAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    _purchases[family] = owned;
    _selectedPaths[family] = path.id;
    notifyListeners();
    return FamilyMasteryEquipResult.equipped;
  }

  Future<SurvivalFamilyMasterySnapshot> buildSnapshot(
    Iterable<FamilyMasteryPartyMemberRef> members,
  ) async {
    final memberList = members.toList(growable: false);
    if (memberList.isEmpty) return SurvivalFamilyMasterySnapshot.empty;

    final rows = await _db.familyMasteryDao.getAllFamilyMasteries();
    final rowByFamily = <CreatureFamily, SurvivalFamilyMastery>{};
    for (final row in rows) {
      final family = creatureFamilyFromStorage(row.familyId);
      if (family != null) rowByFamily[family] = row;
    }

    final result = <int, EquippedFamilyMastery>{};
    for (final member in memberList) {
      final row = rowByFamily[member.family];
      final pathId = row?.selectedPathId;
      if (row == null || pathId == null) continue;
      final path = FamilyMasteryCatalog.pathFor(member.family, pathId);
      if (path == null) continue;
      final owned = FamilyMasteryCatalog.sanitizePurchases(
        member.family,
        _decodeStringSet(row.purchasedNodeIdsJson),
      );
      if (!owned.contains(path.nodes.first.id)) continue;

      result[member.slotIndex] = EquippedFamilyMastery(
        instanceId: member.instanceId,
        family: member.family,
        pathId: path.id,
        activeNodeIds: path.nodes
            .where((node) => owned.contains(node.id))
            .map((node) => node.id),
      );
    }
    return SurvivalFamilyMasterySnapshot(result);
  }
}

Set<String> _decodeStringSet(String? raw) {
  if (raw == null || raw.isEmpty) return <String>{};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <String>{};
    return decoded.whereType<String>().toSet();
  } catch (_) {
    return <String>{};
  }
}

String _encodeStringSet(Iterable<String> values) {
  final sorted = values.toSet().toList()..sort();
  return jsonEncode(sorted);
}
