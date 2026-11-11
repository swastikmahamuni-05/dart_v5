import 'package:flutter/material.dart';

class KpiCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color glowColor;
  final VoidCallback? onTap;

  const KpiCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.glowColor,
    this.onTap,
  }) : super(key: key);

  @override
  State<KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<KpiCard> {
  bool _isHovered = false;

  void _showDescriptionSheet(BuildContext context, String title, String longDesc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final textMutedColor = isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B);
    final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0);

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.glowColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, color: widget.glowColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                longDesc,
                style: TextStyle(
                  color: isDark ? Colors.white.withOpacity(0.8) : const Color(0xFF334155),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Long press gesture: Help and diagnostics parameter descriptions are shown for operator reference.',
                style: TextStyle(
                  color: textMutedColor,
                  fontSize: 10.5,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final textMutedColor = isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    Color borderCol = isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0);
    if (_isHovered) {
      borderCol = widget.glowColor;
    }

    final String desc;
    final String longDesc;
    if (widget.title.toLowerCase().contains('total')) {
      desc = 'Total Campus Water Tanks';
      longDesc = 'Shows the total count of storage reservoirs configured within the university utilities network. These are managed locally and synced to AWS IoT.';
    } else if (widget.title.toLowerCase().contains('online')) {
      desc = 'Edge Nodes Online';
      longDesc = 'The number of smart telemetry modules reporting data packet feeds within the last 15 seconds. Online nodes report active levels continuously.';
    } else if (widget.title.toLowerCase().contains('offline')) {
      desc = 'Edge Nodes Offline';
      longDesc = 'Sensors that missed consecutive keepalive heartbeats. Offline nodes require battery inspection or wireless network checkups.';
    } else {
      desc = 'Active Incidents alerts';
      longDesc = 'Total warnings and critical low-level anomalies active right now. Alerts disappear once tanks are replenished above safety thresholds.';
    }

    return Tooltip(
      message: '$desc (Tap for details, long press for help)',
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: () => _showDescriptionSheet(context, widget.title, longDesc),
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderCol,
                width: _isHovered ? 1.5 : 1.2,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: widget.glowColor.withOpacity(0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [
                      BoxShadow(
                        color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                // Icon Container
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.glowColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.glowColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Info Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.title.toUpperCase(),
                        style: TextStyle(
                          color: textMutedColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.value,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
