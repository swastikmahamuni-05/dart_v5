import 'package:flutter/material.dart';
import '../providers/tank_provider.dart';
import '../theme/app_theme.dart';

class TankStatusChip extends StatelessWidget {
  final String status;
  final double fontSize;
  final bool showIcon;

  const TankStatusChip({
    Key? key,
    required this.status,
    this.fontSize = 9.0,
    this.showIcon = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statusColor = TankProvider.getStatusColor(status);
    final statusLightColor = TankProvider.getStatusLightColor(status);
    final statusIcon = AppTheme.getStatusIcon(status);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final displayLabel = status.toUpperCase() == 'OK' ? 'HEALTHY' : status.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? statusColor.withOpacity(0.12) : statusLightColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? statusColor.withOpacity(0.3) : statusColor.withOpacity(0.4),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(statusIcon, size: fontSize + 2, color: statusColor),
            const SizedBox(width: 4),
          ],
          Text(
            displayLabel,
            style: TextStyle(
              color: statusColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
