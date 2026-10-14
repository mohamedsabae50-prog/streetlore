import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'image_defaults.dart';

class RobustImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;
  final Color? fallbackColor;
  final double fallbackIconSize;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final String? fallbackImageUrl;

  const RobustImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIcon = Icons.image_outlined,
    this.fallbackColor,
    this.fallbackIconSize = 40,
    this.memCacheWidth,
    this.memCacheHeight,
    this.fallbackImageUrl,
  });

  @override
  State<RobustImage> createState() => _RobustImageState();
}

class _RobustImageState extends State<RobustImage> {
  static final _client = _buildClient();
  late Future<Uint8List?> _future;

  static http.Client _buildClient() {
    return _UserAgentClient();
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(RobustImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.fallbackImageUrl != widget.fallbackImageUrl) {
      _future = _load();
    }
  }

  
  
  
  
  
  
  Future<Uint8List?> _load() async {
    final urls = <String>[
      widget.imageUrl,
      if (widget.fallbackImageUrl != null &&
          widget.fallbackImageUrl!.isNotEmpty &&
          widget.fallbackImageUrl != widget.imageUrl)
        widget.fallbackImageUrl!,
    ];
    for (final url in urls) {
      try {
        final cached = await OfflineImageCache.instance.read(url);
        if (cached != null) return cached;
      } catch (_) {}
      try {
        final response = await _client.get(Uri.parse(url));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          await OfflineImageCache.instance.write(url, response.bodyBytes);
          return response.bodyBytes;
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.zero;
    return ClipRRect(
      borderRadius: radius,
      child: FutureBuilder<Uint8List?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Shimmer.fromColors(
              baseColor: const Color(0xFFE2E8F0),
              highlightColor: const Color(0xFFF8FAFC),
              period: const Duration(milliseconds: 1400),
              child: Container(color: const Color(0xFFE2E8F0)),
            );
          }
          final bytes = snapshot.data;
          if (bytes == null || bytes.isEmpty) {
            return Container(
              color: const Color(0xFF1C2433),
              alignment: Alignment.center,
              child: Icon(
                widget.fallbackIcon,
                color: widget.fallbackColor ?? Colors.white30,
                size: widget.fallbackIconSize,
              ),
            );
          }
          return Image.memory(
            bytes,
            fit: widget.fit,
            gaplessPlayback: true,
            cacheWidth: widget.memCacheWidth,
            cacheHeight: widget.memCacheHeight,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF1C2433),
              alignment: Alignment.center,
              child: Icon(
                widget.fallbackIcon,
                color: widget.fallbackColor ?? Colors.white30,
                size: widget.fallbackIconSize,
              ),
            ),
          );
        },
      ),
    );
  }
}






class OfflineImageCache {
  OfflineImageCache._();
  static final OfflineImageCache instance = OfflineImageCache._();

  final CacheManager _manager = DefaultCacheManager();

  Future<Uint8List?> read(String url) async {
    if (url.trim().isEmpty) return null;
    try {
      final info = await _manager.getFileFromCache(url);
      if (info == null) return null;
      final file = info.file;
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  
  
  Future<void> write(String url, Uint8List bytes) async {
    try {
      await _manager.putFile(
        url,
        bytes,
        fileExtension: url.toLowerCase().contains('.png') ? 'png' : 'jpg',
      );
    } catch (_) {
      
    }
  }
}

class _UserAgentClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(streetloreImageHeaders);
    return request.send();
  }
}
