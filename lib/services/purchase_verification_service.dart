// lib/services/purchase_verification_service.dart
//
// Client half of the purchase ledger. Sends a store receipt to the
// `redeemPurchase` Cloud Function, which is the only thing allowed to decide
// that a purchase is real and how much gold it is worth.
//
// Nothing here credits gold. It reports what the server said; MobileStoreService
// decides what to do about it.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Result of asking the server to redeem a purchase.
sealed class RedeemOutcome {
  const RedeemOutcome();
}

/// The server verified the receipt and recorded it against this account.
class RedeemGranted extends RedeemOutcome {
  final int goldAmount;
  final String ledgerId;

  /// False when this account had already redeemed the same transaction, which
  /// happens when our first attempt reached the server but its reply did not.
  final bool firstRedeem;
  final bool includedInReset;

  const RedeemGranted({
    required this.goldAmount,
    required this.ledgerId,
    required this.firstRedeem,
    this.includedInReset = false,
  });
}

/// The server refused permanently: a bad receipt, or one already spent on
/// another account. Retrying will never help, so the purchase is dropped.
class RedeemRejected extends RedeemOutcome {
  final String message;

  const RedeemRejected(this.message);
}

/// We could not get an answer. The purchase stays queued and is retried later.
class RedeemDeferred extends RedeemOutcome {
  final String message;

  const RedeemDeferred(this.message);
}

class PurchaseVerificationService {
  PurchaseVerificationService({FirebaseFunctions? functions})
    : _functions = functions;

  final FirebaseFunctions? _functions;

  FirebaseFunctions get _fn => _functions ?? FirebaseFunctions.instance;

  Future<RedeemOutcome> redeem({
    required String platform,
    required String productId,
    required String? transactionId,
    required String verificationData,
  }) async {
    try {
      final callable = _fn.httpsCallable('redeemPurchase');
      final response = await callable.call<Map<String, dynamic>>({
        'platform': platform,
        'productId': productId,
        'transactionId': transactionId,
        'verificationData': verificationData,
      });

      final data = response.data;
      final goldAmount = (data['goldAmount'] as num?)?.toInt();
      final ledgerId = data['ledgerId'] as String?;
      if (goldAmount == null || goldAmount <= 0 || ledgerId == null) {
        return const RedeemDeferred(
          'The store server returned an unexpected response.',
        );
      }

      return RedeemGranted(
        goldAmount: goldAmount,
        ledgerId: ledgerId,
        firstRedeem: data['firstRedeem'] as bool? ?? true,
        includedInReset: data['includedInReset'] == true,
      );
    } on FirebaseFunctionsException catch (error) {
      final message = error.message?.trim().isNotEmpty == true
          ? error.message!.trim()
          : 'Purchase verification failed (${error.code}).';

      switch (error.code) {
        // Permanent: the receipt is not valid, is not ours to redeem, or names
        // a product the server does not sell.
        case 'permission-denied':
        case 'failed-precondition':
        case 'invalid-argument':
          return RedeemRejected(message);

        // Everything else is worth another try: no network, the store's API is
        // down, the player is briefly signed out, our own misconfiguration.
        default:
          return RedeemDeferred(message);
      }
    } catch (error) {
      debugPrint('redeemPurchase call failed: $error');
      return RedeemDeferred('Could not reach the purchase server.');
    }
  }
}
