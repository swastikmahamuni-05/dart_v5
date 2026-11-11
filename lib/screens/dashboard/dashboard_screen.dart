import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../providers/tank_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/tank_card.dart';
import '../add_tank/add_tank_screen.dart';
import '../../widgets/animated_add_button.dart';
import 'reports/reports_screen.dart';
import 'alerts/alerts_screen.dart';
import 'settings/settings_screen.dart';
import '../../widgets/fade_in_slide.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  int _currentTabIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _currentTabIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final tankProvider = Provider.of<TankProvider>(context, listen: false);
        tankProvider.startAutoRefresh();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final tankProvider = Provider.of<TankProvider>(context, listen: false);
    if (state == AppLifecycleState.resumed) {
      tankProvider.startAutoRefresh();
      tankProvider.fetchTanks();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      tankProvider.stopAutoRefresh();
    }
  }

  void _showNotificationsSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Consumer<TankProvider>(
          builder: (context, tankProvider, child) {
            final unread = tankProvider.notifications.where((n) => !n.isRead).toList();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Notifications & System Alerts',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (unread.isNotEmpty)
                        TextButton(
                          onPressed: () => tankProvider.markAllNotificationsAsRead(),
                          child: const Text('Mark all read', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (tankProvider.notifications.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text(
                          'No unread notifications',
                          style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 12),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: tankProvider.notifications.length,
                        itemBuilder: (context, idx) {
                          final n = tankProvider.notifications[idx];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.notifications_active_outlined,
                              color: n.isRead ? Colors.grey : const Color(0xFF1565C0),
                              size: 20,
                            ),
                            title: Text(
                              n.title,
                              style: TextStyle(
                                color: n.isRead ? Colors.grey : textColor,
                                fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            subtitle: Text(
                              n.body,
                              style: TextStyle(
                                color: textColor.withOpacity(0.5),
                                fontSize: 11,
                              ),
                            ),
                            trailing: !n.isRead
                                ? IconButton(
                                    icon: const Icon(Icons.check, size: 16),
                                    onPressed: () => tankProvider.markNotificationAsRead(n.id),
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showProfileSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final textMutedColor = isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final sheetBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0);
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'User Profile & Identity',
                style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: const Color(0xFF1565C0).withOpacity(0.12),
                      foregroundColor: const Color(0xFF1565C0),
                      child: Icon(user?.isAdmin == true ? Icons.admin_panel_settings : Icons.person, size: 36),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      user?.name ?? 'Dr. Marcus Vance',
                      style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'ROLE: ${user?.roleName ?? "ADMIN"}',
                        style: const TextStyle(
                          color: Color(0xFF1565C0),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    _buildProfileRow('Email ID', user?.email ?? 'admin@mit.edu', textColor, textMutedColor),
                    Divider(color: borderColor, height: 16),
                    _buildProfileRow('Assigned Campus', 'MIT ADT University', textColor, textMutedColor),
                    Divider(color: borderColor, height: 16),
                    _buildProfileRow('Assigned Location', 'IT Building', textColor, textMutedColor),
                    Divider(color: borderColor, height: 16),
                    _buildProfileRow('Last Session', user?.lastLogin ?? 'Today, 10:15 AM', textColor, textMutedColor),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await authService.logout();
                  if (mounted) {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileRow(String label, String value, Color textColor, Color textMutedColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: textMutedColor, fontSize: 11)),
        Text(value, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildNavItem(int index, IconData inactiveIcon, IconData activeIcon, String label) {
    final isSelected = _currentTabIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? const Color(0xFF00E5FF) : const Color(0xFF1565C0);
    final inactiveColor = isDark ? Colors.white.withOpacity(0.4) : const Color(0xFF64748B);

    return InkWell(
      onTap: () => _navigateToPage(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? activeColor : inactiveColor,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPage(int index) {
    setState(() {
      _currentTabIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authService = Provider.of<AuthService>(context);
    final tankProvider = Provider.of<TankProvider>(context);
    final isAdmin = authService.isAdmin;
    final unreadNotifs = tankProvider.notifications.where((n) => !n.isRead).length;

    final appBarBgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FA);
    final subtitleColor = isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B);

    // Standard 4 primary tabs: Dashboard, Alerts, Reports, Settings
    final List<Widget> pages = [
      OverviewTab(onNavigateToTab: (idx) => _navigateToPage(idx)),
      const AlertsScreen(),
      const ReportsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: appBarBgColor,
        elevation: 0,
        toolbarHeight: 68,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Image.asset(
                    'assets/icon/crystal_drop.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LEVELS',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'MIT ADT UNIVERSITY • ${isAdmin ? "ADMIN PORTAL" : "OPERATOR PORTAL"}',
                    style: TextStyle(
                      color: subtitleColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 8.5,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: isDark ? Colors.white : const Color(0xFF1E293B), size: 22),
            tooltip: 'Refresh system',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshing system...'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              try {
                await tankProvider.fetchTanks();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Updated just now'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Unable to refresh telemetry'),
                      action: SnackBarAction(
                        label: 'Retry',
                        onPressed: () => tankProvider.fetchTanks(),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.notifications_none_rounded, color: isDark ? Colors.white : const Color(0xFF1E293B), size: 24),
                onPressed: () => _showNotificationsSheet(context),
              ),
              if (unreadNotifs > 0)
                Positioned(
                  top: 10,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$unreadNotifs',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          GestureDetector(
            onTap: () => _showProfileSheet(context),
            child: Container(
              margin: const EdgeInsets.only(right: 16, left: 6),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF1565C0), width: 1.5),
              ),
              child: Icon(
                isAdmin ? Icons.admin_panel_settings : Icons.person,
                size: 18,
                color: const Color(0xFF1565C0),
              ),
            ),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        physics: const NeverScrollableScrollPhysics(),
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border(top: BorderSide(color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0))),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard_rounded, 'Dashboard'),
                _buildNavItem(1, Icons.notifications_active_outlined, Icons.notifications_active_rounded, 'Alerts'),
                _buildNavItem(2, Icons.analytics_outlined, Icons.analytics_rounded, 'Reports'),
                _buildNavItem(3, Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Overview tab layout
class OverviewTab extends StatelessWidget {
  final void Function(int)? onNavigateToTab;

  const OverviewTab({Key? key, this.onNavigateToTab}) : super(key: key);

  void _showBuildingsModal(BuildContext context, TankProvider tankProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final textMutedColor = isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final sheetBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0);

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final summaries = tankProvider.buildingSummaries;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Monitored Buildings',
                    style: TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${summaries.length} Campus Locations',
                    style: TextStyle(color: textMutedColor, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (summaries.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Text('No buildings currently monitored.', style: TextStyle(color: textMutedColor)),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: summaries.length,
                    itemBuilder: (context, idx) {
                      final b = summaries[idx];
                      final statusColor = TankProvider.getStatusColor(b.statusSummary);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: InkWell(
                          onTap: () {
                            tankProvider.setSelectedBuilding(b.buildingName);
                            Navigator.pop(context);
                          },
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.apartment_rounded, color: statusColor, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      b.buildingName,
                                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${b.totalTanks} Tanks • ${b.onlineDevices} Online Devices',
                                      style: TextStyle(color: textMutedColor, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              if (b.activeAlerts > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${b.activeAlerts} ALERT',
                                    style: const TextStyle(color: Color(0xFFDC2626), fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              const SizedBox(width: 6),
                              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: textMutedColor),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAllTanksModal(BuildContext context, TankProvider tankProvider) {
    tankProvider.setSelectedBuilding('ALL');
    tankProvider.setSelectedTankType('ALL');
    tankProvider.setSelectedStatusFilter('ALL');
    tankProvider.setSearchQuery('');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Displaying all ${tankProvider.tanks.length} campus water tanks.'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showDeviceStatusModal(BuildContext context, TankProvider tankProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final textMutedColor = isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final sheetBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0);

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final tanks = tankProvider.tanks;
        final onlineCount = tanks.where((t) => t.status != 'OFFLINE').length;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Device Status Registry',
                    style: TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$onlineCount/${tanks.length} Online',
                    style: const TextStyle(color: Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: tanks.length,
                  itemBuilder: (context, idx) {
                    final t = tanks[idx];
                    final isOnline = t.status != 'OFFLINE';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                            color: isOnline ? const Color(0xFF16A34A) : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${t.tankName} (${t.deviceId})',
                                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                Text(
                                  '${t.building} • Last Telemetry: ${t.lastUpdated}',
                                  style: TextStyle(color: textMutedColor, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isOnline ? const Color(0xFF16A34A) : Colors.grey).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isOnline ? 'ONLINE' : 'OFFLINE',
                              style: TextStyle(
                                color: isOnline ? const Color(0xFF16A34A) : Colors.grey,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
    final authService = Provider.of<AuthService>(context);
    final tankProvider = Provider.of<TankProvider>(context);
    final isAdmin = authService.isAdmin;
    final tanks = tankProvider.tanks;

    // Section 14: Exactly Four Operational Summary Cards
    final totalBuildings = tankProvider.totalMonitoredBuildings;
    final totalTanks = tanks.length;
    final onlineDevices = tanks.where((t) => t.status != 'OFFLINE').length;
    final activeAlertsCount = tankProvider.alerts.where((a) => !a.isResolved).length;

    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final textMutedColor = isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0);

    final availableBuildings = ['ALL', ...tankProvider.buildingSummaries.map((b) => b.buildingName)];

    return RefreshIndicator(
      onRefresh: () => tankProvider.fetchTanks(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 14: Exactly Four Operational Summary Cards
            FadeInSlide(
              delay: Duration.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OPERATIONAL SUMMARY',
                    style: TextStyle(
                      color: textMutedColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      mainAxisExtent: 70,
                    ),
                    children: [
                      // CARD 1: Total Buildings -> Tap opens Buildings window
                      KpiCard(
                        title: 'Total Buildings',
                        value: '$totalBuildings',
                        icon: Icons.apartment_rounded,
                        glowColor: const Color(0xFF1565C0),
                        onTap: () => _showBuildingsModal(context, tankProvider),
                      ),
                      // CARD 2: Tanks -> Tap opens All Tanks window
                      KpiCard(
                        title: 'Tanks',
                        value: '$totalTanks',
                        icon: Icons.layers_outlined,
                        glowColor: const Color(0xFF1565C0),
                        onTap: () => _showAllTanksModal(context, tankProvider),
                      ),
                      // CARD 3: Online Devices -> Tap opens Device Status window
                      KpiCard(
                        title: 'Online Devices',
                        value: '$onlineDevices',
                        icon: Icons.wifi_rounded,
                        glowColor: const Color(0xFF16A34A),
                        onTap: () => _showDeviceStatusModal(context, tankProvider),
                      ),
                      // CARD 4: Active Alerts -> Tap opens Alerts window (visually emphasized if > 0)
                      KpiCard(
                        title: 'Active Alerts',
                        value: '$activeAlertsCount',
                        icon: Icons.warning_amber_rounded,
                        glowColor: activeAlertsCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                        onTap: () => onNavigateToTab?.call(1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 16 & 86: Multi-Criteria Filter Bar Section
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar Input (Section 18)
                  TextField(
                    onChanged: (val) => tankProvider.setSearchQuery(val),
                    style: TextStyle(color: textColor, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search tank by name, building, or location...',
                      hintStyle: TextStyle(color: textMutedColor, fontSize: 12),
                      prefixIcon: Icon(Icons.search_rounded, color: textMutedColor, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Dropdown Filters Row (Building & Tank Type)
                  Row(
                    children: [
                      // Building Filter Dropdown
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: availableBuildings.contains(tankProvider.selectedBuilding)
                                  ? tankProvider.selectedBuilding
                                  : 'ALL',
                              isExpanded: true,
                              icon: Icon(Icons.keyboard_arrow_down_rounded, color: textMutedColor, size: 18),
                              style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
                              onChanged: (val) {
                                if (val != null) tankProvider.setSelectedBuilding(val);
                              },
                              items: availableBuildings.map((bName) {
                                return DropdownMenuItem(
                                  value: bName,
                                  child: Text(bName == 'ALL' ? 'All Buildings' : bName),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Tank Type Filter Dropdown
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: tankProvider.selectedTankType,
                              isExpanded: true,
                              icon: Icon(Icons.keyboard_arrow_down_rounded, color: textMutedColor, size: 18),
                              style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
                              onChanged: (val) {
                                if (val != null) tankProvider.setSelectedTankType(val);
                              },
                              items: const [
                                DropdownMenuItem(value: 'ALL', child: Text('All Tank Types')),
                                DropdownMenuItem(value: 'Underground', child: Text('Underground')),
                                DropdownMenuItem(value: 'Overhead', child: Text('Overhead')),
                                DropdownMenuItem(value: 'Sump', child: Text('Sump')),
                                DropdownMenuItem(value: 'Elevated', child: Text('Elevated')),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Status Filter Chips (Section 86 & 87: ALL, NORMAL, LOW, CRITICAL, FULL, OFFLINE)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['ALL', 'NORMAL', 'LOW', 'CRITICAL', 'FULL', 'OFFLINE'].map((status) {
                        final isSelected = tankProvider.selectedStatusFilter == status;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ChoiceChip(
                            label: Text(status),
                            selected: isSelected,
                            onSelected: (sel) {
                              if (sel) tankProvider.setSelectedStatusFilter(status);
                            },
                            selectedColor: const Color(0xFF1565C0),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : textMutedColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            side: BorderSide(color: isSelected ? const Color(0xFF1565C0) : borderColor),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 17: Displayed Tanks (Must be named "Displayed Tanks")
            FadeInSlide(
              delay: const Duration(milliseconds: 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Displayed Tanks',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${tankProvider.filteredTanks.length} Tanks Displayed',
                        style: TextStyle(
                          color: textMutedColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (tankProvider.filteredTanks.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.layers_clear_outlined, size: 36, color: textMutedColor),
                          const SizedBox(height: 10),
                          Text(
                            '0 Tanks Displayed',
                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No monitored water tanks match your active filter or search selection.',
                            style: TextStyle(color: textMutedColor, fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () {
                              tankProvider.setSearchQuery('');
                              tankProvider.setSelectedBuilding('ALL');
                              tankProvider.setSelectedTankType('ALL');
                              tankProvider.setSelectedStatusFilter('ALL');
                            },
                            child: const Text('Reset All Filters', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      height: 220,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: tankProvider.filteredTanks.length,
                        itemBuilder: (context, index) {
                          return Container(
                            width: 200,
                            margin: const EdgeInsets.only(right: 14),
                            child: TankCard(tank: tankProvider.filteredTanks[index]),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

