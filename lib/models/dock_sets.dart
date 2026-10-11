import 'package:alchemons/models/faction.dart';

/// A look for the dock: its five tabs drawn with one of a faction's Lets,
/// standing in its element's light (widgets/nav_emblems.dart).
///
/// Each faction has three. Its [free] one comes with joining it and is kept
/// after leaving; the other two are bought in the shop while in it, and kept
/// too. Whichever are owned, one is worn.
class DockSet {
  const DockSet({
    required this.id,
    required this.faction,
    required this.letId,
    required this.name,
    required this.element,
    this.free = false,
  });

  final String id;
  final FactionId faction;

  /// The Let's species id in the creature catalog.
  final String letId;

  /// What it is called in the shop: the Let's name.
  final String name;

  /// The Let's element: the color of the light it stands in.
  final String element;

  /// The faction's own set, owned by joining it.
  final bool free;

  /// The shop offer that sells it (only sets that are not [free]).
  String get offerId => 'dock.$id';

  /// The Settings row that says it is owned (it travels with the save).
  String get settingKey => 'dock_set_owned_$id';

  /// The two Lets behind it on the Creatures tab: the rest of its faction's.
  List<DockSet> get companions => [
    for (final s in kDockSets)
      if (s.faction == faction && s.id != id) s,
  ];

  static DockSet? byId(String? id) {
    for (final s in kDockSets) {
      if (s.id == id) return s;
    }
    return null;
  }

  static DockSet? byOffer(String offerId) {
    for (final s in kDockSets) {
      if (!s.free && s.offerId == offerId) return s;
    }
    return null;
  }

  /// [faction]'s own set. No faction yet reads as Oceanic, as the home
  /// screen does.
  static DockSet of(FactionId? faction) => kDockSets.firstWhere(
    (s) => s.free && s.faction == (faction ?? FactionId.oceanic),
  );

  /// [faction]'s three, its own first.
  static List<DockSet> ofFaction(FactionId faction) => [
    for (final s in kDockSets)
      if (s.faction == faction) s,
  ];
}

/// Every dock set, by faction, each faction's own first.
const List<DockSet> kDockSets = [
  DockSet(
    id: 'firelet',
    faction: FactionId.volcanic,
    letId: 'LET01',
    name: 'Firelet',
    element: 'Fire',
    free: true,
  ),
  DockSet(
    id: 'lavalet',
    faction: FactionId.volcanic,
    letId: 'LET06',
    name: 'Lavalet',
    element: 'Lava',
  ),
  DockSet(
    id: 'lightninglet',
    faction: FactionId.volcanic,
    letId: 'LET07',
    name: 'Lightninglet',
    element: 'Lightning',
  ),
  DockSet(
    id: 'waterlet',
    faction: FactionId.oceanic,
    letId: 'LET02',
    name: 'Waterlet',
    element: 'Water',
    free: true,
  ),
  DockSet(
    id: 'icelet',
    faction: FactionId.oceanic,
    letId: 'LET09',
    name: 'Icelet',
    element: 'Ice',
  ),
  DockSet(
    id: 'steamlet',
    faction: FactionId.oceanic,
    letId: 'LET05',
    name: 'Steamlet',
    element: 'Steam',
  ),
  DockSet(
    id: 'airlet',
    faction: FactionId.verdant,
    letId: 'LET04',
    name: 'Airlet',
    element: 'Air',
    free: true,
  ),
  DockSet(
    id: 'plantlet',
    faction: FactionId.verdant,
    letId: 'LET12',
    name: 'Plantlet',
    element: 'Plant',
  ),
  DockSet(
    id: 'poisonlet',
    faction: FactionId.verdant,
    letId: 'LET13',
    name: 'Poisonlet',
    element: 'Poison',
  ),
  DockSet(
    id: 'mudlet',
    faction: FactionId.earthen,
    letId: 'LET08',
    name: 'Mudlet',
    element: 'Mud',
    free: true,
  ),
  DockSet(
    id: 'earthlet',
    faction: FactionId.earthen,
    letId: 'LET03',
    name: 'Earthlet',
    element: 'Earth',
  ),
  DockSet(
    id: 'dustlet',
    faction: FactionId.earthen,
    letId: 'LET10',
    name: 'Dustlet',
    element: 'Dust',
  ),
];
