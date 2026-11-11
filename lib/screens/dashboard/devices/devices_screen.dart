import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/tank_provider.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tankProvider = Provider.of<TankProvider>(context);
    final tanks = tankProvider.tanks;

    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final textMutedColor = isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.developer_board_rounded, color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF1565C0), size: 24),
                const SizedBox(width: 10),
                Text(
                  'Device Management',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'University IoT Sensors & Node Hardware Registry',
              style: TextStyle(color: textMutedColor, fontSize: 12),
            ),
            const SizedBox(height: 20),

            if (tanks.isEmpty)
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Center(
                  child: Text('No active devices registered.', style: TextStyle(color: textMutedColor)),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tanks.length,
                itemBuilder: (context, index) {
                  final tank = tanks[index];
                  final isOnline = tank.status != 'OFFLINE';

                  return Card(
                    color: cardBg,
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: borderColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
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
                                      color: (isOnline ? const Color(0xFF16A34A) : Colors.grey).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.memory_rounded,
                                      color: isOnline ? const Color(0xFF16A34A) : Colors.grey,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tank.deviceId,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'ESP32 Water Level Sensor',
                                        style: TextStyle(color: textMutedColor, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (isOnline ? const Color(0xFF16A34A) : Colors.grey).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: (isOnline ? const Color(0xFF16A34A) : Colors.grey).withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  isOnline ? 'ONLINE' : 'OFFLINE',
                                  style: TextStyle(
                                    color: isOnline ? const Color(0xFF16A34A) : Colors.grey,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Divider(color: borderColor, height: 1),
                          const SizedBox(height: 12),
                          _buildDeviceDetailRow('Assigned Tank', tank.tankName, textColor, textMutedColor),
                          _buildDeviceDetailRow('Building Location', '${tank.building} (${tank.university})', textColor, textMutedColor),
                          _buildDeviceDetailRow('Raw ADC Reading', '${tank.rawADC} / 4095', textColor, textMutedColor),
                          _buildDeviceDetailRow('Sensor Voltage', '${tank.dataVoltage.toStringAsFixed(1)} mV', textColor, textMutedColor),
                          _buildDeviceDetailRow('Sensor Current Draw', '${tank.dataCurrent.toStringAsFixed(2)} mA', textColor, textMutedColor),
                          _buildDeviceDetailRow('Battery Voltage', '${tank.battery.toStringAsFixed(2)} V', textColor, textMutedColor),
                          _buildDeviceDetailRow('WiFi RSSI Signal', '${tank.rssi} dBm', textColor, textMutedColor),
                          _buildDeviceDetailRow('MQTT Topic', 'water/${tank.deviceId}/telemetry', textColor, textMutedColor),
                          _buildDeviceDetailRow('AWS IoT Rule', 'Water_Tank_Telemetry', textColor, textMutedColor),
                          _buildDeviceDetailRow('DynamoDB Tables', 'Tank_Telemetry, Tank_Config', textColor, textMutedColor),
                          _buildDeviceDetailRow('Calibrated Depth', '${tank.depth.toStringAsFixed(2)} m (Height: ${(tank.tankHeight / 1000.0).toStringAsFixed(1)} m)', textColor, textMutedColor),
                          _buildDeviceDetailRow('Last Telemetry Packet', tank.lastUpdated, textColor, textMutedColor),
                          _buildDeviceDetailRow('Firmware Version', 'v1.3.6-stable (NTP sync)', textColor, textMutedColor),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceDetailRow(String label, String value, Color textColor, Color mutedColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: mutedColor, fontSize: 11)),
          Text(value, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
