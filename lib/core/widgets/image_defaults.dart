import 'package:flutter/material.dart';

const Map<String, String> streetloreImageHeaders = {
  'User-Agent':
      'StreetloreApp/2.1 (https://github.com/mohamedsabae50-prog/streetlore)',
};

String imageFallbackUrlForCategory(String? category) {
  final normalized = category?.toLowerCase() ?? '';
  final id = switch (normalized) {
    final value when value.contains('hotel') =>
      'photo-1566073771259-6a8506099945',
    final value when value.contains('food') || value.contains('restaurant') =>
      'photo-1517248135467-4c7edcad34c4',
    final value when value.contains('mosque') || value.contains('religious') =>
      'photo-1519817650390-64a93db51149',
    final value when value.contains('church') ||
          value.contains('cathedral') =>
      'photo-1438032005730-c779502df39b',
    final value when value.contains('nature') || value.contains('beach') =>
      'photo-1500530855697-b586d89ba3ee',
    final value when value.contains('shopping') ||
          value.contains('market') =>
      'photo-1441986300917-64674bd600d8',
    final value when value.contains('historical') ||
          value.contains('archaeological') =>
      'photo-1511818966892-d7d671e672a2',
    _ => 'photo-1564399579883-451a5d44ec08',
  };
  return 'https://images.unsplash.com/$id?auto=format&fit=crop&w=1000&q=80';
}

IconData imageFallbackIconForCategory(String? category) {
  final normalized = category?.toLowerCase() ?? '';
  if (normalized.contains('hotel')) return Icons.hotel_rounded;
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
  });

  final String? category;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) => Image.network(
    imageFallbackUrlForCategory(category),
    fit: fit,
    width: width,
    height: height,
    headers: streetloreImageHeaders,
    errorBuilder: (context, error, stackTrace) => Container(
      width: width,
      height: height,
      color: const Color(0xFF1C2433),
      alignment: Alignment.center,
      child: Icon(
        imageFallbackIconForCategory(category),
        color: Colors.white54,
      ),
    ),
  );
}
