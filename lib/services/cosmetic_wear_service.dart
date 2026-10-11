// What is worn of the Athanor's case styles, trails, fusion styles and home
// ambiences (lib/models/cosmetic_wear.dart), and what is owned of them
// (OwnedCosmetics). Only owned things can be worn: [wearCase] and the rest
// refuse anything else and change nothing, and what is read back is always
// filtered to what is owned.
//
// It reloads when the Athanor changes (a pour can grant one) and after a
// save restore. It keeps [FusionStyle.worn] for the fusion's fields, which
// are made without a context.

import 'dart:async';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/athanor.dart';
import 'package:alchemons/models/cosmetic_wear.dart';
import 'package:alchemons/models/owned_cosmetics.dart';
import 'package:flutter/foundation.dart';

class CosmeticWearService extends ChangeNotifier {
  CosmeticWearService(this.db, {Listenable? refreshOn})
    : _refreshOn = refreshOn {
    _refreshOn?.addListener(_refresh);
  }

  final AlchemonsDatabase db;
  final Listenable? _refreshOn;

  Map<AthanorPieceKind, Set<String>> _owned = const {};
  CosmeticWear _saved = CosmeticWear.empty;
  CosmeticWear _worn = CosmeticWear.empty;
  bool _loaded = false;
  bool _disposed = false;

  bool get loaded => _loaded;

  void _refresh() => unawaited(load());

  /// Reads what is owned and worn. Safe to call again.
  Future<void> load() async {
    final s = db.settingsDao;
    final owned = OwnedCosmetics.decode(await s.getSetting(OwnedCosmetics.key));
    final saved = CosmeticWear.decode(
      cases: await s.getSetting(CosmeticWear.caseKey),
      trails: await s.getSetting(CosmeticWear.trailKey),
      fusion: await s.getSetting(CosmeticWear.fusionKey),
      ambience: await s.getSetting(CosmeticWear.ambienceKey),
    );
    if (_disposed) return;
    _owned = owned;
    _saved = saved;
    _worn = saved.owned(owned);
    _loaded = true;
    FusionStyle.worn.value = _worn.fusion;
    notifyListeners();
  }

  // ── owned ────────────────────────────────────────────────────────────

  Set<String> _ids(AthanorPieceKind kind) => _owned[kind] ?? const {};

  List<CaseStyle> get ownedCases => [
    for (final s in CaseStyle.values)
      if (_ids(AthanorPieceKind.caseStyle).contains(s.id)) s,
  ];

  List<TrailStyle> get ownedTrails => [
    for (final s in TrailStyle.values)
      if (_ids(AthanorPieceKind.trail).contains(s.id)) s,
  ];

  List<FusionStyle> get ownedFusionStyles => [
    for (final s in FusionStyle.values)
      if (_ids(AthanorPieceKind.fusionStyle).contains(s.id)) s,
  ];

  List<HomeAmbience> get ownedAmbiences => [
    for (final s in HomeAmbience.values)
      if (_ids(AthanorPieceKind.ambience).contains(s.id)) s,
  ];

  // ── worn ─────────────────────────────────────────────────────────────

  CaseStyle? caseOf(String instanceId) => _worn.cases[instanceId];
  TrailStyle? trailOf(String instanceId) => _worn.trails[instanceId];
  FusionStyle? get fusionStyle => _worn.fusion;
  HomeAmbience? ambienceIn(String realm) => _worn.ambience[realm];

  /// Stands [instanceId] in [style], or the plain case for null. False, and
  /// nothing changes, for a style not owned.
  Future<bool> wearCase(String instanceId, CaseStyle? style) => _wear(
    AthanorPieceKind.caseStyle,
    style?.id,
    (w) => CosmeticWear(
      cases: _put(w.cases, instanceId, style),
      trails: w.trails,
      fusion: w.fusion,
      ambience: w.ambience,
    ),
    CosmeticWear.caseKey,
    (w) => CosmeticWear.encodeMap(w.cases, (s) => s.id),
  );

  /// Gives [instanceId] [trail], or none for null.
  Future<bool> wearTrail(String instanceId, TrailStyle? trail) => _wear(
    AthanorPieceKind.trail,
    trail?.id,
    (w) => CosmeticWear(
      cases: w.cases,
      trails: _put(w.trails, instanceId, trail),
      fusion: w.fusion,
      ambience: w.ambience,
    ),
    CosmeticWear.trailKey,
    (w) => CosmeticWear.encodeMap(w.trails, (s) => s.id),
  );

  /// Plays every fusion in [style], or the plain fusion for null.
  Future<bool> wearFusionStyle(FusionStyle? style) => _wear(
    AthanorPieceKind.fusionStyle,
    style?.id,
    (w) => CosmeticWear(
      cases: w.cases,
      trails: w.trails,
      fusion: style,
      ambience: w.ambience,
    ),
    CosmeticWear.fusionKey,
    (w) => w.fusion?.id ?? '',
  );

  /// Lays [ambience] over the home realm [realm] (`HomeRealm.name`), or
  /// none for null.
  Future<bool> wearAmbience(String realm, HomeAmbience? ambience) => _wear(
    AthanorPieceKind.ambience,
    ambience?.id,
    (w) => CosmeticWear(
      cases: w.cases,
      trails: w.trails,
      fusion: w.fusion,
      ambience: _put(w.ambience, realm, ambience),
    ),
    CosmeticWear.ambienceKey,
    (w) => CosmeticWear.encodeMap(w.ambience, (s) => s.id),
  );

  static Map<String, T> _put<T>(Map<String, T> map, String key, T? value) {
    final out = {...map};
    if (value == null) {
      out.remove(key);
    } else {
      out[key] = value;
    }
    return out;
  }

  Future<bool> _wear(
    AthanorPieceKind kind,
    String? id,
    CosmeticWear Function(CosmeticWear) change,
    String key,
    String Function(CosmeticWear) encode,
  ) async {
    final ok = await db.transaction(() async {
      final s = db.settingsDao;
      final owned = OwnedCosmetics.decode(
        await s.getSetting(OwnedCosmetics.key),
      );
      if (id != null && !(owned[kind]?.contains(id) ?? false)) return false;
      final saved = CosmeticWear.decode(
        cases: await s.getSetting(CosmeticWear.caseKey),
        trails: await s.getSetting(CosmeticWear.trailKey),
        fusion: await s.getSetting(CosmeticWear.fusionKey),
        ambience: await s.getSetting(CosmeticWear.ambienceKey),
      );
      final next = change(saved);
      await s.setSetting(key, encode(next));
      _owned = owned;
      _saved = next;
      return true;
    });
    if (!ok || _disposed) return ok;
    _worn = _saved.owned(_owned);
    FusionStyle.worn.value = _worn.fusion;
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshOn?.removeListener(_refresh);
    super.dispose();
  }
}
