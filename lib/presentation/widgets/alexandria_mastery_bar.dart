import 'package:flutter/material.dart';

import '../../data/models/place_model.dart';

class AlexandriaMasteryBar extends StatelessWidget {
  const AlexandriaMasteryBar({
    super.key,
    required this.places,
    required this.visitedPlaceIds,
  });

  final List<PlaceModel> places;
  final Set<String> visitedPlaceIds;

  @override
  Widget build(BuildContext context) {
    final totalPlaces = places.length;
    final visitedCount = places
        .where((place) => visitedPlaceIds.contains(place.id))
        .length;
    final percentage = totalPlaces > 0
        ? ((visitedCount / totalPlaces) * 100).round()
        : 0;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final progress = totalPlaces > 0 ? visitedCount / totalPlaces : 0.0;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: isArabic
          ? 'تمت زيارة $visitedCount من أصل $totalPlaces مكانًا، $percentage٪'
          : 'Visited $visitedCount of $totalPlaces places, $percentage%',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFD5A934).withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF14532D).withValues(alpha: 0.07),
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
                const Icon(
                  Icons.explore_rounded,
                  color: Color(0xFFD5A934),
                  size: 21,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabic ? 'إتقان الإسكندرية' : 'Alexandria Mastery',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  isArabic ? '$percentage٪' : '$percentage%',
                  style: textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF047857),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isArabic
                  ? 'تمت زيارة $visitedCount من أصل $totalPlaces مكانًا — استكشاف $percentage٪ من الإسكندرية'
                  : 'Visited $visitedCount / $totalPlaces Places — $percentage% of Alexandria Explored',
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: Color(0xFFE9E7E1)),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => FractionallySizedBox(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: value.clamp(0.0, 1.0).toDouble(),
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFD5A934), Color(0xFF10B981)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CompactAlexandriaMasteryPill extends StatelessWidget {
  const CompactAlexandriaMasteryPill({
    super.key,
    required this.places,
    required this.visitedPlaceIds,
    required this.onTap,
  });

  final List<PlaceModel> places;
  final Set<String> visitedPlaceIds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final total = places.length;
    final visited = places
        .where((place) => visitedPlaceIds.contains(place.id))
        .length;
    final progress = total == 0 ? 0.0 : visited / total;
    final percentage = (progress * 100).round();
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final color = const Color(0xFF047857);

    return Semantics(
      button: true,
      label: isArabic
          ? 'تمت زيارة $visited من أصل $total مكانًا، $percentage٪'
          : 'Visited $visited of $total places, $percentage%',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 9, 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.explore_rounded,
                color: Color(0xFFD5A934),
                size: 16,
              ),
              const SizedBox(width: 5),
              Text(
                '$visited/$total · $percentage${isArabic ? '٪' : '%'}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 7),
              SizedBox(
                width: 34,
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0).toDouble(),
                    backgroundColor: const Color(0xFFE9E7E1),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF10B981),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
