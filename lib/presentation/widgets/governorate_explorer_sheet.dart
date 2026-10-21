import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/egypt_governorate.dart';
import '../../data/models/place_model.dart';
import '../../logic/governorate_provider.dart';

class GovernoratePill extends StatelessWidget {
  const GovernoratePill({super.key, required this.onTap, this.compact = false});

  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GovernorateProvider>();
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final active =
        EgyptGovernorate.byId[provider.activeGovernorate] ??
        EgyptGovernorate.byId['alexandria']!;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 36 : 42),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 9 : 14,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFF0F9D8A).withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📍'),
              SizedBox(width: compact ? 4 : 6),
              if (compact)
                Flexible(
                  child: Text(
                    '${isArabic ? active.nameAr : active.nameEn} · '
                    '${provider.unlockedGovernorateIds.length}/27',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else
                Text(
                  '${isArabic ? active.nameAr : active.nameEn} · '
                  '${provider.unlockedGovernorateIds.length}/27',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              SizedBox(width: compact ? 1 : 4),
              Icon(Icons.expand_more_rounded, size: compact ? 17 : 19),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showGovernorateExplorerSheet(
  BuildContext context, {
  required List<PlaceModel> places,
  Set<String> visitedPlaceIds = const {},
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => GovernorateExplorerSheet(
      places: places,
      visitedPlaceIds: visitedPlaceIds,
    ),
  );
}

class GovernorateExplorerSheet extends StatelessWidget {
  const GovernorateExplorerSheet({
    super.key,
    required this.places,
    this.visitedPlaceIds = const {},
  });

  final List<PlaceModel> places;
  final Set<String> visitedPlaceIds;

  @override
  Widget build(BuildContext context) {
    final governorates = context.watch<GovernorateProvider>();
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final placeCounts = <String, int>{};
    for (final place in places) {
      placeCounts.update(
        place.governorate,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    final unlocked = governorates.unlockedGovernorateIds;
    final ordered = [...EgyptGovernorate.all]
      ..sort((a, b) {
        final aOpen = unlocked.contains(a.id) || (placeCounts[a.id] ?? 0) > 0;
        final bOpen = unlocked.contains(b.id) || (placeCounts[b.id] ?? 0) > 0;
        return aOpen == bOpen ? a.nameEn.compareTo(b.nameEn) : (aOpen ? -1 : 1);
      });

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 14, 8),
            child: Row(
              children: [
                const Icon(Icons.explore_rounded, color: Color(0xFF0F9D8A)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isArabic ? 'استكشف محافظات مصر' : 'Explore Egypt',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isArabic
                        ? '${unlocked.length} / 27 محافظات مفتوحة'
                        : '${unlocked.length} / 27 Governorates Unlocked',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF078B78),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  isArabic ? 'ضباب الخريطة' : 'Fog of War',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Switch(
                  value: governorates.fogEnabled,
                  onChanged: governorates.setFogEnabled,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: ordered.length,
              itemBuilder: (context, index) {
                final item = ordered[index];
                final count = placeCounts[item.id] ?? 0;
                final isOpen = unlocked.contains(item.id) || count > 0;
                final governoratePlaces = places
                    .where((place) => place.governorate == item.id)
                    .toList(growable: false);
                final visited = governoratePlaces
                    .where((place) => visitedPlaceIds.contains(place.id))
                    .length;
                final progress = governoratePlaces.isEmpty
                    ? 0
                    : (visited / governoratePlaces.length * 100).round();
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isOpen
                          ? const Color(0xFF0F9D8A).withValues(alpha: 0.12)
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        isOpen ? Icons.place_rounded : Icons.lock_rounded,
                        color: isOpen
                            ? const Color(0xFF0F9D8A)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(isArabic ? item.nameAr : item.nameEn),
                    subtitle: Text(
                      isOpen
                          ? isArabic
                                ? '$count أماكن · إتقان $progress٪'
                                : '$count places · $progress% mastery'
                          : 'Coming Soon · قريباً تحت الضباب 🌫️',
                    ),
                    trailing: item.id == governorates.activeGovernorate
                        ? const Icon(
                            Icons.check_circle,
                            color: Color(0xFF0F9D8A),
                          )
                        : isOpen
                        ? Text('$progress%')
                        : const Icon(Icons.lock_outline_rounded),
                    onTap: isOpen
                        ? () {
                            governorates.unlockAndSelectGovernorate(item.id);
                            Navigator.pop(context);
                          }
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
