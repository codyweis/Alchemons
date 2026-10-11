import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'web_ads_bridge_stub.dart'
    if (dart.library.js_interop) 'web_ads_bridge_web.dart'
    as bridge;

/// Ads exist only in the browser build (alchemons.com/play). The iOS and
/// Android apps never show one: off the web every call here does nothing.
///
/// The page owns the ad network (web/ads/ads.js and web/ads/config.js), so
/// the publisher id, ad units and how often an ad may interrupt are set
/// there without rebuilding the game. This side only says *when* a pause is
/// natural and asks for rewarded ads the player chose to watch.
abstract final class WebAds {
  /// True while an ad covers the page; the audio controller hushes itself.
  static final ValueNotifier<bool> showing = ValueNotifier(false);

  /// The page has ads configured and the ad script loaded.
  static bool get enabled => kIsWeb && bridge.configured();

  /// The player has just left a run, a dungeon, a field: a natural pause.
  /// The page decides whether an ad actually shows (its own spacing, and the
  /// network's). Fire-and-forget, so it is safe to call from dispose().
  static void breakAfter(String placement) {
    if (!enabled) return;
    unawaited(
      bridge.interstitial(placement, _start, _end).catchError((Object _) {}),
    );
  }

  /// Plays a rewarded ad the player asked for. True only when the ad was
  /// watched to the end.
  static Future<bool> rewarded(String placement) async {
    if (!enabled) return false;
    try {
      return await bridge.rewarded(placement, _start, _end);
    } catch (_) {
      return false;
    } finally {
      _end();
    }
  }

  static void _start() => showing.value = true;
  static void _end() => showing.value = false;

  // ── The shop's watch-for-gold offer ─────────────────────────────────────

  /// Gold for one rewarded ad, and how many the shop offers per day.
  static const int rewardGold = 1;
  static const int rewardsPerDay = 10;

  static const _dayKey = 'webads.reward_day';
  static const _countKey = 'webads.reward_count';

  /// Rewarded ads still on offer today (resets at local midnight).
  static Future<int> rewardsLeftToday() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_dayKey) != _today()) return rewardsPerDay;
    return (rewardsPerDay - (prefs.getInt(_countKey) ?? 0)).clamp(
      0,
      rewardsPerDay,
    );
  }

  static Future<void> countReward() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    final used = prefs.getString(_dayKey) == today
        ? (prefs.getInt(_countKey) ?? 0)
        : 0;
    await prefs.setString(_dayKey, today);
    await prefs.setInt(_countKey, used + 1);
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }
}
