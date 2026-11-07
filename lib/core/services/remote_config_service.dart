import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RemoteConfigData {
  const RemoteConfigData({
    this.appleSignInEnabled = false,
    this.weeklyPriceEn = '49 EGP / week',
    this.weeklyPriceAr = '49 ج.م / أسبوع',
    this.weeklyUsdLabel = '~\$0.99 USD',
    this.monthlyPriceEn = '49 EGP / month',
    this.monthlyPriceAr = '49 ج.م / شهر',
    this.monthlyUsdLabel = '~\$0.99 USD',
    this.annualPriceEn = '199 EGP / year',
    this.annualPriceAr = '199 ج.م / سنة',
    this.annualUsdLabel = '~\$4.99 USD',
    this.promoBannerEnabled = false,
    this.promoBannerEn = '',
    this.promoBannerAr = '',
    this.latestAppVersion = '2.1.43',
    this.latestBuildNumber = 246,
    this.directApkUrl =
        'https://github.com/mohamedsabae50-prog/streetlore/releases/latest/download/app-release.apk',
    this.releaseNotesEn = '',
    this.releaseNotesAr = '',
    this.updatedAt,
  });

  final bool appleSignInEnabled;
  final String weeklyPriceEn;
  final String weeklyPriceAr;
  final String weeklyUsdLabel;
  final String monthlyPriceEn;
  final String monthlyPriceAr;
  final String monthlyUsdLabel;
  final String annualPriceEn;
  final String annualPriceAr;
  final String annualUsdLabel;
  final bool promoBannerEnabled;
  final String promoBannerEn;
  final String promoBannerAr;
  final String latestAppVersion;
  final int latestBuildNumber;
  final String directApkUrl;
  final String releaseNotesEn;
  final String releaseNotesAr;
  final DateTime? updatedAt;

  factory RemoteConfigData.fromJson(Map<String, dynamic> json) {
    String stringValue(String key, String fallback) {
      final value = json[key];
      return value is String ? value : fallback;
    }

    bool boolValue(String key, bool fallback) {
      final value = json[key];
      return value is bool ? value : fallback;
    }

    int intValue(String key, int fallback) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return fallback;
    }

    final updatedAtValue = json['updated_at'];
    return RemoteConfigData(
      appleSignInEnabled: boolValue('apple_sign_in_enabled', false),
      weeklyPriceEn: stringValue('weekly_price_en', '49 EGP / week'),
      weeklyPriceAr: stringValue('weekly_price_ar', '49 ج.م / أسبوع'),
      weeklyUsdLabel: stringValue('weekly_usd_label', '~\$0.99 USD'),
      monthlyPriceEn: stringValue('monthly_price_en', '49 EGP / month'),
      monthlyPriceAr: stringValue('monthly_price_ar', '49 ج.م / شهر'),
      monthlyUsdLabel: stringValue('monthly_usd_label', '~\$0.99 USD'),
      annualPriceEn: stringValue('annual_price_en', '199 EGP / year'),
      annualPriceAr: stringValue('annual_price_ar', '199 ج.م / سنة'),
      annualUsdLabel: stringValue('annual_usd_label', '~\$4.99 USD'),
      promoBannerEnabled: boolValue('promo_banner_enabled', false),
      promoBannerEn: stringValue('promo_banner_en', ''),
      promoBannerAr: stringValue('promo_banner_ar', ''),
      latestAppVersion: stringValue('latest_app_version', '2.1.43'),
      latestBuildNumber: intValue('latest_build_number', 246),
      directApkUrl: stringValue(
        'direct_apk_url',
        'https://github.com/mohamedsabae50-prog/streetlore/releases/latest/download/app-release.apk',
      ),
      releaseNotesEn: stringValue('release_notes_en', ''),
      releaseNotesAr: stringValue('release_notes_ar', ''),
      updatedAt: updatedAtValue is String
          ? DateTime.tryParse(updatedAtValue)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'apple_sign_in_enabled': appleSignInEnabled,
    'weekly_price_en': weeklyPriceEn,
    'weekly_price_ar': weeklyPriceAr,
    'weekly_usd_label': weeklyUsdLabel,
    'monthly_price_en': monthlyPriceEn,
    'monthly_price_ar': monthlyPriceAr,
    'monthly_usd_label': monthlyUsdLabel,
    'annual_price_en': annualPriceEn,
    'annual_price_ar': annualPriceAr,
    'annual_usd_label': annualUsdLabel,
    'promo_banner_enabled': promoBannerEnabled,
    'promo_banner_en': promoBannerEn,
    'promo_banner_ar': promoBannerAr,
    'latest_app_version': latestAppVersion,
    'latest_build_number': latestBuildNumber,
    'direct_apk_url': directApkUrl,
    'release_notes_en': releaseNotesEn,
    'release_notes_ar': releaseNotesAr,
  };

  RemoteConfigData copyWith({
    bool? appleSignInEnabled,
    String? weeklyPriceEn,
    String? weeklyPriceAr,
    String? weeklyUsdLabel,
    String? monthlyPriceEn,
    String? monthlyPriceAr,
    String? monthlyUsdLabel,
    String? annualPriceEn,
    String? annualPriceAr,
    String? annualUsdLabel,
    bool? promoBannerEnabled,
    String? promoBannerEn,
    String? promoBannerAr,
    String? latestAppVersion,
    int? latestBuildNumber,
    String? directApkUrl,
    String? releaseNotesEn,
    String? releaseNotesAr,
    DateTime? updatedAt,
  }) {
    return RemoteConfigData(
      appleSignInEnabled: appleSignInEnabled ?? this.appleSignInEnabled,
      weeklyPriceEn: weeklyPriceEn ?? this.weeklyPriceEn,
      weeklyPriceAr: weeklyPriceAr ?? this.weeklyPriceAr,
      weeklyUsdLabel: weeklyUsdLabel ?? this.weeklyUsdLabel,
      monthlyPriceEn: monthlyPriceEn ?? this.monthlyPriceEn,
      monthlyPriceAr: monthlyPriceAr ?? this.monthlyPriceAr,
      monthlyUsdLabel: monthlyUsdLabel ?? this.monthlyUsdLabel,
      annualPriceEn: annualPriceEn ?? this.annualPriceEn,
      annualPriceAr: annualPriceAr ?? this.annualPriceAr,
      annualUsdLabel: annualUsdLabel ?? this.annualUsdLabel,
      promoBannerEnabled: promoBannerEnabled ?? this.promoBannerEnabled,
      promoBannerEn: promoBannerEn ?? this.promoBannerEn,
      promoBannerAr: promoBannerAr ?? this.promoBannerAr,
      latestAppVersion: latestAppVersion ?? this.latestAppVersion,
      latestBuildNumber: latestBuildNumber ?? this.latestBuildNumber,
      directApkUrl: directApkUrl ?? this.directApkUrl,
      releaseNotesEn: releaseNotesEn ?? this.releaseNotesEn,
      releaseNotesAr: releaseNotesAr ?? this.releaseNotesAr,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class RemoteConfigService extends ChangeNotifier {
  RemoteConfigService({this._client, RemoteConfigData? initialConfig})
    : _config = initialConfig ?? const RemoteConfigData();

  static final RemoteConfigService instance = RemoteConfigService();

  final SupabaseClient? _client;
  RealtimeChannel? _channel;
  RemoteConfigData _config;
  RemoteConfigData get config => _config;

  Future<void> initialize() async {
    startRealtimeUpdates();
    await fetchRemoteConfig();
  }

  void startRealtimeUpdates() {
    if (_channel != null) return;
    try {
      _channel = (_client ?? Supabase.instance.client)
          .channel('app-remote-config')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'app_remote_config',
            callback: (payload) {
              if (payload.newRecord.isEmpty) return;
              applyRemoteConfig(RemoteConfigData.fromJson(payload.newRecord));
            },
          )
          .subscribe((status, error) {
            if (error != null) {
              debugPrint(
                'RemoteConfigService: realtime subscription failed: $error',
              );
            }
          });
    } catch (error, stackTrace) {
      debugPrint(
        'RemoteConfigService: could not start realtime updates: '
        '$error\n$stackTrace',
      );
    }
  }

  void applyRemoteConfig(RemoteConfigData config) {
    _config = config;
    notifyListeners();
  }

  Future<void> fetchRemoteConfig({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final row = await (_client ?? Supabase.instance.client)
          .from('app_remote_config')
          .select()
          .eq('id', 1)
          .maybeSingle()
          .timeout(timeout);
      if (row == null) {
        debugPrint('RemoteConfigService: singleton config row was not found.');
        return;
      }
      applyRemoteConfig(RemoteConfigData.fromJson(row));
    } on TimeoutException {
      debugPrint('RemoteConfigService: remote config fetch timed out.');
    } catch (error, stackTrace) {
      debugPrint(
        'RemoteConfigService: remote config fetch failed; keeping defaults: '
        '$error\n$stackTrace',
      );
    }
  }

  Future<void> updateRemoteConfig(RemoteConfigData nextConfig) async {
    final previousConfig = _config;
    _config = nextConfig;
    notifyListeners();
    try {
      final response = await (_client ?? Supabase.instance.client).rpc(
        'admin_update_remote_config',
        params: {'p_payload': nextConfig.toJson()},
      );
      if (response is! Map) {
        throw const FormatException(
          'The remote config RPC returned an invalid response.',
        );
      }
      _config = RemoteConfigData.fromJson(Map<String, dynamic>.from(response));
      notifyListeners();
    } catch (error, stackTrace) {
      _config = previousConfig;
      notifyListeners();
      debugPrint(
        'RemoteConfigService: admin update failed and was rolled back: '
        '$error\n$stackTrace',
      );
      rethrow;
    }
  }

  bool isUpdateAvailable(String currentVersion, int currentBuildNumber) {
    return _config.latestBuildNumber > currentBuildNumber ||
        _compareVersions(_config.latestAppVersion, currentVersion) > 0;
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) unawaited(channel.unsubscribe());
    super.dispose();
  }

  static int _compareVersions(String first, String second) {
    final firstVersion = _parseVersion(first);
    final secondVersion = _parseVersion(second);
    if (firstVersion == null || secondVersion == null) return 0;

    for (var index = 0; index < 3; index++) {
      final difference = firstVersion.core[index] - secondVersion.core[index];
      if (difference != 0) return difference.sign.toInt();
    }

    final firstPreRelease = firstVersion.preRelease;
    final secondPreRelease = secondVersion.preRelease;
    if (firstPreRelease == null && secondPreRelease == null) return 0;
    if (firstPreRelease == null) return 1;
    if (secondPreRelease == null) return -1;
    for (
      var index = 0;
      index < firstPreRelease.length && index < secondPreRelease.length;
      index++
    ) {
      final firstPart = firstPreRelease[index];
      final secondPart = secondPreRelease[index];
      if (firstPart == secondPart) continue;
      final firstNumber = int.tryParse(firstPart);
      final secondNumber = int.tryParse(secondPart);
      if (firstNumber != null && secondNumber != null) {
        return firstNumber < secondNumber ? -1 : 1;
      }
      if (firstNumber != null) return -1;
      if (secondNumber != null) return 1;
      return firstPart.compareTo(secondPart).sign;
    }
    return firstPreRelease.length.compareTo(secondPreRelease.length).sign;
  }

  static ({List<int> core, List<String>? preRelease})? _parseVersion(
    String version,
  ) {
    final match = RegExp(
      r'^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$',
    ).firstMatch(version.trim());
    if (match == null) return null;
    final major = int.tryParse(match.group(1)!);
    final minor = int.tryParse(match.group(2)!);
    final patch = int.tryParse(match.group(3)!);
    if (major == null || minor == null || patch == null) return null;
    return (
      core: [major, minor, patch],
      preRelease: match.group(4)?.split('.'),
    );
  }
}
