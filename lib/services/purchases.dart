import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../data/settings.dart';

/// One non-consumable product: the lifetime unlock. Create it in both stores
/// with exactly this id before testing purchases.
const kLifetimeProductId = 'gratideo_lifetime';

class Purchases {
  Purchases._();
  static final Purchases instance = Purchases._();
  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? product;
  String? lastError;

  Future<void> init(Settings settings) async {
    if (!await _iap.isAvailable()) return;
    _sub ??= _iap.purchaseStream.listen((purchases) async {
      for (final p in purchases) {
        if (p.productID != kLifetimeProductId) continue;
        if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
          await settings.setUnlocked(true);
        } else if (p.status == PurchaseStatus.error) {
          lastError = p.error?.message;
        }
        if (p.pendingCompletePurchase) await _iap.completePurchase(p);
      }
    }, onError: (Object e) => lastError = '$e');
    try {
      final r = await _iap.queryProductDetails({kLifetimeProductId});
      if (r.productDetails.isNotEmpty) product = r.productDetails.first;
      if (r.notFoundIDs.isNotEmpty) debugPrint('store product missing: ${r.notFoundIDs}');
    } catch (e) {
      lastError = '$e';
    }
  }

  String get priceLabel => product?.price ?? r'US$8.99';

  Future<void> buy() async {
    final p = product;
    if (p == null) {
      lastError = 'The store product is not set up yet.';
      return;
    }
    await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: p));
  }

  Future<void> restore() => _iap.restorePurchases();
}
