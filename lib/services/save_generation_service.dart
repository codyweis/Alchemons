import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:alchemons/database/alchemons_db.dart';

/// The game on this device belongs to a different account than the one
/// asking to use it.
class SaveOwnershipException implements Exception {
  const SaveOwnershipException();

  String get message =>
      'The game on this device belongs to a different account. Sign into '
      'that account to keep playing it, restore this account\'s backup, or '
      'start a new game for this account.';

  @override
  String toString() => message;
}

/// Account generations retire all saves from before a reset.
class SaveGenerationService {
  static const settingKey = 'account.save_generation';
  static const ownerKey = 'account.save_owner';

  /// The account this device's game belongs to, or null for a guest game that
  /// has never been tied to one.
  static Future<String?> owner(AlchemonsDatabase db) async {
    final value = await db.settingsDao.getSetting(ownerKey);
    return value == null || value.isEmpty ? null : value;
  }

  /// Ties a guest game to [uid], or confirms it already belongs to [uid].
  ///
  /// A game that belongs to another account is never handed over. Without
  /// this, signing out and into a second account (or creating one) let that
  /// account claim the device and back up the first account's game, gold
  /// included, as its own, as many times as there were accounts. The other
  /// account can restore its own backup here, or start a new game, which
  /// leaves a guest game for it to take.
  static Future<void> claimFor(AlchemonsDatabase db, String uid) async {
    final current = await owner(db);
    if (current == null) {
      await db.settingsDao.setSetting(ownerKey, uid);
    } else if (current != uid) {
      throw const SaveOwnershipException();
    }
  }

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
