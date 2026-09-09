import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:alchemons/database/alchemons_db.dart';

/// Account generations retire all saves from before a reset.
class SaveGenerationService {
  static const settingKey = 'account.save_generation';
  static const ownerKey = 'account.save_owner';

  static Future<int> local(AlchemonsDatabase db) async =>
      int.tryParse(await db.settingsDao.getSetting(settingKey) ?? '0') ?? 0;

  static Map<String, dynamic> payload(String code) {
    final v2 = code.startsWith('ALCHEMONS_SAVE_V2:');
    final prefix = v2 ? 'ALCHEMONS_SAVE_V2:' : 'ALCHEMONS_SAVE_V1:';
    if (!code.startsWith(prefix)) throw StateError('Invalid save header.');
    final bytes = base64Url.decode(code.substring(prefix.length));
    return jsonDecode(
          utf8.decode(v2 ? GZipDecoder().decodeBytes(bytes) : bytes),
        )
        as Map<String, dynamic>;
  }

  static int codeGeneration(String code) =>
      (payload(code)['generation'] as num?)?.toInt() ?? 0;

  static Future<void> validate(String uid, int generation) async {
    final snapshot = await FirebaseFirestore.instance
        .doc('account_progress/$uid')
        .get(const GetOptions(source: Source.server));
    final data = snapshot.data();
    if (data?['resetPending'] == true) {
      throw StateError(
        'Finish the pending reset on its original device first.',
      );
    }
    if (((data?['generation'] as num?)?.toInt() ?? 0) != generation) {
      throw StateError(
        'This save is from before an account reset. Restore the latest account backup.',
      );
    }
  }
}
