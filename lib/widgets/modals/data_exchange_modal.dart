import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/tank.dart';
import '../../models/tank_history.dart';
import '../../providers/tank_provider.dart';
import '../../services/export_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/file_share.dart';

/// Report Export Modal & Data Exchange Suite
/// Tailored specifically for authoritative historical export of Water Level & Water Used Reports
/// Supports CSV, Excel TSV, and 72-character padded ASCII reports with Download and Native/Web Share actions.
class DataExchangeModal extends StatefulWidget {
  final Tank tank;
  final List<TankHistory> readings;
  final String initialTab; // 'export' or 'import'
  final String initialReportType; // 'water_level' or 'water_used'

  const DataExchangeModal({
    Key? key,
    required this.tank,
    required this.readings,
    this.initialTab = 'export',
    this.initialReportType = 'water_level',
  }) : super(key: key);

  static void show(
    BuildContext context, {
    required Tank tank,
    required List<TankHistory> readings,
    String initialTab = 'export',
    String initialReportType = 'water_level',
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820, maxHeight: 860),
          child: DataExchangeModal(
            tank: tank,
            readings: readings,
            initialTab: initialTab,
            initialReportType: initialReportType,
          ),
        ),
      ),
    );
  }

  @override
  State<DataExchangeModal> createState() => _DataExchangeModalState();
}

class _DataExchangeModalState extends State<DataExchangeModal> {
  // Mode: 'export' or 'import'
  late String _activeMode;

  // Report Type: 'water_level' or 'water_used'
  late String _reportType;

  // Export Settings
  String _exportTimeframe = '24h'; // '24h', '7d', '30d', 'custom'
  DateTimeRange? _customDateRange;
  String _exportFormat = 'CSV'; // 'CSV', 'Excel', 'Report'

  // Loading & Telemetry State
  bool _isLoadingHistory = false;
  String? _historyError;
  List<TankHistory> _activeReadings = [];
  ExportResult? _cachedExportResult;

  // Action States
  bool _isExporting = false;
  bool _isSharing = false;
  String? _exportSuccessMessage;
  String? _shareNoticeMessage;

  // Import State
  final TextEditingController _importTextController = TextEditingController();
  ImportAuditResult? _auditResult;
  bool _isValidating = false;
  bool _isImporting = false;
  String? _importSuccessMessage;

