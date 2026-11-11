import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:water_tank_monitor/main.dart';
import '../../../providers/tank_provider.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_theme.dart';
import '../../add_tank/add_tank_screen.dart';
import '../../update_tank/update_tank_screen.dart';
import '../../delete_tank/delete_tank_screen.dart';
import '../devices/devices_screen.dart';
import '../users/users_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _audibleAlarms = true;

  void _showAdminRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Access Restricted', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'This action requires Administrator privileges. Please sign in with an Administrator account.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showInfoModal(BuildContext context, String title, String content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: TextStyle(fontSize: 13, height: 1.5, color: isDark ? Colors.white70 : const Color(0xFF475569)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showConfigureTimeoutDialog(BuildContext context, TankProvider provider) {
    int current = provider.offlineTimeoutSeconds;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Telemetry Freshness Threshold', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mark device offline if no packet received within:', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$current seconds', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('(${current ~/ 60}m ${current % 60}s)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              Slider(
                value: current.toDouble(),
                min: 30,
                max: 300,
                divisions: 9,
                label: '$current s',
                onChanged: (val) {
                  setDialogState(() => current = val.round());
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                provider.setOfflineTimeoutSeconds(current);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Offline threshold updated to $current seconds'), behavior: SnackBarBehavior.floating),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authService = Provider.of<AuthService>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final tankProvider = Provider.of<TankProvider>(context);

    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final textMutedColor = isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0);
    final labelColor = isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Settings Header
            Row(
              children: [
                Icon(Icons.settings_outlined, color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF1565C0), size: 24),
                const SizedBox(width: 10),
                Text(
                  'Settings',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 1. ACCOUNT SECTION
            _buildGroupHeader('ACCOUNT', textMutedColor),
            Card(
              color: cardBg,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF1565C0).withOpacity(0.1),
                          child: const Icon(Icons.person_outline, size: 20, color: Color(0xFF1565C0)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    authService.userName ?? 'Dr. Marcus Vance',
                                    style: TextStyle(color: labelColor, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: authService.isAdmin
                                          ? const Color(0xFF1565C0).withOpacity(0.15)
                                          : const Color(0xFF16A34A).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      authService.isAdmin ? 'ADMIN' : 'OPERATOR',
                                      style: TextStyle(
                                        color: authService.isAdmin ? const Color(0xFF1565C0) : const Color(0xFF16A34A),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                authService.userEmail ?? 'admin@mit.edu',
                                style: TextStyle(color: textMutedColor, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Divider(color: borderColor, height: 24),
                    _buildActionRow(
                      icon: Icons.vpn_key_outlined,
                      title: 'Change Password',
                      subtitle: 'Update your campus utilities authentication key',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password reset instructions sent to registered campus email.'), behavior: SnackBarBehavior.floating),
                        );
                      },
                      labelColor: labelColor,
                      textMutedColor: textMutedColor,
                    ),
                    Divider(color: borderColor, height: 24),
                    _buildInfoRow('Session State', 'Active (Secure Token)', const Color(0xFF16A34A), textMutedColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 2. NOTIFICATIONS SECTION
            _buildGroupHeader('NOTIFICATIONS', textMutedColor),
            Card(
              color: cardBg,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildSwitchTile(
                      title: 'Push Notifications',
                      subtitle: 'Critical water level alerts & device connectivity warnings',
                      value: _pushNotifications,
                      onChanged: (val) => setState(() => _pushNotifications = val),
                      labelColor: labelColor,
                      textMutedColor: textMutedColor,
                    ),
                    Divider(color: borderColor, height: 24),
                    _buildSwitchTile(
                      title: 'Audible Critical Alarms',
                      subtitle: 'Sound alarm for critical water level and overflow risk',
                      value: _audibleAlarms,
                      onChanged: (val) => setState(() => _audibleAlarms = val),
                      labelColor: labelColor,
                      textMutedColor: textMutedColor,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 3. DEVICES & HARDWARE SECTION
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildGroupHeader('DEVICES & HARDWARE', textMutedColor),
                if (!authService.isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                    child: Text('Admin Managed', style: TextStyle(color: textMutedColor, fontSize: 10, fontStyle: FontStyle.italic)),
                  ),
              ],
            ),
            Card(
              color: cardBg,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: borderColor),
              ),
              child: Column(
                children: [
                  _buildNavigationTile(
                    title: 'Hardware Nodes & ESP32 Registry',
                    subtitle: 'Sensor ADC signals, supply voltages, and signal diagnostics',
                    icon: Icons.developer_board_rounded,
                    color: const Color(0xFF0284C7),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const DevicesScreen()));
                    },
                    labelColor: labelColor,
                    textMutedColor: textMutedColor,
                  ),
                  Divider(color: borderColor, height: 1),
                  _buildNavigationTile(
                    title: 'Freshness Threshold: ${tankProvider.offlineTimeoutSeconds}s',
                    subtitle: 'Configure device offline & stale detection timeout',
                    icon: Icons.timer_outlined,
                    color: const Color(0xFF059669),
                    onTap: () => _showConfigureTimeoutDialog(context, tankProvider),
                    labelColor: labelColor,
                    textMutedColor: textMutedColor,
                  ),
                  Divider(color: borderColor, height: 1),
                  _buildNavigationTile(
                    title: 'Add Tank',
                    subtitle: 'Provision a new reservoir and IoT node',
                    icon: Icons.add_circle_outline_rounded,
                    color: const Color(0xFF16A34A),
                    onTap: () {
                      if (!authService.isAdmin) {
                        _showAdminRequiredDialog(context);
                        return;
                      }
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AddTankScreen()));
                    },
                    labelColor: labelColor,
                    textMutedColor: textMutedColor,
                  ),
                  Divider(color: borderColor, height: 1),
                  _buildNavigationTile(
                    title: 'Update Tank Configuration',
                    subtitle: 'Calibrate sensor thresholds, heights, and geometry',
                    icon: Icons.edit_note_rounded,
                    color: const Color(0xFFCA8A04),
                    onTap: () {
                      if (!authService.isAdmin) {
                        _showAdminRequiredDialog(context);
                        return;
                      }
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const UpdateTankScreen()));
                    },
                    labelColor: labelColor,
                    textMutedColor: textMutedColor,
                  ),
                  Divider(color: borderColor, height: 1),
                  _buildNavigationTile(
                    title: 'Delete Tank',
                    subtitle: 'Decommission reservoir from campus monitoring',
                    icon: Icons.delete_outline_rounded,
                    color: const Color(0xFFDC2626),
                    onTap: () {
                      if (!authService.isAdmin) {
                        _showAdminRequiredDialog(context);
                        return;
                      }
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const DeleteTankScreen()));
                    },
                    labelColor: labelColor,
                    textMutedColor: textMutedColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4. SYSTEM SECTION
            _buildGroupHeader('SYSTEM & ENVIRONMENT', textMutedColor),
            Card(
              color: cardBg,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildSwitchTile(
                      title: 'Dark Theme Layout',
                      subtitle: 'High contrast theme for operations rooms',
                      value: themeProvider.isDarkMode,
                      onChanged: (val) => themeProvider.toggleTheme(val),
                      labelColor: labelColor,
                      textMutedColor: textMutedColor,
                    ),
                    Divider(color: borderColor, height: 24),
                    _buildInfoRow('Application Name', 'LEVELS', textColor, textMutedColor),
                    Divider(color: borderColor, height: 16),
                    _buildInfoRow('Version', 'Version 1.1.0', textColor, textMutedColor),
                    Divider(color: borderColor, height: 16),
                    _buildInfoRow('Build Number', 'Build 2002', textColor, textMutedColor),
                    Divider(color: borderColor, height: 16),
                    _buildInfoRow('Cloud Environment', 'Production (AWS IoT ap-south-1)', const Color(0xFF1565C0), textMutedColor),
                    Divider(color: borderColor, height: 16),
                    _buildInfoRow('Telemetry Pipeline', 'Operational (HTTP / MQTT)', const Color(0xFF16A34A), textMutedColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 5. SUPPORT & OPERATIONS
            _buildGroupHeader('SUPPORT & OPERATIONS', textMutedColor),
            Card(
              color: cardBg,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: borderColor),
              ),
              child: Column(
                children: [
                  _buildNavigationTile(
                    title: 'Help Center & Documentation',
                    subtitle: 'Operating manuals, calibration guides, and specs',
                    icon: Icons.help_outline_rounded,
                    color: const Color(0xFF0284C7),
                    onTap: () {
                      _showInfoModal(
                        context,
                        'LEVELS Help & Documentation',
                        'LEVELS is the campus-wide water tank monitoring and SCADA utility for MIT ADT University.\n\nKey Thresholds:\n• Critical: < 15% (Requires immediate action)\n• Low: 15% – 30%\n• Normal: 30% – 90%\n• Full: >= 90% (Overflow risk)\n\nData Freshness Model:\n• Online: Packet received within 90 seconds\n• Stale: Packet received 90s – 15m ago\n• Offline: No packet in over 15 minutes',
                      );
                    },
                    labelColor: labelColor,
                    textMutedColor: textMutedColor,
                  ),
                  Divider(color: borderColor, height: 1),
                  _buildNavigationTile(
                    title: 'Contact Campus Utilities',
                    subtitle: 'Facilities & physical plant operations team',
                    icon: Icons.support_agent_rounded,
                    color: const Color(0xFF0D9488),
                    onTap: () {
                      _showInfoModal(
                        context,
                        'Campus Utilities Support',
                        'Facilities Management & Utility Operations\nMIT ADT University, Pune\n\nEmail: facilities-ops@mit.edu\nEmergency Hotline: +91 20 1234 5678\nOperating Hours: 24/7 Monitoring Desk',
                      );
                    },
                    labelColor: labelColor,
                    textMutedColor: textMutedColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 6. LEGAL SECTION
            _buildGroupHeader('LEGAL & COMPLIANCE', textMutedColor),
            Card(
              color: cardBg,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: borderColor),
              ),
              child: Column(
                children: [
                  _buildNavigationTile(
                    title: 'Privacy Policy',
                    subtitle: 'Campus telemetry data protection & privacy guidelines',
                    icon: Icons.privacy_tip_outlined,
                    color: const Color(0xFF64748B),
                    onTap: () {
                      _showInfoModal(
                        context,
                        'Privacy Policy',
                        'Telemetry measurements (water volume, sensor signals, supply voltages) collected by LEVELS are strictly internal institutional records of MIT ADT University.\n\nNo personal data is transmitted to external third parties.',
                      );
                    },
                    labelColor: labelColor,
                    textMutedColor: textMutedColor,
                  ),
                  Divider(color: borderColor, height: 1),
                  _buildNavigationTile(
                    title: 'Terms of Service',
                    subtitle: 'Acceptable use guidelines for campus operators',
                    icon: Icons.description_outlined,
                    color: const Color(0xFF64748B),
                    onTap: () {
                      _showInfoModal(
                        context,
                        'Terms of Service',
                        'Use of LEVELS is restricted to authorized campus facilities personnel, building administrators, and campus operators.\n\nAll sensor calibration modifications and pump overrides are audited and logged.',
                      );
                    },
                    labelColor: labelColor,
                    textMutedColor: textMutedColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Disconnect Session Button
            ElevatedButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Confirm Disconnect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    content: const Text('Are you sure you want to log out from this device session?', style: TextStyle(fontSize: 13)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                        child: const Text('Log Out'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await authService.logout();
                  if (mounted) {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('DISCONNECT SESSION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor, Color labelColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: 12)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color labelColor,
    required Color textMutedColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF1565C0)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: labelColor, fontSize: 13, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: TextStyle(color: textMutedColor, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: textMutedColor),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color labelColor,
    required Color textMutedColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: labelColor, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: textMutedColor, fontSize: 11)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF1565C0),
        ),
      ],
    );
  }

  Widget _buildNavigationTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required Color labelColor,
    required Color textMutedColor,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: TextStyle(color: labelColor, fontSize: 13, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(color: textMutedColor, fontSize: 11)),
      trailing: Icon(Icons.arrow_forward_ios_rounded, color: textMutedColor, size: 14),
    );
  }
}
