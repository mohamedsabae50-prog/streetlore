import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/auth_provider.dart';
import 'choose_username_screen.dart';
import 'login_screen.dart';
import 'main_navigation.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _exitController;
  late final Animation<double> _introFade;
  Timer? _navigationTimer;

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
    _introController.forward();

    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _navigationTimer = Timer(const Duration(seconds: 5), _exitThenNavigate);
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _introController.dispose();
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
    return Scaffold(
      backgroundColor: const Color(0xFF101A2B),
      body: FadeTransition(
        opacity: _introFade,
        child: FadeTransition(
          opacity: ReverseAnimation(_exitController),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Semantics(
                container: true,
                label:
                    'EgyptLore. Egypt Unseen — Discover Egypt’s Hidden Stories. اكتشف حكايات وكنوز مصر المخفية',
                child: Image.asset(
                  'assets/images/splash_bg.png',
                  key: const ValueKey('splash-background'),
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x08081422),
                      Color(0x0010182B),
                      Color(0x1210182B),
                    ],
                    stops: [0, 0.48, 1],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
