import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/tank.dart';
import '../../providers/tank_provider.dart';

class DeleteTankScreen extends StatelessWidget {
  const DeleteTankScreen({Key? key}) : super(key: key);

  void _showDeleteConfirmation(BuildContext context, Tank tank, TankProvider tankProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Delete Tank?',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tank.tankName,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'This action cannot be undone.',
                style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'CANCEL',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700], fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                tankProvider.deleteTank(tank.tankId);
                Navigator.pop(context); // Pop dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Tank "${tank.tankName}" deleted successfully.'),
                    backgroundColor: const Color(0xFFDC2626), // Red
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('DELETE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
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
          'DELETE TANK',
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
                'No tanks available to delete.',
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
                      color: const Color(0xFFDC2626).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFDC2626), size: 20),
                  ),
                  title: Text(
                    tank.tankName,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Device: ${tank.deviceId} • ${tank.location}',
                    style: TextStyle(color: textMutedColor, fontSize: 11),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 22),
                    onPressed: () => _showDeleteConfirmation(context, tank, tankProvider),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
