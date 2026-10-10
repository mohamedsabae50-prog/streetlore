import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;








class CurrencyService {
  CurrencyService._();
  static final CurrencyService instance = CurrencyService._();

  static const _endpoint = 'https://open.er-api.com/v6/latest/EGP';
  static const _maxAge = Duration(hours: 6);

  
  
  Map<String, double>? _ratesPerEgp;
  DateTime? _fetchedAt;
  bool _fetching = false;

  Future<void> _ensureFresh() async {
    if (_ratesPerEgp != null &&
        _fetchedAt != null &&
        DateTime.now().difference(_fetchedAt!) < _maxAge) {
      return;
    }
    if (_fetching) return;
    _fetching = true;
    try {
      final res = await http
          .get(Uri.parse(_endpoint))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final rates = body['rates'] as Map<String, dynamic>?;
        if (rates != null) {
          _ratesPerEgp = rates.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          );
          _fetchedAt = DateTime.now();
          return;
        }
      }
      debugPrint(
        'CurrencyService: live fetch failed (${res.statusCode}) — using fallback',
      );
    } on TimeoutException {
      debugPrint('CurrencyService: timeout — using fallback');
    } catch (e) {
      debugPrint('CurrencyService: $e — using fallback');
    } finally {
      _fetching = false;
    }
    _ratesPerEgp ??= _fallback;
  }

  
  
  Future<double?> convert(
    double amount,
    String from,
    String to,
  ) async {
    if (from == to) return amount;
    await _ensureFresh();
    final table = _ratesPerEgp ?? _fallback;

    final fromRate = table[from];
    final toRate = table[to];
    if (fromRate == null || toRate == null || fromRate == 0) return null;
    // Each entry in the table is "X of <currency> per 1 EGP", i.e.
    //   table[USD] = 0.019 means 1 EGP = 0.019 USD.
    // To convert `amount` units of `from` into `to`:
    //   result = amount * (toRate / fromRate)
    return amount * (toRate / fromRate);
  }

  /// Quote a single rate "1 `from` = ? `to`" using the same per-1-EGP table.
  /// Returns null when either side is missing from the table.
  Future<double?> rateFor(String from, String to) async {
    if (from == to) return 1.0;
    await _ensureFresh();
    final table = _ratesPerEgp ?? _fallback;
    final fromRate = table[from];
    final toRate = table[to];
    if (fromRate == null || toRate == null || fromRate == 0) return null;
    return toRate / fromRate;
  }

  /// Fallback rates, expressed as "X of <code> per 1 EGP". Matches the
  /// shape of the live `latest/EGP` response from open.er-api.com so the
  /// convert math works identically for both.
  static const Map<String, double> _fallback = {
    'EGP': 1.0,
    'USD': 0.0191,
    'EUR': 0.0186,
    'GBP': 0.0159,
    'SAR': 0.0758,
    'AED': 0.0741,
    'KWD': 0.0062,
    'JPY': 3.03,
    'CNY': 0.146,
    'RUB': 1.85,
  };
}
