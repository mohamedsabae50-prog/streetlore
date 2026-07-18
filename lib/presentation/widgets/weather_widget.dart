import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/weather_service.dart';
import '../screens/currency_converter_screen.dart';

class WeatherWidget extends StatefulWidget {
  const WeatherWidget({super.key});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  WeatherData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final d = await WeatherService.instance.fetch();
    if (mounted) {
      setState(() {
        _data = d;
        _loading = false;
      });
    }
  }

  IconData _iconForCode(String code) {
    if (code.startsWith('01')) return Icons.wb_sunny_rounded;
    if (code.startsWith('02')) return Icons.wb_cloudy_rounded;
    if (code.startsWith('03') || code.startsWith('04')) return Icons.cloud_rounded;
    if (code.startsWith('09') || code.startsWith('10')) return Icons.umbrella_rounded;
    if (code.startsWith('11')) return Icons.thunderstorm_rounded;
    if (code.startsWith('13')) return Icons.ac_unit_rounded;
    if (code.startsWith('50')) return Icons.foggy;
    return Icons.wb_sunny_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) {
      return Container(
        height: 100,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: SizedBox(
            width: 22, height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    final d = _data!;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CurrencyConverterScreen()),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _gradientFor(d.iconCode),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _gradientFor(d.iconCode).first.withValues(alpha: 0.3),
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
                    '${d.tempC.round()}°C · ${d.description}',
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
                    'feels ${d.feelsLikeC.round()}° · ${d.humidity}% humidity',
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
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _gradientFor(String code) {
    if (code.startsWith('01')) return [const Color(0xFF60A5FA), const Color(0xFFFBBF24)];
    if (code.startsWith('02') || code.startsWith('03') || code.startsWith('04')) {
      return [const Color(0xFF64748B), const Color(0xFF94A3B8)];
    }
    if (code.startsWith('09') || code.startsWith('10')) {
      return [const Color(0xFF1E40AF), const Color(0xFF3B82F6)];
    }
    if (code.startsWith('11')) return [const Color(0xFF1E1B4B), const Color(0xFF4338CA)];
    if (code.startsWith('13')) return [const Color(0xFFE0F2FE), const Color(0xFFBAE6FD)];
    if (code.startsWith('50')) return [const Color(0xFF6B7280), const Color(0xFF9CA3AF)];
    return [const Color(0xFF3B82F6), const Color(0xFF60A5FA)];
  }
}
