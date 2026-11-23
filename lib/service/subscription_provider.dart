import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class SubscriptionProvider with ChangeNotifier {
  static const String _trialStartDateKey = 'trial_start_date_v1';
  static const String _premiumOverrideKey = 'premium_override_enabled';
  // Set once the store confirms the purchase, so a buyer keeps access after
  // the trial ends even before the store answers on the next launch.
  static const String _premiumPurchasedKey = 'premium_purchased_v1';
  static const int _trialDurationDays = 15;

  // REPLACE THIS with your actual Product ID from Google Play Console
  static const String _productID = 'lifetime_subscription_199';

  // in_app_purchase only has Android and iOS/macOS implementations. On web,
  // Windows and Linux every call into it throws, so we skip it there.
  static bool get _isStoreSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  // Lazy so the plugin is never touched on unsupported platforms.
  InAppPurchase get _iap => InAppPurchase.instance;
  bool _available = _isStoreSupported;
  List<ProductDetails> _products = [];
  bool _isPremium = false;
  bool _isTrialActive = true;
  bool _loading = true;
  int _daysLeft = 15;

  bool get isPremium => _isPremium;
  bool get isTrialActive => _isTrialActive;
  bool get isLoading => _loading;
  int get daysLeft => _daysLeft;
  List<ProductDetails> get products => _products;
  bool get canAccessApp => _isPremium || _isTrialActive;

  SubscriptionProvider() {
    _init();
  }

  Future<void> _init() async {
    try {
      // 1. Check Trial Status & Local Override
      await _checkTrialStatus();

      // 2. Initialize IAP. Always listen to the purchase stream so purchases
      // that were still pending last time get completed.
      await _initIAP();

      // 3. Ask the store for past purchases (e.g. after a reinstall or
      // "Clear storage"). Results arrive on the purchase stream. On Android
      // this is silent; on iOS it can show a sign-in prompt, so we only do
      // it automatically on Android.
      if (!_isPremium &&
          _available &&
          defaultTargetPlatform == TargetPlatform.android) {
        await _iap.restorePurchases();
      }
    } catch (e) {
      debugPrint('SubscriptionProvider init failed: $e');
    } finally {
      // Always finish loading, otherwise the splash screen waits on us.
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _checkTrialStatus() async {
    final prefs = await SharedPreferences.getInstance();

    // Check Manual Override
    final bool isOverridden = prefs.getBool(_premiumOverrideKey) ?? false;
    if (isOverridden) {
      _isPremium = true;
      _isTrialActive = false; // Not needed
      _daysLeft = 9999;
      return;
    }

    if (prefs.getBool(_premiumPurchasedKey) ?? false) {
      _isPremium = true;
    }

    String? startDateStr = prefs.getString(_trialStartDateKey);

    DateTime startDate;
    if (startDateStr == null) {
      // First run ever
      startDate = DateTime.now();
      await prefs.setString(_trialStartDateKey, startDate.toIso8601String());
    } else {
      startDate = DateTime.parse(startDateStr);
    }

    final daysPassed = DateTime.now().difference(startDate).inDays;
    _daysLeft = (_trialDurationDays - daysPassed).clamp(0, _trialDurationDays);
    _isTrialActive = daysPassed < _trialDurationDays;
  }

  Future<void> _initIAP() async {
    if (!_isStoreSupported) {
      _available = false;
      return;
    }
    _available = await _iap.isAvailable();
    if (!_available) {
      return;
    }

    // Listen to purchase updates (buys, restores)
    // IMPORTANT: This stream should be listened to as early as possible
    _iap.purchaseStream.listen(
      (List<PurchaseDetails> purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () {},
      onError: (error) {},
    );

    // Query Products
    const Set<String> kIds = {_productID};
    final ProductDetailsResponse response = await _iap.queryProductDetails(
      kIds,
    );
    if (response.notFoundIDs.isNotEmpty) {
      // Handle missing IDs if necessary
    }
    _products = response.productDetails;

    // Check local receipts or wait for restore (optional, but restore is better for reinstall)
    // Note: On iOS, restorePurchases usually prompts for password. On Android, it's often silent.
    // We can just rely on the stream updates if the store cache is fresh,
    // but explicit restore is often triggered by user button.
    // However, 'pastPurchases' might be available immediately on Android?
    // For now we assume 'not premium' until we get a purchased event or user clicks 'Restore'.
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // UI can show pending state
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          // Handle error
        } else if ((purchaseDetails.status == PurchaseStatus.purchased ||
                purchaseDetails.status == PurchaseStatus.restored) &&
            purchaseDetails.productID == _productID) {
          _grantPremium();
        }

        if (purchaseDetails.pendingCompletePurchase) {
          _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _grantPremium() async {
    _isPremium = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_premiumPurchasedKey, true);
    } catch (e) {
      debugPrint('Could not save premium state: $e');
    }
  }

  Future<String?> buyLifetime() async {
    if (!_available) {
      return "Store not available";
    }
    if (_products.isEmpty) {
      return "Product not found. Please check Google Play Console setup for ID: $_productID";
    }
    try {
      final ProductDetails productDetails = _products.first;
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
      );

      // For auto-consumable, use buyConsumable. For lifetime, use buyNonConsumable.
      final bool result = await _iap.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      if (!result) {
        return "Purchase failed to start";
      }
      return null; // Success (flow started)
    } catch (e) {
      return "Error: $e";
    }
  }

  Future<void> restorePurchases() async {
    if (!_available) return;
    await _iap.restorePurchases();
  }

  // SECRET BACKDOOR
  Future<void> activateSecretOverride() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumOverrideKey, true);
    _isPremium = true;
    notifyListeners();
  }
}
