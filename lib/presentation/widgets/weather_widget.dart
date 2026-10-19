import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/weather_service.dart';
import '../../core/services/widget_sync_service.dart';
import '../../l10n/app_strings.dart';

class WeatherWidget extends StatefulWidget {
  const WeatherWidget({super.key});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  WeatherData? _data;
  bool _loading = true;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    final cached = await WeatherService.instance.loadCached();
    if (!mounted) return;
    if (cached != null) {
      setState(() {
        _data = cached;
        _loading = false;
      });
      if ((forceRefresh || !WeatherService.instance.isCacheFresh(cached)) &&
          !_locating) {
        final refreshed = await WeatherService.instance
            .fetchForDeviceLocation();
        if (mounted && refreshed != null) {
          setState(() => _data = refreshed);
        // update native widget after a successful refresh (fire-and-forget)
        try {
          WidgetSyncService.updateWidgetData(context);
        } catch (_) {}
        }
      }
      return;
    }
    setState(() => _loading = true);
    final d = await WeatherService.instance.fetchForDeviceLocation();
    if (mounted) {
      setState(() {
        _data = d;
        _loading = false;
      });
      if (d != null) {
        try {
        WidgetSyncService.updateWidgetData(context);
        } catch (_) {}
      }
    }
  }

  Future<void> _useMyLocation() async {
    HapticFeedback.lightImpact();
    setState(() {
      _locating = true;
    });
    final d = await WeatherService.instance.fetchForDeviceLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _loading = false;
      if (d != null) _data = d;
    });
    if (d != null) {
      try {
        await WidgetSyncService.updateWidgetData(context);
      } catch (_) {}
    }
    if (d == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('weather_unavailable'))),
      );
    }
  }

  IconData _iconForCode(String code) {
    final weatherCode = int.tryParse(code.replaceFirst('wmo_', ''));
    if (weatherCode == null) return Icons.cloud_off_rounded;
    if ((_data?.precipitationProbability ?? 0) >= 40 &&
        (_data?.precipitation ?? 0) == 0 &&
        weatherCode <= 3) {
      return Icons.umbrella_rounded;
    }
    if (weatherCode >= 95) return Icons.thunderstorm_rounded;
    if ((weatherCode >= 51 && weatherCode <= 67) ||
        (weatherCode >= 80 && weatherCode <= 82)) {
      return Icons.umbrella_rounded;
    }
    if ((weatherCode >= 71 && weatherCode <= 77) ||
        (weatherCode == 85 || weatherCode == 86)) {
      return Icons.ac_unit_rounded;
    }
    if (weatherCode == 45 || weatherCode == 48) return Icons.foggy;
    if (weatherCode == 0 && _data?.isDay == false) {
      return Icons.nightlight_round;
    }
    if (weatherCode <= 1 && _data?.isDay == true) {
      return Icons.wb_sunny_rounded;
    }
    if (weatherCode <= 2) {
      return _data?.isDay == true
          ? Icons.wb_cloudy_rounded
          : Icons.cloud_rounded;
    }
    if (weatherCode >= 3) {
      return Icons.cloud_rounded;
    }
    return Icons.cloud_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) {
      return Container(
        height: 100,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    if (_data == null) {
      return Container(
        height: 100,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const SizedBox(width: 18),
            const Icon(Icons.cloud_off_rounded, color: Colors.blueGrey),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr('weather_unavailable'),
                style: TextStyle(color: context.textSec, fontSize: 13),
              ),
            ),
            IconButton(
              onPressed: () => _load(forceRefresh: true),
              tooltip: context.tr('refresh'),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      );
    }
    final d = _data!;
    final gradient = _gradientFor(d);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(_iconForCode(d.iconCode), color: Colors.white, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${d.tempC.round()}°  ${context.tr(d.conditionKey)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr('weather_feels', {
                    't': '${d.feelsLikeC.round()}',
                    'h': '${d.humidity}',
                  }),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _locating ? null : _useMyLocation,
            tooltip: context.tr('weather_my_location'),
            icon: _locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.my_location_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            onPressed: () => _load(forceRefresh: true),
            tooltip: context.tr('refresh'),
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  List<Color> _gradientFor(WeatherData data) {
    if (!data.isDay) {
      return [const Color(0xFF0F172A), const Color(0xFF334155)];
    }
    final code = data.weatherCode;
    if (data.precipitationProbability >= 40 ||
        data.precipitation > 0 ||
        code >= 51) {
      return [const Color(0xFF1E40AF), const Color(0xFF3B82F6)];
    }
    if (code <= 1) {
      return [const Color(0xFF2563EB), const Color(0xFFF59E0B)];
    }
    if (code <= 3) {
      return [const Color(0xFF64748B), const Color(0xFF94A3B8)];
    }
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      return [const Color(0xFF1E40AF), const Color(0xFF3B82F6)];
    }
    if (code >= 95) {
      return [const Color(0xFF1E1B4B), const Color(0xFF4338CA)];
    }
    if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
      return [const Color(0xFFE0F2FE), const Color(0xFFBAE6FD)];
    }
    if (code == 45 || code == 48) {
      return [const Color(0xFF6B7280), const Color(0xFF9CA3AF)];
    }
    return [const Color(0xFF3B82F6), const Color(0xFF60A5FA)];
  }
}
