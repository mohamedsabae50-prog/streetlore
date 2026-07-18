import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;
  final Color? fallbackColor;
  final double fallbackIconSize;

  const ShimmerImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIcon = Icons.image_outlined,
    this.fallbackColor,
    this.fallbackIconSize = 40,
  });

  @override
  State<ShimmerImage> createState() => _ShimmerImageState();
}

class _ShimmerImageState extends State<ShimmerImage> {
  late final ImageProvider _provider;
  late final ImageStream _stream;
  bool _loaded = false;
  bool _failed = false;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _provider = NetworkImage(widget.imageUrl);
    _stream = _provider.resolve(const ImageConfiguration());
    _listener = ImageStreamListener(
      (_, __) {
        if (mounted) setState(() => _loaded = true);
      },
      onError: (_, __) {
        if (mounted) setState(() => _failed = true);
      },
    );
    _stream.addListener(_listener!);
  }

  @override
  void dispose() {
    _stream.removeListener(_listener!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.zero;
    final clip = ClipRRect(
      borderRadius: radius,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOut,
        child: _failed
            ? _Fallback(
                key: const ValueKey('fallback'),
                icon: widget.fallbackIcon,
                color: widget.fallbackColor ?? Colors.grey,
                iconSize: widget.fallbackIconSize,
              )
            : _loaded
                ? Image(
                    key: const ValueKey('image'),
                    image: _provider,
                    fit: widget.fit,
                    gaplessPlayback: true,
                  )
                : Shimmer.fromColors(
                    key: const ValueKey('shimmer'),
                    baseColor: const Color(0xFFE2E8F0),
                    highlightColor: const Color(0xFFF8FAFC),
                    period: const Duration(milliseconds: 1400),
                    child: Container(color: const Color(0xFFE2E8F0)),
                  ),
      ),
    );
    return clip;
  }
}

class _Fallback extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double iconSize;
  const _Fallback({
    super.key,
    required this.icon,
    required this.color,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F5F9),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

class ShimmerCardPlaceholder extends StatelessWidget {
  final double height;
  final double imageHeight;
  final bool dark;

  const ShimmerCardPlaceholder({
    super.key,
    this.height = 220,
    this.imageHeight = 130,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final base = dark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0);
    final highlight =
        dark ? const Color(0xFF4A5568) : const Color(0xFFF8FAFC);
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      period: const Duration(milliseconds: 1400),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: imageHeight,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        width: 180,
                        height: 14,
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 8)),
                    Container(
                        width: double.infinity,
                        height: 10,
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 6)),
                    Container(
                        width: 220,
                        height: 10,
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 12)),
                    Row(
                      children: [
                        Container(
                            width: 60,
                            height: 22,
                            color: Colors.white,
                            margin: const EdgeInsets.only(right: 6)),
                        Container(
                            width: 70,
                            height: 22,
                            color: Colors.white),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
