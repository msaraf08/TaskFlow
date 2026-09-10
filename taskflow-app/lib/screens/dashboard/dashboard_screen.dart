import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task.dart';
import '../../providers/activity_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/team_provider.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/status_badge.dart';
import '../tasks/task_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const DashboardScreen({super.key, this.onNavigateTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadDashboardData();
      }
    });
  }

  Future<void> _loadDashboardData() async {
    final teamProv = context.read<TeamProvider>();
    final projProv = context.read<ProjectProvider>();
    final taskProv = context.read<TaskProvider>();
    final actProv = context.read<ActivityProvider>();

    await Future.wait([
      teamProv.fetchTeams().catchError((_) {}),
      projProv.fetchProjects().catchError((_) {}),
      taskProv.fetchTasks().catchError((_) {}),
      actProv.fetchActivities(limit: 5).catchError((_) {}),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authUser = context.watch<AuthProvider>().user;
    final teamProv = context.watch<TeamProvider>();
    final projProv = context.watch<ProjectProvider>();
    final taskProv = context.watch<TaskProvider>();
    final actProv = context.watch<ActivityProvider>();

    final isLoading =
        teamProv.isLoading || projProv.isLoading || taskProv.isLoading;

    if (isLoading &&
        teamProv.teams.isEmpty &&
        projProv.projects.isEmpty &&
        taskProv.tasks.isEmpty) {
      return const Scaffold(
        body: AppLoadingIndicator(message: 'Loading dashboard...'),
      );
    }

    final tasks = taskProv.tasks;
    final projects = projProv.projects;
    final teams = teamProv.teams;

    final todoCount = tasks.where((t) => t.status == TaskStatus.todo).length;
    final inProgressCount = tasks
        .where((t) => t.status == TaskStatus.inProgress)
        .length;
    final completedCount = tasks
        .where((t) => t.status == TaskStatus.completed)
        .length;
    final overdueCount = tasks.where((t) => t.isOverdue).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: theme.colorScheme.primary,
                        child: Text(
                          (authUser?.name.isNotEmpty ?? false)
                              ? authUser!.name[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back, ${authUser?.name ?? 'User'}!',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Role: ${authUser?.role.displayName ?? 'Employee'} | ${authUser?.email ?? ''}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Metric Summary Cards
              Text(
                'Overview',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 600;
                  return GridView.count(
                    crossAxisCount: isWide ? 4 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: isWide ? 1.4 : 1.3,
                    children: [
                      _buildMetricCard(
                        context,
                        title: 'Teams',
                        value: '${teams.length}',
                        icon: Icons.group_outlined,
                        color: Colors.blue,
                        onTap: () => widget.onNavigateTab?.call(1),
                      ),
                      _buildMetricCard(
                        context,
                        title: 'Projects',
                        value: '${projects.length}',
                        icon: Icons.folder_outlined,
                        color: Colors.indigo,
                        onTap: () => widget.onNavigateTab?.call(2),
                      ),
                      _buildMetricCard(
                        context,
                        title: 'Total Tasks',
                        value: '${tasks.length}',
                        icon: Icons.task_alt_outlined,
                        color: Colors.teal,
                        onTap: () => widget.onNavigateTab?.call(3),
                      ),
                      _buildMetricCard(
                        context,
                        title: 'Overdue',
                        value: '$overdueCount',
                        icon: Icons.warning_amber_rounded,
                        color: Colors.red,
                        onTap: () => widget.onNavigateTab?.call(3),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Task Status Breakdown
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Task Status Breakdown',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatusItem(
                            context,
                            'To Do',
                            todoCount,
                            Colors.blueGrey,
                          ),
                          _buildStatusItem(
                            context,
                            'In Progress',
                            inProgressCount,
                            Colors.blue,
                          ),
                          _buildStatusItem(
                            context,
                            'Completed',
                            completedCount,
                            Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Recent Tasks
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Tasks',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigateTab?.call(3),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (tasks.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'No tasks assigned or created yet.',
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
                  itemCount: tasks.length > 5 ? 5 : tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          task.hasDueDate
                              ? 'Due: ${task.formattedDueDate}'
                              : 'No due date',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PriorityBadge(
                              priority: task.priority,
                              showIcon: false,
                            ),
                            const SizedBox(width: 8),
                            StatusBadge(status: task.status, showIcon: false),
                          ],
                        ),
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
              const SizedBox(height: 20),

              // Recent Activity Stream
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Activity',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigateTab?.call(4),
                    child: const Text('View Stream'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (actProv.activities.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'No recent activity recorded.',
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
                  itemCount: actProv.activities.length > 5
                      ? 5
                      : actProv.activities.length,
                  itemBuilder: (context, index) {
                    final act = actProv.activities[index];
                    final taskTitles = {
                      for (final t in taskProv.tasks) t.id: t.title,
                    };
                    final description = act.formatDescription(
                      taskTitles: taskTitles,
                    );
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.secondaryContainer,
                          child: Icon(
                            Icons.history,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                        title: Text(
                          description,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(act.formattedDate),
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

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusItem(
    BuildContext context,
    String label,
    int count,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
