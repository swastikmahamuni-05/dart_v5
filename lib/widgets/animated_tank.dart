import 'dart:math';
import 'package:flutter/material.dart';
import '../providers/tank_provider.dart';
import '../theme/app_theme.dart';

class AnimatedTank extends StatefulWidget {
  final double levelPercent; // 0.0 to 1.0
  final double capacityLitres;
  final String status;

  const AnimatedTank({
    Key? key,
    required this.levelPercent,
    required this.capacityLitres,
    required this.status,
  }) : super(key: key);

  @override
  State<AnimatedTank> createState() => _AnimatedTankState();
}

class _AnimatedTankState extends State<AnimatedTank> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOnline = widget.status.toUpperCase() != 'OFFLINE';
    final flowingWaterColor = AppTheme.getWaterFlowColor(
      levelPercent: widget.levelPercent,
      isOnline: isOnline,
      status: widget.status,
    );

    // Dynamic outline color for the tank shell
    final shellOutlineColor = isDark ? Colors.white.withOpacity(0.35) : const Color(0xFF1E293B);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: widget.levelPercent, end: widget.levelPercent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      builder: (context, animatedLevel, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Custom Paint for Tank structure and fluid level
            SizedBox(
              width: 180,
              height: 280,
              child: CustomPaint(
                painter: AnimatedTankPainter(
                  levelPercent: animatedLevel,
                  waveAnimationValue: 0.0,
                  waterColor: flowingWaterColor,
                  outlineColor: shellOutlineColor,
                  isDark: isDark,
                ),
              ),
            ),
            // Text Overlays with 360-degree high-contrast outline shadow
            Positioned(
              top: 100,
              child: Column(
                children: [
                  Text(
                    '${(widget.levelPercent * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(offset: Offset(-1.5, -1.5), color: Colors.black87, blurRadius: 2.0),
                        Shadow(offset: Offset(1.5, -1.5), color: Colors.black87, blurRadius: 2.0),
                        Shadow(offset: Offset(1.5, 1.5), color: Colors.black87, blurRadius: 2.0),
                        Shadow(offset: Offset(-1.5, 1.5), color: Colors.black87, blurRadius: 2.0),
                        Shadow(offset: Offset(0, 4), color: Colors.black38, blurRadius: 6.0),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(widget.levelPercent * widget.capacityLitres).toStringAsFixed(0)} L',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(offset: Offset(-1.0, -1.0), color: Colors.black87),
                        Shadow(offset: Offset(1.0, -1.0), color: Colors.black87),
                        Shadow(offset: Offset(1.0, 1.0), color: Colors.black87),
                        Shadow(offset: Offset(-1.0, 1.0), color: Colors.black87),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cap: ${widget.capacityLitres.toStringAsFixed(0)} L',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      shadows: const [
                        Shadow(offset: Offset(-1.0, -1.0), color: Colors.black54),
                        Shadow(offset: Offset(1.0, -1.0), color: Colors.black54),
                        Shadow(offset: Offset(1.0, 1.0), color: Colors.black54),
                        Shadow(offset: Offset(-1.0, 1.0), color: Colors.black54),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class AnimatedTankPainter extends CustomPainter {
  final double levelPercent;
  final double waveAnimationValue;
  final Color waterColor;
  final Color outlineColor;
  final bool isDark;

  AnimatedTankPainter({
    required this.levelPercent,
    required this.waveAnimationValue,
    required this.waterColor,
    required this.outlineColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    const double cornerRadius = 24.0;

    // Tank outer boundary rounded rectangle
    final RRect tankOuterRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      const Radius.circular(cornerRadius),
    );

    // 1. Draw Tank Background (translucent chamber interior)
    final Paint bgPaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(tankOuterRect, bgPaint);

    // Save layer to clip water rendering strictly inside the tank container boundary
    canvas.save();
    canvas.clipRRect(tankOuterRect);

    // Water level height calculations
    final double waterHeight = h * levelPercent;
    final double waterTopY = h - waterHeight;

    if (levelPercent > 0.005) {
      final Rect waterRect = Rect.fromLTWH(0, waterTopY, w, waterHeight);
      final Paint fluidPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            waterColor.withOpacity(0.90),
            waterColor.withOpacity(0.65),
          ],
        ).createShader(waterRect);
      canvas.drawRect(waterRect, fluidPaint);

      // Subtle surface meniscus highlight
      final Paint highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawLine(Offset(0, waterTopY), Offset(w, waterTopY), highlightPaint);
    }

    // Glass Reflection gloss highlights
    final Paint reflectionPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.12),
          Colors.white.withOpacity(0.01),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawRRect(tankOuterRect, reflectionPaint);

    // Vertical gloss strip
    final Path glossStrip = Path();
    glossStrip.moveTo(w * 0.15, cornerRadius);
    glossStrip.lineTo(w * 0.15, h - cornerRadius);
    glossStrip.quadraticBezierTo(w * 0.15, h - 8, w * 0.12, h - 8);
    glossStrip.lineTo(w * 0.08, h - 8);
    glossStrip.lineTo(w * 0.08, cornerRadius + 8);
    glossStrip.close();
    
    canvas.drawPath(
      glossStrip, 
      Paint()..color = Colors.white.withOpacity(0.06)..style = PaintingStyle.fill
    );

    // Restore clipping layer
    canvas.restore();

    // Measurement Ticks
    final Paint tickPaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Draw 4 tick markers (25%, 50%, 75%)
    for (int i = 1; i <= 3; i++) {
      final double y = h - (h * 0.25 * i);
      canvas.drawLine(Offset(0, y), Offset(10, y), tickPaint);
      canvas.drawLine(Offset(w, y), Offset(w - 10, y), tickPaint);

      textPainter.text = TextSpan(
        text: '${25 * i}%',
        style: TextStyle(
          color: isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.25),
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(16, y - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant AnimatedTankPainter oldDelegate) {
    return oldDelegate.levelPercent != levelPercent ||
        oldDelegate.waveAnimationValue != waveAnimationValue ||
        oldDelegate.waterColor != waterColor ||
        oldDelegate.outlineColor != outlineColor;
  }
}
