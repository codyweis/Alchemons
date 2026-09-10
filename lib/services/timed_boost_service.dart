import 'package:alchemons/database/daos/settings_dao.dart';
import 'package:flutter/foundation.dart';

/// Boosts that run on a clock rather than being spent.
///
/// The first of them halves cultivation time. It is bought, awarded, and
/// handed out at the start of a save, so three different paths can switch it
/// on and they all have to agree about when it ends — hence one service with
/// one stored expiry rather than a flag per source.
///
/// The expiry is an absolute UTC timestamp, so it keeps running while the app
/// is closed. That is the honest reading of "24 hours": the player was told a
/// day, not a day of screen time.
class TimedBoostService extends ChangeNotifier {
  TimedBoostService(this._settings);

  final SettingsDao _settings;

  static const halfCultivationKey = 'boost.half_cultivation_until_ms';
  static const halfCultivationDuration = Duration(hours: 24);

  /// The multiplier a live boost applies to a new cultivation.
  static const halfCultivationMultiplier = 0.5;

  DateTime? _halfCultivationUntil;

  /// Read synchronously by the cultivation maths, which runs inside a
  /// non-async modifier chain, so the value is cached rather than fetched.
  DateTime? get halfCultivationUntil => _halfCultivationUntil;

  bool get halfCultivationActive {
    final until = _halfCultivationUntil;
    return until != null && until.isAfter(DateTime.now().toUtc());
  }

  Duration get halfCultivationRemaining {
    final until = _halfCultivationUntil;
    if (until == null) return Duration.zero;
    final left = until.difference(DateTime.now().toUtc());
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> load() async {
    final raw = await _settings.getSetting(halfCultivationKey);
    final ms = int.tryParse(raw ?? '');
    _halfCultivationUntil = ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    notifyListeners();
  }

  /// Starts the boost, or pushes an already-running one further out.
  ///
  /// Extending rather than replacing matters because the same boost arrives
  /// from a shop purchase, a species milestone and the opening grant: a
  /// player who buys one an hour into the free day should not lose the hour
  /// they had left.
  Future<void> grantHalfCultivation({
    Duration duration = halfCultivationDuration,
  }) async {
    final now = DateTime.now().toUtc();
    final base = halfCultivationActive ? _halfCultivationUntil! : now;
    final until = base.add(duration);
    _halfCultivationUntil = until;
    await _settings.setSetting(
      halfCultivationKey,
      '${until.millisecondsSinceEpoch}',
    );
    notifyListeners();
  }

  /// Whether the boost has ever been handed out on this save — the opening
  /// grant is once per account, not once per launch.
  static const openingGrantKey = 'boost.half_cultivation_opening_v1';

  Future<bool> openingGrantGiven() async =>
      await _settings.getSetting(openingGrantKey) == '1';

  Future<void> giveOpeningGrant() async {
    if (await openingGrantGiven()) return;
    await _settings.setSetting(openingGrantKey, '1');
    await grantHalfCultivation();
  }

  /// Drops a lapsed boost so listeners repaint once when it ends. Cheap
  /// enough to call from the countdown that is already ticking.
  void pruneExpired() {
    if (_halfCultivationUntil == null) return;
    if (halfCultivationActive) return;
    _halfCultivationUntil = null;
    notifyListeners();
  }
}
