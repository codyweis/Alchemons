import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountTransferException implements Exception {
  final String message;

  const AccountTransferException(this.message);

  @override
  String toString() => message;
}

class ParsedTransferCode {
  final String transferId;
  final String saveCode;

  const ParsedTransferCode({required this.transferId, required this.saveCode});
}

class AccountTransferService {
  static const String _prefix = 'ALCHEMONS_TRANSFER_V1:';
  static const String _pendingTransferCodeKey = 'account.pending_transfer_code';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _sessionDoc(String uid) =>
      _firestore.collection('account_sessions').doc(uid);

  DocumentReference<Map<String, dynamic>> _transferDoc(String transferId) =>
      _firestore.collection('account_transfers').doc(transferId);

  Future<String> createTransferCode({
    required String uid,
    required String sourceDeviceId,
    required String saveCode,
  }) async {
    final transferRef = _firestore.collection('account_transfers').doc();
    try {
      await _firestore.runTransaction((transaction) async {
        final sessionRef = _sessionDoc(uid);
        final sessionSnap = await transaction.get(sessionRef);
        final session = sessionSnap.data();
        final activeDeviceId = session?['activeDeviceId'] as String?;
        final status = session?['status'] as String?;
        final pendingTransferId = session?['pendingTransferId'] as String?;
        final activeEmail = session?['activeEmail'] as String?;
        final activeDisplayName = session?['activeDisplayName'] as String?;

        if (activeDeviceId != sourceDeviceId) {
          throw const AccountTransferException(
            'Only the active device can create a transfer.',
          );
        }
        if (status == 'transfer_pending' &&
            pendingTransferId != null &&
            pendingTransferId.isNotEmpty) {
          throw const AccountTransferException(
            'A transfer is already pending for this account.',
          );
        }

        transaction.set(transferRef, {
          'uid': uid,
          'sourceDeviceId': sourceDeviceId,
          'status': 'open',
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.set(
          sessionRef,
          _sessionDocData(
            activeDeviceId: sourceDeviceId,
            activeEmail: activeEmail,
            activeDisplayName: activeDisplayName,
            status: 'transfer_pending',
            pendingTransferId: transferRef.id,
          ),
        );
      });
    } on FirebaseException catch (error) {
      throw AccountTransferException(_friendlyFirestoreError(error));
    }

    final payload = <String, dynamic>{
      'transferId': transferRef.id,
      'saveCode': saveCode,
    };
    final code = '$_prefix${base64UrlEncode(utf8.encode(jsonEncode(payload)))}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingTransferCodeKey, code);
    return code;
  }

  ParsedTransferCode parseTransferCode(String transferCode) {
    final trimmed = transferCode.trim();
    if (!trimmed.startsWith(_prefix)) {
      throw const AccountTransferException(
        'Transfer code is missing the expected header.',
      );
    }

    try {
      final decoded = utf8.decode(
        base64Url.decode(trimmed.substring(_prefix.length)),
      );
      final payload = jsonDecode(decoded) as Map<String, dynamic>;
      final transferId = payload['transferId'] as String?;
      final saveCode = payload['saveCode'] as String?;
      if (transferId == null ||
          transferId.isEmpty ||
          saveCode == null ||
          saveCode.isEmpty) {
        throw const AccountTransferException('Transfer code is incomplete.');
      }
      return ParsedTransferCode(transferId: transferId, saveCode: saveCode);
    } on AccountTransferException {
      rethrow;
    } catch (_) {
      throw const AccountTransferException(
        'Transfer code could not be decoded.',
      );
    }
  }

  Future<String> consumeTransferCode({
    required String uid,
    required String targetDeviceId,
    required String transferCode,
  }) async {
    final parsed = parseTransferCode(transferCode);

    try {
      await _firestore.runTransaction((transaction) async {
        final transferRef = _transferDoc(parsed.transferId);
        final transferSnap = await transaction.get(transferRef);
        final transfer = transferSnap.data();
        if (transfer == null) {
          throw const AccountTransferException('Transfer was not found.');
        }

        final ownerUid = transfer['uid'] as String?;
        final status = transfer['status'] as String?;
        if (ownerUid != uid) {
          throw const AccountTransferException(
            'This transfer belongs to a different account.',
          );
        }
        if (status != 'open') {
          throw const AccountTransferException(
            'This transfer code has already been used.',
          );
        }

        final sessionRef = _sessionDoc(uid);
        final sessionSnap = await transaction.get(sessionRef);
        final session = sessionSnap.data();

        transaction.set(transferRef, {
          'status': 'consumed',
          'targetDeviceId': targetDeviceId,
          'consumedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        transaction.set(
          sessionRef,
          _sessionDocData(
            activeDeviceId: targetDeviceId,
            activeEmail: session?['activeEmail'] as String?,
            activeDisplayName: session?['activeDisplayName'] as String?,
            status: 'active',
          ),
        );
      });
    } on FirebaseException catch (error) {
      throw AccountTransferException(_friendlyFirestoreError(error));
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingTransferCodeKey);
    return parsed.saveCode;
  }

  Future<void> cancelPendingTransfer({
    required String uid,
    required String sourceDeviceId,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final sessionRef = _sessionDoc(uid);
        final sessionSnap = await transaction.get(sessionRef);
        final session = sessionSnap.data();
        final activeDeviceId = session?['activeDeviceId'] as String?;
        final pendingTransferId = session?['pendingTransferId'] as String?;
        final status = session?['status'] as String?;
        final activeEmail = session?['activeEmail'] as String?;
        final activeDisplayName = session?['activeDisplayName'] as String?;

        if (activeDeviceId != sourceDeviceId) {
          throw const AccountTransferException(
            'Only the active device can cancel a pending transfer.',
          );
        }
        if (status != 'transfer_pending' ||
            pendingTransferId == null ||
            pendingTransferId.isEmpty) {
          throw const AccountTransferException('No transfer is pending.');
        }

        transaction.set(_transferDoc(pendingTransferId), {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        transaction.set(
          sessionRef,
          _sessionDocData(
            activeDeviceId: sourceDeviceId,
            activeEmail: activeEmail,
            activeDisplayName: activeDisplayName,
            status: 'active',
          ),
        );
      });
    } on FirebaseException catch (error) {
      throw AccountTransferException(_friendlyFirestoreError(error));
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingTransferCodeKey);
  }

  Future<String?> getPendingTransferCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingTransferCodeKey);
  }

  Map<String, Object?> _sessionDocData({
    required String activeDeviceId,
    required String? activeEmail,
    required String? activeDisplayName,
    required String status,
    String? pendingTransferId,
  }) {
    return <String, Object?>{
      'activeDeviceId': activeDeviceId,
      'activeEmail': activeEmail,
      'activeDisplayName': activeDisplayName,
      'status': status,
      'pendingTransferId': pendingTransferId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  String _friendlyFirestoreError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'This transfer belongs to a different account, login to the correct account.';
      case 'not-found':
        return 'Transfer was not found.';
      case 'unavailable':
        return 'Transfer service is temporarily unavailable.';
      default:
        final message = error.message?.trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
        return 'Transfer request failed (${error.code}).';
    }
  }
}
