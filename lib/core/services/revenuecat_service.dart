import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RevenueCatService {
  RevenueCatService._();

  static final RevenueCatService instance = RevenueCatService._();

  static const bool _enabled = bool.fromEnvironment(
    'ENABLE_REVENUECAT',
    defaultValue: true,
  );
  static const _apiKey = String.fromEnvironment('REVENUECAT_API_KEY');
  static const _androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
  );
  static const _iosApiKey = String.fromEnvironment('REVENUECAT_IOS_API_KEY');
  static const entitlementId = 'pro';
  static const weeklyProductId = String.fromEnvironment(
    'REVENUECAT_WEEKLY_PRODUCT_ID',
  );
  static const monthlyProductId = String.fromEnvironment(
    'REVENUECAT_MONTHLY_PRODUCT_ID',
  );
  static const annualProductId = String.fromEnvironment(
    'REVENUECAT_ANNUAL_PRODUCT_ID',
  );

  bool get isConfigured =>
      _enabled &&
      !kIsWeb &&
      (Platform.isAndroid || Platform.isIOS) &&
      (_androidKey.isNotEmpty || _iosApiKey.isNotEmpty);

  String get _androidKey =>
      _androidApiKey.isNotEmpty ? _androidApiKey : _apiKey;

  Future<bool> configure(String userId) async {
    if (!isConfigured) return false;
    if (await Purchases.isConfigured) {
      if (userId.isNotEmpty && await Purchases.appUserID != userId) {
        await Purchases.logIn(userId);
      }
      return true;
    }

    final apiKey = Platform.isAndroid
        ? _androidKey
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
