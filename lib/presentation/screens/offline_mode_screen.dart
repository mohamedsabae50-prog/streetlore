import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/animated_icons.dart';
import '../../data/models/offline_pack.dart';
import '../../logic/offline_provider.dart';
import '../../logic/place_provider.dart';

class OfflineModeScreen extends StatefulWidget {
  const OfflineModeScreen({super.key});

  @override
  State<OfflineModeScreen> createState() => _OfflineModeScreenState();
}

class _OfflineModeScreenState extends State<OfflineModeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OfflineProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Offline Mode')),
      body: Consumer<OfflineProvider>(
        builder: (context, off, _) {
          final downloaded = off.packs;
          final available = OfflineProvider.catalog
              .where((p) => !downloaded.any((d) => d.id == p.id))
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            physics: const BouncingScrollPhysics(),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF334155)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: AnimatedLottieIcon(
                          animation: LottieAnimations.cloud,
                          size: 40,
                          color: Colors.white,
                          secondaryColor: Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Travel without signal',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text('${off.totalDownloadedMb} MB downloaded',
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (downloaded.isNotEmpty) ...[
                Text('Downloaded', style: AppTextStyles.sectionTitle),
                const SizedBox(height: 8),
                for (final p in downloaded) _DownloadedTile(pack: p),
                const SizedBox(height: 20),
              ],
              if (available.isNotEmpty) ...[
                Text('Available to download', style: AppTextStyles.sectionTitle),
                const SizedBox(height: 8),
                for (final p in available) _AvailableTile(pack: p),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DownloadedTile extends StatelessWidget {
  final OfflinePack pack;
  const _DownloadedTile({required this.pack});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          _PackIcon(emoji: pack.coverEmoji, downloaded: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pack.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('${pack.sizeMb} MB · ${pack.placeIds.length} places',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.read<OfflineProvider>().remove(pack),
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }
}

class _AvailableTile extends StatelessWidget {
  final OfflinePack pack;
  const _AvailableTile({required this.pack});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textHint.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          _PackIcon(emoji: pack.coverEmoji, downloaded: false),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pack.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(pack.description,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('${pack.sizeMb} MB · ${pack.placeIds.length} places',
                    style: TextStyle(color: AppColors.textHint, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => context.read<OfflineProvider>().download(
                  pack,
                  availablePlaces: context.read<PlaceProvider>().places,
                ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Download',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _PackIcon extends StatelessWidget {
  final String emoji;
  final bool downloaded;
  const _PackIcon({required this.emoji, required this.downloaded});
  @override
  Widget build(BuildContext context) {
    final icon = _iconFor(emoji);
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: (downloaded ? AppColors.success : AppColors.primary)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon,
          color: downloaded ? AppColors.success : AppColors.primary, size: 24),
    );
  }

  IconData _iconFor(String e) {
    
    if (e.contains('book') || e.contains('read')) return Icons.menu_book_rounded;
    if (e.contains('museum') || e.contains('pillar') || e.contains('castle')) {
      return Icons.account_balance_rounded;
    }
    if (e.contains('food') || e.contains('restaurant') || e.contains('cafe')) {
      return Icons.restaurant_rounded;
    }
    if (e.contains('beach') || e.contains('sea') || e.contains('wave')) {
      return Icons.beach_access_rounded;
    }
    return Icons.location_on_rounded;
  }
}
