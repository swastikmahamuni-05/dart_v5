import 'dart:async';
import 'package:flutter/material.dart';
import '../login/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _ripple1Animation;
  late Animation<double> _ripple2Animation;
  late Animation<double> _taglineAnimation;
  late Animation<double> _progressAnimation;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Badge scale entrance with spring/bounce
    _scaleAnimation = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.60, curve: Curves.easeOutBack),
      ),
    );

    // Fade-in animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    // Outer water ripple
    _ripple1Animation = Tween<double>(begin: 0.8, end: 1.45).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.85, curve: Curves.easeOutQuad),
      ),
    );

    // Inner water ripple
    _ripple2Animation = Tween<double>(begin: 0.7, end: 1.25).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.30, 0.95, curve: Curves.easeOutQuad),
      ),
    );

    // Tagline staggered entrance
    _taglineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.40, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    // Smooth loading bar progression
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.95, curve: Curves.easeInOutCubic),
      ),
    );

    _controller.forward();

    // Navigate to LoginScreen after splash animation completes
    _navigationTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 700),
            pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOutCubic,
                ),
                child: child,
              );
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0B1120) : Colors.white;
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const primaryAccent = Color(0xFF0284C7);
    const secondaryAccent = Color(0xFF38BDF8);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final screenHeight = constraints.maxHeight;

            // Responsive badge size clamped safely for mobile screens
            final badgeSize = (screenWidth * 0.42).clamp(130.0, 175.0);
            final spacing = (screenHeight * 0.035).clamp(16.0, 36.0);

            return Stack(
              alignment: Alignment.center,
              children: [
                // 1. Ambient Background Glow Orbs
                Positioned(
                  top: -80,
                  right: -80,
                  child: Container(
                    width: screenWidth * 0.75,
                    height: screenWidth * 0.75,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          secondaryAccent.withValues(alpha: isDark ? 0.18 : 0.14),
                          secondaryAccent.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -80,
                  left: -80,
                  child: Container(
                    width: screenWidth * 0.70,
                    height: screenWidth * 0.70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          primaryAccent.withValues(alpha: isDark ? 0.16 : 0.12),
                          primaryAccent.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. Responsive Center Content scaled safely to screen
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: screenWidth,
                          maxHeight: screenHeight,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Animated Logo Badge with Concentric Water Waves
                            AnimatedBuilder(
                              animation: _controller,
                              builder: (context, child) {
                                final fade = _fadeAnimation.value;
                                final scale = _scaleAnimation.value;
                                final ripple1 = _ripple1Animation.value;
                                final ripple2 = _ripple2Animation.value;

                                final ripple1Opacity = ((1.45 - ripple1) / 0.65).clamp(0.0, 1.0) * 0.35;
                                final ripple2Opacity = ((1.25 - ripple2) / 0.55).clamp(0.0, 1.0) * 0.25;

                                return Opacity(
                                  opacity: fade,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Outer Water Ripple Wave
                                      Transform.scale(
                                        scale: ripple1,
                                        child: Container(
                                          width: badgeSize * 1.35,
                                          height: badgeSize * 1.35,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: secondaryAccent.withValues(alpha: ripple1Opacity),
                                              width: 2.5,
                                            ),
                                            color: secondaryAccent.withValues(alpha: ripple1Opacity * 0.15),
                                          ),
                                        ),
                                      ),

                                      // Secondary Water Ripple Wave
                                      Transform.scale(
                                        scale: ripple2,
                                        child: Container(
                                          width: badgeSize * 1.18,
                                          height: badgeSize * 1.18,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: primaryAccent.withValues(alpha: ripple2Opacity),
                                              width: 2.0,
                                            ),
                                            color: primaryAccent.withValues(alpha: ripple2Opacity * 0.2),
                                          ),
                                        ),
                                      ),

                                      // The Squircle Logo Badge
                                      Transform.scale(
                                        scale: scale,
                                        child: Container(
                                          width: badgeSize,
                                          height: badgeSize,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(badgeSize * 0.24),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.38 : 0.22),
                                                blurRadius: 28,
                                                spreadRadius: 2,
                                                offset: const Offset(0, 8),
                                              ),
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                                                blurRadius: 16,
                                                spreadRadius: 0,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(badgeSize * 0.24),
                                            child: Container(
                                              color: Colors.white,
                                              padding: EdgeInsets.all(badgeSize * 0.16),
                                              child: Image.asset(
                                                'assets/icon/crystal_drop.png',
                                                fit: BoxFit.contain,
                                                filterQuality: FilterQuality.high,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                            SizedBox(height: spacing * 0.9),

                            // Brand Name & Tagline (Staggered Animation)
                            AnimatedBuilder(
                              animation: _taglineAnimation,
                              builder: (context, child) {
                                final tagProgress = _taglineAnimation.value;
                                return Opacity(
                                  opacity: tagProgress,
                                  child: Transform.translate(
                                    offset: Offset(0, (1.0 - tagProgress) * 12),
                                    child: child,
                                  ),
                                );
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'LEVELS',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      fontSize: (screenWidth * 0.065).clamp(24.0, 32.0),
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 4.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'SMART WATER MONITORING',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: primaryAccent,
                                      fontSize: (screenWidth * 0.033).clamp(11.0, 13.5),
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2.2,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'MIT ADT UNIVERSITY',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: textMuted,
                                      fontSize: (screenWidth * 0.028).clamp(9.5, 11.5),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: spacing * 1.4),

                            // Modern Progress Loading Indicator
                            AnimatedBuilder(
                              animation: _controller,
                              builder: (context, child) {
                                final progressVal = _progressAnimation.value;
                                final fadeVal = _fadeAnimation.value;

                                return Opacity(
                                  opacity: fadeVal,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: (screenWidth * 0.38).clamp(120.0, 160.0),
                                        height: 4.0,
                                        decoration: BoxDecoration(
                                          color: primaryAccent.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4.0),
                                        ),
                                        child: FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor: progressVal,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(4.0),
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF0284C7),
                                                  Color(0xFF38BDF8),
                                                ],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        progressVal < 0.85 ? 'INITIALIZING TELEMETRY...' : 'READY',
                                        style: TextStyle(
                                          color: textMuted.withValues(alpha: 0.7),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
