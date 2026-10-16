import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/revenuecat_service.dart';
import '../../logic/auth_provider.dart';
import '../../l10n/app_strings.dart';
import '../widgets/paywall_store_price.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  static final _privacyPolicyUri = Uri.parse(
    'https://mohamedsabae50-prog.github.io/streetlore/privacy.html',
  );
  static final _deleteAccountUri = Uri.parse(
    'https://mohamedsabae50-prog.github.io/streetlore/delete-account.html',
  );

  Package? _weeklyPackage;
  Package? _monthlyPackage;
  Package? _annualPackage;
  bool _loading = false;
  bool _loadingPackages = false;
  bool _restoring = false;

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
        _weeklyPackage = _packageOf(packages, PackageType.weekly);
        _monthlyPackage = _packageOf(packages, PackageType.monthly);
        _annualPackage = _packageOf(packages, PackageType.annual);
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

  Future<void> _restorePurchases() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId.isEmpty) {
      _showMessage(context.tr('restore_sign_in_required'));
      return;
    }
    if (!RevenueCatService.instance.isConfigured) {
      _showMessage(context.tr('restore_setup_required'));
      return;
    }

    setState(() => _restoring = true);
    try {
      final restored = await RevenueCatService.instance.restorePurchases(
        auth.userId,
      );
      if (!mounted) return;
      if (!restored) {
        _showMessage(context.tr('restore_none_found'));
        return;
      }

      try {
        await RevenueCatService.instance.syncSubscription(auth.userId);
      } catch (error) {
        debugPrint('PaywallScreen: RevenueCat restore sync is pending: $error');
      }
      var profileActivated = false;
      for (var attempt = 0; attempt < 5 && !profileActivated; attempt++) {
        try {
          await auth.refreshProStatus();
          profileActivated = auth.isPro;
        } catch (error) {
          debugPrint('PaywallScreen: Pro restore sync is pending: $error');
        }
        if (!profileActivated && attempt < 4) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
      if (!mounted) return;
      _showMessage(
        profileActivated
            ? context.tr('restore_success')
            : context.tr('restore_pending'),
      );
      if (profileActivated) Navigator.pop(context);
    } on PlatformException catch (error) {
      debugPrint(
        'PaywallScreen: RevenueCat restore failed: '
        '${error.code} ${error.message}',
      );
      if (mounted) _showMessage(context.tr('restore_failed'));
    } catch (error, stackTrace) {
      debugPrint('PaywallScreen: restore failed: $error\n$stackTrace');
      if (mounted) _showMessage(context.tr('restore_failed'));
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
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
        PackageType.weekly => _weeklyPackage,
        PackageType.monthly => _monthlyPackage,
        PackageType.annual => _annualPackage,
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
      if (activated) {
        try {
          await RevenueCatService.instance.syncSubscription(auth.userId);
        } catch (error) {
          debugPrint(
            'PaywallScreen: RevenueCat purchase sync is pending: $error',
          );
        }
      }
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

  Future<void> _openPublicPage(Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) throw StateError('No browser could open $uri.');
    } catch (error, stackTrace) {
      debugPrint(
        'PaywallScreen: could not open public page: $error\n$stackTrace',
      );
      if (mounted) _showMessage(context.tr('public_link_failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
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
            _planCard(
              type: PackageType.weekly,
              title: context.tr('pro_weekly'),
              description: context.tr('pro_weekly_description'),
              price: context.tr('pro_weekly_price'),
              usdPrice: context.tr('pro_weekly_usd_price'),
              package: _weeklyPackage,
              icon: Icons.calendar_view_week_rounded,
              accent: AppColors.primary,
              badge: context.tr('pro_weekly_badge'),
              benefits: benefits,
            ),
            const SizedBox(height: 14),
            _planCard(
              type: PackageType.monthly,
              title: context.tr('pro_monthly'),
              description: context.tr('pro_monthly_description'),
              price: context.tr('pro_monthly_price'),
              usdPrice: context.tr('pro_monthly_usd_price'),
              package: _monthlyPackage,
              icon: Icons.calendar_month_rounded,
              accent: AppColors.primary,
              badge: context.tr('pro_monthly_badge'),
              benefits: benefits,
            ),
            const SizedBox(height: 14),
            _planCard(
              type: PackageType.annual,
              title: context.tr('pro_annual'),
              description: context.tr('pro_annual_description'),
              price: context.tr('pro_annual_price'),
              usdPrice: context.tr('pro_annual_usd_price'),
              package: _annualPackage,
              priceNote: context.tr('pro_annual_monthly_equivalent'),
              icon: Icons.calendar_month_rounded,
              accent: const Color(0xFF8B5CF6),
              badge: context.tr('pro_annual_badge'),
              benefits: benefits,
              featured: true,
            ),
            const SizedBox(height: 12),
            Text(
              RevenueCatService.instance.isConfigured
                  ? context.tr('pro_store_note')
                  : context.tr('pro_setup_note'),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSec, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text(
              context.tr('subscription_disclosure'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textSec,
                fontSize: 11,
                height: 1.45,
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  onPressed: () => _openPublicPage(_privacyPolicyUri),
                  child: Text(context.tr('privacy_policy_title')),
                ),
                TextButton(
                  onPressed: () => _openPublicPage(_deleteAccountUri),
                  child: Text(context.tr('delete_account_public')),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: TextButton(
                onPressed: _loading || _restoring ? null : _restorePurchases,
                child: _restoring
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr('restore_purchases')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planCard({
    required PackageType type,
    required String title,
    required String description,
    required String price,
    required String usdPrice,
    required Package? package,
    required IconData icon,
    required Color accent,
    required List<String> benefits,
    String? priceNote,
    String? badge,
    bool featured = false,
  }) {
    final isConfigured = RevenueCatService.instance.isConfigured;
    final isLoading = _loading || _loadingPackages || _restoring;
    final label = isConfigured
        ? Text(
            context.tr('pro_subscribe'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          )
        : Text(
            context.tr('pro_coming_soon'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          );

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: featured
            ? (context.isDark
                  ? const Color(0xFF302817)
                  : const Color(0xFFFFFBEB))
            : context.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accent.withValues(alpha: featured ? 0.75 : 0.32),
          width: featured ? 1.7 : 1,
        ),
        boxShadow: featured
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.textPri,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: TextStyle(color: context.textSec, fontSize: 12, height: 1.4),
          ),
          if (badge != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          PaywallStorePrice(
            product: package?.storeProduct,
            fallbackPrice: price,
            fallbackDetail: usdPrice,
            packageType: type,
          ),
          if (priceNote != null && package == null) ...[
            const SizedBox(height: 3),
            Text(
              priceNote,
              style: TextStyle(
                color: context.textSec,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            context.tr('pro_includes_free'),
            style: TextStyle(
              color: context.textPri,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (final benefit in benefits) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      benefit,
                      style: TextStyle(
                        color: context.textPri,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: !isConfigured || isLoading
                  ? null
                  : () => _purchase(type),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: accent.withValues(alpha: 0.72),
                disabledForegroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: _loading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : label,
            ),
          ),
        ],
      ),
    );
  }
}
