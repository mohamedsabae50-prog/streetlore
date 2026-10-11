import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
  RevenueCatService._();

  static final RevenueCatService instance = RevenueCatService._();

  static const _androidApiKey = 'test_qrlowpR7Y7DFXYHShFjPFdelzFY';
  static const _iosApiKey = 'test_qrlowpR7Y7DFXYHShFjPFdelzFY';
  static const entitlementId = 'pro';

  bool get isConfigured =>
      !kIsWeb &&
      (Platform.isAndroid || Platform.isIOS) &&
      (_androidApiKey.isNotEmpty || _iosApiKey.isNotEmpty);

  Future<bool> configure(String userId) async {
    if (!isConfigured) return false;
    if (await Purchases.isConfigured) {
      if (userId.isNotEmpty && await Purchases.appUserID != userId) {
        await Purchases.logIn(userId);
      }
      return true;
    }

    final apiKey = Platform.isAndroid
        ? _androidApiKey
        : Platform.isIOS
        ? _iosApiKey
        : '';
    if (apiKey.isEmpty) return false;

    await Purchases.configure(
      PurchasesConfiguration(apiKey)
        ..appUserID = userId.isEmpty ? null : userId,
    );
    return true;
  }

  Future<List<Package>> offeringPackages(String userId) async {
    if (!await configure(userId)) return const [];
    final offering = (await Purchases.getOfferings()).current;
    return offering?.availablePackages ?? const [];
  }

  Future<bool> purchase(Package package, String userId) async {
    if (!await configure(userId)) return false;
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return result.customerInfo.entitlements.active.containsKey(entitlementId);
  }
}
