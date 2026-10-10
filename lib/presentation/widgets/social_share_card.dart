import 'dart:typed_data';

import 'package:flutter/material.dart';

class SocialShareCard extends StatelessWidget {
  final Uint8List? photoBytes;
  final Uint8List logoBytes;
  final String category;
  final String title;
  final String subtitle;
  final String footer;
  final TextDirection textDirection;

  const SocialShareCard({
    super.key,
    required this.photoBytes,
    required this.logoBytes,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.footer,
    required this.textDirection,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: textDirection,
      child: SizedBox(
        width: 1080,
        height: 1350,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF10192B), Color(0xFF07111F)],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (photoBytes != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 930,
                  child: Image.memory(
                    photoBytes!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.04),
                        Colors.transparent,
                        const Color(0xFF10192B).withValues(alpha: 0.2),
                        const Color(0xFF10192B),
                      ],
                      stops: const [0, 0.35, 0.58, 0.76],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 64,
                left: 64,
                right: 64,
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.38),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFFFD166),
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 72,
                right: 72,
                bottom: 174,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 76,
                        height: 1.08,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 36,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 64,
                right: 64,
                bottom: 48,
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.memory(
                        logoBytes,
                        width: 82,
                        height: 82,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 20),
                    const Text(
                      'Streetlore',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        footer,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.64),
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
