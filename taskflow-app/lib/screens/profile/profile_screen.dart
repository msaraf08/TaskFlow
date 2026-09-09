import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/team_provider.dart';
import '../../widgets/confirmation_dialog.dart';
import 'change_password_dialog.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProv = context.watch<AuthProvider>();
    final teamProv = context.watch<TeamProvider>();
    final user = authProv.user;

    final employee = teamProv.employees
        .where((e) => e.userId == user?.id)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        (user?.name.isNotEmpty ?? false)
                            ? user!.name[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user?.name ?? 'Unknown User',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Chip(
                      avatar: const Icon(Icons.badge_outlined, size: 18),
                      label: Text(
                        user?.role.displayName ?? 'Employee',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: theme.colorScheme.secondaryContainer,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (employee != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Employee Information',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(height: 20),
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.business_outlined),
                        title: const Text('Department'),
                        subtitle: Text(employee.department),
                      ),
                      if (employee.phone != null && employee.phone!.isNotEmpty)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.phone_outlined),
                          title: const Text('Phone'),
                          subtitle: Text(employee.phone!),
                        ),
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.calendar_month_outlined),
                        title: const Text('Joining Date'),
                        subtitle: Text(employee.formattedJoiningDate),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock_reset_outlined),
                    title: const Text('Change Password'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => const ChangePasswordDialog(),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
                      final confirmed = await showConfirmationDialog(
                        context,
                        title: 'Sign Out',
                        message:
                            'Are you sure you want to sign out of TaskFlow?',
                        confirmLabel: 'Sign Out',
                        isDestructive: true,
                      );
                      if (confirmed == true && context.mounted) {
                        await context.read<AuthProvider>().logout();
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
