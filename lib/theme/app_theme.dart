import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppTheme {
  // Brand Color Palette
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color primaryDarkBlue = Color(0xFF0D47A1);
  static const Color secondaryBlue = Color(0xFF0284C7);
  static const Color accentBlue = Color(0xFF38BDF8);

  // Status Colors
  static const Color statusNormal = Color(0xFF16A34A); // Green
  static const Color statusLow = Color(0xFFF97316); // Amber/Orange
  static const Color statusWarning = statusLow;
  static const Color statusCritical = Color(0xFFDC2626); // Red
  static const Color statusFull = Color(0xFF2563EB); // Positive Blue
  static const Color statusOffline = Color(0xFF64748B); // Slate Grey
  static const Color statusStale = Color(0xFFF59E0B); // Amber / Stale

  // Surface & Background Colors
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color darkBg = Color(0xFF0F172A);
  static const Color lightCardBg = Colors.white;
  static const Color darkCardBg = Color(0xFF1E293B);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color darkBorder = Color(0x1AFFFFFF);

  // Text Colors
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color darkTextPrimary = Colors.white;
  static const Color lightTextMuted = Color(0xFF64748B);
  static const Color darkTextMuted = Color(0x99FFFFFF);

  // Design Scale & Accessibility
  static const double cardRadius = 16.0;
  static const double buttonRadius = 12.0;
  static const double minTouchTarget = 44.0;

  // Spacing Scale
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing40 = 40.0;
  static const double spacing48 = 48.0;
  static const double maxContentWidth = 1400.0;

  // Status Helpers
  static Color getStatusColor(String statusStr) {
    switch (statusStr.toUpperCase()) {
      case 'NORMAL':
      case 'ONLINE':
        return statusNormal;
      case 'LOW':
        return statusLow;
      case 'CRITICAL':
        return statusCritical;
      case 'FULL':
        return statusFull;
      case 'STALE':
        return statusStale;
      case 'OFFLINE':
        return statusOffline;
      default:
        return statusNormal;
    }
  }

  /// Authoritative Water Flowing Color:
  /// GREEN for above 40%, ORANGE for 20% to 40%, RED below 20%, and GREY for OFFLINE.
  static Color getWaterFlowColor({
    required double levelPercent,
    bool isOnline = true,
    String? status,
  }) {
    if (!isOnline || (status != null && status.toUpperCase() == 'OFFLINE')) {
      return const Color(0xFF94A3B8); // Slate grey for OFFLINE
    }
    if (status != null && status.toUpperCase() == 'STALE') {
      return statusStale;
    }
    final pct = levelPercent <= 1.0 ? (levelPercent * 100.0) : levelPercent;
    if (pct > 40.0) {
      return const Color(0xFF16A34A); // Green for above 40
    } else if (pct >= 20.0) {
      return const Color(0xFFF97316); // Orange for 20 to 40
    } else {
      return const Color(0xFFDC2626); // Red below 20
    }
  }

  static IconData getStatusIcon(String statusStr) {
    switch (statusStr.toUpperCase()) {
      case 'NORMAL':
        return Icons.check_circle_rounded;
      case 'ONLINE':
        return Icons.wifi_rounded;
      case 'LOW':
        return Icons.warning_amber_rounded;
      case 'CRITICAL':
        return Icons.error_rounded;
      case 'FULL':
        return Icons.water_drop_rounded;
      case 'STALE':
        return Icons.history_rounded;
      case 'OFFLINE':
        return Icons.wifi_off_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  // Formatters
  static final NumberFormat _numberFormat = NumberFormat('#,##0');

  static String formatPercent(double percentValue) {
    // Expects value either 0.72 or 72.0
    final pct = percentValue <= 1.0 ? percentValue * 100.0 : percentValue;
    return '${pct.round()}%';
  }

  static String formatVolume(double liters) {
    return '${_numberFormat.format(liters.round())} L';
  }

  static String formatHeight(double mm) {
    return '${_numberFormat.format(mm.round())} mm';
  }

  // Card Decoration Helper
  static BoxDecoration cardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? darkCardBg : lightCardBg,
      borderRadius: BorderRadius.circular(cardRadius),
      border: Border.all(color: isDark ? darkBorder : lightBorder),
      boxShadow: isDark
          ? []
          : [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
    );
  }
}
