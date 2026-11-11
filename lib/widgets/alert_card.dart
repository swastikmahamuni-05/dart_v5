import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/alert.dart';
import '../models/tank.dart';
import '../providers/tank_provider.dart';
import '../screens/dashboard/tank_details/tank_details_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/app_status_chip.dart';

class AlertCard extends StatelessWidget {
  final Alert alert;
  final VoidCallback? onResolve;

  const AlertCard({
    Key? key,
    required this.alert,
    this.onResolve,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = AppTheme.getStatusColor(alert.severity);
    final icon = AppTheme.getStatusIcon(alert.severity);
    final formattedTime = DateFormat('hh:mm:ss a').format(alert.timestamp);

    final cardBg = isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMutedColor = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final borderCol = alert.isResolved
        ? (isDark ? AppTheme.darkBorder : AppTheme.lightBorder)
        : color.withOpacity(0.35);

    // Look up tank building if available
    final tankProvider = Provider.of<TankProvider>(context, listen: false);
    Tank? tank;
    try {
      tank = tankProvider.tanks.firstWhere((t) => t.id == alert.tankId);
    } catch (_) {
      tank = null;
    }
    final locationText = tank != null ? '${alert.tankName} • ${tank.building}' : alert.tankName;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(
          color: borderCol,
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          onTap: () {
            // Section 47 & 85: Tapping an alert opens relevant tank details
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TankDetailsScreen(tankId: alert.tankId),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: alert.isResolved
                        ? (isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9))
                        : color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    alert.isResolved ? Icons.check_circle_outline_rounded : icon,
                    color: alert.isResolved ? textMutedColor : color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              alert.title,
                              style: TextStyle(
                                color: alert.isResolved ? textMutedColor : textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            formattedTime,
                            style: TextStyle(
                              color: textMutedColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              locationText,
                              style: TextStyle(
                                color: alert.isResolved ? textMutedColor : color,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          AppStatusChip(
                            status: alert.severity,
                            fontSize: 7.5,
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        alert.message,
                        style: TextStyle(
                          color: alert.isResolved ? textMutedColor : textColor.withOpacity(0.85),
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      ),
                      if (!alert.isResolved && onResolve != null) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: onResolve,
                            style: TextButton.styleFrom(
                              foregroundColor: color,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: color.withOpacity(0.4), width: 1.0),
                              ),
                            ),
                            icon: const Icon(Icons.done_all_rounded, size: 14),
                            label: const Text(
                              'Acknowledge Alert',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ] else if (alert.isResolved) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.done_all_rounded, color: AppTheme.statusNormal, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Acknowledged ${alert.resolvedAt != null ? DateFormat('hh:mm:ss a').format(alert.resolvedAt!) : ""}',
                              style: const TextStyle(
                                color: AppTheme.statusNormal,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
