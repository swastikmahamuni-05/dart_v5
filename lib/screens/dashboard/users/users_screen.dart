import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/tank_provider.dart';
import '../../../models/user_model.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({Key? key}) : super(key: key);

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  void _showAddUserDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    UserRole selectedRole = UserRole.operator;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add System User', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name', hintText: 'e.g. Anil Kumar'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email Address', hintText: 'e.g. operator2@mit.edu'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserRole>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Assigned Role'),
                items: const [
                  DropdownMenuItem(value: UserRole.admin, child: Text('ADMIN')),
                  DropdownMenuItem(value: UserRole.operator, child: Text('OPERATOR')),
                ],
                onChanged: (val) {
                  if (val != null) selectedRole = val;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && emailController.text.isNotEmpty) {
                  final newUser = UserModel(
                    id: 'USR-${DateTime.now().millisecondsSinceEpoch % 1000}',
                    name: nameController.text.trim(),
                    email: emailController.text.trim(),
                    role: selectedRole,
                    assignedBuildings: ['IT Building'],
                    assignedTanks: ['tank_001'],
                    isActive: true,
                    lastLogin: 'Never',
                  );
                  Provider.of<TankProvider>(context, listen: false).addUser(newUser);
                  Navigator.pop(context);
                }
              },
              child: const Text('Create User'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tankProvider = Provider.of<TankProvider>(context);
    final users = tankProvider.users;

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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.people_outline_rounded, color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF1565C0), size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'User Management',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddUserDialog(context),
                  icon: const Icon(Icons.person_add_rounded, size: 16),
                  label: const Text('Add User', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Manage platform personnel and operator scope access.',
              style: TextStyle(color: textMutedColor, fontSize: 12),
            ),
            const SizedBox(height: 20),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final isAdminRole = user.isAdmin;

                return Card(
                  color: cardBg,
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: borderColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: (isAdminRole ? const Color(0xFF1565C0) : const Color(0xFF00E5FF)).withOpacity(0.12),
                          child: Icon(
                            isAdminRole ? Icons.admin_panel_settings_outlined : Icons.person_outline_rounded,
                            color: isAdminRole ? const Color(0xFF1565C0) : const Color(0xFF00E5FF),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    user.name,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (isAdminRole ? const Color(0xFF1565C0) : const Color(0xFF16A34A)).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      user.roleName,
                                      style: TextStyle(
                                        color: isAdminRole ? const Color(0xFF1565C0) : const Color(0xFF16A34A),
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(user.email, style: TextStyle(color: textMutedColor, fontSize: 11)),
                              const SizedBox(height: 4),
                              Text(
                                'Scope: ${user.assignedBuildings.join(', ')}',
                                style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: user.isActive,
                          activeColor: const Color(0xFF16A34A),
                          onChanged: (val) {
                            tankProvider.toggleUserStatus(user.id);
                          },
                        ),
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
}
