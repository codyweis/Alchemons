import 'dart:async';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

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

class MobileStoreService extends ChangeNotifier {
  MobileStoreService(this._db) {
    _purchaseSub = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error, StackTrace stackTrace) {
        _lastError = 'Store stream error: $error';
        notifyListeners();
      },
    );
    unawaited(refreshCatalog());
  }

  final AlchemonsDatabase _db;
  final InAppPurchase _iap = InAppPurchase.instance;
  late final StreamSubscription<List<PurchaseDetails>> _purchaseSub;

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
      title: 'Celestial Reserve',
      subtitle: 'Heavy stockpile for long-form progression.',
      goldAmount: 500,
      badge: 'PREMIUM',
    ),
  ];

  bool _isSupportedPlatform = false;
  bool _storeAvailable = false;
  bool _loading = true;
  String? _lastError;
  final Map<String, ProductDetails> _productsById = {};
  final Set<String> _pendingProductIds = <String>{};

  bool get isSupportedPlatform => _isSupportedPlatform;
  bool get storeAvailable => _storeAvailable;
  bool get isLoading => _loading;
  String? get lastError => _lastError;

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
  }

  Future<bool> purchaseGoldPack(String productId) async {
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
          await _deliverPurchase(purchase);
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
  }

  Future<void> _deliverPurchase(PurchaseDetails purchase) async {
    final pack = _catalog.cast<GoldPackDefinition?>().firstWhere(
      (entry) => entry?.productId == purchase.productID,
      orElse: () => null,
    );
    if (pack == null) return;

    final purchaseKey = _creditKeyForPurchase(purchase);
    final alreadyCredited =
        await _db.settingsDao.getSetting(purchaseKey) == '1';
    if (alreadyCredited) return;

    await _db.currencyDao.addGold(pack.goldAmount);
    await _db.settingsDao.setSetting(purchaseKey, '1');
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
    _purchaseSub.cancel();
    super.dispose();
  }
}
