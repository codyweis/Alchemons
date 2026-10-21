// lib/games/shared/burn_healing.dart
//
// Burn: what a Fire or Lava burn leaves on the body it lands on. While it
// burns, every heal the body receives is halved. One rule for every mode that
// has enemies or creatures that heal, so it reads the same wherever it shows.

/// The share of a heal a burning body still receives.
const double kBurnHealingMultiplier = 0.5;

/// How long a body keeps burning after the last burn landed on it.
const double kBurnSeconds = 4.0;

/// [amount] as a body with [burnTimer] seconds of burn left receives it.
double healingAfterBurn(double amount, double burnTimer) =>
    burnTimer > 0 ? amount * kBurnHealingMultiplier : amount;
