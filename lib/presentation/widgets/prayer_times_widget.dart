import 'package:flutter/material.dart';
import '../../core/services/prayer_times_service.dart';

class PrayerTimesWidget extends StatelessWidget {
  const PrayerTimesWidget({super.key});

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
    return FutureBuilder<PrayerTimes>(
      future: PrayerTimesService.instance.getTimes(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.all(18),
            height: 130,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF14B8A6), Color(0xFF0E7490)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
          );
        }
        return _buildContent(context, snap.data!);
      },
    );
  }

  Widget _buildContent(BuildContext context, PrayerTimes times) {
    final current = times.currentPrayer;
    final nextName = times.nextPrayerName();
    final remaining = times.timeUntilNext;
    final hh = remaining.inHours;
    final mm = remaining.inMinutes % 60;
    final remainingStr = hh > 0
        ? '${hh}h ${mm}m'
        : '${mm}m';

    final prayers = [
      ('Fajr', times.fajr),
      ('Sunrise', times.sunrise),
      ('Dhuhr', times.dhuhr),
      ('Asr', times.asr),
      ('Maghrib', times.maghrib),
      ('Isha', times.isha),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14B8A6), Color(0xFF0E7490)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14B8A6).withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.mosque_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مواقيت الصلاة',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Text(
                      'Alexandria · $nextName · $remainingStr',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  current,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: prayers.map((p) {
              final name = p.$1;
              final time = _formatTime(p.$2);
              final isNext = name == nextName;
              final isCurrent = name == current;
              return Expanded(
                child: Column(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: isNext
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.75),
                        fontSize: 10,
                        fontWeight:
                            isNext ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isNext
                            ? Colors.white
                            : (isCurrent
                                ? Colors.white.withValues(alpha: 0.28)
                                : Colors.white.withValues(alpha: 0.10)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        time,
                        style: TextStyle(
                          color: isNext
                              ? const Color(0xFF0E7490)
                              : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
