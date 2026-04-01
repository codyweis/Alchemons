typedef WildernessStatRange = ({
  double min,
  double max,
  double potMin,
  double potMax,
});

WildernessStatRange wildernessStatRangeForRarity(
  String rarity, {
  required bool arcaneBoostUnlocked,
}) {
  if (arcaneBoostUnlocked) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
        return (min: 2.0, max: 4.0, potMin: 2.0, potMax: 4.0);
      case 'common':
      case 'uncommon':
      case 'rare':
        return (min: 1.5, max: 2.5, potMin: 2.0, potMax: 3.0);
      default:
        return (min: 1.5, max: 2.5, potMin: 2.0, potMax: 3.0);
    }
  }

  switch (rarity.toLowerCase()) {
    case 'common':
      return (min: 1.0, max: 2.0, potMin: 1.0, potMax: 2.0);
    case 'uncommon':
      return (min: 1.0, max: 1.0, potMin: 1.0, potMax: 2.0);
    case 'rare':
      return (min: 2.0, max: 2.0, potMin: 2.0, potMax: 3.0);
    case 'legendary':
      return (min: 2.0, max: 3.0, potMin: 3.0, potMax: 4.0);
    default:
      return (min: 1.0, max: 3.0, potMin: 2.0, potMax: 4.0);
  }
}
