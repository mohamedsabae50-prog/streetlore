import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/offline_pack.dart';
import '../../l10n/app_strings.dart';
import '../../logic/auth_provider.dart';
import '../../logic/offline_provider.dart';
import '../../logic/place_provider.dart';
import '../../logic/tour_provider.dart';
import 'paywall_screen.dart';

class OfflinePackagesScreen extends StatefulWidget {
  const OfflinePackagesScreen({super.key});

  @override
  State<OfflinePackagesScreen> createState() => _OfflinePackagesScreenState();
}

class _OfflinePackagesScreenState extends State<OfflinePackagesScreen> {
  static final _cityPacks = OfflineProvider.catalog
      .where((pack) => pack.id == 'all_alexandria' || pack.id == 'all_cairo')
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadCatalogData();
    });
  }

  Future<void> _loadCatalogData() async {
    try {
      await Future.wait([
        context.read<PlaceProvider>().ensureLoaded(),
        context.read<TourProvider>().loadTours(),
      ]);
    } catch (error, stackTrace) {
      debugPrint(
        'OfflinePackagesScreen: failed to load pack catalog: '
        '$error\n$stackTrace',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('offline_packages_load_failed'))),
      );
    }
  }

  Future<void> _downloadPack(
    OfflinePack pack, {
    required OfflineProvider offline,
    required bool isPro,
  }) async {
    if (!isPro) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => const PaywallScreen()),
      );
      return;
    }
    try {
      final result = await offline.download(
        pack,
        availablePlaces: context.read<PlaceProvider>().allPlaces,
        availableTours: context.read<TourProvider>().allTours,
        isPro: isPro,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result is DownloadOk
                ? context.tr('offline_packages_download_complete')
                : context.tr('offline_packages_download_empty'),
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'OfflinePackagesScreen: download failed for ${pack.id}: '
        '$error\n$stackTrace',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('offline_packages_download_failed'))),
      );
    }
  }

  Future<void> _removePack(OfflinePack pack, OfflineProvider offline) async {
    try {
      await offline.remove(pack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('offline_packages_removed'))),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'OfflinePackagesScreen: remove failed for ${pack.id}: '
        '$error\n$stackTrace',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('offline_packages_remove_failed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final places = context.watch<PlaceProvider>().allPlaces;
    final tours = context.watch<TourProvider>().allTours;
    final auth = context.watch<AuthProvider>();
    final offline = context.watch<OfflineProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('offline_packages_title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            context.tr('offline_packages_intro'),
            style: TextStyle(color: context.textSec),
          ),
          const SizedBox(height: 16),
          for (final pack in _cityPacks)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _OfflinePackageCard(
                key: ValueKey('offline-package-${pack.id}'),
                pack: pack,
                locale: locale,
                placesCount: places
                    .where((place) => place.governorate == pack.governorateId)
                    .length,
                toursCount: tours
                    .where((tour) => tour.governorate == pack.governorateId)
                    .length,
                isPro: auth.isPro,
                offline: offline,
                onDownload: () =>
                    _downloadPack(pack, offline: offline, isPro: auth.isPro),
                onRemove: () => _removePack(pack, offline),
              ),
            ),
        ],
      ),
    );
  }
}

class _OfflinePackageCard extends StatelessWidget {
  const _OfflinePackageCard({
    super.key,
    required this.pack,
    required this.locale,
    required this.placesCount,
    required this.toursCount,
    required this.isPro,
    required this.offline,
    required this.onDownload,
    required this.onRemove,
  });

  final OfflinePack pack;
  final String locale;
  final int placesCount;
  final int toursCount;
  final bool isPro;
  final OfflineProvider offline;
  final VoidCallback onDownload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final downloaded = offline.isDownloaded(
      pack.id,
      governorateId: pack.governorateId,
    );
    final downloadedPack = offline.packs.firstWhere(
      (candidate) => candidate.storageKey == pack.storageKey,
      orElse: () => pack,
    );
    final downloading = offline.isDownloadingPack(pack);
    final progress = offline.downloadProgress;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.cloud_download_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    pack.id == 'all_cairo'
                        ? context.tr('offline_package_all_cairo')
                        : pack.localizedName(locale),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('offline_package_counts', {
                'places': '$placesCount',
                'tours': '$toursCount',
              }),
              key: ValueKey('offline-counts-${pack.id}'),
              style: TextStyle(color: context.textSec),
            ),
            if (downloaded) ...[
              const SizedBox(height: 6),
              Text(
                context.tr('offline_pack_downloaded', {
                  'places': '${downloadedPack.placesCount}',
                  'tours': '${downloadedPack.toursCount}',
                  'size': downloadedPack.sizeMb.toStringAsFixed(1),
                }),
                style: TextStyle(color: context.textSec, fontSize: 12),
              ),
            ],
            if (downloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress.progress),
              const SizedBox(height: 6),
              Text(
                context.tr('offline_pack_progress', {
                  'done': '${progress.itemsDone}',
                  'total': '${progress.totalItems}',
                  'images': '${progress.cachedImagesCount}',
                  'size': progress.sizeMb.toStringAsFixed(1),
                }),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            if (downloaded)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: ValueKey('update-pack-${pack.id}'),
                    onPressed: offline.isDownloading ? null : onDownload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(context.tr('offline_pack_update')),
                  ),
                  TextButton.icon(
                    key: ValueKey('remove-pack-${pack.id}'),
                    onPressed: offline.isDownloading ? null : onRemove,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(context.tr('offline_pack_remove')),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: ValueKey('download-pack-${pack.id}'),
                  onPressed: offline.isDownloading ? null : onDownload,
                  icon: Icon(
                    isPro
                        ? Icons.download_for_offline_rounded
                        : Icons.workspace_premium_rounded,
                  ),
                  label: Text(context.tr('offline_download')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class OfflinePackagesEntryTile extends StatelessWidget {
  const OfflinePackagesEntryTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineProvider>(
      builder: (context, offline, _) {
        final downloadedCount = OfflineProvider.catalog
            .where(
              (pack) =>
                  (pack.id == 'all_alexandria' || pack.id == 'all_cairo') &&
                  offline.isDownloaded(
                    pack.id,
                    governorateId: pack.governorateId,
                  ),
            )
            .length;
        return Material(
          key: const ValueKey('profile-offline-packages'),
          color: context.cardColor,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const OfflinePackagesScreen(),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.cloud_download_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('offline_packages_title'),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr('offline_packages_profile_subtitle', {
                            'count': '$downloadedCount',
                          }),
                          style: TextStyle(
                            color: context.textSec,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: context.hintColor),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
