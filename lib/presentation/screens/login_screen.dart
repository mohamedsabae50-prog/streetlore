import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/animations/app_animations.dart';
import '../../core/constants/app_colors.dart';
import '../../logic/auth_provider.dart';
import 'main_navigation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  bool _isLoading = false;
  String? _focusedField;

  late final AnimationController _animCtrl;
  late final Animation<double> _bgBlob1;
  late final Animation<double> _bgBlob2;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _bgBlob1 = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.linear));
    _bgBlob2 = Tween<double>(
      begin: 0.5,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.linear));
    _nameFocus.addListener(
      () => setState(() => _focusedField = _nameFocus.hasFocus ? 'name' : null),
    );
    _emailFocus.addListener(
      () =>
          setState(() => _focusedField = _emailFocus.hasFocus ? 'email' : null),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    await context.read<AuthProvider>().signIn(
      name: _nameCtrl.text,
      email: _emailCtrl.text,
    );

    if (!mounted) return;
    _goToMain();
  }

  Future<void> _continueAsGuest() async {
    HapticFeedback.lightImpact();
    await context.read<AuthProvider>().signIn(
      name: 'Guest Explorer',
      email: 'guest@streetlore.com',
    );
    if (!mounted) return;
    _goToMain();
  }

  void _goToMain() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (ctx, a, second) => const MainNavigation(),
        transitionDuration: const Duration(milliseconds: 550),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (ctx, a, second, child) =>
            PageTransitions.fadeScale(ctx, a, second, child),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: Stack(
        children: [
          if (!context.isDark)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _animCtrl,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _BlobPainter(
                        phase: _bgBlob1.value,
                        phase2: _bgBlob2.value,
                      ),
                    );
                  },
                ),
              ),
            ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),

                    Center(
                      child: PopIn(
                        duration: const Duration(milliseconds: 700),
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.explore_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FadeInUp(
                      delay: const Duration(milliseconds: 200),
                      child: Text(
                        'Welcome to\nStreetlore',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: context.textPri,
                          height: 1.15,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FadeInUp(
                      delay: const Duration(milliseconds: 280),
                      child: Text(
                        'Sign in to save your favorite places and access exclusive tours.',
                        style: TextStyle(
                          fontSize: 15,
                          color: context.textSec,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          FadeInUp(
                            delay: const Duration(milliseconds: 360),
                            child: _InputField(
                              controller: _nameCtrl,
                              focusNode: _nameFocus,
                              isFocused: _focusedField == 'name',
                              label: 'Full Name',
                              hint: 'e.g. Ahmed Hassan',
                              icon: Icons.person_outline_rounded,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Please enter your name';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          FadeInUp(
                            delay: const Duration(milliseconds: 440),
                            child: _InputField(
                              controller: _emailCtrl,
                              focusNode: _emailFocus,
                              isFocused: _focusedField == 'email',
                              label: 'Email Address',
                              hint: 'e.g. ahmed@example.com',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!v.contains('@')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 28),
                          FadeInUp(
                            delay: const Duration(milliseconds: 520),
                            child: _GradientButton(
                              isLoading: _isLoading,
                              onTap: _signIn,
                              label: 'Sign In',
                              icon: Icons.login_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    FadeInUp(
                      delay: const Duration(milliseconds: 600),
                      child: Row(
                        children: [
                          Expanded(child: Divider(color: context.borderColor)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'or',
                              style: TextStyle(
                                color: context.textSec,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: context.borderColor)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    FadeInUp(
                      delay: const Duration(milliseconds: 660),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SocialButton(
                              label: 'Google',
                              icon: Icons.g_mobiledata_rounded,
                              color: const Color(0xFFEA4335),
                              onTap: () async {
                                try {
                                  await Supabase.instance.client.auth
                                      .signInWithOAuth(
                                        OAuthProvider.google,
                                        redirectTo: kIsWeb
                                            ? null
                                            : 'io.supabase.streetlore://login-callback/',
                                      );
                                } catch (e) {
                                  print('Error signing in with Google: $e');
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    FadeInUp(
                      delay: const Duration(milliseconds: 740),
                      child: Center(
                        child: PressScale(
                          onTap: _continueAsGuest,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 14),
                                children: [
                                  TextSpan(
                                    text: 'Just exploring? ',
                                    style: TextStyle(color: context.textSec),
                                  ),
                                  TextSpan(
                                    text: 'Continue as Guest',
                                    style: TextStyle(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '  →',
                                    style: TextStyle(color: AppColors.accent),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool isFocused;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    this.focusNode,
    this.isFocused = false,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        style: TextStyle(
          color: context.textPri,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: context.textSec, fontSize: 14),
          hintStyle: TextStyle(color: context.hintColor, fontSize: 14),
          prefixIcon: AnimatedScale(
            scale: isFocused ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Icon(
              icon,
              color: isFocused ? AppColors.primary : context.textSec,
              size: 20,
            ),
          ),
          filled: true,
          fillColor: context.cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: context.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: context.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
        ),
        validator: validator,
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;
  final String label;
  final IconData icon;

  const _GradientButton({
    required this.isLoading,
    required this.onTap,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: isLoading ? null : onTap,
      pressedScale: 0.97,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: isLoading
              ? const LinearGradient(
                  colors: [Color(0xFF64748B), Color(0xFF475569)],
                )
              : AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isLoading
              ? []
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      pressedScale: 0.96,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: context.textPri,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  final double phase;
  final double phase2;
  _BlobPainter({required this.phase, required this.phase2});

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.18),
              AppColors.primary.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(
                size.width * (0.2 + 0.15 * _wave(phase)),
                size.height * (0.25 + 0.1 * _wave(phase + 0.3)),
              ),
              radius: 200,
            ),
          );
    canvas.drawCircle(
      Offset(
        size.width * (0.2 + 0.15 * _wave(phase)),
        size.height * (0.25 + 0.1 * _wave(phase + 0.3)),
      ),
      200,
      paint1,
    );

    final paint2 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.accent.withValues(alpha: 0.16),
              AppColors.accent.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(
                size.width * (0.85 - 0.1 * _wave(phase2)),
                size.height * (0.7 - 0.05 * _wave(phase2 + 0.5)),
              ),
              radius: 240,
            ),
          );
    canvas.drawCircle(
      Offset(
        size.width * (0.85 - 0.1 * _wave(phase2)),
        size.height * (0.7 - 0.05 * _wave(phase2 + 0.5)),
      ),
      240,
      paint2,
    );

    final paint3 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.success.withValues(alpha: 0.10),
              AppColors.success.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(
                size.width * (0.5 + 0.2 * _wave(phase2 + 0.7)),
                size.height * (1.1 - 0.2 * _wave(phase + 0.2)),
              ),
              radius: 280,
            ),
          );
    canvas.drawCircle(
      Offset(
        size.width * (0.5 + 0.2 * _wave(phase2 + 0.7)),
        size.height * (1.1 - 0.2 * _wave(phase + 0.2)),
      ),
      280,
      paint3,
    );
  }

  double _wave(double t) {
    return 0.5 - 0.5 * (1 - t % 1) * 2 + (t % 1) * 2 - 1;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
