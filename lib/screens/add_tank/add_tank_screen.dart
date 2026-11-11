import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/tank.dart';
import '../../providers/tank_provider.dart';
import '../../widgets/tank_form.dart';

class AddTankScreen extends StatelessWidget {
  const AddTankScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final tankProvider = Provider.of<TankProvider>(context, listen: false);

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
          'ADD NEW TANK',
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: TankForm(
            submitButtonText: 'PROVISION TANK',
            onSave: (formData) async {
              final nowStr = DateTime.now().toIso8601String();
              final uniqueId = formData['deviceId'];

              final newTank = Tank(
                tankId: uniqueId,
                deviceId: formData['deviceId'],
                tankName: formData['tankName'],
                location: formData['location'],
                tankCapacity: formData['tankCapacity'],
                tankHeight: formData['tankHeight'],
                vref: formData['vref'],
                correctionFactor: formData['correctionFactor'],
                offset: formData['offset'],
                range: formData['range'],
                warningThreshold: formData['warningThreshold'],
                criticalThreshold: formData['criticalThreshold'],
                isActive: true,
                isDeleted: false,
                createdAt: nowStr,
                updatedAt: nowStr,
                currentLevelPercent: 0.0,
                temperature: 0.0,
                status: 'offline',
                lastUpdated: 'Never updated',
                depth: 0.0,
                rssi: -99,
                battery: 0.0,
              );

              try {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => Center(
                    child: Card(
                      color: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              'Provisioning Tank...',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );

                await tankProvider.addTank(newTank);
                await tankProvider.fetchTanks();

                if (context.mounted) {
                  Navigator.pop(context); // Close loading dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Tank "${formData['tankName']}" provisioned successfully.'),
                      backgroundColor: const Color(0xFF16A34A), // Green
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  Navigator.pop(context); // Pop AddTankScreen
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Close loading dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to provision tank: $e'),
                      backgroundColor: const Color(0xFFDC2626), // Red
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              }
            },
          ),
        ),
      ),
    );
  }
}
