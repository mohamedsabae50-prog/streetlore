import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';

class RobustImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;
  final Color? fallbackColor;
  final double fallbackIconSize;
  final int? memCacheWidth;
  final int? memCacheHeight;

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
    if (oldWidget.imageUrl != widget.imageUrl) {
      _future = _load();
    }
  }

  /// Load order:
  ///   1. Disk cache populated by the Offline Download flow
  ///      (DefaultCacheManager via flutter_cache_manager).
  ///   2. Live network fetch (also written through the same cache so
  ///      the next view is offline-ready).
  ///   3. Null → the UI shows the fallback icon.
  Future<Uint8List?> _load() async {
    try {
      final cached = await OfflineImageCache.instance.read(widget.imageUrl);
      if (cached != null) {
        return cached;
      }
    } catch (_) {/* ignore and fall back to network */}
    try {
      final res = await _client.get(
        Uri.parse(widget.imageUrl),
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Mobile Safari/537.36',
        },
      );
      if (res.statusCode == 200) {
        // Persist to the shared cache so the same image is offline-ready
        // for the next view. Fire-and-forget; the caller already has the
        // bytes in memory.
        // ignore: discarded_futures
        OfflineImageCache.instance.write(widget.imageUrl, res.bodyBytes);
        return res.bodyBytes;
      }
      return null;
    } catch (_) {
      return null;
    }
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

/// Thin wrapper around [DefaultCacheManager] from `flutter_cache_manager`
/// that gives the rest of the app a synchronous-read-style interface for
/// cached network images. The Offline Download flow already populates
/// this same manager, so an image that was prefetched will be served
/// from disk on the next render — even with airplane mode on.
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

  /// Write raw image bytes to the same disk cache used by
  /// `CachedNetworkImage` and by `RobustImage`. Fire-and-forget.
  Future<void> write(String url, Uint8List bytes) async {
    try {
      await _manager.putFile(url, bytes);
    } catch (_) {
      // best-effort write; never block the render path on it
    }
  }
}

class _UserAgentClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['User-Agent'] =
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Mobile Safari/537.36';
    return request.send();
  }
}
