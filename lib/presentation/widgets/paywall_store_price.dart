import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../l10n/app_strings.dart';

class PaywallStorePrice extends StatelessWidget {
  const PaywallStorePrice({
    required this.product,
    required this.fallbackPrice,
    required this.fallbackDetail,
    required this.packageType,
    super.key,
  });

  final StoreProduct? product;
  final String fallbackPrice;
  final String fallbackDetail;
  final PackageType packageType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product?.priceString ?? fallbackPrice,
          style: TextStyle(
            color: context.textPri,
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          product == null
              ? fallbackDetail
              : context.tr('pro_billing_period', {
                  'period':
                      _localizedPeriod(context, product!.subscriptionPeriod) ??
                      _defaultPeriod(context),
                }),
          style: TextStyle(
            color: context.textSec,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _defaultPeriod(BuildContext context) {
    final key = switch (packageType) {
      PackageType.weekly => 'pro_period_week',
      PackageType.monthly => 'pro_period_month',
      PackageType.annual => 'pro_period_year',
      _ => 'pro_period_month',
    };
    return context.tr(key);
  }

  String? _localizedPeriod(BuildContext context, String? subscriptionPeriod) {
    if (subscriptionPeriod == null) return null;
    final match = RegExp(
      r'^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?$',
    ).firstMatch(subscriptionPeriod);
    if (match == null) return null;

    const units = [
      (capture: 1, singular: 'year', plural: 'years'),
      (capture: 2, singular: 'month', plural: 'months'),
      (capture: 3, singular: 'week', plural: 'weeks'),
      (capture: 4, singular: 'day', plural: 'days'),
    ];
    final components = [
      for (final unit in units)
        if (match.group(unit.capture) != null)
          (unit: unit, count: int.tryParse(match.group(unit.capture)!)),
    ];
    if (components.length != 1 || components.single.count == null) {
      return null;
    }

    final component = components.single;
    final count = component.count!;
    if (count < 1) return null;
    final key =
        'pro_period_${count == 1 ? component.unit.singular : component.unit.plural}';
    return count == 1 ? context.tr(key) : context.tr(key, {'count': '$count'});
  }
}
