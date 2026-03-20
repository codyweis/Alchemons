import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdentityService {
  static const String _deviceIdKey = 'account.device_id.v1';
  static const Uuid _uuid = Uuid();

  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final next = _uuid.v4();
    await prefs.setString(_deviceIdKey, next);
    return next;
  }

  Future<String> rotateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final next = _uuid.v4();
    await prefs.setString(_deviceIdKey, next);
    return next;
  }
}
