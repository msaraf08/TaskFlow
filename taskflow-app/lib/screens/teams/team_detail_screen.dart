import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/team_provider.dart';
import '../../widgets/app_error_widget.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/confirmation_dialog.dart';
import 'team_form_screen.dart';

class TeamDetailScreen extends StatefulWidget {
  final String teamId;

  const TeamDetailScreen({super.key, required this.teamId});

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadTeam();
      }
    });
  }

  Future<void> _loadTeam() async {
    final teamProv = context.read<TeamProvider>();
    await Future.wait([
      teamProv.getTeam(widget.teamId).catchError((_) => teamProv.selectedTeam),
      teamProv.fetchEmployees().catchError((_) {}),
    ]);
  }

  void _showAddMemberDialog() {
    final teamProv = context.read<TeamProvider>();
    final currentTeam = teamProv.selectedTeam;
    if (currentTeam == null) return;

    final availableEmployees = teamProv.employees.where((emp) {
      return !currentTeam.memberIds.contains(emp.id);
    }).toList();

    if (availableEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All available employees are already in this team.'),
        ),
      );
      return;
    }

    String? selectedEmpId = availableEmployees.first.id;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Team Member'),
          content: DropdownButtonFormField<String>(
            initialValue: selectedEmpId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Select Employee',
              prefixIcon: Icon(Icons.person_add_outlined),
            ),
            items: availableEmployees.map((emp) {
              return DropdownMenuItem(
                value: emp.id,
                child: Text('${emp.name} (${emp.email})'),
              );
            }).toList(),
            onChanged: (val) {
              setDialogState(() {
                selectedEmpId = val;
              });
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedEmpId == null
                  ? null
                  : () async {
                      Navigator.of(ctx).pop();
                      try {
                        await context.read<TeamProvider>().addMember(
                          widget.teamId,
                          selectedEmpId!,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Member added successfully'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to add member: $e')),
                          );
                        }
                      }
                    },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthProvider>().user;
    final teamProv = context.watch<TeamProvider>();
    final team = teamProv.selectedTeam;

    final isAdmin = user?.role == UserRole.admin;
    final isManager = user?.role == UserRole.manager;
    final canManage = isAdmin || isManager;

    if (teamProv.isLoading && team == null) {
      return const Scaffold(
        body: AppLoadingIndicator(message: 'Loading team details...'),
      );
    }

    if (teamProv.errorMessage != null && team == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Team Details')),
        body: AppErrorWidget(
          message: teamProv.errorMessage!,
          onRetry: _loadTeam,
        ),
      );
    }

    if (team == null) {
      return const Scaffold(body: Center(child: Text('Team not found')));
    }

    final manager = teamProv.employees
        .where((e) => e.id == team.managerId)
        .firstOrNull;
    final memberEmployees = teamProv.employees
        .where((e) => team.memberIds.contains(e.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(team.name),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Team',
              onPressed: () async {
                final updated = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => TeamFormScreen(team: team)),
                );
                if (updated == true) {
                  _loadTeam();
                }
              },
            ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete Team',
              onPressed: () async {
                final confirmed = await showConfirmationDialog(
                  context,
                  title: 'Delete Team',
                  message:
                      'Are you sure you want to delete "${team.name}"? This action cannot be undone.',
                  confirmLabel: 'Delete',
                  isDestructive: true,
                );
                if (confirmed == true && context.mounted) {
                  try {
                    await teamProv.deleteTeam(team.id);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Team deleted successfully'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to delete team: $e')),
                      );
                    }
                  }
                }
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTeam,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        team.description ?? '',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Icon(
                            Icons.manage_accounts,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Manager: ',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Expanded(
                            child: Text(
                              manager != null
                                  ? '${manager.name} (${manager.email})'
                                  : (team.managerId ?? 'None'),
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    'Team Members (${memberEmployees.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (canManage)
                    FilledButton.icon(
                      onPressed: _showAddMemberDialog,
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('Add Member'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (memberEmployees.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'No members assigned to this team yet.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: memberEmployees.length,
                  itemBuilder: (context, index) {
                    final emp = memberEmployees[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            emp.name.isNotEmpty
                                ? emp.name[0].toUpperCase()
                                : 'E',
                          ),
                        ),
                        title: Text(
                          emp.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${emp.email} • ${emp.role.toUpperCase()} • ${emp.department.isNotEmpty ? emp.department : 'General'}',
                        ),
                        trailing: canManage
                            ? IconButton(
                                icon: const Icon(
                                  Icons.person_remove_outlined,
                                  color: Colors.red,
                                ),
                                tooltip: 'Remove from team',
                                onPressed: () async {
                                  final confirm = await showConfirmationDialog(
                                    context,
                                    title: 'Remove Member',
                                    message:
                                        'Remove ${emp.name} from ${team.name}?',
                                    confirmLabel: 'Remove',
                                    isDestructive: true,
                                  );
                                  if (confirm == true && context.mounted) {
                                    try {
                                      await teamProv.removeMember(
                                        team.id,
                                        emp.id,
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Member removed from team',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Failed to remove member: $e',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                              )
                            : null,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
