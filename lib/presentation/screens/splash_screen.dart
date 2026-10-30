import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/auth_provider.dart';
import 'choose_username_screen.dart';
import 'login_screen.dart';
import 'main_navigation.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.minimumDisplayDuration = const Duration(milliseconds: 2800),
  });

  final Duration minimumDisplayDuration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _radarStageDuration = Duration(milliseconds: 800);
  static const _stageTransitionDuration = Duration(milliseconds: 400);
  static const _pyramidsVisibleDuration = Duration(milliseconds: 1600);

  late final AnimationController _introController;
  late final AnimationController _ambientController;
  late final AnimationController _exitController;
  late final AnimationController _pyramidsProgressController;
  late final AnimationController _stageTransitionController;
  late final Animation<double> _introFade;
  late final Animation<double> _logoScale;
  final Stopwatch _splashStopwatch = Stopwatch();
  Timer? _navigationTimer;
  Timer? _stageTimer;
  bool _showPyramids = false;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _introFade = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeInOut,
    );
    _logoScale = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0, 0.7, curve: Curves.elasticOut),
    );
    _introController.forward();

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _pyramidsProgressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _stageTransitionController =
        AnimationController(vsync: this, duration: _stageTransitionDuration)
          ..addStatusListener((status) {
            if (status != AnimationStatus.completed) return;
            final remaining =
                widget.minimumDisplayDuration - _splashStopwatch.elapsed;
            final visibleDuration = remaining > _pyramidsVisibleDuration
                ? remaining
                : _pyramidsVisibleDuration;
            _navigationTimer = Timer(visibleDuration, _exitThenNavigate);
          });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _splashStopwatch.start();
      _stageTimer = Timer(_radarStageDuration, () {
        if (!mounted) return;
        setState(() => _showPyramids = true);
        _pyramidsProgressController.forward();
        _stageTransitionController.forward();
      });
    });

    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _stageTimer?.cancel();
    _ambientController.dispose();
    _introController.dispose();
    _pyramidsProgressController.dispose();
    _stageTransitionController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  Future<void> _exitThenNavigate() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();

    const maxWait = Duration(seconds: 3);
    final started = DateTime.now();
    while (auth.isLoading && DateTime.now().difference(started) < maxWait) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }

    await _exitController.forward();
    if (!mounted) return;

    final Widget destination;
    if (!auth.hasSeenOnboarding) {
      destination = const OnboardingScreen();
    } else if (!auth.isLoggedIn) {
      destination = const LoginScreen();
    } else if (auth.requiresUsername) {
      destination = const ChooseUsernameScreen();
    } else {
      destination = const MainNavigation();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (ctx, animation, second) => destination,
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (ctx, animation, second, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      backgroundColor: const Color(0xFF060D1A),
      body: FadeTransition(
        opacity: ReverseAnimation(_exitController),
        child: AnimatedSwitcher(
          duration: _stageTransitionDuration,
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          child: _showPyramids
              ? _buildPyramidsStage()
              : _buildRadarStage(isArabic),
        ),
      ),
    );
  }

  Widget _buildRadarStage(bool isArabic) {
    return KeyedSubtree(
      key: const ValueKey('radar-stage'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            key: const ValueKey('radar-background'),
            container: true,
            label:
                'EgyptLore. Egypt Unseen — Discover Egypt’s Hidden Stories. اكتشف حكايات وكنوز مصر المخفية',
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.22),
                  radius: 1.15,
                  colors: [
                    Color(0xFF14263C),
                    Color(0xFF0D1B2A),
                    Color(0xFF060D1A),
                  ],
                  stops: [0, 0.52, 1],
                ),
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 0.5,
                colors: [
                  Color(0x22D4AF37),
                  Color(0x0DD4AF37),
                  Color(0x00D4AF37),
                ],
                stops: [0, 0.48, 1],
              ),
            ),
          ),
          RepaintBoundary(
            child: CustomPaint(
              painter: _ExplorerSkyPainter(_ambientController),
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _introFade,
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  ScaleTransition(
                    scale: _logoScale,
                    child: Semantics(
                      image: true,
                      label: 'EgyptLore compass',
                      child: Container(
                        width: 204,
                        height: 204,
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF15253A).withValues(alpha: .5),
                          border: Border.all(
                            color: const Color(0x66D4AF37),
                            width: 1,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x44D4AF37),
                              blurRadius: 60,
                              spreadRadius: 5,
                            ),
                            BoxShadow(
                              color: Color(0x663BCCD2),
                              blurRadius: 100,
                              spreadRadius: -10,
                            ),
                          ],
                        ),
                        child: AnimatedBuilder(
                          animation: _ambientController,
                          child: Image.asset(
                            'assets/images/compass_only.png',
                            fit: BoxFit.contain,
                          ),
                          builder: (context, logo) => ShaderMask(
                            blendMode: BlendMode.srcATop,
                            shaderCallback: (bounds) => LinearGradient(
                              begin: Alignment(
                                -1.6 + 3.2 * _ambientController.value,
                                -0.5,
                              ),
                              end: Alignment(
                                -0.8 + 3.2 * _ambientController.value,
                                0.5,
                              ),
                              colors: const [
                                Color(0x00FFE7A3),
                                Color(0x44FFE7A3),
                                Color(0x00FFE7A3),
                              ],
                              stops: const [0, 0.5, 1],
                            ).createShader(bounds),
                            child: logo,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0, .24),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _introController,
                            curve: const Interval(
                              .24,
                              .78,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                        ),
                    child: Column(
                      children: [
                        Text(
                          'EgyptLore',
                          textDirection: isArabic
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          style: const TextStyle(
                            color: Color(0xFFF4E7C8),
                            fontSize: 34,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 2.2,
                            shadows: [
                              Shadow(color: Color(0x66D4AF37), blurRadius: 22),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 17,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x1AD4AF37),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0x55D4AF37)),
                          ),
                          child: Text(
                            isArabic
                                ? 'استكشف الحكايات والكنوز من حولك'
                                : 'Discover the Hidden Stories Around You',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFE7D6AF),
                              fontSize: 13,
                              letterSpacing: .25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 2),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(48, 0, 48, 36),
                    child: AnimatedBuilder(
                      animation: _ambientController,
                      builder: (context, child) => Container(
                        height: 3,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            begin: Alignment(
                              -1 + 2 * _ambientController.value,
                              0,
                            ),
                            end: Alignment(1 + 2 * _ambientController.value, 0),
                            colors: const [
                              Color(0x223BCCD2),
                              Color(0xFFD4AF37),
                              Color(0xFFF59E0B),
                              Color(0xFF3BCCD2),
                              Color(0x223BCCD2),
                            ],
                          ),
                          boxShadow: const [
                            BoxShadow(color: Color(0x66D4AF37), blurRadius: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPyramidsStage() {
    return KeyedSubtree(
      key: const ValueKey('pyramids-stage'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            container: true,
            label:
                'EgyptLore. Egypt Unseen — Discover Egypt’s Hidden Stories. اكتشف حكايات وكنوز مصر المخفية',
            child: Image.asset(
              'assets/images/splash_bg.png',
              key: const ValueKey('pyramids-background-image'),
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
          RepaintBoundary(
            child: CustomPaint(
              painter: _GoldenParticlesPainter(_ambientController),
              child: const SizedBox.expand(),
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.36),
            child: RotationTransition(
              turns: _ambientController,
              child: Image.asset(
                'assets/images/compass_only.png',
                key: const ValueKey('pyramids-compass-image'),
                width: 72,
                height: 72,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const Align(
            alignment: Alignment(0, -0.02),
            child: Text(
              'EGYPTLORE',
              key: ValueKey('pyramids-title'),
              style: TextStyle(
                color: Color(0xFFF4E7C8),
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 5,
                shadows: [Shadow(color: Color(0x99D4AF37), blurRadius: 20)],
              ),
            ),
          ),
          Positioned(
            left: 48,
            right: 48,
            bottom: 56,
            child: AnimatedBuilder(
              animation: _pyramidsProgressController,
              builder: (context, _) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  key: const ValueKey('pyramids-progress'),
                  value: _pyramidsProgressController.value,
                  minHeight: 3,
                  backgroundColor: const Color(0x55D4AF37),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFD4AF37)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldenParticlesPainter extends CustomPainter {
  _GoldenParticlesPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(29);
    final time = animation.value;
    for (var i = 0; i < 36; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final y = (baseY - time * size.height * .16) % size.height;
      final twinkle = .25 + .75 * (1 + math.sin(time * math.pi * 4 + i)) / 2;
      final paint = Paint()
        ..color = const Color(0xFFFFD978).withValues(alpha: .42 * twinkle);
      canvas.drawCircle(Offset(x, y), i % 7 == 0 ? 1.6 : 1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GoldenParticlesPainter oldDelegate) => false;
}

class _ExplorerSkyPainter extends CustomPainter {
  _ExplorerSkyPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .4);
    final maxRadius = size.shortestSide * .46;
    final time = animation.value;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 0; i < 3; i++) {
      final phase = (time + i / 3) % 1;
      ringPaint.color = const Color(
        0xFFD4AF37,
      ).withValues(alpha: (1 - phase) * .17);
      canvas.drawCircle(center, maxRadius * (.28 + phase * .72), ringPaint);
    }

    final hexPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    const hexWidth = 30.0;
    const hexHeight = 26.0;
    for (var row = -12; row <= 12; row++) {
      for (var column = -12; column <= 12; column++) {
        final x = size.width / 2 + column * hexWidth * 1.5;
        final y =
            size.height * .4 +
            row * hexHeight * 1.72 +
            (column.isEven ? 0 : hexHeight * .86);
        final position = Offset(x, y);
        final distance = (position - center).distance / maxRadius;
        if (distance > 1.35) continue;
        final fade = (1 - distance / 1.35).clamp(0.0, 1.0);
        hexPaint.color = const Color(0xFF63B8B8).withValues(
          alpha:
              fade *
              (.035 + .035 * (1 + math.sin(time * math.pi * 2 + row)) / 2),
        );
        final path = Path();
        for (var corner = 0; corner < 6; corner++) {
          final angle = math.pi / 3 * corner;
          final point = Offset(
            x + 12 * math.cos(angle),
            y + 12 * math.sin(angle),
          );
          if (corner == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        path.close();
        canvas.drawPath(path, hexPaint);
      }
    }

    final compassRadius = size.shortestSide * .31;
    final compassPaint = Paint()
      ..color = const Color(0x44D4AF37)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(time * math.pi * 2);
    canvas.drawCircle(Offset.zero, compassRadius, compassPaint);
    canvas.drawCircle(Offset.zero, compassRadius - 5, compassPaint);
    for (var point = 0; point < 16; point++) {
      final angle = math.pi * 2 * point / 16;
      final inner = compassRadius - (point.isEven ? 13 : 7);
      final outer = compassRadius - 1;
      canvas.drawLine(
        Offset(math.cos(angle) * inner, math.sin(angle) * inner),
        Offset(math.cos(angle) * outer, math.sin(angle) * outer),
        compassPaint,
      );
    }
    canvas.restore();

    final random = math.Random(29);
    final particlePaint = Paint();
    for (var i = 0; i < 42; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final y = (baseY - time * size.height * .22) % size.height;
      final twinkle = .25 + .75 * (1 + math.sin(time * math.pi * 4 + i)) / 2;
      particlePaint.color = const Color(
        0xFFFFD978,
      ).withValues(alpha: .36 * twinkle);
      canvas.drawCircle(Offset(x, y), i % 7 == 0 ? 1.7 : 1, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ExplorerSkyPainter oldDelegate) => false;
}
