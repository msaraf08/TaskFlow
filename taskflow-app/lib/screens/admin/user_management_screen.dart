import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/employee.dart';
import '../../providers/auth_provider.dart';
import '../../providers/team_provider.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_error_widget.dart';
import '../../widgets/app_loading_indicator.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadEmployees();
      }
    });
  }

  Future<void> _loadEmployees() async {
    final teamProv = context.read<TeamProvider>();
    await teamProv.fetchEmployees();
  }

  String _formatRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Admin';
      case 'manager':
        return 'Manager';
      case 'employee':
        return 'Employee';
      default:
        return role;
    }
  }

  Color _getRoleColor(String role, ColorScheme colorScheme) {
    switch (role.toLowerCase()) {
      case 'admin':
        return colorScheme.error;
      case 'manager':
        return colorScheme.primary;
      case 'employee':
        return colorScheme.secondary;
      default:
        return colorScheme.outline;
    }
  }

  Future<void> _showChangeRoleDialog(Employee employee) async {
    final availableRoles = ['employee', 'manager', 'admin'];
    String? selectedRole;

    final chosenRole = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return AlertDialog(
              title: Text('Change Role for ${employee.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current role: ${_formatRole(employee.role)}',
                    style: Theme.of(builderContext).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Select New Role',
                      border: OutlineInputBorder(),
                    ),
                    items: availableRoles
                        .where(
                          (r) => r.toLowerCase() != employee.role.toLowerCase(),
                        )
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(_formatRole(r)),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedRole = val;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selectedRole == null
                      ? null
                      : () => Navigator.of(dialogContext).pop(selectedRole),
                  child: const Text('Next'),
                ),
              ],
            );
          },
        );
      },
    );

    if (chosenRole == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (confirmContext) {
        return AlertDialog(
          title: const Text('Confirm Role Change'),
          content: Text(
            'Are you sure you want to change the role of ${employee.name} from ${_formatRole(employee.role)} to ${_formatRole(chosenRole)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(confirmContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(confirmContext).pop(true),
              child: const Text('Confirm Change'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      final teamProv = context.read<TeamProvider>();
      await teamProv.updateEmployeeRole(employee.id, chosenRole);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Role updated to ${_formatRole(chosenRole)} for ${employee.name}',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authUser = context.watch<AuthProvider>().user;
    final teamProv = context.watch<TeamProvider>();
    final employees = teamProv.employees;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh user list',
            onPressed: _loadEmployees,
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (teamProv.isLoading && employees.isEmpty) {
            return const AppLoadingIndicator(message: 'Loading users...');
          }

          if (teamProv.errorMessage != null && employees.isEmpty) {
            return AppErrorWidget(
              message: teamProv.errorMessage!,
              onRetry: _loadEmployees,
            );
          }

          if (employees.isEmpty) {
            return const AppEmptyState(
              icon: Icons.people_outline,
              title: 'No Users Found',
              message: 'No employees or users were found in the system.',
            );
          }

          return RefreshIndicator(
            onRefresh: _loadEmployees,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: employees.length,
              itemBuilder: (context, index) {
                final emp = employees[index];
                final isSelf =
                    authUser != null &&
                    (authUser.id == emp.userId ||
                        authUser.email.toLowerCase() ==
                            emp.email.toLowerCase());

                final roleColor = _getRoleColor(emp.role, theme.colorScheme);

                return Semantics(
                  label:
                      'User ${emp.name}, ${emp.department} department, ${_formatRole(emp.role)} role',
                  child: Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: roleColor.withValues(alpha: 0.15),
                            child: Text(
                              emp.name.isNotEmpty
                                  ? emp.name[0].toUpperCase()
                                  : 'U',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: roleColor,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        emp.name,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: roleColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: roleColor.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        _formatRole(emp.role),
                                        style: TextStyle(
                                          color: roleColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  emp.email,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (emp.department.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    emp.department,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isSelf)
                            Tooltip(
                              message: 'Cannot change your own role',
                              child: TextButton(
                                onPressed: null,
                                child: const Text('Self'),
                              ),
                            )
                          else
                            Semantics(
                              button: true,
                              label: 'Change role for ${emp.name}',
                              child: OutlinedButton(
                                onPressed: () => _showChangeRoleDialog(emp),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                                child: const Text('Change Role'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
