import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_version.dart';
import '../../core/services/remote_config_service.dart';
import '../../core/services/revenuecat_service.dart';
import '../../logic/auth_provider.dart';
import '../../logic/locale_provider.dart';
import '../../l10n/app_strings.dart';
import '../widgets/paywall_store_price.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, this.remoteConfigService});

  final RemoteConfigService? remoteConfigService;

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
  bool _updateBannerDismissed = false;
  bool _previewUpdateBanner = false;
  String? _billingDiagnostic;

  RemoteConfigService get _remoteConfigService =>
      widget.remoteConfigService ?? RemoteConfigService.instance;

  bool get _supportsNativeBilling =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _remoteConfigService.addListener(_handleRemoteConfigChanged);
    _loadPackages();
  }

  @override
  void didUpdateWidget(covariant PaywallScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldService =
        oldWidget.remoteConfigService ?? RemoteConfigService.instance;
    if (oldService != _remoteConfigService) {
      oldService.removeListener(_handleRemoteConfigChanged);
      _remoteConfigService.addListener(_handleRemoteConfigChanged);
    }
  }

  @override
  void dispose() {
    _remoteConfigService.removeListener(_handleRemoteConfigChanged);
    super.dispose();
  }

  void _handleRemoteConfigChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPackages() async {
    if (!_supportsNativeBilling) {
      setState(() {
        _billingCheckComplete = true;
        _hasStoreProducts = false;
        _billingDiagnostic =
            'Native store billing is unavailable on this platform.';
      });
      return;
    }
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

    final enablePro = !auth.isPro;
    setState(() => _adminPreviewLoading = true);
    try {
      await Supabase.instance.client.rpc(
        'admin_update_user_plan',
        params: {
          'p_user_id': auth.userId,
          'p_tier': enablePro ? 'lifetime' : 'free',
        },
      );
      await auth.refreshProStatus();
      if (!mounted) return;
      if (auth.isPro == enablePro) {
        _showMessage(
          context.tr(
            enablePro
                ? 'pro_admin_preview_activated'
                : 'pro_admin_preview_deactivated',
          ),
        );
      } else {
        throw StateError(
          'Admin plan preview was not reflected in the profile.',
        );
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
    if (!_supportsNativeBilling || !RevenueCatService.instance.isConfigured) {
      await _showBillingUnavailableDialog();
      return;
    }
    final auth = context.read<AuthProvider>();
    if (auth.userId.isEmpty) {
      _showMessage(context.tr('pro_sign_in_required'));
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
        await _showBillingUnavailableDialog();
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

  Future<void> _showBillingUnavailableDialog() async {
    final auth = context.read<AuthProvider>();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14171F),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Color(0xFFC8A24A)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFC8A24A),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 20),
              const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFFE5C165),
                size: 38,
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('pro_web_billing_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFE7A8),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.tr('pro_web_billing_message'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFE7D6AF), height: 1.5),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _openDirectApk(_remoteConfigService.config.directApkUrl);
                  },
                  icon: const Icon(Icons.android_rounded),
                  label: Text(context.tr('pro_download_android_app')),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE5C165),
                    foregroundColor: const Color(0xFF17130A),
                  ),
                ),
              ),
              if (auth.isAdmin) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _adminPreviewLoading
                        ? null
                        : () async {
                            Navigator.of(sheetContext).pop();
                            await _activateAdminPreview();
                          },
                    icon: const Icon(Icons.admin_panel_settings_rounded),
                    label: Text(
                      context.tr(
                        auth.isPro
                            ? 'pro_admin_preview_revoke_action'
                            : 'pro_admin_preview_action',
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE5C165),
                      side: const BorderSide(color: Color(0xFFC8A24A)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text(context.tr('cancel')),
              ),
            ],
          ),
        ),
      ),
    );
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

  Future<void> _openDirectApk(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw const FormatException('The direct APK URL is invalid.');
      }
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) throw StateError('No browser could open $uri.');
    } catch (error, stackTrace) {
      debugPrint(
        'PaywallScreen: could not open direct APK: $error\n$stackTrace',
      );
      if (mounted) {
        _showMessage(
          context.read<LocaleProvider>().isArabic
              ? 'تعذر فتح رابط التحديث.'
              : 'Unable to open the update link.',
        );
      }
    }
  }

  Future<void> _editRemoteConfig() async {
    final config = _remoteConfigService.config;
    final controllers = <String, TextEditingController>{
      'weekly_price_en': TextEditingController(text: config.weeklyPriceEn),
      'weekly_price_ar': TextEditingController(text: config.weeklyPriceAr),
      'weekly_usd_label': TextEditingController(text: config.weeklyUsdLabel),
      'monthly_price_en': TextEditingController(text: config.monthlyPriceEn),
      'monthly_price_ar': TextEditingController(text: config.monthlyPriceAr),
      'monthly_usd_label': TextEditingController(text: config.monthlyUsdLabel),
      'annual_price_en': TextEditingController(text: config.annualPriceEn),
      'annual_price_ar': TextEditingController(text: config.annualPriceAr),
      'annual_usd_label': TextEditingController(text: config.annualUsdLabel),
      'promo_banner_en': TextEditingController(text: config.promoBannerEn),
      'promo_banner_ar': TextEditingController(text: config.promoBannerAr),
      'latest_app_version': TextEditingController(
        text: config.latestAppVersion,
      ),
      'latest_build_number': TextEditingController(
        text: config.latestBuildNumber.toString(),
      ),
      'direct_apk_url': TextEditingController(text: config.directApkUrl),
      'release_notes_en': TextEditingController(text: config.releaseNotesEn),
      'release_notes_ar': TextEditingController(text: config.releaseNotesAr),
    };
    var appleEnabled = config.appleSignInEnabled;
    var promoEnabled = config.promoBannerEnabled;
    var isSaving = false;
    String? saveError;
    final isArabic = context.read<LocaleProvider>().isArabic;

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF151821),
            title: Text(
              isArabic
                  ? 'إعدادات الدفع والتحديث المباشر'
                  : 'Edit Live Paywall & Remote Config',
              style: const TextStyle(color: Color(0xFFFFF8E8)),
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        isArabic ? 'تفعيل تسجيل Apple' : 'Enable Apple Sign-In',
                        style: const TextStyle(color: Color(0xFFE7D6AF)),
                      ),
                      value: appleEnabled,
                      onChanged: isSaving
                          ? null
                          : (value) =>
                                setDialogState(() => appleEnabled = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        isArabic
                            ? 'تفعيل العرض الترويجي'
                            : 'Enable promo banner',
                        style: const TextStyle(color: Color(0xFFE7D6AF)),
                      ),
                      value: promoEnabled,
                      onChanged: isSaving
                          ? null
                          : (value) =>
                                setDialogState(() => promoEnabled = value),
                    ),
                    for (final entry in controllers.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: entry.value,
                          keyboardType: entry.key == 'latest_build_number'
                              ? TextInputType.number
                              : TextInputType.text,
                          maxLines: entry.key.startsWith('release_notes_')
                              ? 3
                              : 1,
                          style: const TextStyle(color: Color(0xFFFFF8E8)),
                          decoration: InputDecoration(
                            labelText: entry.key.replaceAll('_', ' '),
                            labelStyle: const TextStyle(
                              color: Color(0xFFE7D6AF),
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF5B5038)),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFE5C165)),
                            ),
                          ),
                        ),
                      ),
                    if (saveError != null)
                      Text(
                        saveError!,
                        style: const TextStyle(color: Color(0xFFFF8A80)),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving
                    ? null
                    : () => Navigator.pop(dialogContext, false),
                child: Text(isArabic ? 'إلغاء' : 'Cancel'),
              ),
              FilledButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final buildNumber = int.tryParse(
                          controllers['latest_build_number']!.text.trim(),
                        );
                        if (buildNumber == null || buildNumber < 0) {
                          setDialogState(
                            () => saveError = isArabic
                                ? 'أدخل رقم إصدار صحيحاً.'
                                : 'Enter a valid build number.',
                          );
                          return;
                        }
                        setDialogState(() {
                          isSaving = true;
                          saveError = null;
                        });
                        try {
                          await _remoteConfigService.updateRemoteConfig(
                            config.copyWith(
                              appleSignInEnabled: appleEnabled,
                              weeklyPriceEn: controllers['weekly_price_en']!
                                  .text
                                  .trim(),
                              weeklyPriceAr: controllers['weekly_price_ar']!
                                  .text
                                  .trim(),
                              weeklyUsdLabel: controllers['weekly_usd_label']!
                                  .text
                                  .trim(),
                              monthlyPriceEn: controllers['monthly_price_en']!
                                  .text
                                  .trim(),
                              monthlyPriceAr: controllers['monthly_price_ar']!
                                  .text
                                  .trim(),
                              monthlyUsdLabel: controllers['monthly_usd_label']!
                                  .text
                                  .trim(),
                              annualPriceEn: controllers['annual_price_en']!
                                  .text
                                  .trim(),
                              annualPriceAr: controllers['annual_price_ar']!
                                  .text
                                  .trim(),
                              annualUsdLabel: controllers['annual_usd_label']!
                                  .text
                                  .trim(),
                              promoBannerEnabled: promoEnabled,
                              promoBannerEn: controllers['promo_banner_en']!
                                  .text
                                  .trim(),
                              promoBannerAr: controllers['promo_banner_ar']!
                                  .text
                                  .trim(),
                              latestAppVersion:
                                  controllers['latest_app_version']!.text
                                      .trim(),
                              latestBuildNumber: buildNumber,
                              directApkUrl: controllers['direct_apk_url']!.text
                                  .trim(),
                              releaseNotesEn: controllers['release_notes_en']!
                                  .text
                                  .trim(),
                              releaseNotesAr: controllers['release_notes_ar']!
                                  .text
                                  .trim(),
                            ),
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (error, stackTrace) {
                          debugPrint(
                            'PaywallScreen: remote config save failed: '
                            '$error\n$stackTrace',
                          );
                          if (!dialogContext.mounted) return;
                          setDialogState(() {
                            isSaving = false;
                            saveError = isArabic
                                ? 'تعذر حفظ الإعدادات. تحقق من صلاحيات المسؤول والاتصال.'
                                : 'Could not save. Check admin access and connectivity.';
                          });
                        }
                      },
                child: isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isArabic ? 'حفظ مباشر' : 'Save live'),
              ),
            ],
          ),
        ),
      );
      if (saved == true && mounted) {
        _showMessage(
          isArabic ? 'تم حفظ الإعدادات المباشرة.' : 'Live settings saved.',
        );
      }
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isArabic = context.watch<LocaleProvider>().isArabic;
    final compactHero = MediaQuery.sizeOf(context).width < 360;
    final benefits = [
      context.tr('pro_benefit_hidden_gems'),
      context.tr('pro_benefit_premium_tours'),
      context.tr('pro_benefit_ai'),
      context.tr('pro_benefit_offline'),
      context.tr('pro_benefit_badges'),
    ];
    final config = _remoteConfigService.config;
    final updateAvailable =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        _remoteConfigService.isUpdateAvailable(kAppVersion, kAppBuildNumber);
    final showUpdateBanner =
        !_updateBannerDismissed &&
        (updateAvailable || (auth.isAdmin && _previewUpdateBanner));
    final promoText = isArabic ? config.promoBannerAr : config.promoBannerEn;

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
            if (auth.isAdmin) ...[
              const SizedBox(height: 12),
              _adminRemoteConfigCard(isArabic),
            ],
            if (config.promoBannerEnabled && promoText.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _promoBanner(promoText),
            ],
            if (showUpdateBanner) ...[
              const SizedBox(height: 12),
              _directUpdateBanner(
                config,
                isArabic,
                onDismiss: () => setState(() => _updateBannerDismissed = true),
              ),
            ],
            const SizedBox(height: 20),
            _planCard(
              type: PackageType.weekly,
              title: context.tr('pro_weekly'),
              description: context.tr('pro_weekly_description'),
              price: isArabic ? config.weeklyPriceAr : config.weeklyPriceEn,
              usdEquivalent: config.weeklyUsdLabel,
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
              price: isArabic ? config.monthlyPriceAr : config.monthlyPriceEn,
              usdEquivalent: config.monthlyUsdLabel,
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
              price: isArabic ? config.annualPriceAr : config.annualPriceEn,
              usdEquivalent: config.annualUsdLabel,
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

  Widget _adminRemoteConfigCard(bool isArabic) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151821),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC8A24A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isArabic ? 'إدارة إعدادات التطبيق المباشرة' : 'Live app controls',
            style: const TextStyle(
              color: Color(0xFFE7D6AF),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const ValueKey('edit-live-remote-config'),
            onPressed: _editRemoteConfig,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE5C165),
              side: const BorderSide(color: Color(0xFFC8A24A)),
            ),
            child: Text(
              isArabic
                  ? 'تعديل الدفع والإعدادات المباشرة'
                  : 'Edit Live Paywall & Remote Config',
            ),
          ),
          TextButton(
            key: const ValueKey('preview-direct-update'),
            onPressed: () => setState(() {
              _previewUpdateBanner = !_previewUpdateBanner;
              _updateBannerDismissed = false;
            }),
            child: Text(
              _previewUpdateBanner
                  ? (isArabic ? 'إخفاء معاينة التحديث' : 'Hide update preview')
                  : (isArabic ? 'معاينة شريط التحديث' : 'Preview OTA banner'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _promoBanner(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2415),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC8A24A)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFFFFE7A8),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _directUpdateBanner(
    RemoteConfigData config,
    bool isArabic, {
    required VoidCallback onDismiss,
  }) {
    final notes = isArabic ? config.releaseNotesAr : config.releaseNotesEn;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF211D13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5C165), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.system_update_alt_rounded,
                color: Color(0xFFE5C165),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic
                      ? 'تحديث فوري متاح · ${config.latestAppVersion}'
                      : 'Instant update available · ${config.latestAppVersion}',
                  style: const TextStyle(
                    color: Color(0xFFFFE7A8),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: isArabic ? 'إغلاق' : 'Dismiss',
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded, color: Color(0xFFE7D6AF)),
              ),
            ],
          ),
          if (notes.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                notes,
                style: const TextStyle(color: Color(0xFFE7D6AF)),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openDirectApk(config.directApkUrl),
              icon: const Icon(Icons.download_rounded),
              label: Text(
                isArabic ? 'تحميل التحديث الفوري' : 'Download Instant Update',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE5C165),
                foregroundColor: const Color(0xFF17130A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminBillingPreviewCard() {
    final auth = context.watch<AuthProvider>();
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
                  : Text(
                      context.tr(
                        auth.isPro
                            ? 'pro_admin_preview_revoke_action'
                            : 'pro_admin_preview_action',
                      ),
                    ),
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
