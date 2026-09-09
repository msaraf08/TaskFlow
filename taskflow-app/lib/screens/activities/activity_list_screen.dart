import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/activity_provider.dart';
import '../../providers/task_provider.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_error_widget.dart';
import '../../widgets/app_loading_indicator.dart';

class ActivityListScreen extends StatefulWidget {
  const ActivityListScreen({super.key});

  @override
  State<ActivityListScreen> createState() => _ActivityListScreenState();
}

class _ActivityListScreenState extends State<ActivityListScreen> {
  String? _filterEntityType;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadActivities();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final actProv = context.read<ActivityProvider>();
      if (!actProv.isLoadingMore && actProv.hasMore) {
        actProv.loadMore(entityType: _filterEntityType);
      }
    }
  }

  Future<void> _loadActivities() async {
    final actProv = context.read<ActivityProvider>();
    final taskProv = context.read<TaskProvider>();
    await Future.wait([
      actProv.fetchActivities(entityType: _filterEntityType).catchError((_) {}),
      taskProv.fetchTasks().catchError((_) {}),
    ]);
  }

  IconData _getEntityIcon(String entityType) {
    switch (entityType.toLowerCase()) {
      case 'task':
        return Icons.assignment_outlined;
      case 'project':
        return Icons.folder_outlined;
      case 'team':
        return Icons.groups_outlined;
      case 'comment':
        return Icons.chat_bubble_outline;
      default:
        return Icons.history;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actProv = context.watch<ActivityProvider>();
    final taskProv = context.watch<TaskProvider>();

    final Map<String, String> taskTitles = {
      for (final t in taskProv.tasks) t.id: t.title,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Activity Stream')),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _filterEntityType == null,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _filterEntityType = null;
                        });
                        _loadActivities();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Tasks'),
                    selected: _filterEntityType == 'task',
                    onSelected: (selected) {
                      setState(() {
                        _filterEntityType = selected ? 'task' : null;
                      });
                      _loadActivities();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Projects'),
                    selected: _filterEntityType == 'project',
                    onSelected: (selected) {
                      setState(() {
                        _filterEntityType = selected ? 'project' : null;
                      });
                      _loadActivities();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Teams'),
                    selected: _filterEntityType == 'team',
                    onSelected: (selected) {
                      setState(() {
                        _filterEntityType = selected ? 'team' : null;
                      });
                      _loadActivities();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Comments'),
                    selected: _filterEntityType == 'comment',
                    onSelected: (selected) {
                      setState(() {
                        _filterEntityType = selected ? 'comment' : null;
                      });
                      _loadActivities();
                    },
                  ),
                ],
              ),
            ),
          ),

          // Activity List
          Expanded(
            child: Builder(
              builder: (context) {
                if (actProv.isLoading && actProv.activities.isEmpty) {
                  return const AppLoadingIndicator(
                    message: 'Loading activities...',
                  );
                }

                if (actProv.errorMessage != null &&
                    actProv.activities.isEmpty) {
                  return AppErrorWidget(
                    message: actProv.errorMessage!,
                    onRetry: _loadActivities,
                  );
                }

                if (actProv.activities.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.history_toggle_off,
                    title: 'No Activity Found',
                    message:
                        'Activity records will appear here as actions are performed in the system.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: _loadActivities,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16.0),
                    itemCount:
                        actProv.activities.length +
                        (actProv.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == actProv.activities.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final activity = actProv.activities[index];
                      final actorName =
                          (activity.actorName != null &&
                              activity.actorName!.isNotEmpty)
                          ? activity.actorName!
                          : 'Unknown User';
                      final description = activity.formatDescription(
                        taskTitles: taskTitles,
                      );

                      return Semantics(
                        label: '$actorName performed: $description',
                        container: true,
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12.0),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      theme.colorScheme.secondaryContainer,
                                  child: Icon(
                                    _getEntityIcon(activity.entityType),
                                    color:
                                        theme.colorScheme.onSecondaryContainer,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        actorName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        description,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Entity: ${activity.entityType} | Action: ${activity.action}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        activity.formattedDate,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme.secondary,
                                        ),
                                      ),
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
