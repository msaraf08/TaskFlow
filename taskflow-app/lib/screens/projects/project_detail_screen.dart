import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/team_provider.dart';
import '../../widgets/app_error_widget.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/status_badge.dart';
import '../tasks/task_detail_screen.dart';
import '../tasks/task_form_screen.dart';
import 'project_form_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final projProv = context.read<ProjectProvider>();
    final taskProv = context.read<TaskProvider>();
    final teamProv = context.read<TeamProvider>();

    await Future.wait([
      projProv
          .getProject(widget.projectId)
          .catchError((_) => projProv.selectedProject as dynamic),
      taskProv.fetchTasks(projectId: widget.projectId).catchError((_) {}),
      teamProv.fetchTeams().catchError((_) {}),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthProvider>().user;
    final projProv = context.watch<ProjectProvider>();
    final taskProv = context.watch<TaskProvider>();
    final teamProv = context.watch<TeamProvider>();
    final project = projProv.selectedProject;

    final isAdmin = user?.role == UserRole.admin;
    final isManager = user?.role == UserRole.manager;
    final canManage = isAdmin || isManager;

    if (projProv.isLoading && project == null) {
      return const Scaffold(
        body: AppLoadingIndicator(message: 'Loading project details...'),
      );
    }

    if (projProv.errorMessage != null && project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Project Details')),
        body: AppErrorWidget(
          message: projProv.errorMessage!,
          onRetry: _loadData,
        ),
      );
    }

    if (project == null) {
      return const Scaffold(body: Center(child: Text('Project not found')));
    }

    final team = teamProv.teams
        .where((t) => t.id == project.teamId)
        .firstOrNull;
    final projectTasks = taskProv.tasks
        .where((t) => t.projectId == project.id)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Project',
              onPressed: () async {
                final updated = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => ProjectFormScreen(project: project),
                  ),
                );
                if (updated == true) {
                  _loadData();
                }
              },
            ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete Project',
              onPressed: () async {
                final confirmed = await showConfirmationDialog(
                  context,
                  title: 'Delete Project',
                  message:
                      'Are you sure you want to delete "${project.name}"? All associated tasks will be deleted.',
                  confirmLabel: 'Delete',
                  isDestructive: true,
                );
                if (confirmed == true && context.mounted) {
                  try {
                    await projProv.deleteProject(project.id);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Project deleted successfully'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to delete project: $e')),
                      );
                    }
                  }
                }
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              project.name,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          StatusBadge(status: project.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        project.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Icon(
                            Icons.group,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Team: ',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Expanded(
                            child: Text(
                              team != null ? team.name : project.teamId,
                            ),
                          ),
                        ],
                      ),
                      if (project.startDate.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.date_range,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Timeline: ',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Expanded(
                              child: Text(
                                '${project.startDate} to ${project.endDate}',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text(
                    'Tasks (${projectTasks.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (canManage)
                    FilledButton.icon(
                      onPressed: () async {
                        final created = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) =>
                                TaskFormScreen(defaultProjectId: project.id),
                          ),
                        );
                        if (created == true) {
                          _loadData();
                        }
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Task'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (projectTasks.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'No tasks in this project yet.',
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
                  itemCount: projectTasks.length,
                  itemBuilder: (context, index) {
                    final task = projectTasks[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: task.isOverdue
                              ? Colors.red.shade100
                              : theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            task.isOverdue
                                ? Icons.warning_amber
                                : Icons.assignment_outlined,
                            color: task.isOverdue
                                ? Colors.red
                                : theme.colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          task.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                PriorityBadge(
                                  priority: task.priority,
                                  showIcon: false,
                                ),
                                StatusBadge(
                                  status: task.status,
                                  showIcon: false,
                                ),
                                Text(
                                  task.hasDueDate
                                      ? 'Due: ${task.formattedDueDate}'
                                      : 'No due date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: task.isOverdue
                                        ? Colors.red
                                        : theme.colorScheme.onSurfaceVariant,
                                    fontWeight: task.isOverdue
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TaskDetailScreen(taskId: task.id),
                            ),
                          );
                        },
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