  @override
  void initState() {
    super.initState();
    _activeMode = widget.initialTab;
    _reportType = widget.initialReportType;

    final now = DateTime.now();
    _customDateRange = DateTimeRange(
      start: now.subtract(const Duration(days: 7)),
      end: now,
    );

    // Initial dataset population from parent or asynchronous authoritative fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAuthoritativeHistory();
    });
  }

  @override
  void dispose() {
    _importTextController.dispose();
    super.dispose();
  }

  /// Asynchronously loads real historical data from TankProvider / API
  Future<void> _loadAuthoritativeHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
      _exportSuccessMessage = null;
      _shareNoticeMessage = null;
    });

    final provider = Provider.of<TankProvider>(context, listen: false);

    try {
      List<TankHistory> items;

      if (_exportTimeframe == 'custom' && _customDateRange != null) {
        final startEpoch = DateTime(
          _customDateRange!.start.year,
          _customDateRange!.start.month,
          _customDateRange!.start.day,
          0,
          0,
          0,
        ).toUtc().millisecondsSinceEpoch ~/ 1000;

        final endEpoch = DateTime(
          _customDateRange!.end.year,
          _customDateRange!.end.month,
          _customDateRange!.end.day,
          23,
          59,
          59,
        ).toUtc().millisecondsSinceEpoch ~/ 1000;

        items = await provider.fetchHistoryForExport(
          widget.tank.deviceId,
          range: 'custom',
          start: startEpoch,
          end: endEpoch,
        );
        // Filter strictly to date range boundaries
        items = ExportService.filterReadingsByDateRange(
          items,
          _customDateRange!.start,
          _customDateRange!.end,
        );
      } else {
        // Range 24h, 7d, 30d
        items = await provider.fetchHistoryForExport(
          widget.tank.deviceId,
          range: _exportTimeframe,
        );

        // If backend fetch returned empty, check provider cached or widget initial readings if non-empty
        if (items.isEmpty && widget.readings.isNotEmpty && _exportTimeframe == '24h') {
          items = List<TankHistory>.from(widget.readings);
        }
      }

      if (!mounted) return;

      setState(() {
        _activeReadings = items;
        _isLoadingHistory = false;
        _regenerateExportResult();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingHistory = false;
        _historyError = 'Unable to retrieve historical readings. Please check connection and try again.';
        _activeReadings = [];
        _regenerateExportResult();
      });
    }
  }

  /// Computes the single authoritative ExportResult once.
  /// Preview == Downloaded File == Shared File
  void _regenerateExportResult() {
    final String timeframeDesc = _exportTimeframe == 'custom' && _customDateRange != null
        ? '${DateFormat('yyyy-MM-dd').format(_customDateRange!.start)} to ${DateFormat('yyyy-MM-dd').format(_customDateRange!.end)}'
        : (_exportTimeframe == '24h'
            ? 'Last 24 Hours'
            : (_exportTimeframe == '7d' ? 'Last 7 Days' : 'Last 30 Days'));

    DateTime? customStart;
    DateTime? customEnd;
    if (_exportTimeframe == 'custom' && _customDateRange != null) {
      customStart = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day, 0, 0, 0);
      customEnd = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
    }

    ExportResult result;

    if (_reportType == 'water_used') {
      if (_exportFormat == 'CSV') {
        result = ExportService.generateWaterUsageReportCsv(
          tank: widget.tank,
          readings: _activeReadings,
          timeframe: timeframeDesc,
          rangeKey: _exportTimeframe == 'custom' ? '24h' : _exportTimeframe,
          startTime: customStart,
          endTime: customEnd,
        );
      } else if (_exportFormat == 'Excel') {
        result = ExportService.generateWaterUsageReportExcel(
          tank: widget.tank,
          readings: _activeReadings,
          timeframe: timeframeDesc,
          rangeKey: _exportTimeframe == 'custom' ? '24h' : _exportTimeframe,
          startTime: customStart,
          endTime: customEnd,
        );
      } else {
        result = ExportService.generateWaterUsageReportText(
          tank: widget.tank,
          readings: _activeReadings,
          timeframe: timeframeDesc,
          rangeKey: _exportTimeframe == 'custom' ? '24h' : _exportTimeframe,
          startTime: customStart,
          endTime: customEnd,
        );
      }
    } else {
      // Water Level Report
      if (_exportFormat == 'CSV') {
        result = ExportService.generateWaterLevelReportCsv(
          tank: widget.tank,
          readings: _activeReadings,
          timeframe: timeframeDesc,
        );
      } else if (_exportFormat == 'Excel') {
        result = ExportService.generateWaterLevelReportExcel(
          tank: widget.tank,
          readings: _activeReadings,
          timeframe: timeframeDesc,
        );
      } else {
        result = ExportService.generateWaterLevelReportText(
          tank: widget.tank,
          readings: _activeReadings,
          timeframe: timeframeDesc,
        );
      }
    }

    _cachedExportResult = result;
  }

  Future<void> _handleDownload() async {
    if (_cachedExportResult == null || _cachedExportResult!.isEmpty) return;

    setState(() {
      _isExporting = true;
      _exportSuccessMessage = null;
    });

    try {
      // Trigger genuine client browser download
      ExportService.downloadExport(_cachedExportResult!);

      setState(() {
        _isExporting = false;
        _exportSuccessMessage = 'Downloaded "${_cachedExportResult!.fileName}" (${_cachedExportResult!.recordCount} records).';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Report downloaded: ${_cachedExportResult!.fileName}'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() {
        _isExporting = false;
        _exportSuccessMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to download report: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleShare() async {
    if (_cachedExportResult == null || _cachedExportResult!.isEmpty) return;

    setState(() {
      _isSharing = true;
      _shareNoticeMessage = null;
    });

    try {
      final shareResult = await ExportService.shareExport(
        _cachedExportResult!,
        title: 'LEVELS ${_reportType == 'water_used' ? "Water Usage" : "Water Level"} Report',
        text: 'LEVELS Water Telemetry Report for ${widget.tank.tankName} (${widget.tank.building})',
      );

      setState(() => _isSharing = false);

      if (shareResult.status == FileShareStatus.success) {
        setState(() {
          _shareNoticeMessage = '✓ Report shared successfully.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Report shared successfully'),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (shareResult.status == FileShareStatus.unsupported) {
        setState(() {
          _shareNoticeMessage = shareResult.message ??
              'File sharing is not supported by this browser. The report has been prepared and can be downloaded directly instead.';
        });
      } else if (shareResult.status == FileShareStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(shareResult.message ?? 'Unable to share report'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSharing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Share error: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _validateImportContent(String content) {
    setState(() {
      _isValidating = true;
      _importSuccessMessage = null;
    });

    final audit = ExportService.validateAndParseCsv(
      content,
      tankCapacity: widget.tank.tankCapacity > 0 ? widget.tank.tankCapacity : 280000.0,
      tankHeight: double.tryParse(widget.tank.tankHeight.toString()) ?? 2.5,
    );

    setState(() {
      _auditResult = audit;
      _isValidating = false;
    });
  }

  void _handleExecuteImport() {
    if (_auditResult == null || !_auditResult!.isValid || _auditResult!.parsedReadings.isEmpty) return;

    setState(() => _isImporting = true);

    final provider = Provider.of<TankProvider>(context, listen: false);
    final key = '${widget.tank.deviceId}:24h';
    provider.setMockHistoryForTest(key, _auditResult!.parsedReadings);

    setState(() {
      _isImporting = false;
      _importSuccessMessage = 'Successfully ingested ${_auditResult!.validRows} telemetry readings into ${widget.tank.tankName}.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMutedColor = isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Modal Header with Tank Metadata & Device Freshness Status
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _activeMode == 'import'
                            ? Icons.upload_file_rounded
                            : (_reportType == 'water_used' ? Icons.bar_chart_rounded : Icons.water_drop_rounded),
                        color: AppTheme.primaryBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _activeMode == 'import'
                              ? 'DATA INGESTION'
                              : (_reportType == 'water_used' ? 'EXPORT WATER USAGE REPORT' : 'EXPORT WATER LEVEL REPORT'),
                          style: TextStyle(
                            color: textMutedColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${widget.tank.tankName} (${widget.tank.building})',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: widget.tank.isOnline()
                                    ? const Color(0xFF16A34A).withOpacity(0.12)
                                    : Colors.grey.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.tank.isOnline() ? 'ONLINE' : 'OFFLINE',
                                style: TextStyle(
                                  color: widget.tank.isOnline() ? const Color(0xFF16A34A) : Colors.grey,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: textMutedColor, size: 20),
                  splashRadius: 18,
                ),
              ],
            ),
          ),

          // 2. Report Type Selector (Segmented: Water Level vs Water Used)
          if (_activeMode == 'export')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildReportTypeSelector(
                      title: 'Water Level Report',
                      subtitle: 'Level %, Depth in meters & Capacity',
                      icon: Icons.water_drop_rounded,
                      isSelected: _reportType == 'water_level',
                      onTap: () {
                        if (_reportType != 'water_level') {
                          setState(() {
                            _reportType = 'water_level';
                            _regenerateExportResult();
                          });
                        }
                      },
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildReportTypeSelector(
                      title: 'Water Used Report',
                      subtitle: 'Hourly consumption in L/Hr & Peak usage',
                      icon: Icons.bar_chart_rounded,
                      isSelected: _reportType == 'water_used',
                      onTap: () {
                        if (_reportType != 'water_used') {
                          setState(() {
                            _reportType = 'water_used';
                            _regenerateExportResult();
                          });
                        }
                      },
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),

          // 3. Body View (Export or Import)
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _activeMode == 'export'
                  ? _buildExportTab(isDark, textColor, textMutedColor, borderColor)
                  : _buildImportTab(isDark, textColor, textMutedColor, borderColor),
            ),
          ),

          // 4. Modal Footer Switcher
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : const Color(0xFFF8FAFC),
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_activeMode == 'export')
                  TextButton.icon(
                    onPressed: () => setState(() => _activeMode = 'import'),
                    icon: const Icon(Icons.file_upload_outlined, size: 14),
                    label: const Text(
                      'Need to import offline logs? Open CSV Ingestion',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: () => setState(() => _activeMode = 'export'),
                    icon: const Icon(Icons.arrow_back_rounded, size: 14),
                    label: const Text(
                      'Back to Report Exports',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: TextStyle(color: textMutedColor, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTypeSelector({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryBlue.withOpacity(0.12)
              : (isDark ? Colors.white.withOpacity(0.02) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : (isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryBlue : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppTheme.primaryBlue : (isDark ? Colors.white : const Color(0xFF1E293B)),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: REPORT EXPORT HUB
  // ==========================================
  Widget _buildExportTab(
    bool isDark,
    Color textColor,
    Color textMutedColor,
    Color borderColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Timeframe Selection
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '1. SELECT REPORT TIMEFRAME',
              style: TextStyle(color: textMutedColor, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            if (_isLoadingHistory)
              Row(
                children: [
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5)),
                  const SizedBox(width: 6),
                  Text('Fetching telemetry…', style: TextStyle(color: textMutedColor, fontSize: 10)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildTimeframeChip('24h', 'Last 24 Hours'),
            _buildTimeframeChip('7d', 'Last 7 Days'),
            _buildTimeframeChip('30d', 'Last 30 Days'),
            _buildTimeframeChip('custom', 'Custom Range'),
          ],
        ),
        if (_exportTimeframe == 'custom') ...[
          const SizedBox(height: 10),
          InkWell(
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now(),
                initialDateRange: _customDateRange,
              );
              if (picked != null) {
                setState(() => _customDateRange = picked);
                _loadAuthoritativeHistory();
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.date_range_rounded, size: 16, color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  Text(
                    _customDateRange != null
                        ? '${DateFormat('MMM dd, yyyy').format(_customDateRange!.start)}  →  ${DateFormat('MMM dd, yyyy').format(_customDateRange!.end)}'
                        : 'Pick Custom Date Range',
                    style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 18),

        // 2. Export Format Selection
        Text(
          '2. SELECT EXPORT FORMAT',
          style: TextStyle(color: textMutedColor, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildFormatCard('CSV', 'CSV Spreadsheet', '.csv', Icons.table_chart_rounded, isDark)),
            const SizedBox(width: 10),
            Expanded(child: _buildFormatCard('Excel', 'Excel Spreadsheet', '.xls', Icons.grid_on_rounded, isDark)),
            const SizedBox(width: 10),
            Expanded(child: _buildFormatCard('Report', 'Printable Text Report', '.txt', Icons.description_rounded, isDark)),
          ],
        ),

        const SizedBox(height: 18),

        // 3. Live Data Audit & Status
        _buildDataAuditSection(isDark, textColor, textMutedColor, borderColor),

        const SizedBox(height: 16),

        // 4. Live 5-Row Preview Table
        _buildPreviewSection(isDark, textColor, textMutedColor, borderColor),

        // 5. Feedback Messages (Download success, share unsupported notice)
        if (_shareNoticeMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _shareNoticeMessage!,
                    style: const TextStyle(color: Color(0xFFB45309), fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (_exportSuccessMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _exportSuccessMessage!,
                    style: const TextStyle(color: Color(0xFF16A34A), fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // 6. Dual Primary Action Bar: [ Download Report ] and [ Share Report ]
        _buildActionBar(isDark),
      ],
    );
  }

  /// Builds the live dataset summary card with stats and data completeness badges
  Widget _buildDataAuditSection(
    bool isDark,
    Color textColor,
    Color textMutedColor,
    Color borderColor,
  ) {
    if (_isLoadingHistory) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Text(
              'Preparing report… Fetching historical readings',
              style: TextStyle(color: textMutedColor, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    if (_historyError != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _historyError!,
                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: _loadAuthoritativeHistory,
              child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ],
        ),
      );
    }

    if (_cachedExportResult == null || _cachedExportResult!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B), size: 16),
                const SizedBox(width: 8),
                const Text(
                  'No historical readings found',
                  style: TextStyle(color: Color(0xFFB45309), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'There are no authoritative telemetry records for this tank during the selected period.',
              style: TextStyle(color: textMutedColor, fontSize: 11),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () {
                    setState(() => _exportTimeframe = '30d');
                    _loadAuthoritativeHistory();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Change Date Range', style: TextStyle(fontSize: 10.5)),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _loadAuthoritativeHistory,
                  child: const Text('Retry', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final stats = _cachedExportResult!.summaryStats;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _reportType == 'water_used' ? 'WATER USAGE DATA AUDIT' : 'WATER LEVEL DATA AUDIT',
                style: const TextStyle(color: AppTheme.primaryBlue, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              Row(
                children: [
                  Text(
                    '${_cachedExportResult!.recordCount} Records  •  ${_cachedExportResult!.formattedSize}',
                    style: TextStyle(color: textMutedColor, fontSize: 10.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_reportType == 'water_used')
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Consumed', style: TextStyle(color: textMutedColor, fontSize: 10)),
                    const SizedBox(height: 2),
                    Text(
                      '${NumberFormat('#,###').format(((stats['totalUsed'] as num?) ?? 0).round())} L',
                      style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Hourly Average', style: TextStyle(color: textMutedColor, fontSize: 10)),
                    const SizedBox(height: 2),
                    Text(
                      '${NumberFormat('#,###').format(((stats['avgHourly'] as num?) ?? 0).round())} L/Hr',
                      style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Peak Usage', style: TextStyle(color: textMutedColor, fontSize: 10)),
                    const SizedBox(height: 2),
                    Text(
                      '${NumberFormat('#,###').format(((stats['peakUsage'] as num?) ?? 0).round())} L/Hr',
                      style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Level', style: TextStyle(color: textMutedColor, fontSize: 10)),
                    const SizedBox(height: 2),
                    Text(
                      '${((stats['currentLevel'] as num?) ?? widget.tank.waterLevel).toStringAsFixed(1)}%',
                      style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Period Average', style: TextStyle(color: textMutedColor, fontSize: 10)),
                    const SizedBox(height: 2),
                    Text(
                      '${((stats['avgLevel'] as num?) ?? widget.tank.waterLevel).toStringAsFixed(1)}%',
                      style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Stored Volume', style: TextStyle(color: textMutedColor, fontSize: 10)),
                    const SizedBox(height: 2),
                    Text(
                      '${NumberFormat('#,###').format(((stats['storedVolume'] as num?) ?? (widget.tank.tankCapacity * (widget.tank.waterLevel / 100.0))).round())} L',
                      style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// 5-Row Live Preview Table rendered directly from the exact generated ExportResult
  Widget _buildPreviewSection(
    bool isDark,
    Color textColor,
    Color textMutedColor,
    Color borderColor,
  ) {
    if (_cachedExportResult == null || _cachedExportResult!.isEmpty) {
      return const SizedBox.shrink();
    }

    final previewRows = _cachedExportResult!.previewRows;
    if (previewRows.isEmpty) return const SizedBox.shrink();

    final isUsage = _reportType == 'water_used';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'LIVE REPORT PREVIEW (First ${previewRows.length} Rows)',
                  style: TextStyle(color: textMutedColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _cachedExportResult!.fileName,
                    style: const TextStyle(color: AppTheme.primaryBlue, fontSize: 10, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 32,
              dataRowMinHeight: 28,
              dataRowMaxHeight: 32,
              horizontalMargin: 14,
              columnSpacing: 18,
              headingTextStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textMutedColor),
              dataTextStyle: TextStyle(fontSize: 11, color: textColor),
              columns: isUsage
                  ? const [
                      DataColumn(label: Text('WINDOW')),
                      DataColumn(label: Text('START TIME')),
                      DataColumn(label: Text('WATER USED')),
                      DataColumn(label: Text('USAGE SHARE')),
                    ]
                  : const [
                      DataColumn(label: Text('DATE & TIME')),
                      DataColumn(label: Text('WATER LEVEL')),
                      DataColumn(label: Text('DEPTH')),
                      DataColumn(label: Text('VOLUME')),
                      DataColumn(label: Text('STATUS')),
                    ],
              rows: previewRows.map((row) {
                if (isUsage) {
                  return DataRow(
                    cells: [
                      DataCell(Text(row['Window'] ?? '')),
                      DataCell(Text(row['StartTime'] ?? '')),
                      DataCell(Text(row['WaterUsed'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(row['Share'] ?? '')),
                    ],
                  );
                } else {
                  return DataRow(
                    cells: [
                      DataCell(Text(row['DateTime'] ?? '')),
                      DataCell(Text(row['Level'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(row['Height'] ?? '')),
                      DataCell(Text(row['Volume'] ?? '')),
                      DataCell(Text(row['Status'] ?? '')),
                    ],
                  );
                }
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Dual Action Bar: Side-by-side Download and Share buttons with responsive stacking
  Widget _buildActionBar(bool isDark) {
    final bool canAction = !_isLoadingHistory &&
        _historyError == null &&
        _cachedExportResult != null &&
        !_cachedExportResult!.isEmpty &&
        !_isExporting &&
        !_isSharing;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 450;

        final downloadButton = ElevatedButton.icon(
          onPressed: canAction ? _handleDownload : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          icon: _isExporting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.file_download_rounded, size: 18),
          label: Text(
            _isExporting ? 'Downloading…' : 'Download Report',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        );

        final shareButton = ElevatedButton.icon(
          onPressed: canAction ? _handleShare : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
            foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
              ),
            ),
            elevation: 0,
          ),
          icon: _isSharing
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.share_rounded, size: 17),
          label: Text(
            _isSharing ? 'Sharing…' : 'Share Report',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        );

        if (isNarrow) {
          return Column(
            children: [
              SizedBox(width: double.infinity, height: 46, child: downloadButton),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, height: 46, child: shareButton),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: SizedBox(height: 46, child: downloadButton)),
            const SizedBox(width: 12),
            Expanded(child: SizedBox(height: 46, child: shareButton)),
          ],
        );
      },
    );
  }

  Widget _buildTimeframeChip(String key, String label) {
    final isSelected = _exportTimeframe == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
      selected: isSelected,
      onSelected: (val) {
        if (val && _exportTimeframe != key) {
          setState(() => _exportTimeframe = key);
          _loadAuthoritativeHistory();
        }
      },
      selectedColor: AppTheme.primaryBlue.withOpacity(0.15),
      labelStyle: TextStyle(color: isSelected ? AppTheme.primaryBlue : Colors.grey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildFormatCard(String formatKey, String label, String ext, IconData icon, bool isDark) {
    final isSelected = _exportFormat == formatKey;
    return GestureDetector(
      onTap: () {
        if (_exportFormat != formatKey) {
          setState(() {
            _exportFormat = formatKey;
            _regenerateExportResult();
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue.withOpacity(0.08) : (isDark ? Colors.white.withOpacity(0.02) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : (isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primaryBlue : Colors.grey, size: 22),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: isSelected ? AppTheme.primaryBlue : (isDark ? Colors.white : const Color(0xFF1E293B)), fontSize: 10.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
            Text(ext, style: const TextStyle(color: Colors.grey, fontSize: 9.5)),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: SAFE IMPORT HUB
  // ==========================================
  Widget _buildImportTab(bool isDark, Color textColor, Color textMutedColor, Color borderColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '1. INPUT CSV LOG',
              style: TextStyle(color: textMutedColor, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            TextButton.icon(
              onPressed: () {
                final template = ExportService.generateCsvTemplate();
                final result = ExportResult(
                  fileName: 'LEVELS_telemetry_template.csv',
                  content: template,
                  mimeType: 'text/csv',
                  recordCount: 3,
                );
                ExportService.downloadExport(result);
              },
              icon: const Icon(Icons.download_rounded, size: 14),
              label: const Text('Download Template', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Container(
          height: 120,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: TextField(
            controller: _importTextController,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            style: TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: textColor),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Paste CSV contents here, or click "Load Sample Data" below...',
              hintStyle: TextStyle(fontSize: 11, color: textMutedColor),
            ),
            onChanged: (val) {
              if (val.trim().isNotEmpty) {
                _validateImportContent(val);
              } else {
                setState(() => _auditResult = null);
              }
            },
          ),
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () {
                final template = ExportService.generateCsvTemplate();
                _importTextController.text = template;
                _validateImportContent(template);
              },
              icon: const Icon(Icons.playlist_add_check_rounded, size: 14),
              label: const Text('Load Sample Data', style: TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const Spacer(),
            if (_importTextController.text.isNotEmpty)
              TextButton(
                onPressed: () {
                  _importTextController.clear();
                  setState(() => _auditResult = null);
                },
                child: const Text('Clear', style: TextStyle(color: Colors.red, fontSize: 11)),
              ),
          ],
        ),

        const SizedBox(height: 14),

        if (_auditResult != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _auditResult!.isValid
                  ? const Color(0xFF16A34A).withOpacity(0.08)
                  : const Color(0xFFDC2626).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _auditResult!.isValid
                    ? const Color(0xFF16A34A).withOpacity(0.3)
                    : const Color(0xFFDC2626).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _auditResult!.isValid ? Icons.check_circle_rounded : Icons.warning_rounded,
                      color: _auditResult!.isValid ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _auditResult!.isValid ? 'CSV SCHEMA VALIDATED' : 'INGESTION WARNINGS DETECTED',
                      style: TextStyle(
                        color: _auditResult!.isValid ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Rows Analyzed: ${_auditResult!.totalRows}  •  Valid: ${_auditResult!.validRows}  •  Invalid: ${_auditResult!.invalidRows}  •  Duplicates Skipped: ${_auditResult!.skippedRows}',
                  style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: (_auditResult != null && _auditResult!.isValid && !_isImporting)
                ? _handleExecuteImport
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            icon: _isImporting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.cloud_upload_rounded, size: 18),
            label: Text(
              _isImporting
                  ? 'Ingesting Readings...'
                  : (_auditResult != null && _auditResult!.isValid
                      ? 'Confirm & Ingest ${_auditResult!.validRows} Records'
                      : 'Validate File to Enable Import'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
          ),
        ),

        if (_importSuccessMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _importSuccessMessage!,
                    style: const TextStyle(color: Color(0xFF16A34A), fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
