import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/team_provider.dart';
import '../../widgets/app_error_widget.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/comments_section.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/status_badge.dart';
import 'task_form_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadTaskData();
      }
    });
  }

  Future<void> _loadTaskData() async {
    if (!mounted) return;
    final taskProv = context.read<TaskProvider>();
    final projProv = context.read<ProjectProvider>();
    final teamProv = context.read<TeamProvider>();

    await Future.wait([
      taskProv
          .getTask(widget.taskId)
          .catchError((_) => taskProv.selectedTask as dynamic),
      taskProv.fetchComments(widget.taskId).catchError((_) {}),
      projProv.fetchProjects().catchError((_) {}),
      teamProv.fetchTeams().catchError((_) {}),
      teamProv.fetchEmployees().catchError((_) {}),
    ]);
  }

  Future<void> _updateStatus(TaskStatus newStatus) async {
    final taskProv = context.read<TaskProvider>();
    final authUser = context.read<AuthProvider>().user;
    final isEmployee = authUser?.role == UserRole.employee;

    try {
      await taskProv.updateTask(
        widget.taskId,
        status: newStatus,
        isEmployeeRole: isEmployee,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task status changed to ${newStatus.displayName}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthProvider>().user;
    final taskProv = context.watch<TaskProvider>();
    final projProv = context.watch<ProjectProvider>();
    final teamProv = context.watch<TeamProvider>();
    final task = taskProv.selectedTask;

    final isAdmin = user?.role == UserRole.admin;
    final isManager = user?.role == UserRole.manager;
    final isEmployee = user?.role == UserRole.employee;

    if (taskProv.isLoading && task == null) {
      return const Scaffold(
        body: AppLoadingIndicator(message: 'Loading task details...'),
      );
    }

    if (taskProv.errorMessage != null && task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Task Details')),
        body: AppErrorWidget(
          message: taskProv.errorMessage!,
          onRetry: _loadTaskData,
        ),
      );
    }

    if (task == null) {
      return const Scaffold(body: Center(child: Text('Task not found')));
    }

    final currentEmployee = teamProv.employees
        .where((e) => e.userId == user?.id || e.id == user?.id)
        .firstOrNull;
    final isAssignee =
        (currentEmployee != null && currentEmployee.id == task.assignedTo) ||
        (user?.id == task.assignedTo);

    final canEdit = isAdmin || isManager || (isEmployee && isAssignee);

    final project = projProv.projects
        .where((p) => p.id == task.projectId)
        .firstOrNull;
    final assignedEmployee = teamProv.employees
        .where((e) => e.id == task.assignedTo || e.userId == task.assignedTo)
        .firstOrNull;
    final assigneeName = task.assignedTo.isEmpty
        ? 'Unassigned'
        : ((task.assigneeName != null && task.assigneeName!.isNotEmpty)
              ? task.assigneeName!
              : (assignedEmployee != null
                    ? assignedEmployee.name
                    : (user != null &&
                              (user.id == task.assignedTo ||
                                  currentEmployee?.id == task.assignedTo)
                          ? user.name
                          : 'Unknown User')));

    return Scaffold(
      appBar: AppBar(
        title: Text(task.title),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Task',
              onPressed: () async {
                final updated = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => TaskFormScreen(task: task)),
                );
                if (updated == true) {
                  _loadTaskData();
                }
              },
            ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete Task',
              onPressed: () async {
                final confirmed = await showConfirmationDialog(
                  context,
                  title: 'Delete Task',
                  message:
                      'Are you sure you want to delete "${task.title}"? This action cannot be undone.',
                  confirmLabel: 'Delete',
                  isDestructive: true,
                );
                if (confirmed == true && context.mounted) {
                  try {
                    await taskProv.deleteTask(task.id);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Task deleted successfully'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to delete task: $e')),
                      );
                    }
                  }
                }
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTaskData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Task Summary Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          PriorityBadge(priority: task.priority),
                          StatusBadge(status: task.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        task.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Icon(
                            Icons.folder_outlined,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Project: ',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Expanded(
                            child: Text(
                              project != null ? project.name : task.projectId,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        label: 'Assigned to: $assigneeName',
                        container: true,
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Assigned to: ',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Expanded(
                              child: Text(
                                assigneeName,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            task.isOverdue
                                ? Icons.warning_amber
                                : Icons.calendar_today_outlined,
                            size: 18,
                            color: task.isOverdue
                                ? Colors.red
                                : theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Due Date: ',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 4,
                              children: [
                                Text(
                                  task.hasDueDate
                                      ? task.formattedDueDate
                                      : 'Not set',
                                  style: TextStyle(
                                    color: task.isOverdue ? Colors.red : null,
                                    fontWeight: task.isOverdue
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                if (task.isOverdue)
                                  const Text(
                                    '(OVERDUE)',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Quick Status Transition
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Change Status',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: TaskStatus.values.map((s) {
                          final isCurrent = task.status == s;
                          return ChoiceChip(
                            label: Text(s.displayName),
                            selected: isCurrent,
                            onSelected: (isCurrent || !canEdit)
                                ? null
                                : (selected) {
                                    if (selected) {
                                      _updateStatus(s);
                                    }
                                  },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Comments Section
              CommentsSection(
                taskId: task.id,
                comments: taskProv.comments,
                isLoading: taskProv.isCommentsLoading,
                currentUserId: user?.id ?? '',
                isManagerOrAdmin: isAdmin || isManager,
                onAddComment: (content) =>
                    taskProv.addComment(task.id, content),
                onUpdateComment: (commentId, content) =>
                    taskProv.updateComment(commentId, content),
                onDeleteComment: (commentId) =>
                    taskProv.deleteComment(commentId),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
