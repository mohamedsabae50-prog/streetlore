import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/egypt_governorate.dart';
import '../../logic/governorate_provider.dart';

class GovernorateSelector extends StatelessWidget {
  const GovernorateSelector({
    super.key,
    this.buttonKey,
    this.compact = false,
    this.onChanged,
    this.onExploreAll,
  });

  static const _cityIds = ['alexandria', 'cairo'];
  static const _exploreAll = '__explore_all__';

  final Key? buttonKey;
  final bool compact;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onExploreAll;

  void _select(BuildContext context, GovernorateProvider provider, String id) {
    if (id == _exploreAll) {
      onExploreAll?.call();
      return;
    }
    if (provider.activeGovernorate == id) return;
    if (provider.unlockAndSelectGovernorate(id)) onChanged?.call(id);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GovernorateProvider>();
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final active =
        EgyptGovernorate.byId[provider.activeGovernorate] ??
        EgyptGovernorate.byId['alexandria']!;
    String label(EgyptGovernorate governorate) =>
        isArabic ? governorate.nameAr : governorate.nameEn;

    if (compact) {
      return PopupMenuButton<String>(
        key: buttonKey,
        onSelected: (id) => _select(context, provider, id),
        itemBuilder: (context) => [
          for (final id in _cityIds)
            PopupMenuItem(
              value: id,
              child: Text(label(EgyptGovernorate.byId[id]!)),
            ),
          if (onExploreAll != null) ...[
            const PopupMenuDivider(),
            PopupMenuItem(
              value: _exploreAll,
              child: Text(isArabic ? 'استكشف كل المحافظات' : 'Explore Egypt'),
            ),
          ],
        ],
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFF0F9D8A).withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📍'),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label(active),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(Icons.expand_more_rounded, size: 17),
            ],
          ),
        ),
      );
    }

    return Wrap(
      key: buttonKey,
      spacing: 8,
      children: [
        for (final id in _cityIds)
          ChoiceChip(
            label: Text(label(EgyptGovernorate.byId[id]!)),
            selected: provider.activeGovernorate == id,
            onSelected: (_) => _select(context, provider, id),
          ),
      ],
    );
  }
}
