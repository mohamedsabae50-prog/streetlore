import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/place_model.dart';
import '../../l10n/app_strings.dart';

class HeadToHeadComparisonCard extends StatelessWidget {
  const HeadToHeadComparisonCard({
    super.key,
    required this.places,
    required this.myVisitedIds,
    required this.theirVisitedIds,
    required this.otherUsername,
  });

  final List<PlaceModel> places;
  final Set<String> myVisitedIds;
  final Set<String> theirVisitedIds;
  final String otherUsername;

  @override
  Widget build(BuildContext context) {
    final total = places.length;
    final myCount = places
        .where((place) => myVisitedIds.contains(place.id))
        .length;
    final theirCount = places
        .where((place) => theirVisitedIds.contains(place.id))
        .length;
    final myProgress = total == 0 ? 0.0 : myCount / total;
    final theirProgress = total == 0 ? 0.0 : theirCount / total;
    final myPercent = (myProgress * 100).round();
    final theirPercent = (theirProgress * 100).round();
    final sharedPlaces = places
        .where(
          (place) =>
              myVisitedIds.contains(place.id) &&
              theirVisitedIds.contains(place.id),
        )
        .toList(growable: false);
    final leading = myCount > theirCount
        ? context.tr('mastery_you_ahead')
        : theirCount > myCount
        ? context.tr('mastery_them_ahead', {'name': otherUsername})
        : context.tr('mastery_tied');
    final locale = Localizations.localeOf(context).languageCode;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('head_to_head'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _MasteryProgressLine(
            label: context.tr('mastery_you'),
            percent: myPercent,
            count: myCount,
            progress: myProgress,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 10),
          _MasteryProgressLine(
            label: otherUsername.isEmpty
                ? context.tr('mastery_them')
                : '@$otherUsername',
            percent: theirPercent,
            count: theirCount,
            progress: theirProgress,
            color: const Color(0xFFD5A934),
          ),
          const SizedBox(height: 12),
          Text(
            leading,
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Divider(height: 24),
          Text(
            context.tr('shared_places'),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr(
              sharedPlaces.length == 1
                  ? 'shared_places_count_one'
                  : 'shared_places_count',
              {'count': '${sharedPlaces.length}'},
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (sharedPlaces.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: sharedPlaces.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final place = sharedPlaces[index];
                  return Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      place.localizedName(locale),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MasteryProgressLine extends StatelessWidget {
  const _MasteryProgressLine({
    required this.label,
    required this.percent,
    required this.count,
    required this.progress,
    required this.color,
  });

  final String label;
  final int percent;
  final int count;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              isArabic
                  ? '$percent٪ · $count مكان'
                  : '$percent% · $count ${count == 1 ? 'place' : 'places'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0).toDouble(),
            minHeight: 7,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
