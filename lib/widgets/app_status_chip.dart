import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppStatusChip extends StatelessWidget {
  final String status;
  final bool showIcon;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const AppStatusChip({
    Key? key,
    required this.status,
    this.showIcon = true,
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statusColor = AppTheme.getStatusColor(status);
    final statusIcon = AppTheme.getStatusIcon(status);
    final statusText = status.toUpperCase();

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: statusColor.withOpacity(0.35),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(statusIcon, size: fontSize + 3, color: statusColor),
            const SizedBox(width: 4),
          ],
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
