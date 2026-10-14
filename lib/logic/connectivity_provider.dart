import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';

class ConnectivityProvider extends ChangeNotifier with WidgetsBindingObserver {
  final Connectivity _connectivity = Connectivity();
  final http.Client _httpClient = http.Client();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool? _hasInternet;
  bool _checking = false;

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
        _setInternet(false);
      },
    );
    unawaited(refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  Future<void> refresh() async {
    _checking = true;
    notifyListeners();
    try {
      final results = await _connectivity.checkConnectivity();
      if (!_hasNetworkInterface(results)) {
        _setInternet(false);
        return;
      }
      _setInternet(await _probeInternet());
    } catch (error, stackTrace) {
      debugPrint('ConnectivityProvider.refresh failed: $error\n$stackTrace');
      _setInternet(false);
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    if (!_hasNetworkInterface(results)) {
      _setInternet(false);
      return;
    }
    unawaited(refresh());
  }

  bool _hasNetworkInterface(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  Future<bool> _probeInternet() async {
    try {
      await _httpClient
          .get(Uri.parse('${AppConfig.supabaseUrl}/auth/v1/health'))
          .timeout(const Duration(seconds: 2));
      return true;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } on http.ClientException catch (error) {
      debugPrint('ConnectivityProvider: internet probe failed: $error');
      return false;
    }
  }

  void _setInternet(bool value) {
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
