import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flutter/foundation.dart';

enum FamilyMasteryPurchaseResult {
  purchased,
  invalidNode,
  wrongFamily,
  creatureNotFound,
  alreadyOwned,
  prerequisiteMissing,
  insufficientSilver,
  insufficientGold,
}

enum FamilyMasteryEquipResult {
  equipped,
  cleared,
  invalidPath,
  creatureNotFound,
  wrongFamily,
  pathNotUnlocked,
}

class FamilyMasteryService extends ChangeNotifier {
  FamilyMasteryService(this._db);

  final AlchemonsDatabase _db;
  final Map<CreatureFamily, Set<String>> _purchases = {};
  final Map<String, String> _selectedPaths = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Set<String> purchasedNodes(CreatureFamily family) =>
      Set<String>.unmodifiable(_purchases[family] ?? const {});

  String? selectedPathFor(String instanceId) => _selectedPaths[instanceId];

  bool isNodePurchased(String nodeId) {
    final entry = FamilyMasteryCatalog.entryForNode(nodeId);
    if (entry == null) return false;
    return _purchases[entry.tree.family]?.contains(nodeId) ?? false;
  }

  Future<void> load() async {
    final progressRows = await _db.familyMasteryDao.getAllFamilyMasteries();
    final loadoutRows = await _db.familyMasteryDao.getAllLoadouts();

    _purchases.clear();
    for (final row in progressRows) {
      final family = creatureFamilyFromStorage(row.familyId);
      if (family == null) continue;
      _purchases[family] = FamilyMasteryCatalog.sanitizePurchases(
        family,
        _decodeStringSet(row.purchasedNodeIdsJson),
      );
    }

    _selectedPaths.clear();
    for (final row in loadoutRows) {
      final family = creatureFamilyFromStorage(row.familyId);
      final pathId = row.selectedPathId;
      if (family == null || pathId == null) continue;
      final path = FamilyMasteryCatalog.pathFor(family, pathId);
      if (path == null || !_pathIsUnlocked(family, path)) continue;
      _selectedPaths[row.instanceId] = pathId;
    }

    _loaded = true;
    notifyListeners();
  }

  Future<FamilyMasteryPurchaseResult> purchaseNode({
    required String instanceId,
    required String nodeId,
  }) async {
    final entry = FamilyMasteryCatalog.entryForNode(nodeId);
    if (entry == null) return FamilyMasteryPurchaseResult.invalidNode;

    final instance = await _db.creatureDao.getInstance(instanceId);
    if (instance == null) return FamilyMasteryPurchaseResult.creatureNotFound;
    final actualFamily = creatureFamilyFromBaseId(instance.baseId);
    if (actualFamily != entry.tree.family) {
      return FamilyMasteryPurchaseResult.wrongFamily;
    }

    late FamilyMasteryPurchaseResult result;
    await _db.transaction(() async {
      final stored = await _db.familyMasteryDao.getFamilyMastery(
        entry.tree.family.name,
      );
      final owned = FamilyMasteryCatalog.sanitizePurchases(
        entry.tree.family,
        _decodeStringSet(stored?.purchasedNodeIdsJson),
      );
      if (owned.contains(nodeId)) {
        result = FamilyMasteryPurchaseResult.alreadyOwned;
        return;
      }

      final nodeIndex = entry.path.nodes.indexWhere((n) => n.id == nodeId);
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
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await _db.familyMasteryDao.saveFamilyMastery(
        familyId: entry.tree.family.name,
        purchasedNodeIdsJson: _encodeStringSet(owned),
        updatedAtUtcMs: now,
      );

      final currentLoadout = await _db.familyMasteryDao.getLoadout(instanceId);
      final currentPathId = currentLoadout?.selectedPathId;
      final currentPath = currentPathId == null
          ? null
          : FamilyMasteryCatalog.pathFor(entry.tree.family, currentPathId);
      final hasValidCurrentPath =
          currentPath != null &&
          owned.contains(currentPath.nodes.first.id) &&
          currentLoadout?.familyId == entry.tree.family.name;
      if (entry.node.tier == 1 && !hasValidCurrentPath) {
        await _db.familyMasteryDao.saveLoadout(
          instanceId: instanceId,
          familyId: entry.tree.family.name,
          selectedPathId: entry.path.id,
          updatedAtUtcMs: now,
        );
      }
      result = FamilyMasteryPurchaseResult.purchased;
    });

    if (result == FamilyMasteryPurchaseResult.purchased) await load();
    return result;
  }

