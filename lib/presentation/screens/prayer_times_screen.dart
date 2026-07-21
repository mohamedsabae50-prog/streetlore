import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/prayer_times_service.dart';
import '../widgets/prayer_times_widget.dart';

class PrayerTimesScreen extends StatelessWidget {
  const PrayerTimesScreen({super.key});

  String _formatTime(DateTime t) {
    final h24 = t.hour;
    final h12 = h24 == 0
        ? 12
        : (h24 > 12 ? h24 - 12 : h24);
    final ampm = h24 >= 12 ? 'PM' : 'AM';
    final hh = h12.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$hh:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final times = PrayerTimesService.instance.compute();
    final next = times.nextPrayerName();
    final remaining = times.timeUntilNext;
    final hh = remaining.inHours;
    final mm = remaining.inMinutes % 60;
    final remainingStr = hh > 0
        ? '${hh}h ${mm}m'
        : '${mm}m';

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: const Text(
          'Prayer Times',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: context.bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPri),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            const PrayerTimesWidget(),
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: context.textSec.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF14B8A6)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.access_time_rounded,
                          color: Color(0xFF14B8A6),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Next Prayer',
                              style: TextStyle(
                                color: context.textSec,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$next · $remainingStr',
                              style: TextStyle(
                                color: context.textPri,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Divider(
                    color: context.textSec.withValues(alpha: 0.15),
                    height: 1,
                  ),
                  const SizedBox(height: 18),
                  _DetailRow(
                    label: 'Fajr',
                    time: _formatTime(times.fajr),
                    icon: Icons.nights_stay_rounded,
                  ),
                  _DetailRow(
                    label: 'Sunrise',
                    time: _formatTime(times.sunrise),
                    icon: Icons.wb_twilight_rounded,
                  ),
                  _DetailRow(
                    label: 'Dhuhr',
                    time: _formatTime(times.dhuhr),
                    icon: Icons.wb_sunny_rounded,
                  ),
                  _DetailRow(
                    label: 'Asr',
                    time: _formatTime(times.asr),
                    icon: Icons.wb_cloudy_rounded,
                  ),
                  _DetailRow(
                    label: 'Maghrib',
                    time: _formatTime(times.maghrib),
                    icon: Icons.wb_twilight_rounded,
                  ),
                  _DetailRow(
                    label: 'Isha',
                    time: _formatTime(times.isha),
                    icon: Icons.bedtime_rounded,
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF14B8A6).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFF14B8A6),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Alexandria, Egypt · 31.20°N, 29.92°E',
                      style: TextStyle(
                        color: context.textPri,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String time;
  final IconData icon;
  final bool isLast;

  const _DetailRow({
    required this.label,
    required this.time,
    required this.icon,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF14B8A6).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF14B8A6), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: context.textPri,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.textSec.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              time,
              style: TextStyle(
                color: context.textPri,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
