import 'dart:async';
import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/purchase_verification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoldPackDefinition {
  final String productId;
  final String title;
  final String subtitle;
  final int goldAmount;
  final String badge;

  const GoldPackDefinition({
    required this.productId,
    required this.title,
    required this.subtitle,
    required this.goldAmount,
    required this.badge,
  });
}

/// A purchase the store has handed us that the server has not confirmed yet.
///
/// These are held on the device, outside the save, until `redeemPurchase`
/// accepts or permanently refuses them, so a purchase made on a bad connection
/// is not lost.
class _PendingRedeem {
  final String platform;
  final String productId;
  final String? transactionId;
  final String verificationData;
  final String localKey;

  const _PendingRedeem({
    required this.platform,
    required this.productId,
    required this.transactionId,
    required this.verificationData,
    required this.localKey,
  });

  Map<String, dynamic> toJson() => {
    'platform': platform,
    'productId': productId,
    'transactionId': transactionId,
    'verificationData': verificationData,
    'localKey': localKey,
  };

  static _PendingRedeem? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final platform = raw['platform'] as String?;
    final productId = raw['productId'] as String?;
    final verificationData = raw['verificationData'] as String?;
    final localKey = raw['localKey'] as String?;
    if (platform == null ||
        productId == null ||
        verificationData == null ||
        localKey == null) {
      return null;
    }
    return _PendingRedeem(
      platform: platform,
      productId: productId,
      transactionId: raw['transactionId'] as String?,
      verificationData: verificationData,
      localKey: localKey,
    );
  }
}

