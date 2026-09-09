import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/team_provider.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_error_widget.dart';
import '../../widgets/app_loading_indicator.dart';
import 'team_detail_screen.dart';
import 'team_form_screen.dart';

class TeamListScreen extends StatefulWidget {
  const TeamListScreen({super.key});

  @override
  State<TeamListScreen> createState() => _TeamListScreenState();
}

class _TeamListScreenState extends State<TeamListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadTeams();
      }
    });
  }

  Future<void> _loadTeams() async {
    final teamProv = context.read<TeamProvider>();
    await Future.wait([
      teamProv.fetchTeams().catchError((_) {}),
      teamProv.fetchEmployees().catchError((_) {}),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthProvider>().user;
    final teamProv = context.watch<TeamProvider>();
    final isAdmin = user?.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(title: const Text('Teams')),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const TeamFormScreen()),
                );
                if (created == true) {
                  _loadTeams();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('New Team'),
            )
          : null,
      body: Builder(
        builder: (context) {
          if (teamProv.isLoading && teamProv.teams.isEmpty) {
            return const AppLoadingIndicator(message: 'Loading teams...');
          }

          if (teamProv.errorMessage != null && teamProv.teams.isEmpty) {
            return AppErrorWidget(
              message: teamProv.errorMessage!,
              onRetry: _loadTeams,
            );
          }

          if (teamProv.teams.isEmpty) {
            return AppEmptyState(
              icon: Icons.group_off_outlined,
              title: 'No Teams Found',
              message: isAdmin
                  ? 'Get started by creating your first team.'
                  : 'You are not currently assigned to any team.',
              actionLabel: isAdmin ? 'Create Team' : null,
              onAction: isAdmin
                  ? () async {
                      final created = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => const TeamFormScreen(),
                        ),
                      );
                      if (created == true) {
                        _loadTeams();
                      }
                    }
                  : null,
            );
          }

          return RefreshIndicator(
            onRefresh: _loadTeams,
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: teamProv.teams.length,
              itemBuilder: (context, index) {
                final team = teamProv.teams[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(
                        Icons.groups,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      team.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          team.description ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 16,
                              color: theme.colorScheme.secondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${team.memberIds.length} members',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.secondary,
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
                          builder: (_) => TeamDetailScreen(teamId: team.id),
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
    );
  }
}
