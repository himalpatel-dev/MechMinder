import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class SubscriptionProvider with ChangeNotifier {
  static const String _trialStartDateKey = 'trial_start_date_v1';
  static const String _premiumOverrideKey = 'premium_override_enabled';
  static const int _trialDurationDays = 15;

  // REPLACE THIS with your actual Product ID from Google Play Console
  static const String _productID = 'lifetime_subscription_79';

  final InAppPurchase _iap = InAppPurchase.instance;
  bool _available = true;
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
    // 1. Check Trial Status & Local Override
    await _checkTrialStatus();

    // 2. Initialize IAP and check past purchases
    // Only fetch if not already overridden locally
    if (!_isPremium) {
      await _initIAP();
    }

    _loading = false;
    notifyListeners();
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
    _available = await _iap.isAvailable();
    if (!_available) {
      print("IAP not available");
      return;
    }

    // Listen to purchase updates (buys, restores)
    // IMPORTANT: This stream should be listened to as early as possible
    _iap.purchaseStream.listen(
      (List<PurchaseDetails> purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () {
        print("IAP Stream Done");
      },
      onError: (error) {
        print("IAP Stream Error: $error");
      },
    );

    // Query Products
    const Set<String> _kIds = {_productID};
    final ProductDetailsResponse response = await _iap.queryProductDetails(
      _kIds,
    );
    if (response.notFoundIDs.isNotEmpty) {
      print("Product IDs not found: ${response.notFoundIDs}");
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
          print("IAP Error: ${purchaseDetails.error}");
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          _grantPremium();
        }

        if (purchaseDetails.pendingCompletePurchase) {
          _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  void _grantPremium() {
    print("Granting Premium Access");
    _isPremium = true;
    notifyListeners();
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
