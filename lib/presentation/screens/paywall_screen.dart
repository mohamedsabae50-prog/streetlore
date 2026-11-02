import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
  StoreProduct? _weeklyProduct;
  StoreProduct? _monthlyProduct;
  StoreProduct? _annualProduct;
  bool _loading = false;
  bool _loadingPackages = false;
  bool _restoring = false;
  bool _billingCheckComplete = false;
  bool _hasStoreProducts = false;
  bool _adminPreviewLoading = false;
  String? _billingDiagnostic;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId.isEmpty) {
      setState(() {
        _billingCheckComplete = true;
        _hasStoreProducts = false;
      });
      return;
    }
    setState(() => _loadingPackages = true);
    List<Package> packages = const [];
    List<StoreProduct> products = const [];
    try {
      packages = await RevenueCatService.instance.offeringPackages(auth.userId);
    } catch (error, stackTrace) {
      debugPrint(
        'PaywallScreen: failed to load RevenueCat offerings: '
        '$error\n$stackTrace',
      );
    }
    try {
      products = await RevenueCatService.instance.storeProducts(auth.userId);
    } catch (error, stackTrace) {
      debugPrint(
        'PaywallScreen: failed to load RevenueCat store products: '
        '$error\n$stackTrace',
      );
    }
    if (!mounted) return;
    setState(() {
      _weeklyPackage = _packageOf(packages, PackageType.weekly);
      _monthlyPackage = _packageOf(packages, PackageType.monthly);
      _annualPackage = _packageOf(packages, PackageType.annual);
      _weeklyProduct = _productOf(products, PackageType.weekly);
      _monthlyProduct = _productOf(products, PackageType.monthly);
      _annualProduct = _productOf(products, PackageType.annual);
      _hasStoreProducts =
          _weeklyPackage != null ||
          _monthlyPackage != null ||
          _annualPackage != null ||
          _weeklyProduct != null ||
          _monthlyProduct != null ||
          _annualProduct != null;
      _billingDiagnostic = RevenueCatService.instance.lastBillingDiagnostic;
      if (!_hasStoreProducts && _billingDiagnostic == null) {
        _billingDiagnostic =
            'Billing returned no products matching the configured weekly, monthly, or yearly plans.';
      }
      _billingCheckComplete = true;
      _loadingPackages = false;
    });
  }

  Package? _packageOf(List<Package> packages, PackageType type) {
    for (final package in packages) {
      if (package.packageType == type) return package;
      if (RevenueCatService.matchesProductId(package.identifier, type) ||
          RevenueCatService.matchesProductId(
            package.storeProduct.identifier,
            type,
          )) {
        return package;
      }
    }
    return null;
  }

  StoreProduct? _productOf(List<StoreProduct> products, PackageType type) {
    for (final product in products) {
      if (RevenueCatService.matchesProductId(product.identifier, type)) {
        return product;
      }
    }
    return null;
  }

  Future<void> _activateAdminPreview() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAdmin || auth.userId.isEmpty || _adminPreviewLoading) return;

    setState(() => _adminPreviewLoading = true);
    try {
      await Supabase.instance.client.rpc(
        'admin_set_user_pro',
        params: {'target_user_id': auth.userId, 'pro_enabled': true},
      );
      await auth.refreshProStatus();
      if (!mounted) return;
      if (auth.isPro) {
        _showMessage(context.tr('pro_admin_preview_activated'));
      } else {
        throw StateError('Admin Pro preview was not reflected in the profile.');
      }
    } catch (error, stackTrace) {
      debugPrint(
        'PaywallScreen: admin Pro preview failed: $error\n$stackTrace',
      );
      if (mounted) _showMessage(context.tr('pro_admin_preview_failed'));
    } finally {
      if (mounted) setState(() => _adminPreviewLoading = false);
    }
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

      RevenueCatSubscriptionState? state;
      try {
        state = await RevenueCatService.instance.syncSubscription(auth.userId);
        if (state.isPro) {
          // server already reports this user as Pro
        }
      } catch (error) {
        debugPrint('PaywallScreen: RevenueCat restore sync is pending: $error');
      }

      var profileActivated = state?.isPro ?? false;
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
      _showMessage(context.tr('pro_native_unavailable'));
      return;
    }

    setState(() => _loading = true);
    try {
      var package = switch (type) {
        PackageType.weekly => _weeklyPackage,
        PackageType.monthly => _monthlyPackage,
        PackageType.annual => _annualPackage,
        _ => null,
      };
      var storeProduct = switch (type) {
        PackageType.weekly => _weeklyProduct,
        PackageType.monthly => _monthlyProduct,
        PackageType.annual => _annualProduct,
        _ => null,
      };
      if (package == null && storeProduct == null) {
        await _loadPackages();
        if (!mounted) return;
        package = switch (type) {
          PackageType.weekly => _weeklyPackage,
          PackageType.monthly => _monthlyPackage,
          PackageType.annual => _annualPackage,
          _ => null,
        };
        storeProduct = switch (type) {
          PackageType.weekly => _weeklyProduct,
          PackageType.monthly => _monthlyProduct,
          PackageType.annual => _annualProduct,
          _ => null,
        };
      }
      if (package == null && storeProduct == null) {
        _showMessage(context.tr('pro_native_unavailable'));
        return;
      }
      final activated = await RevenueCatService.instance.purchase(
        package: package,
        storeProduct: storeProduct,
        userId: auth.userId,
      );
      if (!mounted) return;
      RevenueCatSubscriptionState? state;
      if (activated) {
        try {
          state = await RevenueCatService.instance.syncSubscription(
            auth.userId,
          );
        } catch (error) {
          debugPrint(
            'PaywallScreen: RevenueCat purchase sync is pending: $error',
          );
        }
      }

      var profileActivated = state?.isPro ?? false;
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
    final auth = context.watch<AuthProvider>();
    final compactHero = MediaQuery.sizeOf(context).width < 360;
    final benefits = [
      context.tr('pro_benefit_hidden_gems'),
      context.tr('pro_benefit_premium_tours'),
      context.tr('pro_benefit_ai'),
      context.tr('pro_benefit_offline'),
      context.tr('pro_benefit_badges'),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0F14),
        foregroundColor: const Color(0xFFFFF8E8),
        title: Text(context.tr('pro_title')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Container(
              key: const ValueKey('paywall-hero-card'),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                color: const Color(0xFF14171F),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFFC8A24A).withValues(alpha: 0.68),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EgyptLore',
                          style: TextStyle(
                            color: Color(0xFFFFF8E8),
                            fontSize: compactHero ? 22 : 26,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                        Text(
                          'Pro',
                          style: TextStyle(
                            color: Color(0xFFE5C165),
                            fontSize: compactHero ? 30 : 34,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr('pro_subtitle'),
                          style: const TextStyle(
                            color: Color(0xFFE7D6AF),
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: compactHero ? 104 : 138,
                    height: compactHero ? 75 : 100,
                    child: CustomPaint(
                      key: const ValueKey('paywall-wedjat-emblem'),
                      painter: WedjatPainter(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _planCard(
              type: PackageType.weekly,
              title: context.tr('pro_weekly'),
              description: context.tr('pro_weekly_description'),
              price: context.tr('pro_weekly_price'),
              usdEquivalent: context.tr('pro_weekly_usd'),
              package: _weeklyPackage,
              accent: const Color(0xFFC8A24A),
              badge: context.tr('pro_weekly_badge'),
              benefits: benefits,
            ),
            const SizedBox(height: 14),
            _planCard(
              type: PackageType.monthly,
              title: context.tr('pro_monthly'),
              description: context.tr('pro_monthly_description'),
              price: context.tr('pro_monthly_price'),
              usdEquivalent: context.tr('pro_monthly_usd'),
              package: _monthlyPackage,
              accent: const Color(0xFFC8A24A),
              badge: context.tr('pro_monthly_badge'),
              benefits: benefits,
            ),
            const SizedBox(height: 14),
            _planCard(
              type: PackageType.annual,
              title: context.tr('pro_annual'),
              description: context.tr('pro_annual_description'),
              price: context.tr('pro_annual_price'),
              usdEquivalent: context.tr('pro_annual_usd'),
              package: _annualPackage,
              accent: const Color(0xFFC8A24A),
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
              style: const TextStyle(color: Color(0xFFB8AD94), fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text(
              context.tr('subscription_disclosure'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFB8AD94),
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
            const SizedBox(height: 10),
            if (auth.isAdmin &&
                _billingCheckComplete &&
                !_hasStoreProducts) ...[
              const SizedBox(height: 14),
              _adminBillingPreviewCard(),
            ],
            if (kDebugMode && RevenueCatService.instance.isConfigured) ...[
              const SizedBox(height: 6),
              Text(
                context.tr('pro_detected_offerings'),
                style: const TextStyle(color: Color(0xFFB8AD94), fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Center(
                child: Column(
                  children: [
                    Text(
                      'weekly: ${_weeklyPackage?.storeProduct.identifier ?? RevenueCatService.weeklyProductId}',
                    ),
                    Text(
                      'monthly: ${_monthlyPackage?.storeProduct.identifier ?? RevenueCatService.monthlyProductId}',
                    ),
                    Text(
                      'annual: ${_annualPackage?.storeProduct.identifier ?? RevenueCatService.annualProductId}',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _adminBillingPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151821),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFC8A24A).withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('pro_admin_billing_diagnostic'),
            style: const TextStyle(
              color: Color(0xFFE7D6AF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_billingDiagnostic case final diagnostic?) ...[
            const SizedBox(height: 6),
            Text(
              diagnostic,
              style: const TextStyle(
                color: Color(0xFFB8AD94),
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: const ValueKey('activate-admin-pro-preview'),
              onPressed: _adminPreviewLoading ? null : _activateAdminPreview,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE5C165),
                side: const BorderSide(color: Color(0xFFC8A24A)),
              ),
              child: _adminPreviewLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.tr('pro_admin_preview_action')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _planCard({
    required PackageType type,
    required String title,
    required String description,
    required String price,
    required String usdEquivalent,
    required Package? package,
    required Color accent,
    required List<String> benefits,
    String? badge,
    bool featured = false,
  }) {
    final isLoading = _loading || _loadingPackages || _restoring;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF151821),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: featured ? 0.75 : 0.5),
          width: featured ? 1.4 : 1,
        ),
        boxShadow: featured
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.14),
                  blurRadius: 22,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFFFF8E8),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDAB356),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    badge,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF17130A),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFFB8AD94),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 17),
          PaywallStorePrice(
            product:
                package?.storeProduct ??
                switch (type) {
                  PackageType.weekly => _weeklyProduct,
                  PackageType.monthly => _monthlyProduct,
                  PackageType.annual => _annualProduct,
                  _ => null,
                },
            fallbackPrice: price,
            packageType: type,
            usdEquivalent: usdEquivalent,
          ),
          const SizedBox(height: 18),
          Text(
            context.tr('pro_includes_free'),
            style: const TextStyle(
              color: Color(0xFFE7D6AF),
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
                    Icons.check_rounded,
                    color: Color(0xFFE5C165),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      benefit,
                      style: const TextStyle(
                        color: Color(0xFFF3EBDD),
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
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey('paywall-subscribe-${type.name}'),
                onTap: isLoading ? null : () => _purchase(type),
                borderRadius: BorderRadius.circular(40),
                child: Ink(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE5C165), Color(0xFFC89B3C)],
                    ),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Center(
                    child: _loading && !_restoring
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF161208),
                            ),
                          )
                        : Text(
                            context.tr('pro_subscribe'),
                            style: const TextStyle(
                              color: Color(0xFF161208),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WedjatPainter extends CustomPainter {
  const WedjatPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 180, size.height / 110);

    final gold = Paint()
      ..color = const Color(0xFFE5C165)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final highlight = Paint()
      ..color = const Color(0xFFC8A24A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final upperLid = Path()
      ..moveTo(13, 49)
      ..cubicTo(45, 23, 100, 17, 151, 46)
      ..cubicTo(160, 51, 166, 56, 170, 61);
    final eye = Path()
      ..moveTo(15, 51)
      ..cubicTo(48, 28, 99, 27, 145, 49)
      ..cubicTo(130, 70, 92, 83, 55, 70)
      ..cubicTo(38, 65, 25, 58, 15, 51)
      ..close();
    final lowerCrease = Path()
      ..moveTo(34, 73)
      ..cubicTo(61, 91, 98, 91, 123, 80)
      ..cubicTo(134, 75, 141, 68, 148, 61);
    final falconMark = Path()
      ..moveTo(41, 66)
      ..cubicTo(39, 78, 42, 90, 50, 97)
      ..cubicTo(57, 103, 65, 102, 69, 96)
      ..cubicTo(73, 90, 70, 84, 65, 82)
      ..cubicTo(61, 80, 57, 83, 57, 87);
    final browAccent = Path()
      ..moveTo(29, 42)
      ..cubicTo(59, 20, 107, 15, 143, 34);

    canvas.drawPath(eye, gold);
    canvas.drawPath(upperLid, highlight);
    canvas.drawPath(lowerCrease, highlight);
    canvas.drawPath(falconMark, gold);
    canvas.drawPath(browAccent, highlight);

    final iris = Paint()
      ..color = const Color(0xFFE5C165)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(const Offset(91, 53), 17, iris);
    canvas.drawCircle(
      const Offset(91, 53),
      6,
      Paint()..color = const Color(0xFFE5C165),
    );
    canvas.drawCircle(
      const Offset(91, 53),
      2.5,
      Paint()..color = const Color(0xFF151821),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WedjatPainter oldDelegate) => false;
}
