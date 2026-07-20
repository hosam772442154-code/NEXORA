import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:nexora_it/core/nexora_theme.dart';

class SplashPlaceholderScreen extends StatefulWidget {
  const SplashPlaceholderScreen({super.key});

  @override
  State<SplashPlaceholderScreen> createState() =>
      _SplashPlaceholderScreenState();
}

class _SplashPlaceholderScreenState extends State<SplashPlaceholderScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotateAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexoraTheme.backgroundColor,
      body: Stack(
        children: [
          _buildGridBackground(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 48),
                    _buildTitle(),
                    const SizedBox(height: 16),
                    _buildSubtitle(),
                    const SizedBox(height: 64),
                    _buildStatusBadge(),
                    const SizedBox(height: 40),
                    _buildPulsingDot(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridBackground() {
    return CustomPaint(
      size: MediaQuery.of(context).size,
      painter: _CircuitGridPainter(),
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: NexoraTheme.cardColor,
              border: Border.all(
                color: NexoraTheme.accentColor.withOpacity(0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: NexoraTheme.accentColor.withOpacity(0.25),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
                BoxShadow(
                  color: NexoraTheme.accentColor.withOpacity(0.10),
                  blurRadius: 80,
                  spreadRadius: 20,
                ),
              ],
            ),
            child: Center(
              child: AnimatedBuilder(
                animation: _rotateAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotateAnimation.value,
                    child: child,
                  );
                },
                child: Icon(
                  Icons.developer_board_rounded,
                  size: 56,
                  color: NexoraTheme.accentColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitle() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          Color(0xFF00D2FF),
          Color(0xFF0080FF),
          Color(0xFF00D2FF),
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(bounds),
      child: const Text(
        'NEXORA IT',
        style: TextStyle(
          color: Colors.white,
          fontSize: 38,
          fontWeight: FontWeight.w900,
          letterSpacing: 6,
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return const Text(
      'Academic Intelligence Platform',
      style: TextStyle(
        color: NexoraTheme.secondaryTextColor,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 2.5,
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
        color: NexoraTheme.cardColor,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: NexoraTheme.accentColor.withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: NexoraTheme.accentColor.withOpacity(0.12),
            blurRadius: 24,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: NexoraTheme.successColor,
              boxShadow: [
                BoxShadow(
                  color: NexoraTheme.successColor.withOpacity(0.6),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'NEXORA IT Initialized Successfully',
            style: TextStyle(
              color: NexoraTheme.primaryTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulsingDot() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final value = (_pulseController.value - delay).clamp(0.0, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: NexoraTheme.accentColor.withOpacity(0.3 + value * 0.7),
              ),
            );
          }),
        );
      },
    );
  }
}

class _CircuitGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00D2FF).withOpacity(0.04)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 40.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final dotPaint = Paint()
      ..color = const Color(0xFF00D2FF).withOpacity(0.10)
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
