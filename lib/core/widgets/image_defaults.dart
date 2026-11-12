import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/offline_storage_service.dart';

const Map<String, String> streetloreImageHeaders = {
  if (!kIsWeb)
    'User-Agent':
        'EgyptLoreApp/2.1 (https://github.com/mohamedsabae50-prog/streetlore)',
};

IconData imageFallbackIconForCategory(String? category) {
  final normalized = category?.toLowerCase() ?? '';
  if (normalized.contains('hotel')) return Icons.hotel_rounded;
  if (normalized.contains('atm') || normalized.contains('cash machine')) {
    return Icons.atm_rounded;
  }
  if (normalized.contains('food') || normalized.contains('restaurant')) {
    return Icons.restaurant_rounded;
  }
  if (normalized.contains('mosque') || normalized.contains('religious')) {
    return Icons.mosque_rounded;
  }
  if (normalized.contains('church') || normalized.contains('cathedral')) {
    return Icons.church_rounded;
  }
  if (normalized.contains('nature') || normalized.contains('beach')) {
    return Icons.landscape_rounded;
  }
  if (normalized.contains('shopping') || normalized.contains('market')) {
    return Icons.storefront_rounded;
  }
  if (normalized.contains('historical') ||
      normalized.contains('archaeological')) {
    return Icons.account_balance_rounded;
  }
  return Icons.museum_rounded;
}

class CategoryImageFallback extends StatelessWidget {
  const CategoryImageFallback({
    super.key,
    required this.category,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.title,
  });

  final String? category;
  final BoxFit fit;
  final double? width;
  final double? height;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF18283A), Color(0xFF101722)],
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            imageFallbackIconForCategory(category),
            color: const Color(0xFFD4AF37),
            size: 36,
          ),
          if (title?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class OfflineAwareImage extends StatelessWidget {
  const OfflineAwareImage({
    super.key,
    required this.imageUrl,
    this.cacheId,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.fallback,
    this.memCacheWidth,
  });

  final String imageUrl;
  final String? cacheId;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? fallback;
  final int? memCacheWidth;

  @override
  Widget build(BuildContext context) {
    final error = fallback ?? const CategoryImageFallback(category: 'General');
    final network = CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      httpHeaders: streetloreImageHeaders,
      placeholder: (_, _) => const ColoredBox(color: Color(0xFF18283A)),
      errorWidget: (_, _, _) => error,
    );
    if (cacheId == null) return network;
    if (kIsWeb) {
      return FutureBuilder<Uint8List?>(
        future: Future.value(
          OfflineStorageService.instance.getCachedImageBytes(imageUrl),
        ),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) return network;
          return Image.memory(
            bytes,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (_, _, _) => error,
          );
        },
      );
    }
    return FutureBuilder<File?>(
      future: OfflineStorageService.instance.getCachedImageFile(
        cacheId!,
        imageUrl,
      ),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) return network;
        return Image.file(
          file,
          fit: fit,
          width: width,
          height: height,
          cacheWidth: memCacheWidth,
          errorBuilder: (_, _, _) => error,
        );
      },
    );
  }
}
