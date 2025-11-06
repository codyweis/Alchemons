// lib/widgets/util/game_data_gate.dart
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/providers/app_providers.dart'; // CatalogData
import 'package:alchemons/services/game_data_service.dart'; // CreatureEntry
import 'package:alchemons/utils/faction_util.dart'; // FactionTheme

// --- Handy selectors when you don't need the full helper ---

extension GameDataSelectors on BuildContext {
  CatalogData? watchCatalogData() => watch<CatalogData?>();
  List<CreatureEntry> watchEntriesOrEmpty() =>
      watch<List<CreatureEntry>?>() ?? const [];
  List<CreatureEntry> watchDiscoveredEntries() =>
      watchEntriesOrEmpty().where((e) => e.player.discovered).toList();
}

// --- One-shot helper you’re using in build() ---

typedef GameDataBuilder =
    Widget Function(
      BuildContext context, {
      required FactionTheme theme,
      required CatalogData catalog,
      required List<CreatureEntry> entries,
      required List<CreatureEntry> discovered,
    });

Widget withGameData(
  BuildContext context, {
  bool isInitialized = true,
  required Widget Function(FactionTheme theme, String message) loadingBuilder,
  required GameDataBuilder builder,
}) {
  final theme = context.watch<FactionTheme>();

  final catalog = context.watch<CatalogData?>();
  if (catalog == null || !catalog.isFullyLoaded || !isInitialized) {
    return loadingBuilder(theme, 'Initializing research facility...');
  }

  // NOTE: keep it nullable here to distinguish loading vs empty.
  final entriesOrNull = context.watch<List<CreatureEntry>?>();
  if (entriesOrNull == null) {
    return loadingBuilder(theme, 'Loading specimen database...');
  }

  final entries = entriesOrNull; // now non-null, may be empty and that's OK
  final discovered = entries.where((e) => e.player.discovered).toList();

  return builder(
    context,
    theme: theme,
    catalog: catalog,
    entries: entries,
    discovered: discovered,
  );
}

extension SpeciesSelectors on BuildContext {
  Set<String> watchAvailableSpecies() => watch<Set<String>?>() ?? const {};
}
