import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/tank_provider.dart';
import '../../../widgets/alert_card.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({Key? key}) : super(key: key);

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _searchQuery = '';
  String _severityFilter = 'all'; // 'all', 'critical', 'full', 'offline'
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tankProvider = Provider.of<TankProvider>(context);

    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final textMutedColor = isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B);
    final inputBg = isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0);

    // Filter logic
    bool _matchesFilter(dynamic alert) {
      final matchesSearch = _searchQuery.isEmpty ||
          alert.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          alert.tankName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          alert.message.toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesSeverity = _severityFilter == 'all' ||
          alert.severity.toLowerCase() == _severityFilter;

      return matchesSearch && matchesSeverity;
    }

    final activeAlarms = tankProvider.alerts.where((a) => !a.isResolved && _matchesFilter(a)).toList();
    final historicalAlarms = tankProvider.alerts.where((a) => a.isResolved && _matchesFilter(a)).toList();

    return Column(
      children: [
        // Search & Filter Panel
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            children: [
              // Search Input field
              Container(
                height: 46,
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  style: TextStyle(color: textColor, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search alert log...',
                    hintStyle: TextStyle(color: textMutedColor, fontSize: 13),
                    prefixIcon: Icon(Icons.search, color: textMutedColor, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: textMutedColor, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Chip filter row - Sections 45 & 85: Strict Alert Categories (critical, full, offline)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: ['all', 'critical', 'full', 'offline'].map((filter) {
                    final isSelected = _severityFilter == filter;
                    String label = 'All Alerts';
                    if (filter == 'critical') label = 'Critical';
                    if (filter == 'full') label = 'Full (Overflow Risk)';
                    if (filter == 'offline') label = 'Offline';

                    Color activeColor = const Color(0xFF1565C0);
                    if (filter == 'critical') activeColor = const Color(0xFFDC2626);
                    if (filter == 'full') activeColor = const Color(0xFF2563EB);
                    if (filter == 'offline') activeColor = const Color(0xFF9CA3AF);

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _severityFilter = filter;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? activeColor.withOpacity(isDark ? 0.15 : 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? activeColor : borderColor,
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: isSelected ? activeColor : textMutedColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // Scrollable Lists area
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section: Active Alarms Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Active Alarms (${activeAlarms.length})',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Section: Active Alarms List
                if (activeAlarms.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.01) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 38,
                          color: Color(0xFF16A34A),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No active alarms! Safe levels.',
                          style: TextStyle(color: textMutedColor, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                else
                  ...activeAlarms.map((alert) => AlertCard(
                        alert: alert,
                        onResolve: () => tankProvider.resolveAlert(alert.id),
                      )),

                const SizedBox(height: 24),

                // Section: Historical Event Logbook Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Historical Event Logbook',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (historicalAlarms.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => tankProvider.clearAllAlerts(),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.delete_sweep, size: 14),
                        label: const Text('Clear', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                // Section: Historical Event Logbook List
                if (historicalAlarms.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.01) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 38,
                          color: textMutedColor.withOpacity(0.3),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No resolved logs match criteria.',
                          style: TextStyle(color: textMutedColor, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                else
                  ...historicalAlarms.map((alert) => AlertCard(
                        alert: alert,
                        onResolve: null, // resolved alerts cannot be marked resolved again
                      )),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
