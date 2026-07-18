import 'package:flutter/material.dart';

class AnimatedStars extends StatefulWidget {
  final double rating;
  final int max;
  final double size;
  final Color color;
  final Color emptyColor;
  final Duration duration;
  final Duration stagger;

  const AnimatedStars({
    super.key,
    required this.rating,
    this.max = 5,
    this.size = 16,
    this.color = const Color(0xFFF59E0B),
    this.emptyColor = const Color(0xFFE2E8F0),
    this.duration = const Duration(milliseconds: 350),
    this.stagger = const Duration(milliseconds: 90),
  });

  @override
  State<AnimatedStars> createState() => _AnimatedStarsState();
}

class _AnimatedStarsState extends State<AnimatedStars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<Animation<double>> _scales;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _scales = List.generate(widget.max, (i) {
      final start = (i * widget.stagger.inMilliseconds) /
          (widget.max * widget.stagger.inMilliseconds + widget.duration.inMilliseconds);
      final end = (start +
              widget.duration.inMilliseconds /
                  (widget.max * widget.stagger.inMilliseconds +
                      widget.duration.inMilliseconds))
          .clamp(0.0, 1.0);
      return Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(start, end, curve: Curves.easeOutBack),
        ),
      );
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.max, (i) {
        final filled = i < widget.rating.floor();
        final half = !filled && i < widget.rating;
        return AnimatedBuilder(
          animation: _scales[i],
          builder: (context, _) {
            return Transform.scale(
              scale: _scales[i].value,
              child: Icon(
                half
                    ? Icons.star_half_rounded
                    : (filled
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded),
                color: filled || half ? widget.color : widget.emptyColor,
                size: widget.size,
              ),
            );
          },
        );
      }),
    );
  }
}
