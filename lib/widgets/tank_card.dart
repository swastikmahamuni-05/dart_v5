import 'dart:math';
import 'package:flutter/material.dart';
import '../models/tank.dart';
import '../theme/app_theme.dart';
import '../widgets/app_status_chip.dart';
import '../screens/dashboard/tank_details/tank_details_screen.dart';

class TankCard extends StatefulWidget {
  final Tank tank;

  const TankCard({
    Key? key,
    required this.tank,
  }) : super(key: key);

  @override
  State<TankCard> createState() => _TankCardState();
}

class _TankCardState extends State<TankCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tank = widget.tank;
    
    final statusColor = AppTheme.getStatusColor(tank.status);
    final levelPct = tank.currentLevelPercent;
    final isOnline = tank.status != 'OFFLINE' && tank.isOnline();
    final flowingWaterColor = AppTheme.getWaterFlowColor(
      levelPercent: levelPct,
      isOnline: isOnline,
      status: tank.status,
    );

    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMutedColor = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(
            color: _isHovered ? statusColor : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: statusColor.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TankDetailsScreen(tankId: tank.tankId),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tank.tankName,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${tank.building} • ${tank.tankType}',
                              style: TextStyle(
                                color: textMutedColor,
                                fontSize: 9.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      AppStatusChip(
                        status: tank.status,
                        fontSize: 8,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Cylinder Fluid Visualizer with Smooth Level Transition
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: 58,
                        height: 84,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.3) : const Color(0xFF1E293B),
                              width: 2.0,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: levelPct, end: levelPct),
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              builder: (context, animatedLevel, child) {
                                return CustomPaint(
                                  painter: CardWavePainter(
                                    levelPercent: animatedLevel,
                                    waveAnimationValue: 0.0,
                                    waterColor: flowingWaterColor,
                                    isDark: isDark,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Water Level & Quantity Row with Truthful Offline Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppTheme.formatVolume(tank.currentVolumeLitres),
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              tank.isOnline()
                                  ? 'Level: ${AppTheme.formatPercent(levelPct)}'
                                  : (tank.isStale()
                                      ? 'Stale: ${AppTheme.formatPercent(levelPct)}'
                                      : 'Last known: ${AppTheme.formatPercent(levelPct)}'),
                              style: TextStyle(
                                color: textMutedColor,
                                fontSize: 9.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: tank.isOnline()
                                        ? AppTheme.statusNormal
                                        : (tank.isStale()
                                            ? AppTheme.statusStale
                                            : AppTheme.statusOffline),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  tank.freshnessLabel,
                                  style: TextStyle(
                                    color: tank.isOnline()
                                        ? AppTheme.statusNormal
                                        : (tank.isStale()
                                            ? AppTheme.statusStale
                                            : AppTheme.statusOffline),
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tank.dataAgeFormatted(),
                              style: TextStyle(
                                color: textMutedColor,
                                fontSize: 9,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CardWavePainter extends CustomPainter {
  final double levelPercent;
  final double waveAnimationValue;
  final Color waterColor;
  final bool isDark;

  CardWavePainter({
    required this.levelPercent,
    required this.waveAnimationValue,
    required this.waterColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final double clampedPct = levelPercent.clamp(0.0, 1.0);
    final double waterHeight = h * clampedPct;
    final double waterTopY = h - waterHeight;

    if (clampedPct > 0.0) {
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
        ..color = Colors.white.withOpacity(0.40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(0, waterTopY), Offset(w, waterTopY), highlightPaint);
    }

    final String pctText = AppTheme.formatPercent(clampedPct);
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: pctText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(offset: Offset(-1.0, -1.0), color: Colors.black87),
            Shadow(offset: Offset(1.0, -1.0), color: Colors.black87),
            Shadow(offset: Offset(1.0, 1.0), color: Colors.black87),
            Shadow(offset: Offset(-1.0, 1.0), color: Colors.black87),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(w / 2 - textPainter.width / 2, h / 2 - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CardWavePainter oldDelegate) {
    return oldDelegate.levelPercent != levelPercent ||
        oldDelegate.waterColor != waterColor ||
        oldDelegate.isDark != isDark;
  }
}
