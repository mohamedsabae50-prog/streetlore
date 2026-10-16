import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/auth_provider.dart';
import '../widgets/compass_brand.dart';
import 'login_screen.dart';
import 'main_navigation.dart';
import 'onboarding_screen.dart';
import 'choose_username_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const Color _bg = Color(0xFFFFF7E6);
  static const Color _letterColor = Color(0xFF18324B);

  late final AnimationController _exitCtrl;
  late final AnimationController _introCtrl;
  Timer? _navigationTimer;
  late final Animation<double> _logoFade;
  late final Animation<double> _taglineFade;
  late final Animation<Offset> _taglineSlide;

  @override
  void initState() {
    super.initState();

    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..forward();

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeIn),
      ),
    );

    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _introCtrl, curve: const Interval(0.55, 1.0)),
    );

    _taglineSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _introCtrl,
            curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _navigationTimer = Timer(
      const Duration(milliseconds: 5000),
      _exitThenNavigate,
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _introCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  Future<void> _exitThenNavigate() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();

    const maxWait = Duration(seconds: 3);
    final started = DateTime.now();
    while (auth.isLoading && DateTime.now().difference(started) < maxWait) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }

    await _exitCtrl.forward();
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
    return Scaffold(
      backgroundColor: _bg,
      body: AnimatedBuilder(
        animation: _exitCtrl,
        builder: (context, _) {
          return DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF8E8), Color(0xFFF2D49B)],
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _EgyptHorizonPainter()),
                ),
                Center(
                  child: SingleChildScrollView(
                    clipBehavior: Clip.none,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'EgyptLore',
                          style: TextStyle(
                            color: _letterColor,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FadeTransition(
                          opacity: _logoFade,
                          child: const CompassBrandIntro(
                            size: 220,
                            totalDuration: Duration(milliseconds: 4200),
                            loop: false,
                            spinCompass: true,
                            compassSpinDuration: Duration(seconds: 18),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FadeTransition(
                          opacity: _taglineFade,
                          child: SlideTransition(
                            position: _taglineSlide,
                            child: const Column(
                              children: [
                                Text(
                                  "Egypt Unseen — Discover Egypt's Hidden Stories",
                                  style: TextStyle(
                                    color: _letterColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'اكتشف حكايات وكنوز مصر المخفية',
                                  style: TextStyle(
                                    color: Color(0xFF8C7B5E),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 160,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _taglineFade,
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _letterColor.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_exitCtrl.value > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: _letterColor.withValues(
                          alpha: _exitCtrl.value * 0.85,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EgyptHorizonPainter extends CustomPainter {
  const _EgyptHorizonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final horizon = size.height * 0.76;
    final sun = Paint()
      ..color = const Color(0xFFE9AF4B).withValues(alpha: 0.36);
    canvas.drawCircle(Offset(size.width * 0.5, horizon - 16), 58, sun);

    final skyline = Paint()
      ..color = const Color(0xFFB97838).withValues(alpha: 0.42);
    final pyramid = Path()
      ..moveTo(size.width * 0.1, horizon)
      ..lineTo(size.width * 0.28, horizon - 118)
      ..lineTo(size.width * 0.45, horizon)
      ..close();
    canvas.drawPath(pyramid, skyline);
    final secondPyramid = Path()
      ..moveTo(size.width * 0.32, horizon)
      ..lineTo(size.width * 0.47, horizon - 82)
      ..lineTo(size.width * 0.61, horizon)
      ..close();
    canvas.drawPath(secondPyramid, skyline);

    final river = Path()
      ..moveTo(0, horizon + 18)
      ..cubicTo(
        size.width * 0.3,
        horizon - 4,
        size.width * 0.62,
        horizon + 42,
        size.width,
        horizon + 10,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      river,
      Paint()..color = const Color(0xFF4D9A9A).withValues(alpha: 0.34),
    );
  }

  @override
  bool shouldRepaint(covariant _EgyptHorizonPainter oldDelegate) => false;
}
