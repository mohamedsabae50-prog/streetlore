import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/revenuecat_service.dart';
import '../../logic/auth_provider.dart';
import '../../l10n/app_strings.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Package? _monthlyPackage;
  Package? _yearlyPackage;
  Package? _lifetimePackage;
  bool _loading = false;
  bool _loadingPackages = false;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId.isEmpty || !RevenueCatService.instance.isConfigured) {
      return;
    }
    setState(() => _loadingPackages = true);
    try {
      final packages = await RevenueCatService.instance.offeringPackages(
        auth.userId,
      );
      if (!mounted) return;
      setState(() {
        _monthlyPackage = _packageOf(packages, PackageType.monthly);
        _yearlyPackage = _packageOf(packages, PackageType.annual);
        _lifetimePackage = _packageOf(packages, PackageType.lifetime);
      });
    } catch (error, stackTrace) {
      debugPrint(
        'PaywallScreen: failed to load RevenueCat offerings: '
        '$error\n$stackTrace',
      );
    } finally {
      if (mounted) setState(() => _loadingPackages = false);
    }
  }

  Package? _packageOf(List<Package> packages, PackageType type) {
    for (final package in packages) {
      if (package.packageType == type) return package;
    }
    return null;
  }

  Future<void> _purchase(PackageType type) async {
    final auth = context.read<AuthProvider>();
    if (auth.userId.isEmpty) {
      _showMessage(context.tr('pro_sign_in_required'));
      return;
    }
    if (!RevenueCatService.instance.isConfigured) {
      _showMessage(context.tr('pro_setup_required'));
      return;
    }

    setState(() => _loading = true);
    try {
      final package = switch (type) {
        PackageType.monthly => _monthlyPackage,
        PackageType.annual => _yearlyPackage,
        PackageType.lifetime => _lifetimePackage,
        _ => null,
      };
      if (package == null) {
        _showMessage(context.tr('pro_offering_unavailable'));
        return;
      }
      final activated = await RevenueCatService.instance.purchase(
        package,
        auth.userId,
      );
      if (!mounted) return;
      var profileActivated = false;
      for (var attempt = 0; attempt < 5 && !profileActivated; attempt++) {
        try {
          await auth.refreshProStatus();
          profileActivated = auth.isPro;
        } catch (error) {
          debugPrint('PaywallScreen: Pro profile sync is pending: $error');
        }
        if (!profileActivated && attempt < 4) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
      if (!mounted) return;
      _showMessage(
        activated && profileActivated
            ? context.tr('pro_purchase_success')
            : context.tr('pro_purchase_pending'),
      );
      if (activated && profileActivated) Navigator.pop(context);
    } on PlatformException catch (error) {
      debugPrint(
        'PaywallScreen: RevenueCat purchase failed: '
        '${error.code} ${error.message}',
      );
      if (mounted) _showMessage(context.tr('pro_purchase_failed'));
    } catch (error, stackTrace) {
      debugPrint('PaywallScreen: purchase failed: $error\n$stackTrace');
      if (mounted) _showMessage(context.tr('pro_purchase_failed'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final benefits = [
      context.tr('pro_benefit_hidden_gems'),
      context.tr('pro_benefit_premium_tours'),
      context.tr('pro_benefit_ai'),
      context.tr('pro_benefit_offline'),
      context.tr('pro_benefit_badges'),
    ];

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(context.tr('pro_title')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ratingGold.withValues(alpha: 0.24),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                    size: 54,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('pro_title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('pro_subtitle'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            for (final benefit in benefits)
              Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        benefit,
                        textAlign: isArabic ? TextAlign.right : TextAlign.left,
                        style: TextStyle(
                          color: context.textPri,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed:
                  _loading ||
                      _loadingPackages ||
                      !RevenueCatService.instance.isConfigured
                  ? null
                  : () => _purchase(PackageType.monthly),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _loading
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : RevenueCatService.instance.isConfigured
                  ? _packageLabel(
                      context.tr('pro_monthly'),
                      _monthlyPackage,
                    )
                  : Text(
                      context.tr('pro_coming_soon'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed:
                  _loading ||
                      _loadingPackages ||
                      !RevenueCatService.instance.isConfigured
                  ? null
                  : () => _purchase(PackageType.annual),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(56),
                side: BorderSide(color: context.hintColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: RevenueCatService.instance.isConfigured
                  ? _packageLabel(
                      context.tr('pro_yearly'),
                      _yearlyPackage,
                    )
                  : Text(
                      context.tr('pro_coming_soon'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed:
                  _loading ||
                      _loadingPackages ||
                      !RevenueCatService.instance.isConfigured
                  ? null
                  : () => _purchase(PackageType.lifetime),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(56),
                side: BorderSide(color: context.hintColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: RevenueCatService.instance.isConfigured
                  ? _packageLabel(
                      context.tr('pro_lifetime'),
                      _lifetimePackage,
                    )
                  : Text(
                      context.tr('pro_coming_soon'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              RevenueCatService.instance.isConfigured
                  ? context.tr('pro_store_note')
                  : context.tr('pro_setup_note'),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSec, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _packageLabel(String label, Package? package) {
    final price = package?.storeProduct.priceString;
    return Text(
      price == null ? label : '$label · $price',
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    );
  }
}
