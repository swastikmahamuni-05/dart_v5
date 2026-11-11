import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/historical_graph_config.dart';
import '../../../models/tank.dart';
import '../../../models/tank_history.dart';
import '../../../providers/tank_provider.dart';
import '../../../services/export_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/charts/tank_analytics_graph.dart';
import '../../../widgets/modals/data_exchange_modal.dart';
import '../../../widgets/tank_status_chip.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedBuilding = 'ALL';
  String _selectedTankId = '';
  String _selectedMetricId = 'water_level';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<TankProvider>(context, listen: false);
      if (provider.tanks.isNotEmpty) {
        setState(() {
          if (_selectedTankId.isEmpty) {
            _selectedTankId = provider.tanks.first.tankId;
          }
        });
        provider.fetchHistory(provider.tanks.first.deviceId);
      }
    });
  }

  void _showExportModal(ExportResult result) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Generated',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          result.fileName,
                          style: TextStyle(
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      result.content,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: result.content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Report copied to clipboard'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy to Clipboard', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Ready for download: ${result.fileName}'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: const Color(0xFF16A34A),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.download_done_rounded, size: 16),
                      label: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleExport(String format, TankProvider provider, Tank targetTank, List<TankHistory> readings, double avg, double min, double max, double cur, double estUsage) {
    ExportResult result;
    const periodDesc = 'Historical 24H';

    if (format == 'CSV') {
      result = ExportService.generateReadingsCsv(tank: targetTank, readings: readings, timeframe: periodDesc);
    } else if (format == 'Excel') {
      result = ExportService.generateExcelTsv(tank: targetTank, readings: readings, timeframe: periodDesc);
    } else {
      // Formatted Printable / Text Report
      result = ExportService.generatePrintableReport(
        tank: targetTank,
        readings: readings,
        events: const [],
        timeframe: periodDesc,
        avgLevel: avg,
        minLevel: min,
        maxLevel: max,
        currentLevel: cur,
        estimatedUsage: estUsage,
      );
    }
    _showExportModal(result);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tankProvider = Provider.of<TankProvider>(context);
    final tanks = tankProvider.tanks;

    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final textMutedColor = isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF1F5F9);

    if (tanks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: Text(
            'No tank monitoring data available.',
            style: TextStyle(color: textMutedColor, fontSize: 13),
          ),
        ),
      );
    }

    // Filter tanks by building scope
    final buildingFilteredTanks = _selectedBuilding == 'ALL'
        ? tanks
        : tanks.where((t) => t.building.trim().toLowerCase() == _selectedBuilding.toLowerCase()).toList();

    // Ensure a specific tank is always chosen
    if (_selectedTankId.isEmpty || !buildingFilteredTanks.any((t) => t.tankId == _selectedTankId)) {
      if (buildingFilteredTanks.isNotEmpty) {
        _selectedTankId = buildingFilteredTanks.first.tankId;
      } else if (tanks.isNotEmpty) {
        _selectedTankId = tanks.first.tankId;
      }
    }

    final Tank targetTank = tanks.firstWhere(
      (t) => t.tankId == _selectedTankId,
      orElse: () => tanks.first,
    );

    final readings = tankProvider.getHistoricalReadingsForRange(targetTank.deviceId, '24h');

    // Compute stats from real authoritative database readings
    double avgLevel = 0.0;
    double maxLevel = 0.0;
    double minLevel = 0.0;
    final double curLevel = targetTank.waterLevel;

    if (readings.isNotEmpty) {
      double sum = 0.0;
      double curMin = readings.first.waterPercent;
      double curMax = readings.first.waterPercent;

      for (final r in readings) {
        sum += r.waterPercent;
        if (r.waterPercent < curMin) curMin = r.waterPercent;
        if (r.waterPercent > curMax) curMax = r.waterPercent;
      }
      avgLevel = sum / readings.length;
      minLevel = curMin;
      maxLevel = curMax;
    }

    final double authoritativeUsed = tankProvider.calculateAuthoritativeWaterUsed(targetTank.deviceId, range: '24h');

    // Distinct buildings list
    final buildingsList = <String>['ALL'];
    for (final t in tanks) {
      if (!buildingsList.contains(t.building.trim())) {
        buildingsList.add(t.building.trim());
      }
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppTheme.maxContentWidth),
        child: Column(
          children: [
            // Scope Selectors Row (Building & Tank) - 1H/6H/24H/7D/30D/CUSTOM Filter Bar Removed (Requirement 2)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Scope Selectors Row: Building & Tank
                  Row(
                    children: [
                      // Building Dropdown
                      Expanded(
                        child: Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: buildingsList.contains(_selectedBuilding) ? _selectedBuilding : 'ALL',
                              isExpanded: true,
                              dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                              style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
                              icon: Icon(Icons.apartment_rounded, color: textMutedColor, size: 16),
                              items: buildingsList.map((b) => DropdownMenuItem(
                                value: b,
                                child: Text(b == 'ALL' ? 'All Buildings' : b, overflow: TextOverflow.ellipsis),
                              )).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedBuilding = val;
                                    final bTanks = val == 'ALL'
                                        ? tanks
                                        : tanks.where((t) => t.building.trim().toLowerCase() == val.toLowerCase()).toList();
                                    if (bTanks.isNotEmpty) {
                                      _selectedTankId = bTanks.first.tankId;
                                      tankProvider.fetchHistory(bTanks.first.deviceId);
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Tank Dropdown - Explicit Tank Selection
                      Expanded(
                        child: Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: buildingFilteredTanks.any((t) => t.tankId == _selectedTankId)
                                  ? _selectedTankId
                                  : (buildingFilteredTanks.isNotEmpty ? buildingFilteredTanks.first.tankId : null),
                              isExpanded: true,
                              dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                              style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
                              icon: Icon(Icons.water_damage_outlined, color: textMutedColor, size: 16),
                              items: buildingFilteredTanks.map((t) => DropdownMenuItem(
                                value: t.tankId,
                                child: Text('${t.tankName} (${t.building})', overflow: TextOverflow.ellipsis),
                              )).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedTankId = val;
                                  });
                                  final selTank = tanks.firstWhere((t) => t.tankId == val, orElse: () => tanks.first);
                                  tankProvider.fetchHistory(selTank.deviceId);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 1-Click Segmented Metric Pill Bar
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildMetricPill(
                          id: 'water_level',
                          label: 'Water Level (%)',
                          icon: Icons.water_drop_rounded,
                          isSelected: _selectedMetricId == 'water_level',
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildMetricPill(
                          id: 'water_height',
                          label: 'Water Height (m)',
                          icon: Icons.straighten_rounded,
                          isSelected: _selectedMetricId == 'water_height',
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildMetricPill(
                          id: 'water_used',
                          label: 'Water Used (L/Hr)',
                          icon: Icons.bar_chart_rounded,
                          isSelected: _selectedMetricId == 'water_used',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Report Content View based on Selected Metric
            Expanded(
              child: _selectedMetricId == 'water_level'
                  ? _buildWaterLevelTab(
                      targetTank: targetTank,
                      readings: readings,
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textColor: textColor,
                      textMutedColor: textMutedColor,
                    )
                  : (_selectedMetricId == 'water_height'
                      ? _buildWaterHeightTab(
                          targetTank: targetTank,
                          readings: readings,
                          isDark: isDark,
                          cardBg: cardBg,
                          borderColor: borderColor,
                          textColor: textColor,
                          textMutedColor: textMutedColor,
                        )
                      : _buildWaterUsedTab(
                          targetTank: targetTank,
                          waterUsedLitres: authoritativeUsed,
                          readings: readings,
                          isDark: isDark,
                          cardBg: cardBg,
                          borderColor: borderColor,
                          textColor: textColor,
                          textMutedColor: textMutedColor,
                        )),
            ),

            // Elevated Export Reports Bar (Water Level & Water Used)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 600;
                    final btn1 = ElevatedButton.icon(
                      icon: const Icon(Icons.water_drop_rounded, size: 15),
                      label: Text(
                        isNarrow ? 'Export Level' : 'Export Water Level Report',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedMetricId == 'water_level' || _selectedMetricId == 'water_height'
                            ? AppTheme.primaryBlue
                            : (isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0)),
                        foregroundColor: _selectedMetricId == 'water_level' || _selectedMetricId == 'water_height'
                            ? Colors.white
                            : textColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        DataExchangeModal.show(
                          context,
                          tank: targetTank,
                          readings: readings,
                          initialReportType: 'water_level',
                        );
                      },
                    );

                    final btn2 = ElevatedButton.icon(
                      icon: const Icon(Icons.bar_chart_rounded, size: 15),
                      label: Text(
                        isNarrow ? 'Export Usage' : 'Export Water Used Report',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedMetricId == 'water_used'
                            ? AppTheme.primaryBlue
                            : (isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0)),
                        foregroundColor: _selectedMetricId == 'water_used' ? Colors.white : textColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        DataExchangeModal.show(
                          context,
                          tank: targetTank,
                          readings: readings,
                          initialReportType: 'water_used',
                        );
                      },
                    );

                    if (isNarrow) {
                      return Row(
                        children: [
                          Expanded(child: btn1),
                          const SizedBox(width: 8),
                          Expanded(child: btn2),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.summarize_rounded, size: 18, color: AppTheme.primaryBlue),
                            const SizedBox(width: 8),
                            Text(
                              'REPORT EXPORTS',
                              style: TextStyle(
                                color: textMutedColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        btn1,
                        const SizedBox(width: 8),
                        btn2,
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricPill({
    required String id,
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMetricId = id;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryBlue
              : (isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryBlue
                : (isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFCBD5E1)),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // VIEW 1: WATER LEVEL
  Widget _buildWaterLevelTab({
    required Tank targetTank,
    required List<TankHistory> readings,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color textMutedColor,
  }) {
    final statusColor = TankProvider.getStatusColor(targetTank.status);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Water Level Hero Metric Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.water_drop_rounded, color: statusColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CURRENT WATER LEVEL',
                          style: TextStyle(
                            color: textMutedColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${targetTank.waterLevel.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TankStatusChip(status: targetTank.status),
                    const SizedBox(height: 6),
                    Text(
                      '${(targetTank.waterLevel * targetTank.tankCapacity / 100.0).toStringAsFixed(0)} / ${targetTank.tankCapacity.toStringAsFixed(0)} L',
                      style: TextStyle(color: textMutedColor, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Historical Water Level Graph with all working aggregation controls
          TankAnalyticsGraph(
            key: ValueKey('${targetTank.deviceId}_water_level'),
            tank: targetTank,
            metricDefinition: GraphMetricDefinition.waterLevel,
          ),
        ],
      ),
    );
  }

  // VIEW 2: WATER HEIGHT
  Widget _buildWaterHeightTab({
    required Tank targetTank,
    required List<TankHistory> readings,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color textMutedColor,
  }) {
    final statusColor = TankProvider.getStatusColor(targetTank.status);
    final curDepth = targetTank.depth > 0
        ? targetTank.depth
        : (targetTank.tankHeight > 0 ? (targetTank.tankHeight / 1000.0) : 2.5) * (targetTank.waterLevel / 100.0);
    final maxDepth = targetTank.tankHeight > 0
        ? (targetTank.tankHeight / 1000.0)
        : (targetTank.depth > 0 ? targetTank.depth : 2.5);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Water Height Hero Metric Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.straighten_rounded, color: statusColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CURRENT WATER HEIGHT',
                          style: TextStyle(
                            color: textMutedColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${curDepth.toStringAsFixed(2)} m',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TankStatusChip(status: targetTank.status),
                    const SizedBox(height: 6),
                    Text(
                      'Max: ${maxDepth.toStringAsFixed(2)} m',
                      style: TextStyle(color: textMutedColor, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Historical Graph for Water Height (Line Chart in Meters)
          TankAnalyticsGraph(
            key: ValueKey('${targetTank.deviceId}_water_depth'),
            tank: targetTank,
            metricDefinition: GraphMetricDefinition.waterDepth,
          ),
        ],
      ),
    );
  }

  // VIEW 3: WATER USED (L/Hr)
  Widget _buildWaterUsedTab({
    required Tank targetTank,
    required double waterUsedLitres,
    required List<TankHistory> readings,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color textMutedColor,
  }) {
    final hourlyAvg = waterUsedLitres / 24.0;
    final buckets = GraphMetricDefinition.calculateUsageBuckets(
      readings: readings,
      tankCapacity: targetTank.tankCapacity > 0 ? targetTank.tankCapacity : 280000.0,
      rangeKey: '24h',
    );
    final peakUsage = buckets.map((b) => b.litersUsed).fold(0.0, math.max);
    final activeHours = buckets.where((b) => b.litersUsed > 0).length;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Authoritative Metric Summary Card: Water Used (24H) Total
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
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
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.water_drop_rounded, color: AppTheme.primaryBlue, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WATER USED (24H)',
                              style: TextStyle(
                                color: textMutedColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${NumberFormat('#,###').format(waterUsedLitres.round())} L',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
                          ),
                          child: Text(
                            'Hourly Avg: ${NumberFormat('#,###').format(hourlyAvg.round())} L/Hr',
                            style: TextStyle(color: AppTheme.primaryBlue, fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Peak: ${NumberFormat('#,###').format(peakUsage.round())} L/Hr  •  Active: $activeHours/24 hrs',
                          style: TextStyle(color: textMutedColor, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Tank: ${targetTank.tankName} (${targetTank.building}) • Noise deadband: 0.2%',
                  style: TextStyle(color: textMutedColor, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Historical Graph for Water Used (24 lines / bars for 24h section)
          TankAnalyticsGraph(
            key: ValueKey('${targetTank.deviceId}_water_used'),
            tank: targetTank,
            metricDefinition: GraphMetricDefinition.waterUsed,
          ),
        ],
      ),
    );
  }
}
