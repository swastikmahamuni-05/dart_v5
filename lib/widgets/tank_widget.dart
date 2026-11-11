import 'dart:math';
import 'package:flutter/material.dart';

class TankWidget extends StatefulWidget {
  final double levelPercent; // 0.0 to 1.0
  final double capacityLitres;
  final String waterType;

  const TankWidget({
    Key? key,
    required this.levelPercent,
    required this.capacityLitres,
    required this.waterType,
  }) : super(key: key);

  @override
  State<TankWidget> createState() => _TankWidgetState();
}

class _TankWidgetState extends State<TankWidget> with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  Color _getWaterColor(String waterType) {
    switch (waterType.toLowerCase()) {
      case 'potable':
        return const Color(0xFF00B0FF); // Ocean Blue
      case 'rainwater':
        return const Color(0xFF1DE9B6); // Teal
      case 'greywater':
        return const Color(0xFFE040FB); // Violet/Purple
      default:
        return const Color(0xFF00E5FF); // Cyan
    }
  }

  @override
  Widget build(BuildContext context) {
    final waterColor = _getWaterColor(widget.waterType);

    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Custom Paint for Tank structure and waves
            SizedBox(
              width: 180,
              height: 280,
              child: CustomPaint(
                painter: TankPainter(
                  levelPercent: widget.levelPercent,
                  waveAnimationValue: _waveController.value,
                  waterColor: waterColor,
                ),
              ),
            ),
            // Text Overlays
            Positioned(
              top: 100,
              child: Column(
                children: [
                  Text(
                    '${(widget.levelPercent * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(widget.levelPercent * widget.capacityLitres).toStringAsFixed(0)} L',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      shadows: const [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 6,
                          offset: Offset(0, 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Cap: ${widget.capacityLitres.toStringAsFixed(0)} L',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
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

class TankPainter extends CustomPainter {
  final double levelPercent;
  final double waveAnimationValue;
  final Color waterColor;

  TankPainter({
    required this.levelPercent,
    required this.waveAnimationValue,
    required this.waterColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    const double cornerRadius = 24.0;

    // Draw background tank cylinder container
    final RRect tankOuterRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      const Radius.circular(cornerRadius),
    );

    final Paint tankBgPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(tankOuterRect, tankBgPaint);

    final Paint borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(tankOuterRect, borderPaint);

    // Save layer to clip waves inside the rounded rectangle tank shape
    canvas.save();
    canvas.clipRRect(tankOuterRect);

    // Water level height calculations
    final double waterHeight = h * levelPercent;
    final double waterTopY = h - waterHeight;

    if (levelPercent > 0.01) {
      // Draw secondary wave (background wave, slightly out of phase, lower opacity)
      final Path wavePath2 = Path();
      wavePath2.moveTo(0, h);
      wavePath2.lineTo(0, waterTopY);

      for (double i = 0.0; i <= w; i++) {
        // Double cycle sine wave
        final double relativeX = i / w;
        final double angle = (relativeX * 2 * pi) + (waveAnimationValue * 2 * pi) + pi; // shifted Phase
        final double waveAmplitude = levelPercent > 0.96 || levelPercent < 0.04 ? 0.0 : 6.0;
        final double y = waterTopY + sin(angle) * waveAmplitude;
        wavePath2.lineTo(i, y);
      }
      wavePath2.lineTo(w, h);
      wavePath2.close();

      final Paint waterPaint2 = Paint()
        ..color = waterColor.withOpacity(0.4)
        ..style = PaintingStyle.fill;
      canvas.drawPath(wavePath2, waterPaint2);

      // Draw primary wave (foreground wave)
      final Path wavePath1 = Path();
      wavePath1.moveTo(0, h);
      wavePath1.lineTo(0, waterTopY);

      for (double i = 0.0; i <= w; i++) {
        final double relativeX = i / w;
        final double angle = (relativeX * 2 * pi) - (waveAnimationValue * 2 * pi); // reverse direction
        final double waveAmplitude = levelPercent > 0.96 || levelPercent < 0.04 ? 0.0 : 8.0;
        final double y = waterTopY + sin(angle) * waveAmplitude;
        wavePath1.lineTo(i, y);
      }
      wavePath1.lineTo(w, h);
      wavePath1.close();

      final Paint waterPaint1 = Paint()
        ..color = waterColor.withOpacity(0.75)
        ..style = PaintingStyle.fill;
      canvas.drawPath(wavePath1, waterPaint1);
    }

    // Glass Reflection Gloss Highlights (Aesthetic Overlay)
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

    // Measurement Ticks (Draw on top of the border)
    final Paint tickPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Draw 4 tick markers (25%, 50%, 75%)
    for (int i = 1; i <= 3; i++) {
      final double y = h - (h * 0.25 * i);
      // Left ticks
      canvas.drawLine(Offset(0, y), Offset(10, y), tickPaint);
      // Right ticks
      canvas.drawLine(Offset(w, y), Offset(w - 10, y), tickPaint);

      // Level texts
      textPainter.text = TextSpan(
        text: '${25 * i}%',
        style: TextStyle(
          color: Colors.white.withOpacity(0.25),
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(16, y - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant TankPainter oldDelegate) {
    return oldDelegate.levelPercent != levelPercent ||
        oldDelegate.waveAnimationValue != waveAnimationValue ||
        oldDelegate.waterColor != waterColor;
  }
}
