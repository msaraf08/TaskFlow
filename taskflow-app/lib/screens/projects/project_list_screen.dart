import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/team_provider.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_error_widget.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/status_badge.dart';
import 'project_detail_screen.dart';
import 'project_form_screen.dart';

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  String? _filterTeamId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadProjects();
      }
    });
  }

  Future<void> _loadProjects() async {
    final projProv = context.read<ProjectProvider>();
    final teamProv = context.read<TeamProvider>();
    await Future.wait([
      projProv.fetchProjects(teamId: _filterTeamId).catchError((_) {}),
      teamProv.fetchTeams().catchError((_) {}),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthProvider>().user;
    final projProv = context.watch<ProjectProvider>();
    final teamProv = context.watch<TeamProvider>();
    final canCreate =
        user?.role == UserRole.admin || user?.role == UserRole.manager;

    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const ProjectFormScreen()),
                );
                if (created == true) {
                  _loadProjects();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('New Project'),
            )
          : null,
      body: Column(
        children: [
          // Filter Bar
          if (teamProv.teams.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Team:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String?>(
                      value: _filterTeamId,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Teams'),
                        ),
                        ...teamProv.teams.map(
                          (t) => DropdownMenuItem<String?>(
                            value: t.id,
                            child: Text(t.name),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _filterTeamId = val;
                        });
                        projProv.fetchProjects(teamId: _filterTeamId);
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Project List Content
          Expanded(
            child: Builder(
              builder: (context) {
                if (projProv.isLoading && projProv.projects.isEmpty) {
                  return const AppLoadingIndicator(
                    message: 'Loading projects...',
                  );
                }

                if (projProv.errorMessage != null &&
                    projProv.projects.isEmpty) {
                  return AppErrorWidget(
                    message: projProv.errorMessage!,
                    onRetry: _loadProjects,
                  );
                }

                if (projProv.projects.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.folder_open_outlined,
                    title: 'No Projects Found',
                    message: canCreate
                        ? 'Get started by creating your first project.'
                        : 'No projects available for your team.',
                    actionLabel: canCreate ? 'Create Project' : null,
                    onAction: canCreate
                        ? () async {
                            final created = await Navigator.of(context)
                                .push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => const ProjectFormScreen(),
                                  ),
                                );
                            if (created == true) {
                              _loadProjects();
                            }
                          }
                        : null,
                  );
                }

                return RefreshIndicator(
                  onRefresh: _loadProjects,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: projProv.projects.length,
                    itemBuilder: (context, index) {
                      final project = projProv.projects[index];
                      final team = teamProv.teams
                          .where((t) => t.id == project.teamId)
                          .firstOrNull;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          leading: CircleAvatar(
                            backgroundColor:
                                theme.colorScheme.secondaryContainer,
                            child: Icon(
                              Icons.folder_outlined,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  project.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              StatusBadge(status: project.status),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (project.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  project.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.group_outlined,
                                        size: 14,
                                        color: theme.colorScheme.secondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        team != null ? team.name : 'Team',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (project.startDate.isNotEmpty)
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
                                          project.endDate.isNotEmpty
                                              ? '${project.startDate} - ${project.endDate}'
                                              : project.startDate,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.secondary,
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
                                    ProjectDetailScreen(projectId: project.id),
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
