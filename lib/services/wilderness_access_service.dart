// lib/services/wilderness_access_service.dart
import 'package:alchemons/database/alchemons_db.dart';

class WildernessAccessService {
  final AlchemonsDatabase db;
  WildernessAccessService(this.db);

  // key example: wl_access::<sceneId>
  String _key(String sceneId) => 'wl_access::$sceneId::last_day_yyyymmdd';

  String _todayStampLocal() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d'; // YYYY-MM-DD
  }

  Future<bool> canEnter(String sceneId) async {
    final last = await db.getSetting(_key(sceneId));
    return last != _todayStampLocal();
  }

  Future<void> markEntered(String sceneId) async {
    await db.setSetting(_key(sceneId), _todayStampLocal());
  }

  /// For countdown UI until reset (midnight local)
  Duration timeUntilReset() {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1); // local midnight+
    return next.difference(now);
  }

  Future<void> refreshWilderness(String sceneId) async {
    await db.setSetting(
      'wl_access::$sceneId::last_day_yyyymmdd',
      '',
    ); // or remove
  }
}
