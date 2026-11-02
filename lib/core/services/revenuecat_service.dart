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
    defaultValue: AppConfig.weeklyProductId,
  );
  static const monthlyProductId = String.fromEnvironment(
    'REVENUECAT_MONTHLY_PRODUCT_ID',
    defaultValue: AppConfig.monthlyProductId,
  );
  static const annualProductId = String.fromEnvironment(
    'REVENUECAT_ANNUAL_PRODUCT_ID',
    defaultValue: AppConfig.annualProductId,
  );
  static const _candidateProductIds = [
    'pro_weekly',
    'pro_monthly_base',
    'pro_yearly',
    'pro_monthly',
    'streetlore_pro_weekly',
    'streetlore_pro_monthly',
    'streetlore_pro_yearly',
    'egyptlore_pro_weekly',
    'egyptlore_pro_monthly',
    'egyptlore_pro_yearly',
  ];

  String? _lastBillingDiagnostic;

  String? get lastBillingDiagnostic => _lastBillingDiagnostic;

  bool get isConfigured => _enabled && _platformApiKey.isNotEmpty;

  String get _androidKey =>
      _androidApiKey.isNotEmpty ? _androidApiKey : _apiKey;

  String get _platformApiKey {
    if (kIsWeb) return '';
    if (Platform.isAndroid) return _androidKey;
    if (Platform.isIOS) return _iosApiKey;
    return '';
  }

  static bool matchesProductId(String identifier, PackageType type) {
    final productId = identifier.toLowerCase().split(':').first;
    final productIds = switch (type) {
      PackageType.weekly => [weeklyProductId, 'pro_weekly'],
      PackageType.monthly => [monthlyProductId, 'pro_monthly_base'],
      PackageType.annual => [annualProductId, 'pro_yearly'],
      _ => const <String>[],
    };
    if (productIds.any((id) => productId == id.toLowerCase())) return true;

    final aliases = switch (type) {
      PackageType.weekly => const ['weekly', 'week', 'explorer'],
      PackageType.monthly => const ['monthly', 'month'],
      PackageType.annual => const ['annual', 'yearly', 'year'],
      _ => const <String>[],
    };
    return aliases.any(productId.contains);
  }

  Future<bool> configure(String userId) async {
    if (!isConfigured) {
      _lastBillingDiagnostic = _enabled
          ? 'RevenueCat is unavailable for this platform or its public SDK key is missing.'
          : 'RevenueCat is disabled by the ENABLE_REVENUECAT build flag.';
      return false;
    }
    try {
      if (await Purchases.isConfigured) {
        if (userId.isNotEmpty && await Purchases.appUserID != userId) {
          await Purchases.logIn(userId);
        }
        return true;
      }

      final apiKey = _platformApiKey;
      if (apiKey.isEmpty) {
        _lastBillingDiagnostic =
            'No RevenueCat public SDK key is configured for this platform.';
        return false;
      }

      await Purchases.configure(
        PurchasesConfiguration(apiKey)
          ..appUserID = userId.isEmpty ? null : userId,
      );
      _lastBillingDiagnostic = null;
      return true;
    } catch (error) {
      _lastBillingDiagnostic = 'RevenueCat configuration failed: $error';
      rethrow;
    }
  }

  Future<List<Package>> offeringPackages(String userId) async {
    if (!await configure(userId)) return const [];
    try {
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
      if (packages.isEmpty) {
        _lastBillingDiagnostic =
            'RevenueCat returned no offering packages. Check the current offering, package configuration, and store product availability.';
      } else {
        _lastBillingDiagnostic = null;
      }
      return packages;
    } catch (error) {
      _lastBillingDiagnostic = 'Loading RevenueCat offerings failed: $error';
      rethrow;
    }
  }

  Future<List<StoreProduct>> storeProducts(String userId) async {
    if (!await configure(userId)) return const [];
    try {
      final products = await Purchases.getProducts(_candidateProductIds);
      if (products.isEmpty) {
        _lastBillingDiagnostic =
            'Google Play returned no store products for the configured product IDs. Verify product IDs, base plans, tester access, and Play Store availability.';
      } else {
        _lastBillingDiagnostic = null;
      }
      return products;
    } catch (error) {
      _lastBillingDiagnostic =
          'Querying Google Play store products failed: $error';
      rethrow;
    }
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
        : throw ArgumentError(
            'A RevenueCat package or store product is required.',
          );
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
