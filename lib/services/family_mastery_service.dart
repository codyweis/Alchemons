import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:alchemons/services/debug_settings_service.dart';
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

  /// Developer tools hand the whole tree over.
  ///
  /// A read-time override and nothing more: it never writes a purchase, so
  /// turning the switch off returns the account to exactly what it paid for
  /// rather than leaving it permanently rich. Choosing a path still matters —
  /// one at a time is the design, and testing the trees means switching
  /// between them, not owning them all at once.
  bool get allNodesUnlocked => DebugSettingsService.toolsVisible;

  /// Every node of [family], for the unlock override.
  Set<String> _allNodesFor(CreatureFamily family) => {
    for (final path in FamilyMasteryCatalog.treeFor(family).paths)
      for (final node in path.nodes) node.id,
  };

  /// What this family effectively owns right now.
  Set<String> _effectiveOwned(CreatureFamily family) => allNodesUnlocked
      ? _allNodesFor(family)
      : (_purchases[family] ?? const <String>{});

  Set<String> purchasedNodes(CreatureFamily family) =>
      Set<String>.unmodifiable(_effectiveOwned(family));

  String? selectedPathForFamily(CreatureFamily family) =>
      _selectedPaths[family];

  bool isNodePurchased(String nodeId) {
    final entry = FamilyMasteryCatalog.entryForNode(nodeId);
    if (entry == null) return false;
    if (allNodesUnlocked) return true;
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
    if (!allNodesUnlocked && !owned.contains(path.nodes.first.id)) {
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
    final owned = <CreatureFamily, Set<String>>{};
    final selected = <CreatureFamily, String>{};
    for (final row in rows) {
      final family = creatureFamilyFromStorage(row.familyId);
      if (family == null) continue;
      owned[family] = FamilyMasteryCatalog.sanitizePurchases(
        family,
        _decodeStringSet(row.purchasedNodeIdsJson),
      );
      final pathId = row.selectedPathId;
      if (pathId != null) selected[family] = pathId;
    }
    return _snapshotFrom(memberList, owned, selected);
  }

  /// The snapshot a run actually locks, built from the loaded in-memory state.
  ///
  /// Starting a run is synchronous — the screen has a party and needs a
  /// snapshot in the same frame it constructs the game. The cache is written
  /// by [load] and refreshed after every purchase and every branch change, so
  /// it is never behind storage by more than the await that just finished.
  SurvivalFamilyMasterySnapshot snapshotForParty(
    Iterable<FamilyMasteryPartyMemberRef> members,
  ) {
    final memberList = members.toList(growable: false);
    if (memberList.isEmpty) return SurvivalFamilyMasterySnapshot.empty;
    return _snapshotFrom(memberList, _purchases, _selectedPaths);
  }

  SurvivalFamilyMasterySnapshot _snapshotFrom(
    List<FamilyMasteryPartyMemberRef> members,
    Map<CreatureFamily, Set<String>> purchases,
    Map<CreatureFamily, String> selectedPaths,
  ) {
    final result = <int, EquippedFamilyMastery>{};
    for (final member in members) {
      final pathId = selectedPaths[member.family];
      if (pathId == null) continue;
      final path = FamilyMasteryCatalog.pathFor(member.family, pathId);
      if (path == null) continue;
      final owned = allNodesUnlocked
          ? _allNodesFor(member.family)
          : (purchases[member.family] ?? const <String>{});
      // An equipped path whose first node is not owned is not a build; it is
      // a stale selection, and a run must not inherit one.
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
