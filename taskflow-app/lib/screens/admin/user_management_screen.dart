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
  String _statusFilter = 'all'; // 'all', 'active', 'inactive'

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

  Future<void> _showProfileDialog(Employee employee) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => _EmployeeProfileDialog(employee: employee),
    );
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

  Future<void> _showDeactivateDialog(Employee employee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (confirmContext) {
        return AlertDialog(
          title: const Text('Deactivate User'),
          content: Text(
            'Are you sure you want to deactivate ${employee.name} (${employee.email})?\n\nThey will not be able to log in to TaskFlow. Their historical tasks, comments, and activity records will be preserved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(confirmContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(confirmContext).colorScheme.error,
                foregroundColor: Theme.of(confirmContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(confirmContext).pop(true),
              child: const Text('Deactivate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      final teamProv = context.read<TeamProvider>();
      await teamProv.deactivateEmployee(employee.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${employee.name} has been deactivated'),
          backgroundColor: Colors.orange.shade800,
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

  Future<void> _showReactivateDialog(Employee employee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (confirmContext) {
        return AlertDialog(
          title: const Text('Reactivate User'),
          content: Text(
            'Are you sure you want to reactivate ${employee.name} (${employee.email})?\n\nThey will regain access to log in and collaborate in TaskFlow.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(confirmContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
              ),
              onPressed: () => Navigator.of(confirmContext).pop(true),
              child: const Text('Reactivate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      final teamProv = context.read<TeamProvider>();
      await teamProv.reactivateEmployee(employee.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${employee.name} has been reactivated'),
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
    final allEmployees = teamProv.employees;

    final filteredEmployees = allEmployees.where((emp) {
      final isInactive = emp.status.toLowerCase() == 'inactive';
      if (_statusFilter == 'active') return !isInactive;
      if (_statusFilter == 'inactive') return isInactive;
      return true;
    }).toList();

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
      body: Column(
        children: [
          // Filter Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('All (${allEmployees.length})'),
                    selected: _statusFilter == 'all',
                    onSelected: (_) => setState(() => _statusFilter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                      'Active (${allEmployees.where((e) => e.status.toLowerCase() != 'inactive').length})',
                    ),
                    selected: _statusFilter == 'active',
                    onSelected: (_) => setState(() => _statusFilter = 'active'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                      'Inactive (${allEmployees.where((e) => e.status.toLowerCase() == 'inactive').length})',
                    ),
                    selected: _statusFilter == 'inactive',
                    onSelected: (_) => setState(() => _statusFilter = 'inactive'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (teamProv.isLoading && allEmployees.isEmpty) {
                  return const AppLoadingIndicator(message: 'Loading users...');
                }

                if (teamProv.errorMessage != null && allEmployees.isEmpty) {
                  return AppErrorWidget(
                    message: teamProv.errorMessage!,
                    onRetry: _loadEmployees,
                  );
                }

                if (filteredEmployees.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.people_outline,
                    title: _statusFilter == 'all'
                        ? 'No Users Found'
                        : 'No ${_statusFilter.capitalize()} Users',
                    message: _statusFilter == 'all'
                        ? 'No employees or users were found in the system.'
                        : 'There are no users with $_statusFilter status.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: _loadEmployees,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredEmployees.length,
                    itemBuilder: (context, index) {
                      final emp = filteredEmployees[index];
                      final isSelf = authUser != null &&
                          (authUser.id == emp.userId ||
                              authUser.email.toLowerCase() == emp.email.toLowerCase());
                      final isInactive = emp.status.toLowerCase() == 'inactive';
                      final roleColor = _getRoleColor(emp.role, theme.colorScheme);

                      return Semantics(
                        label:
                            'User ${emp.name}, ${emp.department} department, ${_formatRole(emp.role)} role, ${isInactive ? "Inactive" : "Active"} status',
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isInactive
                                ? BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.4))
                                : BorderSide.none,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: isInactive
                                          ? theme.colorScheme.surfaceContainerHighest
                                          : roleColor.withValues(alpha: 0.15),
                                      child: Text(
                                        emp.name.isNotEmpty
                                            ? emp.name[0].toUpperCase()
                                            : 'U',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isInactive
                                              ? theme.colorScheme.outline
                                              : roleColor,
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
                                                        color: isInactive
                                                            ? theme.colorScheme.outline
                                                            : null,
                                                      ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              // Role Badge
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: roleColor.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: roleColor.withValues(alpha: 0.3),
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
                                              const SizedBox(width: 6),
                                              // Status Badge
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isInactive
                                                      ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
                                                      : Colors.green.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  isInactive ? 'Inactive' : 'Active',
                                                  style: TextStyle(
                                                    color: isInactive
                                                        ? theme.colorScheme.error
                                                        : Colors.green.shade800,
                                                    fontSize: 11,
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
                                  ],
                                ),
                                const Divider(height: 16),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Wrap(
                                    alignment: WrapAlignment.end,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.person_outline, size: 16),
                                        label: const Text('View Profile'),
                                        onPressed: () => _showProfileDialog(emp),
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                      if (isSelf) ...[
                                        Tooltip(
                                          message: 'You cannot modify your own role or account status',
                                          child: OutlinedButton(
                                            onPressed: null,
                                            style: OutlinedButton.styleFrom(
                                              visualDensity: VisualDensity.compact,
                                            ),
                                            child: const Text('Self'),
                                          ),
                                        ),
                                      ] else ...[
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.badge_outlined, size: 16),
                                          label: const Text('Change Role'),
                                          onPressed: () => _showChangeRoleDialog(emp),
                                          style: OutlinedButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ),
                                        if (isInactive)
                                          FilledButton.icon(
                                            icon: const Icon(Icons.check_circle_outline, size: 16),
                                            label: const Text('Reactivate'),
                                            onPressed: () => _showReactivateDialog(emp),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: Colors.green.shade700,
                                              visualDensity: VisualDensity.compact,
                                            ),
                                          )
                                        else
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.block_outlined, size: 16),
                                            label: const Text('Deactivate'),
                                            onPressed: () => _showDeactivateDialog(emp),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: theme.colorScheme.error,
                                              side: BorderSide(
                                                color: theme.colorScheme.error.withValues(alpha: 0.5),
                                              ),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                          ),
                                      ],
                                    ],
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
          ),
        ],
      ),
    );
  }
}

class _EmployeeProfileDialog extends StatefulWidget {
  final Employee employee;

  const _EmployeeProfileDialog({required this.employee});

  @override
  State<_EmployeeProfileDialog> createState() => _EmployeeProfileDialogState();
}

class _EmployeeProfileDialogState extends State<_EmployeeProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _deptController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.employee.name);
    _phoneController = TextEditingController(text: widget.employee.phone ?? '');
    _deptController = TextEditingController(text: widget.employee.department);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _deptController.dispose();
    super.dispose();
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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final teamProv = context.read<TeamProvider>();
      final updatedEmp = await teamProv.updateEmployeeProfile(
        widget.employee.id,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        department: _deptController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated for ${updatedEmp.name}'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
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
    final roleColor = _getRoleColor(widget.employee.role, theme.colorScheme);
    final isInactive = widget.employee.status.toLowerCase() == 'inactive';

    return AlertDialog(
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isInactive
                ? theme.colorScheme.surfaceContainerHighest
                : roleColor.withValues(alpha: 0.15),
            child: Text(
              widget.employee.name.isNotEmpty
                  ? widget.employee.name[0].toUpperCase()
                  : 'U',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isInactive
                    ? theme.colorScheme.outline
                    : roleColor,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Employee Profile',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badges Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: roleColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _formatRole(widget.employee.role),
                        style: TextStyle(
                          color: roleColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isInactive
                            ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
                            : Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isInactive ? 'Inactive' : 'Active',
                        style: TextStyle(
                          color: isInactive
                              ? theme.colorScheme.error
                              : Colors.green.shade800,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Editable: Full Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Full name cannot be empty';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                // Read-only: Email
                TextFormField(
                  initialValue: widget.employee.email,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                    helperText: 'Email cannot be modified',
                    filled: true,
                  ),
                ),
                const SizedBox(height: 12),
                // Editable: Phone Number
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (Optional)',
                    hintText: 'e.g. +1234567890',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                // Editable: Department
                TextFormField(
                  controller: _deptController,
                  decoration: const InputDecoration(
                    labelText: 'Department (Optional)',
                    hintText: 'e.g. Engineering',
                    prefixIcon: Icon(Icons.business_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                // Read-only: Role
                TextFormField(
                  initialValue: _formatRole(widget.employee.role),
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                    helperText: 'Use "Change Role" action to modify role',
                    filled: true,
                  ),
                ),
                const SizedBox(height: 12),
                // Read-only: Joining Date
                TextFormField(
                  initialValue: widget.employee.formattedJoiningDate,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Joining Date',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 12),
                // Read-only: Status
                TextFormField(
                  initialValue: widget.employee.status.capitalize(),
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Account Status',
                    prefixIcon: Icon(Icons.info_outline),
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save Changes'),
        ),
      ],
    );
  }
}

extension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