  Future<FamilyMasteryEquipResult> equipPath({
    required String instanceId,
    required CreatureFamily family,
    required String? pathId,
  }) async {
    final instance = await _db.creatureDao.getInstance(instanceId);
    if (instance == null) return FamilyMasteryEquipResult.creatureNotFound;
    if (creatureFamilyFromBaseId(instance.baseId) != family) {
      return FamilyMasteryEquipResult.wrongFamily;
    }

    if (pathId == null) {
      await _db.familyMasteryDao.deleteLoadout(instanceId);
      _selectedPaths.remove(instanceId);
      notifyListeners();
      return FamilyMasteryEquipResult.cleared;
    }

    final path = FamilyMasteryCatalog.pathFor(family, pathId);
    if (path == null) return FamilyMasteryEquipResult.invalidPath;

    final owned = await _readPurchasedNodes(family);
    if (!owned.contains(path.nodes.first.id)) {
      return FamilyMasteryEquipResult.pathNotUnlocked;
    }

    await _db.familyMasteryDao.saveLoadout(
      instanceId: instanceId,
      familyId: family.name,
      selectedPathId: path.id,
      updatedAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    _purchases[family] = owned;
    _selectedPaths[instanceId] = path.id;
    notifyListeners();
    return FamilyMasteryEquipResult.equipped;
  }

  Future<FamilyMasteryEquipResult> copyPath({
    required String fromInstanceId,
    required String toInstanceId,
  }) async {
    final source = await _db.familyMasteryDao.getLoadout(fromInstanceId);
    final target = await _db.creatureDao.getInstance(toInstanceId);
    if (source == null || target == null) {
      return FamilyMasteryEquipResult.creatureNotFound;
    }
    final family = creatureFamilyFromStorage(source.familyId);
    if (family == null || creatureFamilyFromBaseId(target.baseId) != family) {
      return FamilyMasteryEquipResult.wrongFamily;
    }
    return equipPath(
      instanceId: toInstanceId,
      family: family,
      pathId: source.selectedPathId,
    );
  }

  Future<SurvivalFamilyMasterySnapshot> buildSnapshot(
    Iterable<FamilyMasteryPartyMemberRef> members,
  ) async {
    final memberList = members.toList(growable: false);
    if (memberList.isEmpty) return SurvivalFamilyMasterySnapshot.empty;
    final loadouts = await _db.familyMasteryDao.getLoadouts(
      memberList.map((m) => m.instanceId),
    );
    final loadoutByInstance = {for (final row in loadouts) row.instanceId: row};
    final purchasesByFamily = <CreatureFamily, Set<String>>{};
    final result = <int, EquippedFamilyMastery>{};

    for (final member in memberList) {
      final row = loadoutByInstance[member.instanceId];
      final pathId = row?.selectedPathId;
      if (row == null ||
          pathId == null ||
          creatureFamilyFromStorage(row.familyId) != member.family) {
        continue;
      }
      final path = FamilyMasteryCatalog.pathFor(member.family, pathId);
      if (path == null) continue;
      final owned = purchasesByFamily.putIfAbsent(
        member.family,
        () => <String>{},
      );
      if (owned.isEmpty) owned.addAll(await _readPurchasedNodes(member.family));
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

  Future<Set<String>> _readPurchasedNodes(CreatureFamily family) async {
    final stored = await _db.familyMasteryDao.getFamilyMastery(family.name);
    return FamilyMasteryCatalog.sanitizePurchases(
      family,
      _decodeStringSet(stored?.purchasedNodeIdsJson),
    );
  }

  bool _pathIsUnlocked(CreatureFamily family, FamilyMasteryPathDef path) {
    return _purchases[family]?.contains(path.nodes.first.id) ?? false;
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
