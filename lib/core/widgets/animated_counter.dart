import 'package:flutter/material.dart';

class AnimatedCounter extends StatefulWidget {
  final int value;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Duration duration;
  final Curve curve;
  final String? prefix;
  final String? suffix;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.textAlign,
    this.duration = const Duration(milliseconds: 900),
    this.curve = Curves.easeOutCubic,
    this.prefix,
    this.suffix,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late int _displayed;

  @override
  void initState() {
    super.initState();
    _displayed = 0;
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    if (widget.value > 0) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animateTo(widget.value);
    }
  }

  void _animateTo(int target) {
    final tween = IntTween(begin: _displayed, end: target);
    final curved = CurvedAnimation(parent: _ctrl, curve: widget.curve);
    final anim = tween.animate(curved);
    void listener() {
      if (mounted) {
        setState(() {
          _displayed = anim.value;
        });
      }
    }

    anim.addListener(listener);
    _ctrl
      ..reset()
      ..forward().whenComplete(() {
        anim.removeListener(listener);
        if (mounted) setState(() => _displayed = target);
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${widget.prefix ?? ''}$_displayed${widget.suffix ?? ''}',
      style: widget.style,
      textAlign: widget.textAlign,
    );
  }
}
