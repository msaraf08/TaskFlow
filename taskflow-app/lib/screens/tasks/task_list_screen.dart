import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/task_provider.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_error_widget.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/status_badge.dart';
import 'task_detail_screen.dart';
import 'task_form_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  String? _filterProjectId;
  TaskStatus? _filterStatus;
  TaskPriority? _filterPriority;

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
    final taskProv = context.read<TaskProvider>();
    final projProv = context.read<ProjectProvider>();
    await Future.wait([
      taskProv
          .fetchTasks(
            projectId: _filterProjectId,
            status: _filterStatus,
            priority: _filterPriority,
          )
          .catchError((_) {}),
      projProv.fetchProjects().catchError((_) {}),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthProvider>().user;
    final taskProv = context.watch<TaskProvider>();
    final projProv = context.watch<ProjectProvider>();
    final canCreate =
        user?.role == UserRole.admin || user?.role == UserRole.manager;

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const TaskFormScreen()),
                );
                if (created == true) {
                  _loadData();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('New Task'),
            )
          : null,
      body: Column(
        children: [
          // Filter Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  DropdownButton<TaskStatus?>(
                    value: _filterStatus,
                    hint: const Text('All Statuses'),
                    underline: const SizedBox(),
                    items: [
                      const DropdownMenuItem<TaskStatus?>(
                        value: null,
                        child: Text('All Statuses'),
                      ),
                      ...TaskStatus.values.map(
                        (s) => DropdownMenuItem<TaskStatus?>(
                          value: s,
                          child: Text(s.displayName),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _filterStatus = val;
                      });
                      _loadData();
                    },
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<TaskPriority?>(
                    value: _filterPriority,
                    hint: const Text('All Priorities'),
                    underline: const SizedBox(),
                    items: [
                      const DropdownMenuItem<TaskPriority?>(
                        value: null,
                        child: Text('All Priorities'),
                      ),
                      ...TaskPriority.values.map(
                        (p) => DropdownMenuItem<TaskPriority?>(
                          value: p,
                          child: Text(p.displayName),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _filterPriority = val;
                      });
                      _loadData();
                    },
                  ),
                  const SizedBox(width: 16),
                  if (projProv.projects.isNotEmpty)
                    DropdownButton<String?>(
                      value: _filterProjectId,
                      hint: const Text('All Projects'),
                      underline: const SizedBox(),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Projects'),
                        ),
                        ...projProv.projects.map(
                          (p) => DropdownMenuItem<String?>(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _filterProjectId = val;
                        });
                        _loadData();
                      },
                    ),
                ],
              ),
            ),
          ),

          // Task List
          Expanded(
            child: Builder(
              builder: (context) {
                if (taskProv.isLoading && taskProv.tasks.isEmpty) {
                  return const AppLoadingIndicator(message: 'Loading tasks...');
                }

                if (taskProv.errorMessage != null && taskProv.tasks.isEmpty) {
                  return AppErrorWidget(
                    message: taskProv.errorMessage!,
                    onRetry: _loadData,
                  );
                }

                if (taskProv.tasks.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.task_alt_outlined,
                    title: 'No Tasks Found',
                    message: canCreate
                        ? 'Get started by creating your first task.'
                        : 'No tasks are currently assigned to you.',
                    actionLabel: canCreate ? 'Create Task' : null,
                    onAction: canCreate
                        ? () async {
                            final created = await Navigator.of(context)
                                .push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => const TaskFormScreen(),
                                  ),
                                );
                            if (created == true) {
                              _loadData();
                            }
                          }
                        : null,
                  );
                }

                return RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: taskProv.tasks.length,
                    itemBuilder: (context, index) {
                      final task = taskProv.tasks[index];
                      final project = projProv.projects
                          .where((p) => p.id == task.projectId)
                          .firstOrNull;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
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
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (task.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  task.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 8),
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
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 160,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.folder_outlined,
                                          size: 14,
                                          color: theme.colorScheme.secondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            project != null
                                                ? project.name
                                                : 'Project',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  theme.colorScheme.secondary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (task.hasDueDate)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.calendar_today_outlined,
                                          size: 14,
                                          color: theme.colorScheme.secondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          task.formattedDueDate,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: task.isOverdue
                                                ? Colors.red
                                                : theme.colorScheme.secondary,
                                            fontWeight: task.isOverdue
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    TaskDetailScreen(taskId: task.id),
                              ),
                            );
                          },
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
