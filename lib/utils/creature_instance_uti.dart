import 'package:alchemons/services/game_data_service.dart';

List<CreatureEntry> filterByAvailableInstances(
  List<CreatureEntry> discovered,
  Set<String> availableIds,
) {
  return discovered
      .where((e) => availableIds.contains(e.creature.id))
      .toList(growable: false);
}
