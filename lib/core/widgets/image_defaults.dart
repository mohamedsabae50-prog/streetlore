import 'package:flutter/material.dart';

const Map<String, String> streetloreImageHeaders = {
  'User-Agent':
      'StreetloreApp/2.1 (https://github.com/mohamedsabae50-prog/streetlore)',
};

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
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF1C2433),
      alignment: Alignment.center,
      child: Icon(
        imageFallbackIconForCategory(category),
        color: Colors.white54,
      ),
    );
  }
}
