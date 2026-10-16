import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import 'internet_status_tracker.dart';

class ConnectivityProvider extends ChangeNotifier with WidgetsBindingObserver {
  final Connectivity _connectivity = Connectivity();
  final http.Client _httpClient = http.Client();
  final InternetStatusTracker _tracker = InternetStatusTracker();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Slow links (hotel Wi-Fi, 3G, a cold radio) can take well over 2 s.
  static const Duration probeTimeout = Duration(seconds: 6);

  bool? _hasInternet;
  bool _checking = false;
  Future<void>? _refreshing;

  /// `true` online, `false` offline, `null` unknown. Only `false` blocks the
  /// app (see main.dart), so an inconclusive probe never locks the user out.
  bool? get hasInternet => _hasInternet;
  bool get isChecking => _checking;

  ConnectivityProvider() {
    WidgetsBinding.instance.addObserver(this);
    _subscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChange,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          'ConnectivityProvider: connectivity stream failed: '
          '$error\n$stackTrace',
        );
        unawaited(refresh());
      },
    );
    unawaited(refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  /// Concurrent calls (resume + connectivity change + retry button) share one
  /// run, so a single outage can't be counted as several failed probes.
  Future<void> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<void> _refresh() async {
    _checking = true;
    notifyListeners();
    try {
      var hasInterface = true;
      try {
        hasInterface = _hasNetworkInterface(
          await _connectivity.checkConnectivity(),
        );
      } catch (error, stackTrace) {
        // Can't tell: let the probe decide rather than assuming offline.
        debugPrint(
          'ConnectivityProvider: checkConnectivity failed: '
          '$error\n$stackTrace',
        );
      }
      if (!hasInterface) {
        _setInternet(_tracker.recordNoNetwork());
        return;
      }
      _setInternet(await _tracker.check(_probeInternet));
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    if (!_hasNetworkInterface(results)) {
      _setInternet(_tracker.recordNoNetwork());
      return;
    }
    unawaited(refresh());
  }

  bool _hasNetworkInterface(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  Future<bool> _probeInternet() async {
    try {
      // Any HTTP response, whatever its status, proves the network works.
      await _httpClient
          .get(Uri.parse('${AppConfig.supabaseUrl}/auth/v1/health'))
          .timeout(probeTimeout);
      return true;
    } on TimeoutException {
      return false;
    } on Exception catch (error) {
      debugPrint('ConnectivityProvider: internet probe failed: $error');
      return false;
    }
  }

  void _setInternet(bool? value) {
    if (_hasInternet == value) return;
    _hasInternet = value;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    _httpClient.close();
    super.dispose();
  }
}
