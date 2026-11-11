import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/tank_provider.dart';
import '../../../models/tank.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/animated_tank.dart';
import '../../../widgets/charts/tank_analytics_graph.dart';
import '../../../widgets/modals/data_exchange_modal.dart';
import '../../update_tank/update_tank_screen.dart';

class TankDetailsScreen extends StatefulWidget {
  final String tankId;

  const TankDetailsScreen({
    Key? key,
    required this.tankId,
  }) : super(key: key);

  @override
  State<TankDetailsScreen> createState() => _TankDetailsScreenState();
}

class _TankDetailsScreenState extends State<TankDetailsScreen> {
  bool _pumpActive = false; // Mutually exclusive: true = PUMP ON, false = PUMP OFF

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<TankProvider>(context, listen: false);
      final tankIdx = provider.allTanks.indexWhere((t) => t.tankId == widget.tankId || t.deviceId == widget.tankId);
      final actualDeviceId = tankIdx != -1 ? provider.allTanks[tankIdx].deviceId : widget.tankId;
      provider.fetchLatestTelemetry(actualDeviceId);
      provider.fetchHistory(actualDeviceId);
    });
  }

  Color _getStatusColor(String status) {
    return AppTheme.getStatusColor(status);
  }

  void _openExportModal(Tank tank, TankProvider provider, {String tab = 'export'}) {
    final readings = provider.getHistoricalReadingsForRange(tank.deviceId, '24h');
    DataExchangeModal.show(
      context,
      tank: tank,
      readings: readings,
      initialTab: tab,
      initialReportType: 'water_level',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tankProvider = Provider.of<TankProvider>(context);
    final tankIndex = tankProvider.allTanks.indexWhere((t) => t.tankId == widget.tankId || t.deviceId == widget.tankId);

    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final textMutedColor = isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0);

    if (tankIndex == -1) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(child: Text('Tank not found', style: TextStyle(color: textColor))),
      );
    }

    final tank = tankProvider.allTanks[tankIndex];
    final statusColor = _getStatusColor(tank.status);
    final isOnline = tank.isOnline();
    final isStale = tank.isStale();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'TANK DETAILS',
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: textColor),
            tooltip: 'Refresh Telemetry',
            onPressed: () {
              tankProvider.fetchLatestTelemetry(tank.deviceId);
              tankProvider.fetchHistory(tank.deviceId, forceRefresh: true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshing telemetry and history...'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tank Header Info Row
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
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.apartment_rounded, color: textMutedColor, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Building: ${tank.building}',
                            style: TextStyle(color: textMutedColor, fontSize: 12),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.layers_outlined, color: textMutedColor, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Type: ${tank.tankType}',
                            style: TextStyle(color: textMutedColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AppTheme.getStatusIcon(tank.status), size: 13, color: statusColor),
                      const SizedBox(width: 5),
                      Text(
                        tank.status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // SECTION 1: CURRENT STATUS
            _buildSectionHeader('CURRENT STATUS', textMutedColor),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: AnimatedTank(
                      levelPercent: tank.currentLevelPercent,
                      capacityLitres: tank.tankCapacity,
                      status: tank.status,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroMetricTile(
                          isOnline ? 'Current Level' : (isStale ? 'Stale Level' : 'Last Known Level'),
                          '${(tank.currentLevelPercent * 100).toStringAsFixed(1)} %',
                          textMutedColor,
                          textColor,
                        ),
                        const SizedBox(height: 8),
                        _buildHeroMetricTile(
                          isOnline ? 'Current Volume' : 'Last Known Volume',
                          '${tank.currentVolumeLitres.toStringAsFixed(0)} L',
                          textMutedColor,
                          textColor,
                        ),
                        const SizedBox(height: 8),
                        _buildHeroMetricTile('Total Capacity', '${tank.tankCapacity.toStringAsFixed(0)} L', textMutedColor, textColor),
                        const SizedBox(height: 8),
                        _buildHeroMetricTile('Water Height', '${tank.depth.toStringAsFixed(2)} m', textMutedColor, textColor),
                        const SizedBox(height: 8),
                        _buildHeroMetricTile(
                          'Connectivity & Freshness',
                          tank.formattedFreshnessSummary,
                          textMutedColor,
                          isOnline
                              ? AppTheme.statusNormal
                              : (isStale ? AppTheme.statusStale : AppTheme.statusOffline),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // SECTION 2: ACTIONS BAR (Export, Share, Calibrate)
            _buildSectionHeader('ACTIONS & UTILITIES', textMutedColor),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openExportModal(tank, tankProvider, tab: 'export'),
                    icon: const Icon(Icons.file_download_outlined, size: 16),
                    label: const Text('Export', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openExportModal(tank, tankProvider, tab: 'export'),
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text('Share', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1565C0),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Color(0xFF1565C0)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const UpdateTankScreen()),
                      );
                    },
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text('Calibrate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : const Color(0xFF334155),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: borderColor),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Pump Controller SCADA Panel Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.power_settings_new_rounded,
                            size: 18,
                            color: _pumpActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'PUMP CONTROLLER OVERRIDE',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (_pumpActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626)).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (_pumpActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626)).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _pumpActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _pumpActive ? 'PUMP RUNNING' : 'PUMP STOPPED',
                              style: TextStyle(
                                color: _pumpActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: !isOnline
                                ? null
                                : () {
                                    setState(() {
                                      _pumpActive = true;
                                    });
                                  },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: _pumpActive
                                    ? const LinearGradient(
                                        colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                                      )
                                    : null,
                                color: _pumpActive ? null : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.play_circle_fill_rounded,
                                    size: 18,
                                    color: _pumpActive ? Colors.white : textMutedColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'START PUMP',
                                    style: TextStyle(
                                      color: _pumpActive ? Colors.white : textMutedColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: GestureDetector(
                            onTap: !isOnline
                                ? null
                                : () {
                                    setState(() {
                                      _pumpActive = false;
                                    });
                                  },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: !_pumpActive
                                    ? const LinearGradient(
                                        colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                                      )
                                    : null,
                                color: !_pumpActive ? null : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.stop_circle_rounded,
                                    size: 18,
                                    color: !_pumpActive ? Colors.white : textMutedColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'STOP PUMP',
                                    style: TextStyle(
                                      color: !_pumpActive ? Colors.white : textMutedColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // SECTION 3: DEVICE HEALTH & HARDWARE DIAGNOSTICS
            _buildSectionHeader('DEVICE HEALTH & HARDWARE DIAGNOSTICS', textMutedColor),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  _buildHealthRow('Hardware Node ID', tank.deviceId, textColor, textMutedColor),
                  Divider(color: borderColor, height: 16),
                  _buildHealthRow('Last Packet Received', tank.lastSeenFormatted, textColor, textMutedColor),
                  Divider(color: borderColor, height: 16),
                  _buildHealthRow('Data Freshness Age', tank.dataAgeFormatted(), textColor, textMutedColor),
                  Divider(color: borderColor, height: 16),
                  _buildHealthRow(
                    'Signal Strength (RSSI)',
                    '${tank.rssi} dBm (${tank.rssi > -65 ? "Good" : (tank.rssi > -80 ? "Fair" : "Weak")})',
                    textColor,
                    textMutedColor,
                  ),
                  Divider(color: borderColor, height: 16),
                  _buildHealthRow('Raw Sensor ADC', '${tank.rawADC} / 4095', textColor, textMutedColor),
                  Divider(color: borderColor, height: 16),
                  _buildHealthRow('Battery / Supply Voltage', '${tank.battery.toStringAsFixed(2)} V (${tank.dataVoltage.toStringAsFixed(0)} mV)', textColor, textMutedColor),
                  Divider(color: borderColor, height: 16),
                  _buildHealthRow('Sensor Loop Current', '${tank.dataCurrent.toStringAsFixed(2)} mA', textColor, textMutedColor),
                  Divider(color: borderColor, height: 16),
                  _buildHealthRow('Firmware Build', 'v1.4.2-esp32-levels', textColor, textMutedColor),
                  Divider(color: borderColor, height: 16),
                  _buildHealthRow(
                    'Sensor Diagnostic Status',
                    tank.rawADC > 0 ? 'CALIBRATED & HEALTHY' : 'UNRESPONSIVE / FAULT',
                    tank.rawADC > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    textMutedColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // SECTION 4: HISTORICAL DATA GRAPH
            _buildSectionHeader('HISTORICAL TELEMETRY TREND', textMutedColor),
            const SizedBox(height: 8),
            TankAnalyticsGraph(
              tank: tank,
              lockedMetric: ChartMetric.percentFull,
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        color: color,
        fontSize: 10.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildHealthRow(String label, String value, Color valueColor, Color labelColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: 11)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildHeroMetricTile(String label, String value, Color labelColor, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: labelColor,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
