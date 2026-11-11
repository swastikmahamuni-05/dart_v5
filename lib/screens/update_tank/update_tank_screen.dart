import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/tank.dart';
import '../../providers/tank_provider.dart';
import '../../widgets/tank_form.dart';

class UpdateTankScreen extends StatelessWidget {
  const UpdateTankScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final textMutedColor = isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0);

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
          'UPDATE TANK CONFIG',
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: Consumer<TankProvider>(
        builder: (context, tankProvider, child) {
          final tanks = tankProvider.tanks;

          if (tanks.isEmpty) {
            return Center(
              child: Text(
                'No tanks available to update.',
                style: TextStyle(color: textMutedColor, fontSize: 13),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            itemCount: tanks.length,
            itemBuilder: (context, index) {
              final tank = tanks[index];

              return Card(
                color: cardBg,
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: borderColor),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCA8A04).withOpacity(0.1), // Yellow/Warning themed
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.settings_outlined, color: Color(0xFFCA8A04), size: 20),
                  ),
                  title: Text(
                    tank.tankName,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Device: ${tank.deviceId} • ${tank.location}',
                    style: TextStyle(color: textMutedColor, fontSize: 11),
                  ),
                  trailing: Icon(Icons.edit_outlined, color: textMutedColor, size: 20),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditTankFormScreen(tank: tank),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class EditTankFormScreen extends StatefulWidget {
  final Tank tank;

  const EditTankFormScreen({
    Key? key,
    required this.tank,
  }) : super(key: key);

  @override
  State<EditTankFormScreen> createState() => _EditTankFormScreenState();
}

class _EditTankFormScreenState extends State<EditTankFormScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TankProvider>(context, listen: false).fetchConfig(widget.tank.deviceId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final textMutedColor = isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B);
    final tankProvider = Provider.of<TankProvider>(context);

    // Find the latest tank state in provider (which may have updated config)
    final tankIdx = tankProvider.allTanks.indexWhere((t) => t.tankId == widget.tank.tankId);
    final currentTank = tankIdx != -1 ? tankProvider.allTanks[tankIdx] : widget.tank;

    if (tankProvider.isConfigLoading) {
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
            'LOADING CONFIG',
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (tankProvider.configError != null) {
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
            'ERROR',
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                tankProvider.configError ?? 'No Internet Connection',
                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Please check your network and try again.',
                style: TextStyle(color: textMutedColor, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => tankProvider.fetchConfig(widget.tank.deviceId),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
          'EDIT ${currentTank.tankName}',
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
            initialTank: currentTank,
            submitButtonText: 'SAVE CHANGES',
            onSave: (formData) async {
              final updatedTank = currentTank.copyWith(
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
                updatedAt: DateTime.now().toIso8601String(),
              );

              // Provider will update status logic as well
              await tankProvider.updateTank(updatedTank);
              await tankProvider.fetchTanks();

              if (!mounted) return;

              if (tankProvider.errorMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to update config: ${tankProvider.errorMessage}'),
                    backgroundColor: const Color(0xFFEF4444),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Tank "${formData['tankName']}" updated successfully.'),
                    backgroundColor: const Color(0xFFCA8A04), // Yellow/Dark Amber
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
                Navigator.pop(context);
              }
            },
          ),
        ),
      ),
    );
  }
}
