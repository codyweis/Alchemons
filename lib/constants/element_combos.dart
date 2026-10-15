// lib/constants/element_combos.dart
//
// The element recipes: two elements that make a third, every time. One
// table for every place elements combine — the dungeons' verbs and the
// Works' Refinery — so a combination learned in one holds in the other.
//
// Read as a ladder: the four classical elements make the first compounds,
// those make Crystal and Spirit, and Spirit makes Light and Dark, which make
// Blood. Fire and Earth are never made; they are only found.

const Map<String, String> kElementCombos = {
  'Air+Fire': 'Lightning',
  'Earth+Fire': 'Lava',
  'Ice+Lava': 'Steam',
  'Fire+Water': 'Steam',
  'Plant+Fire': 'Dust',
  'Air+Earth': 'Dust',
  'Spirit+Water': 'Ice',
  'Plant+Water': 'Mud',
  'Lava+Mud': 'Poison',
  'Plant+Mud': 'Poison',
  'Earth+Lightning': 'Crystal',
  'Dust+Spirit': 'Crystal',
  'Lightning+Crystal': 'Spirit',
  'Crystal+Spirit': 'Light',
  'Poison+Spirit': 'Dark',
  'Dark+Light': 'Blood',
  'Mud+Light': 'Plant',
  'Ice+Light': 'Air',
  'Air+Ice': 'Water',
};

/// Element produced by combining [a] and [b] (order-independent), or null.
String? elementComboResult(String a, String b) =>
    kElementCombos['$a+$b'] ?? kElementCombos['$b+$a'];
