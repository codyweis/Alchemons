import 'package:alchemons/models/faction.dart';

/// A look for the dock: its five tabs drawn with one Let, standing in its
/// element's light (widgets/nav_emblems.dart).
///
/// Each faction has three. Its [free] one comes with joining it and is kept
/// after leaving; the other two are bought in the shop while in it, and kept
/// too. Five more belong to no faction: the Athanor's ([athanorOnly]),
/// drawn from its batches, never sold, and worn whatever the faction.
/// Whichever are owned, one is worn.
class DockSet {
  const DockSet({
    required this.id,
    this.faction,
    required this.letId,
    required this.name,
    required this.element,
    this.free = false,
  });

  final String id;

  /// The faction it is sold in; null for one of the Athanor's.
  final FactionId? faction;

  /// The Let's species id in the creature catalog.
  final String letId;

  /// What it is called in the shop: the Let's name.
  final String name;

  /// The Let's element: the color of the light it stands in.
  final String element;

  /// The faction's own set, owned by joining it.
  final bool free;

  /// One of the Athanor's: drawn from its batches, never sold, worn
  /// whatever the player's faction.
  bool get athanorOnly => faction == null;

  /// The shop offer that sells it (only sets that are not [free], and not
  /// the Athanor's).
  String get offerId => 'dock.$id';

  /// The Settings row that says it is owned (it travels with the save).
  String get settingKey => 'dock_set_owned_$id';

  /// The two Lets behind it on the Creatures tab: the rest of its
  /// faction's; for one of the Athanor's, the Athanor Lets either side of
  /// it ([athanorSets] is a ring).
  List<DockSet> get companions {
    if (athanorOnly) {
      final ring = athanorSets;
      final i = ring.indexOf(this);
      return [
        ring[(i + ring.length - 1) % ring.length],
        ring[(i + 1) % ring.length],
      ];
    }
    return [
      for (final s in kDockSets)
        if (s.faction == faction && s.id != id) s,
    ];
  }

  /// The Athanor's sets, in its batches' order.
  static List<DockSet> get athanorSets => [
    for (final s in kDockSets)
      if (s.athanorOnly) s,
  ];

  static DockSet? byId(String? id) {
    for (final s in kDockSets) {
      if (s.id == id) return s;
    }
    return null;
  }

  static DockSet? byOffer(String offerId) {
    for (final s in kDockSets) {
      if (!s.free && !s.athanorOnly && s.offerId == offerId) return s;
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

/// Every dock set, by faction, each faction's own first; then the
/// Athanor's.
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
  // The Athanor's, one to a batch (docs/athanor/pieces_wearables.md): no
  // faction, never sold.
  DockSet(id: 'darklet', letId: 'LET15', name: 'Darklet', element: 'Dark'),
  DockSet(
    id: 'spiritlet',
    letId: 'LET14',
    name: 'Spiritlet',
    element: 'Spirit',
  ),
  DockSet(id: 'lightlet', letId: 'LET16', name: 'Lightlet', element: 'Light'),
  DockSet(id: 'bloodlet', letId: 'LET17', name: 'Bloodlet', element: 'Blood'),
  DockSet(
    id: 'crystalet',
    letId: 'LET11',
    name: 'Crystalet',
    element: 'Crystal',
  ),
];
