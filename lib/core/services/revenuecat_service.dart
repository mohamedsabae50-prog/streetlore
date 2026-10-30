import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

class RevenueCatService {
  RevenueCatService._();

  static final RevenueCatService instance = RevenueCatService._();

  static const bool _enabled = bool.fromEnvironment(
    'ENABLE_REVENUECAT',
    defaultValue: true,
  );
  static const _apiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
    defaultValue: AppConfig.revenueCatApiKey,
  );
  static const _androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
  );
  static const _iosApiKey = String.fromEnvironment('REVENUECAT_IOS_API_KEY');
  static const entitlementId = 'pro';
  static const weeklyProductId = String.fromEnvironment(
    'REVENUECAT_WEEKLY_PRODUCT_ID',
    defaultValue: 'weekly',
  );
  static const monthlyProductId = String.fromEnvironment(
    'REVENUECAT_MONTHLY_PRODUCT_ID',
    defaultValue: 'monthly',
  );
  static const annualProductId = String.fromEnvironment(
    'REVENUECAT_ANNUAL_PRODUCT_ID',
    defaultValue: 'annual',
  );

  bool get isConfigured => _enabled && _platformApiKey.isNotEmpty;

  String get _androidKey =>
      _androidApiKey.isNotEmpty ? _androidApiKey : _apiKey;

  String get _platformApiKey {
    if (kIsWeb) return '';
    if (Platform.isAndroid) return _androidKey;
    if (Platform.isIOS) return _iosApiKey;
    return '';
  }

  Future<bool> configure(String userId) async {
    if (!isConfigured) return false;
    if (await Purchases.isConfigured) {
      if (userId.isNotEmpty && await Purchases.appUserID != userId) {
        await Purchases.logIn(userId);
      }
      return true;
    }

    final apiKey = _platformApiKey;
    if (apiKey.isEmpty) return false;

    await Purchases.configure(
      PurchasesConfiguration(apiKey)
        ..appUserID = userId.isEmpty ? null : userId,
    );
    return true;
  }

  Future<List<Package>> offeringPackages(String userId) async {
    if (!await configure(userId)) return const [];
    final offerings = await Purchases.getOfferings();
    final packages = <Package>[];
    final seen = <String>{};
    for (final offering in [
      if (offerings.current != null) offerings.current!,
      ...offerings.all.values,
    ]) {
      for (final package in offering.availablePackages) {
        final key =
            '${package.identifier}:${package.storeProduct.identifier}';
        if (seen.add(key)) packages.add(package);
      }
    }
    return packages;
  }

  Future<List<StoreProduct>> storeProducts(String userId) async {
    if (!await configure(userId)) return const [];
    return Purchases.getProducts([
      weeklyProductId,
      monthlyProductId,
      annualProductId,
    ]);
  }

  Future<bool> purchase({
    Package? package,
    StoreProduct? storeProduct,
    required String userId,
  }) async {
    if (!await configure(userId)) return false;
    final params = package != null
        ? PurchaseParams.package(package)
        : storeProduct != null
        ? PurchaseParams.storeProduct(storeProduct)
        : throw ArgumentError('A RevenueCat package or store product is required.');
    final result = await Purchases.purchase(params);
    return result.customerInfo.entitlements.active.containsKey(entitlementId);
  }

  Future<bool> restorePurchases(String userId) async {
    if (!await configure(userId)) return false;
    final customerInfo = await Purchases.restorePurchases();
    return customerInfo.entitlements.active.containsKey(entitlementId);
  }

  Future<RevenueCatSubscriptionState> syncSubscription(String userId) async {
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
    if (response.data is! Map ||
        response.data['is_pro'] is! bool ||
        response.data['subscription_tier'] is! String) {
      throw const FormatException('Invalid subscription sync response.');
    }
    final endDateValue = response.data['subscription_end_date'];
    return RevenueCatSubscriptionState(
      isPro: response.data['is_pro'] as bool,
      tier: response.data['subscription_tier'] as String,
      endDate: endDateValue is String ? DateTime.tryParse(endDateValue) : null,
    );
  }
}

class RevenueCatSubscriptionState {
  const RevenueCatSubscriptionState({
    required this.isPro,
    required this.tier,
    required this.endDate,
  });

  final bool isPro;
  final String tier;
  final DateTime? endDate;
}
