import 'package:cloud_firestore/cloud_firestore.dart';

class AccountCloudSaveException implements Exception {
  final String message;

  const AccountCloudSaveException(this.message);

  @override
  String toString() => message;
}

class AccountCloudSaveSnapshot {
  final int revision;
  final DateTime? updatedAt;

  const AccountCloudSaveSnapshot({
    required this.revision,
    required this.updatedAt,
  });
}

class AccountCloudSaveService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection('account_cloud_saves').doc(uid);

  Future<AccountCloudSaveSnapshot?> getSnapshot(String uid) async {
    try {
      final snapshot = await _doc(uid).get();
      final data = snapshot.data();
      if (data == null) {
        return null;
      }
      return AccountCloudSaveSnapshot(
        revision: (data['revision'] as num?)?.toInt() ?? 0,
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      );
    } on FirebaseException catch (error) {
      throw AccountCloudSaveException(_friendlyFirestoreError(error));
    }
  }

  Future<AccountCloudSaveSnapshot> uploadSave({
    required String uid,
    required String sourceDeviceId,
    required String saveCode,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final ref = _doc(uid);
        final snapshot = await transaction.get(ref);
        final data = snapshot.data();
        final nextRevision = ((data?['revision'] as num?)?.toInt() ?? 0) + 1;

        transaction.set(ref, {
          'uid': uid,
          'sourceDeviceId': sourceDeviceId,
          'saveCode': saveCode,
          'revision': nextRevision,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return AccountCloudSaveSnapshot(
          revision: nextRevision,
          updatedAt: null,
        );
      });
    } on FirebaseException catch (error) {
      throw AccountCloudSaveException(_friendlyFirestoreError(error));
    }
  }

  Future<String> downloadSaveCode(String uid) async {
    try {
      final snapshot = await _doc(uid).get();
      final data = snapshot.data();
      if (data == null) {
        throw const AccountCloudSaveException(
          'No account backup exists yet. Back up this account from the active device first.',
        );
      }

      final ownerUid = data['uid'] as String?;
      final saveCode = data['saveCode'] as String?;
      if (ownerUid != uid || saveCode == null || saveCode.isEmpty) {
        throw const AccountCloudSaveException(
          'The stored account backup is incomplete.',
        );
      }
      return saveCode;
    } on FirebaseException catch (error) {
      throw AccountCloudSaveException(_friendlyFirestoreError(error));
    }
  }

  String _friendlyFirestoreError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Cloud save access was blocked by Firestore rules. Deploy the latest rules, then try again.';
      case 'invalid-argument':
        return 'The account backup is too large for cloud save storage.';
      case 'not-found':
        return 'Cloud save was not found.';
      case 'resource-exhausted':
        return 'The account backup is too large for cloud save storage.';
      case 'unavailable':
        return 'Cloud save service is temporarily unavailable.';
      default:
        final message = error.message?.trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
        return 'Cloud save request failed (${error.code}).';
    }
  }
}
