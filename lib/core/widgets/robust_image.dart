import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';

/// A robust image widget that:
/// - Uses Flutter's native HTTP client (not CachedNetworkImage) with proper User-Agent
/// - Falls back gracefully on errors
/// - Shows a shimmer placeholder while loading
/// - Works on both Android and web
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
  late final Future<http.Response> _future;

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

  Future<http.Response> _load() {
    return _client.get(
      Uri.parse(widget.imageUrl),
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Mobile Safari/537.36',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.zero;
    return ClipRRect(
      borderRadius: radius,
      child: FutureBuilder<http.Response>(
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
          if (snapshot.hasError || snapshot.data?.statusCode != 200) {
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
          final bytes = snapshot.data!.bodyBytes;
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

class _UserAgentClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['User-Agent'] =
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Mobile Safari/537.36';
    return request.send();
  }
}
