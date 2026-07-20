import 'dart:convert';

import 'package:flutter/material.dart';

import 'shimmer_image.dart';

class AppImage extends StatelessWidget {
  final String source;
  final BoxFit fit;
  final double? width;
  final double? height;
  final IconData fallbackIcon;
  final double fallbackIconSize;
  final Color? fallbackColor;

  final int? memCacheWidth;
  final int? memCacheHeight;

  const AppImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.fallbackIcon = Icons.broken_image_rounded,
    this.fallbackIconSize = 32,
    this.fallbackColor,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  static bool isDataUri(String s) => s.startsWith('data:image');

  static bool isNetwork(String s) =>
      s.startsWith('http://') ||
      s.startsWith('https://') ||
      s.startsWith('blob:');

  static String toDataUri(List<int> bytes, {String mime = 'image/jpeg'}) =>
      'data:$mime;base64,${base64Encode(bytes)}';

  @override
  Widget build(BuildContext context) {
    if (isDataUri(source)) {
      final comma = source.indexOf(',');
      if (comma > 0 && comma < source.length - 1) {
        try {
          final bytes = base64Decode(source.substring(comma + 1));
          return Image.memory(
            bytes,
            fit: fit,
            width: width,
            height: height,
            gaplessPlayback: true,
            cacheWidth: memCacheWidth,
            cacheHeight: memCacheHeight,
            errorBuilder: (_, __, ___) => _fallback(),
          );
        } catch (_) {
          return _fallback();
        }
      }
      return _fallback();
    }
    if (isNetwork(source)) {
      return SizedBox(
        width: width,
        height: height,
        child: ShimmerImage(
          imageUrl: source,
          fit: fit,
          fallbackIcon: fallbackIcon,
          fallbackColor: fallbackColor,
          fallbackIconSize: fallbackIconSize,
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF1F5F9),
      alignment: Alignment.center,
      child: Icon(
        fallbackIcon,
        color: fallbackColor ?? Colors.grey,
        size: fallbackIconSize,
      ),
    );
  }
}
