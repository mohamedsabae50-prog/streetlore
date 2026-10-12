import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RevenueCatService {
  RevenueCatService._();

  static final RevenueCatService instance = RevenueCatService._();

  static const bool _enabled = bool.fromEnvironment(
    'ENABLE_REVENUECAT',
    defaultValue: false,
  );
  static const _androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
  );
  static const _iosApiKey = String.fromEnvironment('REVENUECAT_IOS_API_KEY');
  static const entitlementId = 'pro';

  bool get isConfigured =>
      _enabled &&
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

  Future<bool> restorePurchases(String userId) async {
    if (!await configure(userId)) return false;
    final customerInfo = await Purchases.restorePurchases();
    return customerInfo.entitlements.active.containsKey(entitlementId);
  }

  Future<bool> syncSubscription(String userId) async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser?.id != userId) {
      throw StateError('Cannot sync a subscription for a different user.');
    }
    final response = await client.functions.invoke('sync-subscription');
    if (response.status < 200 || response.status >= 300) {
      final data = response.data;
      final detail = data is Map ? data['error'] : null;
      throw StateError(
        'Subscription sync failed (${response.status})'
        '${detail == null ? '' : ': $detail'}',
      );
    }
    if (response.data is! Map || response.data['is_pro'] is! bool) {
      throw const FormatException('Invalid subscription sync response.');
    }
    return response.data['is_pro'] as bool;
  }
}