class MobileStoreService extends ChangeNotifier {
  MobileStoreService(this._db, this._accountService, this._verification) {
    _purchaseSub = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error, StackTrace stackTrace) {
        _lastError = 'Store stream error: $error';
        notifyListeners();
      },
    );
    _accountListener = () => unawaited(drainPendingRedeems());
    _accountService.addListener(_accountListener);
    unawaited(refreshCatalog());
    unawaited(drainPendingRedeems());
  }

  /// Device-local queue of purchases awaiting server verification.
  ///
  /// Registered in SaveTransferService as a protected preference so it never
  /// travels inside a save and is never wiped by a restore.
  static const String pendingRedeemsKey = 'iap.pending_redeems.v1';

  final AlchemonsDatabase _db;
  final AccountService _accountService;
  final PurchaseVerificationService _verification;
  final InAppPurchase _iap = InAppPurchase.instance;
  late final StreamSubscription<List<PurchaseDetails>> _purchaseSub;
  late final VoidCallback _accountListener;

  static const List<GoldPackDefinition> _catalog = [
    GoldPackDefinition(
      productId: 'alchemons_gold_cache',
      title: 'Gold Cache',
      subtitle: 'Quick refill for portal keys and summons.',
      goldAmount: 25,
      badge: 'STARTER',
    ),
    GoldPackDefinition(
      productId: 'alchemons_gold_stash',
      title: 'Gold Stash',
      subtitle: 'Balanced pack for regular premium play.',
      goldAmount: 75,
      badge: 'POPULAR',
    ),
    GoldPackDefinition(
      productId: 'alchemons_gold_vault',
      title: 'Gold Vault',
      subtitle: 'Big injection for cosmetics and unlocks.',
      goldAmount: 200,
      badge: 'VALUE',
    ),
    GoldPackDefinition(
      productId: 'alchemons_gold_celestial',
      title: 'Celestial',
      subtitle: 'Heavy stockpile for long-form progression.',
      goldAmount: 500,
      badge: 'PREMIUM',
    ),
  ];

  bool _isSupportedPlatform = false;
  bool _storeAvailable = false;
  bool _loading = true;
  bool _draining = false;
  bool _drainAgain = false;
  int _pendingRedeemCount = 0;
  String? _lastError;
  final Map<String, ProductDetails> _productsById = {};
  final Set<String> _pendingProductIds = <String>{};

  bool get isSupportedPlatform => _isSupportedPlatform;
  bool get storeAvailable => _storeAvailable;
  bool get isLoading => _loading;
  String? get lastError => _lastError;

  /// Purchases that are paid for but not yet confirmed by the server.
  int get pendingRedeemCount => _pendingRedeemCount;

  /// Gold packs are tied to an account so the purchase can be verified and
  /// restored later. Without one there is nothing to credit the receipt to.
  bool get requiresSignIn => !_accountService.isSignedIn;

  List<GoldPackDefinition> get packDefinitions => _catalog;

  ProductDetails? productFor(String productId) => _productsById[productId];

  bool isPurchasePending(String productId) =>
      _pendingProductIds.contains(productId);

  bool get canShowStore =>
      _isSupportedPlatform && (_storeAvailable || _loading);

  Future<void> refreshCatalog() async {
    _loading = true;
    _lastError = null;
    notifyListeners();

    _isSupportedPlatform =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);

    if (!_isSupportedPlatform) {
      _storeAvailable = false;
      _productsById.clear();
      _loading = false;
      notifyListeners();
      return;
    }

    try {
      _storeAvailable = await _iap.isAvailable();
      if (!_storeAvailable) {
        _productsById.clear();
        _lastError = 'Store unavailable on this device.';
        _loading = false;
        notifyListeners();
        return;
      }

      final response = await _iap.queryProductDetails(
        _catalog.map((pack) => pack.productId).toSet(),
      );

      _productsById
        ..clear()
        ..addEntries(
          response.productDetails.map(
            (product) => MapEntry(product.id, product),
          ),
        );

      if (response.error != null) {
        _lastError = response.error!.message;
      } else if (response.notFoundIDs.isNotEmpty) {
        _lastError =
            'Missing store products: ${response.notFoundIDs.join(', ')}';
      }
    } catch (error) {
      _productsById.clear();
      _storeAvailable = false;
      _lastError = 'Failed to load store: $error';
    }

    _loading = false;
    notifyListeners();

    unawaited(drainPendingRedeems());
  }

  Future<bool> purchaseGoldPack(String productId) async {
    if (requiresSignIn) {
      _lastError =
          'Sign in to your Alchemons account before buying gold, so the '
          'purchase can be restored on your other devices.';
      notifyListeners();
      return false;
    }

    final product = _productsById[productId];
    if (!_storeAvailable || product == null) {
      _lastError = 'This gold pack is not currently available.';
      notifyListeners();
      return false;
    }
    if (_pendingProductIds.contains(productId)) {
      return false;
    }

    _pendingProductIds.add(productId);
    _lastError = null;
    notifyListeners();

    final purchaseParam = PurchaseParam(productDetails: product);
    final started = await _iap.buyConsumable(
      purchaseParam: purchaseParam,
      autoConsume: true,
    );

    if (!started) {
      _pendingProductIds.remove(productId);
      _lastError = 'Store rejected the purchase request.';
      notifyListeners();
      return false;
    }

    return true;
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchase in purchaseDetailsList) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _pendingProductIds.add(purchase.productID);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _queuePurchase(purchase);
          _pendingProductIds.remove(purchase.productID);
          break;
        case PurchaseStatus.canceled:
          _pendingProductIds.remove(purchase.productID);
          break;
        case PurchaseStatus.error:
          _pendingProductIds.remove(purchase.productID);
          _lastError = purchase.error?.message ?? 'Purchase failed.';
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }

    notifyListeners();

    await drainPendingRedeems();
  }

  /// Records a paid purchase locally so it survives a crash or a dead network,
  /// then leaves it for [drainPendingRedeems] to settle.
  Future<void> _queuePurchase(PurchaseDetails purchase) async {
    final pack = _packFor(purchase.productID);
    if (pack == null) return;

    final localKey = _creditKeyForPurchase(purchase);
    if (await _db.settingsDao.getSetting(localKey) == '1') return;

    final verificationData = purchase.verificationData.serverVerificationData
        .trim();
    if (verificationData.isEmpty) {
      _lastError =
          'This purchase arrived without a store receipt and cannot be '
          'verified. Contact support with your store order id.';
      return;
    }

    final entry = _PendingRedeem(
      platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      productId: purchase.productID,
      transactionId: purchase.purchaseID,
      verificationData: verificationData,
      localKey: localKey,
    );

    final queue = await _readQueue();
    if (queue.any((existing) => existing.localKey == entry.localKey)) return;
    queue.add(entry);
    await _writeQueue(queue);
  }

  /// Works through queued purchases, crediting the ones the server confirms.
  ///
  /// Safe to call whenever: on launch, after a purchase, and whenever the
  /// signed-in account changes.
  Future<void> drainPendingRedeems() async {
    if (_draining) {
      // A purchase landed while we were working. Make sure the drain in flight
      // takes another pass rather than leaving it queued until the next launch.
      _drainAgain = true;
      return;
    }
    _draining = true;
    try {
      do {
        _drainAgain = false;
        await _drainOnce();
      } while (_drainAgain);
    } finally {
      _draining = false;
    }
  }

  Future<void> _drainOnce() async {
    var queue = await _readQueue();
    _pendingRedeemCount = queue.length;
    if (queue.isEmpty) {
      notifyListeners();
      return;
    }
    if (requiresSignIn) {
      // Keep everything queued; it redeems as soon as an account is present.
      notifyListeners();
      return;
    }

    final settled = <String>{};
    for (final entry in queue) {
      final outcome = await _verification.redeem(
        platform: entry.platform,
        productId: entry.productId,
        transactionId: entry.transactionId,
        verificationData: entry.verificationData,
      );

      switch (outcome) {
        case RedeemGranted():
          // Credit whenever this device has not already done so, even if the
          // server says it had seen this transaction before. That case means
          // an earlier attempt landed but its reply was lost, and the player is
          // still owed the gold.
          if (await _db.settingsDao.getSetting(entry.localKey) != '1') {
            await _db.currencyDao.creditPurchasedGold(outcome.goldAmount);
            await _db.settingsDao.setSetting(entry.localKey, '1');
          }
          settled.add(entry.localKey);
          break;

        case RedeemRejected(:final message):
          _lastError = message;
          settled.add(entry.localKey);
          break;

        case RedeemDeferred(:final message):
          _lastError = message;
          break;
      }
    }

    if (settled.isNotEmpty) {
      queue = queue
          .where((entry) => !settled.contains(entry.localKey))
          .toList();
      await _writeQueue(queue);
    }
    _pendingRedeemCount = queue.length;
    notifyListeners();
  }

  GoldPackDefinition? _packFor(String productId) => _catalog
      .cast<GoldPackDefinition?>()
      .firstWhere((entry) => entry?.productId == productId, orElse: () => null);

  Future<List<_PendingRedeem>> _readQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(pendingRedeemsKey);
    if (raw == null || raw.isEmpty) return <_PendingRedeem>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <_PendingRedeem>[];
      return decoded
          .map(_PendingRedeem.fromJson)
          .whereType<_PendingRedeem>()
          .toList();
    } catch (error) {
      debugPrint('Discarding unreadable pending purchase queue: $error');
      return <_PendingRedeem>[];
    }
  }

  Future<void> _writeQueue(List<_PendingRedeem> queue) async {
    final prefs = await SharedPreferences.getInstance();
    if (queue.isEmpty) {
      await prefs.remove(pendingRedeemsKey);
      return;
    }
    await prefs.setString(
      pendingRedeemsKey,
      jsonEncode(queue.map((entry) => entry.toJson()).toList()),
    );
  }

  String _creditKeyForPurchase(PurchaseDetails purchase) {
    final rawId =
        purchase.purchaseID ??
        '${purchase.productID}_${purchase.transactionDate ?? 'no_date'}';
    final safeId = rawId.replaceAll(RegExp(r'[^A-Za-z0-9_\-\.]'), '_');
    return 'iap_credit.$safeId';
  }

  @override
  void dispose() {
    _accountService.removeListener(_accountListener);
    _purchaseSub.cancel();
    super.dispose();
  }
}
