import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const EmptyStateWidget({
    Key? key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_rounded,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMutedColor = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppTheme.primaryBlue),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(
                color: textMutedColor,
                fontSize: 12,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
