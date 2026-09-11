import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:taskflow/core/api_client.dart';
import 'package:taskflow/core/secure_storage.dart';
import 'package:taskflow/models/activity.dart';
import 'package:taskflow/models/project.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/models/user.dart';
import 'package:taskflow/providers/activity_provider.dart';
import 'package:taskflow/providers/auth_provider.dart';
import 'package:taskflow/providers/project_provider.dart';
import 'package:taskflow/providers/task_provider.dart';
import 'package:taskflow/providers/team_provider.dart';
import 'package:taskflow/screens/activities/activity_list_screen.dart';
import 'package:taskflow/screens/admin/user_management_screen.dart';
import 'package:taskflow/screens/auth/login_screen.dart';
import 'package:taskflow/screens/auth/register_screen.dart';
import 'package:taskflow/screens/dashboard/dashboard_screen.dart';
import 'package:taskflow/screens/main_navigation_screen.dart';
import 'package:taskflow/screens/projects/project_detail_screen.dart';
import 'package:taskflow/screens/projects/project_list_screen.dart';
import 'package:taskflow/screens/tasks/task_detail_screen.dart';
import 'package:taskflow/screens/tasks/task_form_screen.dart';
import 'package:taskflow/screens/tasks/task_list_screen.dart';
import 'package:taskflow/screens/teams/team_detail_screen.dart';
import 'package:taskflow/screens/teams/team_form_screen.dart';
import 'package:taskflow/widgets/app_empty_state.dart';
import 'package:taskflow/widgets/app_error_widget.dart';
import 'package:taskflow/widgets/confirmation_dialog.dart';
import 'package:taskflow/widgets/priority_badge.dart';
import 'package:taskflow/widgets/status_badge.dart';

void main() {
  group('Widget Tests Suite', () {
    testWidgets(
      'StatusBadge renders correct icon and text for project and task statuses',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  StatusBadge(status: ProjectStatus.active),
                  StatusBadge(status: TaskStatus.inProgress),
                  StatusBadge(status: TaskStatus.completed),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Active'), findsOneWidget);
        expect(find.text('In Progress'), findsOneWidget);
        expect(find.text('Completed'), findsOneWidget);
        expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
        expect(find.byIcon(Icons.autorenew), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      },
    );

    testWidgets('PriorityBadge renders icon and text for all priority levels', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PriorityBadge(priority: TaskPriority.low),
                PriorityBadge(priority: TaskPriority.medium),
                PriorityBadge(priority: TaskPriority.high),
                PriorityBadge(priority: TaskPriority.urgent),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Low'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('Urgent'), findsOneWidget);
    });

    testWidgets('AppEmptyState displays title, message, and executes action', (
      tester,
    ) async {
      bool actionTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppEmptyState(
              icon: Icons.inbox,
              title: 'Empty Inbox',
              message: 'You have no new messages at this time.',
              actionLabel: 'Refresh',
              onAction: () {
                actionTriggered = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Empty Inbox'), findsOneWidget);
      expect(
        find.text('You have no new messages at this time.'),
        findsOneWidget,
      );
      expect(find.text('Refresh'), findsOneWidget);

      await tester.tap(find.text('Refresh'));
      await tester.pump();
      expect(actionTriggered, isTrue);
    });

    testWidgets('AppErrorWidget displays error message and retries on press', (
      tester,
    ) async {
      bool retryTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorWidget(
              message: 'Failed to connect to backend service',
              onRetry: () {
                retryTriggered = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Failed to connect to backend service'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retryTriggered, isTrue);
    });

    testWidgets('ConfirmationDialog shows title and actions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConfirmationDialog(
              title: 'Delete Item',
              content: 'Are you sure you want to delete this item?',
              confirmLabel: 'Delete',
              isDestructive: true,
            ),
          ),
        ),
      );

      expect(find.text('Delete Item'), findsOneWidget);
      expect(
        find.text('Are you sure you want to delete this item?'),
        findsOneWidget,
      );
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets(
      'LoginScreen renders inputs and shows validation errors on empty submit',
      (tester) async {
        final fakeStorage = SecureStorageService();
        final fakeClient = ApiClient(storage: fakeStorage);
        final authProv = AuthProvider(client: fakeClient, storage: fakeStorage);

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<AuthProvider>.value(
              value: authProv,
              child: const LoginScreen(),
            ),
          ),
        );

        expect(find.text('TaskFlow'), findsOneWidget);
        expect(find.text('Sign In'), findsOneWidget);

        // Tap Sign In without filling form
        await tester.tap(find.text('Sign In'));
        await tester.pumpAndSettle();

        expect(find.text('Email is required'), findsOneWidget);
        expect(find.text('Password is required'), findsOneWidget);
      },
    );

    testWidgets(
      'RegisterScreen renders inputs without role selector and shows validation errors on empty submit',
      (tester) async {
        final fakeStorage = SecureStorageService();
        final fakeClient = ApiClient(storage: fakeStorage);
        final authProv = AuthProvider(client: fakeClient, storage: fakeStorage);

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<AuthProvider>.value(
              value: authProv,
              child: const RegisterScreen(),
            ),
          ),
        );

        expect(find.text('Join TaskFlow'), findsOneWidget);
        expect(find.text('Create Account'), findsNWidgets(2));
        expect(find.text('Full Name'), findsOneWidget);
        expect(find.text('Email Address'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.text('Phone Number (Optional)'), findsOneWidget);
        expect(find.text('Department (Optional)'), findsOneWidget);
        // Ensure no Role selector is rendered
        expect(find.text('Role'), findsNothing);
        expect(find.text('Employee'), findsNothing);
        expect(find.text('Manager'), findsNothing);
        expect(find.text('Admin'), findsNothing);

        // Tap Create Account button without filling form
        await tester.ensureVisible(find.widgetWithText(FilledButton, 'Create Account'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
        await tester.pumpAndSettle();

        expect(find.text('Name is required'), findsOneWidget);
        expect(find.text('Email is required'), findsOneWidget);
        expect(find.text('Password is required'), findsOneWidget);
      },
    );

    testWidgets(
      'RegisterScreen submits required-only registration without phone/department/role',
      (tester) async {
        Map<String, dynamic>? capturedBody;
        final mockHttpClient = MockClient((request) async {
          if (request.method == 'POST' && request.url.path == '/auth/register') {
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'message': 'User registered successfully',
                'user': {
                  'id': 'u1',
                  'name': capturedBody!['name'],
                  'email': capturedBody!['email'],
                  'role': 'employee',
                  'status': 'active',
                },
              }),
              201,
            );
          }
          return http.Response(jsonEncode([]), 200);
        });

        final fakeStorage = SecureStorageService();
        final fakeClient = ApiClient(client: mockHttpClient, storage: fakeStorage);
        final authProv = AuthProvider(client: fakeClient, storage: fakeStorage);

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<AuthProvider>.value(
              value: authProv,
              child: const RegisterScreen(),
            ),
          ),
        );

        await tester.enterText(find.byType(TextFormField).at(0), 'Alice Smith');
        await tester.enterText(find.byType(TextFormField).at(1), 'alice@test.com');
        await tester.enterText(find.byType(TextFormField).at(2), 'Password123');

        await tester.ensureVisible(find.widgetWithText(FilledButton, 'Create Account'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
        await tester.pumpAndSettle();

        expect(capturedBody, isNotNull);
        expect(capturedBody!['name'], 'Alice Smith');
        expect(capturedBody!['email'], 'alice@test.com');
        expect(capturedBody!['password'], 'Password123');
        expect(capturedBody!.containsKey('phone'), isFalse);
        expect(capturedBody!.containsKey('department'), isFalse);
        expect(capturedBody!.containsKey('role'), isFalse);
        expect(capturedBody!.containsKey('status'), isFalse);
      },
    );

    testWidgets(
      'RegisterScreen submits optional phone and department when filled',
      (tester) async {
        Map<String, dynamic>? capturedBody;
        final mockHttpClient = MockClient((request) async {
          if (request.method == 'POST' && request.url.path == '/auth/register') {
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'message': 'User registered successfully',
                'user': {
                  'id': 'u2',
                  'name': capturedBody!['name'],
                  'email': capturedBody!['email'],
                  'role': 'employee',
                  'status': 'active',
                },
              }),
              201,
            );
          }
          return http.Response(jsonEncode([]), 200);
        });

        final fakeStorage = SecureStorageService();
        final fakeClient = ApiClient(client: mockHttpClient, storage: fakeStorage);
        final authProv = AuthProvider(client: fakeClient, storage: fakeStorage);

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<AuthProvider>.value(
              value: authProv,
              child: const RegisterScreen(),
            ),
          ),
        );

        await tester.enterText(find.byType(TextFormField).at(0), 'Bob Jones');
        await tester.enterText(find.byType(TextFormField).at(1), 'bob@test.com');
        await tester.enterText(find.byType(TextFormField).at(2), 'Password123');
        await tester.enterText(find.byType(TextFormField).at(3), '+1 555-0199');
        await tester.enterText(find.byType(TextFormField).at(4), 'Engineering');

        await tester.ensureVisible(find.widgetWithText(FilledButton, 'Create Account'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
        await tester.pumpAndSettle();

        expect(capturedBody, isNotNull);
        expect(capturedBody!['name'], 'Bob Jones');
        expect(capturedBody!['email'], 'bob@test.com');
        expect(capturedBody!['password'], 'Password123');
        expect(capturedBody!['phone'], '+1 555-0199');
        expect(capturedBody!['department'], 'Engineering');
        expect(capturedBody!.containsKey('role'), isFalse);
        expect(capturedBody!.containsKey('status'), isFalse);
      },
    );

    testWidgets(
      'DashboardScreen renders user name, role, email, and avatar initial correctly',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({
          'auth_token': 'fake_jwt_token',
        });

        final mockHttpClient = MockClient((request) async {
          if (request.url.path.contains('activities')) {
            return http.Response(
              jsonEncode({'activities': [], 'total': 0, 'skip': 0, 'limit': 5}),
              200,
            );
          }
          return http.Response(jsonEncode([]), 200);
        });
        final fakeStorage = SecureStorageService();
        final fakeClient = ApiClient(
          client: mockHttpClient,
          storage: fakeStorage,
        );
        final authProv = AuthProvider(client: fakeClient, storage: fakeStorage);
        final teamProv = TeamProvider(apiClient: fakeClient);
        final projProv = ProjectProvider(apiClient: fakeClient);
        final taskProv = TaskProvider(apiClient: fakeClient);
        final actProv = ActivityProvider(apiClient: fakeClient);

        // Simulate logged in user
        final testUser = User(
          id: '65f1a2b3c4d5e6f7a8b9c0d1',
          name: 'Main Manager',
          email: 'manager@example.com',
          role: UserRole.manager,
          status: 'active',
        );
        authProv.setUserForTesting(testUser);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiProvider(
              providers: [
                ChangeNotifierProvider<AuthProvider>.value(value: authProv),
                ChangeNotifierProvider<TeamProvider>.value(value: teamProv),
                ChangeNotifierProvider<ProjectProvider>.value(value: projProv),
                ChangeNotifierProvider<TaskProvider>.value(value: taskProv),
                ChangeNotifierProvider<ActivityProvider>.value(value: actProv),
              ],
              child: const DashboardScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Dashboard'), findsOneWidget);
        expect(find.text('Welcome back, Main Manager!'), findsOneWidget);
        expect(
          find.text('Role: Manager | manager@example.com'),
          findsOneWidget,
        );
        expect(find.text('M'), findsOneWidget);
      },
    );

    testWidgets(
      'TeamFormScreen only permits admin or manager roles as Team Manager, excluding employee-role users',
      (tester) async {
        final fakeStorage = SecureStorageService();
        final mockHttpClient = MockClient((request) async {
          if (request.url.path == '/employees') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'emp_admin_1',
                  'name': 'Raj Admin',
                  'email': 'raj@test.com',
                  'role': 'admin',
                  'status': 'active',
                },
                {
                  'id': 'emp_mgr_1',
                  'name': 'Amit Manager',
                  'email': 'amit@taskflow.com',
                  'role': 'manager',
                  'status': 'active',
                },
                {
                  'id': 'emp_emp_1',
                  'name': 'Neha Employee',
                  'email': 'neha@taskflow.com',
                  'role': 'employee',
                  'status': 'active',
                },
              ]),
              200,
            );
          }
          return http.Response(jsonEncode([]), 200);
        });

        final fakeClient = ApiClient(
          client: mockHttpClient,
          storage: fakeStorage,
        );
        final teamProv = TeamProvider(apiClient: fakeClient);
        await teamProv.fetchEmployees();

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<TeamProvider>.value(
              value: teamProv,
              child: const TeamFormScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check Team Name and Description fields
        expect(find.text('Team Name'), findsOneWidget);
        expect(find.text('Description'), findsOneWidget);
        expect(find.text('Team Manager'), findsOneWidget);

        // All employees should be in the initial team members list
        expect(find.text('Neha Employee'), findsOneWidget);
        expect(find.text('Raj Admin'), findsOneWidget);
        expect(find.text('Amit Manager'), findsOneWidget);

        // Open Team Manager dropdown
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();

        // Eligible managers (admin & manager) must appear in dropdown
        expect(find.text('Raj Admin (ADMIN - raj@test.com)'), findsWidgets);
        expect(
          find.text('Amit Manager (MANAGER - amit@taskflow.com)'),
          findsWidgets,
        );

        // Employee-role user Neha must NOT appear in Team Manager dropdown options
        expect(
          find.text('Neha Employee (EMPLOYEE - neha@taskflow.com)'),
          findsNothing,
        );
      },
    );

    test(
      'TeamProvider.createTeam does not send member_ids in POST /teams and adds members sequentially',
      () async {
        final List<Map<String, dynamic>> requestsMade = [];

        final mockHttpClient = MockClient((request) async {
          final body = request.body.isNotEmpty
              ? jsonDecode(request.body) as Map<String, dynamic>
              : <String, dynamic>{};
          requestsMade.add({
            'method': request.method,
            'path': request.url.path,
            'body': body,
          });

          if (request.method == 'POST' && request.url.path == '/teams') {
            return http.Response(
              jsonEncode({
                'id': 'team_123',
                'name': body['name'],
                'description': body['description'],
                'manager_id': body['manager_id'],
                'member_ids': [],
              }),
              201,
            );
          }

          if (request.method == 'POST' &&
              request.url.path == '/teams/team_123/members') {
            return http.Response(
              jsonEncode({
                'id': 'team_123',
                'name': 'Engineering',
                'description': 'Core dev team',
                'manager_id': 'emp_admin_1',
                'member_ids': [body['employee_id']],
              }),
              200,
            );
          }

          return http.Response(jsonEncode([]), 200);
        });

        final fakeStorage = SecureStorageService();
        final fakeClient = ApiClient(
          client: mockHttpClient,
          storage: fakeStorage,
        );
        final teamProv = TeamProvider(apiClient: fakeClient);

        final createdTeam = await teamProv.createTeam(
          name: 'Engineering',
          description: 'Core dev team',
          managerId: 'emp_admin_1',
          memberIds: ['emp_emp_1'],
        );

        // Verify team was created and member was assigned
        expect(createdTeam.id, 'team_123');
        expect(createdTeam.memberIds, contains('emp_emp_1'));

        // 1. Verify first request was POST /teams and did NOT contain member_ids
        expect(requestsMade[0]['method'], 'POST');
        expect(requestsMade[0]['path'], '/teams');
        expect(requestsMade[0]['body']['name'], 'Engineering');
        expect(requestsMade[0]['body']['manager_id'], 'emp_admin_1');
        expect(requestsMade[0]['body'].containsKey('member_ids'), isFalse);

        // 2. Verify second request was POST /teams/team_123/members
        expect(requestsMade[1]['method'], 'POST');
        expect(requestsMade[1]['path'], '/teams/team_123/members');
        expect(requestsMade[1]['body'], {'employee_id': 'emp_emp_1'});
      },
    );

    test('ProjectProvider.getProject sends GET /projects/{id}', () async {
      String? requestedPath;
      final mockHttpClient = MockClient((request) async {
        requestedPath = request.url.path;
        return http.Response(
          jsonEncode({
            'id': 'proj_999',
            'name': 'Test Project',
            'description': 'Description',
            'team_id': 'team_1',
            'status': 'active',
            'created_at': '2026-01-01T00:00:00.000Z',
          }),
          200,
        );
      });

      final fakeStorage = SecureStorageService();
      final fakeClient = ApiClient(
        client: mockHttpClient,
        storage: fakeStorage,
      );
      final projProv = ProjectProvider(apiClient: fakeClient);

      final project = await projProv.getProject('proj_999');
      expect(project.id, 'proj_999');
      expect(requestedPath, '/projects/proj_999');
    });

    testWidgets(
      'ProjectDetailScreen renders project details and tasks correctly',
      (tester) async {
        final mockHttpClient = MockClient((request) async {
          if (request.url.path == '/projects/proj_999') {
            return http.Response(
              jsonEncode({
                'id': 'proj_999',
                'name': 'TaskFlow Mobile App',
                'description': 'Mobile Flutter App development',
                'team_id': 'team_1',
                'status': 'active',
                'start_date': '2026-01-01',
                'end_date': '2026-06-30',
                'created_at': '2026-01-01T00:00:00.000Z',
              }),
              200,
            );
          }
          if (request.url.path == '/tasks') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'task_1',
                  'title': 'Implement Auth Screen',
                  'description': 'Flutter UI for Auth',
                  'project_id': 'proj_999',
                  'assigned_to': 'emp_1',
                  'priority': 'high',
                  'status': 'in_progress',
                  'due_date': '2026-02-01',
                  'created_at': '2026-01-01T00:00:00.000Z',
                },
              ]),
              200,
            );
          }
          if (request.url.path == '/teams') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'team_1',
                  'name': 'Core Engineering',
                  'description': 'Dev Team',
                  'manager_id': 'emp_mgr_1',
                  'member_ids': ['emp_1'],
                },
              ]),
              200,
            );
          }
          return http.Response(jsonEncode([]), 200);
        });

        final fakeStorage = SecureStorageService();
        final fakeClient = ApiClient(
          client: mockHttpClient,
          storage: fakeStorage,
        );
        final authProv = AuthProvider(
          apiClient: fakeClient,
          storage: fakeStorage,
        );
        final projProv = ProjectProvider(apiClient: fakeClient);
        final taskProv = TaskProvider(apiClient: fakeClient);
        final teamProv = TeamProvider(apiClient: fakeClient);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authProv),
              ChangeNotifierProvider.value(value: projProv),
              ChangeNotifierProvider.value(value: taskProv),
              ChangeNotifierProvider.value(value: teamProv),
            ],
            child: const MaterialApp(
              home: ProjectDetailScreen(projectId: 'proj_999'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('TaskFlow Mobile App'), findsWidgets);
        expect(find.text('Mobile Flutter App development'), findsOneWidget);
        expect(find.text('Core Engineering'), findsOneWidget);
        expect(find.text('2026-01-01 to 2026-06-30'), findsOneWidget);
        expect(find.text('Tasks (1)'), findsOneWidget);
        expect(find.text('Implement Auth Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'TaskFormScreen renders Assigned To dropdown with employee name, role, and email',
      (tester) async {
        final mockHttpClient = MockClient((request) async {
          if (request.url.path == '/employees') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'emp_neha_1',
                  'user_id': 'user_neha_1',
                  'name': 'Neha',
                  'email': 'neha@flow.com',
                  'role': 'employee',
                  'department': 'Engineering',
                  'status': 'active',
                },
                {
                  'id': 'emp_amit_2',
                  'user_id': 'user_amit_2',
                  'name': 'Amit Sharma',
                  'email': 'amit@taskflow.com',
                  'role': 'manager',
                  'department': 'Engineering',
                  'status': 'active',
                },
                {
                  'id': 'emp_raj_3',
                  'user_id': 'user_raj_3',
                  'name': 'Raj',
                  'email': 'raj@test.com',
                  'role': 'admin',
                  'department': 'Management',
                  'status': 'active',
                },
              ]),
              200,
            );
          }
          if (request.url.path == '/projects') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'proj_1',
                  'name': 'TaskFlow Web',
                  'description': 'Web Application',
                  'team_id': 'team_1',
                  'status': 'active',
                },
              ]),
              200,
            );
          }
          return http.Response(jsonEncode([]), 200);
        });

        final fakeStorage = SecureStorageService();
        final fakeClient = ApiClient(
          client: mockHttpClient,
          storage: fakeStorage,
        );
        final authProv = AuthProvider(
          apiClient: fakeClient,
          storage: fakeStorage,
        );
        final projProv = ProjectProvider(apiClient: fakeClient);
        final taskProv = TaskProvider(apiClient: fakeClient);
        final teamProv = TeamProvider(apiClient: fakeClient);

        // Preload projects and employees
        await projProv.fetchProjects();
        await teamProv.fetchEmployees();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authProv),
              ChangeNotifierProvider.value(value: projProv),
              ChangeNotifierProvider.value(value: taskProv),
              ChangeNotifierProvider.value(value: teamProv),
            ],
            child: const MaterialApp(home: TaskFormScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // Initial selected value rendered in the dropdown
        expect(find.text('Neha (EMPLOYEE - neha@flow.com)'), findsOneWidget);

        // Open the Assigned To dropdown
        await tester.tap(find.text('Neha (EMPLOYEE - neha@flow.com)'));
        await tester.pumpAndSettle();

        // Verify all employee options are rendered with the required format
        expect(find.text('Neha (EMPLOYEE - neha@flow.com)'), findsWidgets);
        expect(
          find.text('Amit Sharma (MANAGER - amit@taskflow.com)'),
          findsOneWidget,
        );
        expect(find.text('Raj (ADMIN - raj@test.com)'), findsOneWidget);
      },
    );

    testWidgets(
      'ActivityListScreen displays Entity, Action, and resolved Task title',
      (tester) async {
        final mockHttpClient = MockClient((request) async {
          if (request.url.path == '/activities') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'act_1',
                  'actor_user_id': 'user_amit_1',
                  'actor_name': 'Amit Sharma',
                  'action': 'task_priority_changed',
                  'entity_type': 'task',
                  'entity_id': 'task_auth_123',
                  'task_id': 'task_auth_123',
                  'metadata': {'old_value': 'high', 'new_value': 'low'},
                  'created_at': '2026-09-07T10:30:00Z',
                },
                {
                  'id': 'act_2',
                  'actor_user_id': 'user_amit_1',
                  'actor_name': 'Amit Sharma',
                  'action': 'task_status_changed',
                  'entity_type': 'task',
                  'entity_id': 'task_auth_123',
                  'task_id': 'task_auth_123',
                  'metadata': {
                    'title': 'Implement User Authentication',
                    'old_value': 'todo',
                    'new_value': 'in_progress',
                  },
                  'created_at': '2026-09-07T11:00:00Z',
                },
              ]),
              200,
            );
          }
          if (request.url.path == '/tasks') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'task_auth_123',
                  'title': 'Implement User Authentication',
                  'description': 'Auth Flow',
                  'project_id': 'proj_1',
                  'assigned_to': 'emp_1',
                  'priority': 'low',
                  'status': 'in_progress',
                  'created_at': '2026-09-01T00:00:00Z',
                },
              ]),
              200,
            );
          }
          return http.Response(jsonEncode([]), 200);
        });

        final fakeStorage = SecureStorageService();
        final fakeClient = ApiClient(
          client: mockHttpClient,
          storage: fakeStorage,
        );
        final authProv = AuthProvider(
          apiClient: fakeClient,
          storage: fakeStorage,
        );
        final actProv = ActivityProvider(apiClient: fakeClient);
        final taskProv = TaskProvider(apiClient: fakeClient);
        final projProv = ProjectProvider(apiClient: fakeClient);
        final teamProv = TeamProvider(apiClient: fakeClient);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authProv),
              ChangeNotifierProvider.value(value: actProv),
              ChangeNotifierProvider.value(value: taskProv),
              ChangeNotifierProvider.value(value: projProv),
              ChangeNotifierProvider.value(value: teamProv),
            ],
            child: const MaterialApp(home: ActivityListScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // Verify Actor Name is rendered in the header
        expect(find.text('Amit Sharma'), findsNWidgets(2));

        // Verify Entity & Action labels are populated
        expect(
          find.text('Entity: task | Action: task_priority_changed'),
          findsOneWidget,
        );
        expect(
          find.text('Entity: task | Action: task_status_changed'),
          findsOneWidget,
        );

        // Verify resolved Task titles and formatted values with actor names
        expect(
          find.text(
            'Amit Sharma changed task "Implement User Authentication" priority from High to Low',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Amit Sharma changed task "Implement User Authentication" status from To Do to In Progress',
          ),
          findsOneWidget,
        );

        // Verify accessibility Semantics
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.label ==
                    'Amit Sharma changed task "Implement User Authentication" priority from High to Low',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TaskDetailScreen RBAC: Employee sees Edit button ONLY when assigned to them; Manager and Admin always see Edit button',
      (tester) async {
        final mockHttpClient = MockClient((request) async {
          if (request.url.path == '/tasks/task_auth_123') {
            return http.Response(
              jsonEncode({
                'id': 'task_auth_123',
                'title': 'Implement User Authentication',
                'description': 'Auth flow description',
                'project_id': 'proj_1',
                'assigned_to':
                    'emp_amit_2', // Initially assigned to Amit Sharma (Manager)
                'priority': 'high',
                'status': 'todo',
                'due_date': '2026-10-01',
                'created_by': 'emp_amit_2',
              }),
              200,
            );
          }
          if (request.url.path == '/employees') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'emp_neha_1',
                  'user_id': 'user_neha_1',
                  'name': 'Neha',
                  'email': 'neha@flow.com',
                  'role': 'employee',
                  'department': 'Engineering',
                  'status': 'active',
                },
                {
                  'id': 'emp_amit_2',
                  'user_id': 'user_amit_2',
                  'name': 'Amit Sharma',
                  'email': 'amit@taskflow.com',
                  'role': 'manager',
                  'department': 'Engineering',
                  'status': 'active',
                },
                {
                  'id': 'emp_raj_3',
                  'user_id': 'user_raj_3',
                  'name': 'Raj',
                  'email': 'raj@test.com',
                  'role': 'admin',
                  'department': 'Management',
                  'status': 'active',
                },
              ]),
              200,
            );
          }
          if (request.url.path == '/projects') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'proj_1',
                  'name': 'TaskFlow Web',
                  'description': 'Web Application',
                  'team_id': 'team_1',
                  'status': 'active',
                },
              ]),
              200,
            );
          }
          if (request.url.path.contains('/comments')) {
            return http.Response(jsonEncode([]), 200);
          }
          return http.Response(jsonEncode({}), 200);
        });

        final fakeStorage = SecureStorageService();
        final fakeClient = ApiClient(
          client: mockHttpClient,
          storage: fakeStorage,
        );
        final authProv = AuthProvider(
          apiClient: fakeClient,
          storage: fakeStorage,
        );
        final taskProv = TaskProvider(apiClient: fakeClient);
        final projProv = ProjectProvider(apiClient: fakeClient);
        final teamProv = TeamProvider(apiClient: fakeClient);

        // Preload data
        await taskProv.getTask('task_auth_123');
        await teamProv.fetchEmployees();
        await projProv.fetchProjects();

        // 1. Employee + task assigned to another employee/manager -> Edit button HIDDEN
        authProv.setUserForTesting(
          const User(
            id: 'user_neha_1',
            name: 'Neha',
            email: 'neha@flow.com',
            role: UserRole.employee,
          ),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authProv),
              ChangeNotifierProvider.value(value: taskProv),
              ChangeNotifierProvider.value(value: projProv),
              ChangeNotifierProvider.value(value: teamProv),
            ],
            child: MaterialApp(home: TaskDetailScreen(taskId: 'task_auth_123')),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.edit_outlined), findsNothing);

        // 2. Employee + assigned task -> Edit button VISIBLE
        taskProv.setSelectedTaskForTesting(
          taskProv.selectedTask!.copyWith(assignedTo: 'emp_neha_1'),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

        // 3. Manager -> Edit button VISIBLE even when assigned to employee
        authProv.setUserForTesting(
          const User(
            id: 'user_amit_2',
            name: 'Amit Sharma',
            email: 'amit@taskflow.com',
            role: UserRole.manager,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

        // 4. Admin -> Edit button VISIBLE
        authProv.setUserForTesting(
          const User(
            id: 'user_raj_3',
            name: 'Raj',
            email: 'raj@test.com',
            role: UserRole.admin,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'TaskDetailScreen resolves assignee name and comment author names with accessibility semantics',
      (tester) async {
        final mockHttpClient = MockClient((request) async {
          if (request.url.path == '/tasks/task_auth_123') {
            return http.Response(
              jsonEncode({
                'id': 'task_auth_123',
                'title': 'Implement User Authentication',
                'description': 'Auth flow description',
                'project_id': 'proj_1',
                'assigned_to': 'emp_amit_2',
                'priority': 'high',
                'status': 'todo',
                'due_date': '2026-10-01',
                'created_by': 'emp_raj_3',
              }),
              200,
            );
          }
          if (request.url.path == '/employees') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'emp_neha_1',
                  'user_id': 'user_neha_1',
                  'name': 'Neha',
                  'email': 'neha@flow.com',
                  'role': 'employee',
                  'department': 'Engineering',
                  'status': 'active',
                },
                {
                  'id': 'emp_amit_2',
                  'user_id': 'user_amit_2',
                  'name': 'Amit Sharma',
                  'email': 'amit@taskflow.com',
                  'role': 'manager',
                  'department': 'Engineering',
                  'status': 'active',
                },
                {
                  'id': 'emp_raj_3',
                  'user_id': 'user_raj_3',
                  'name': 'Raj',
                  'email': 'raj@test.com',
                  'role': 'admin',
                  'department': 'Management',
                  'status': 'active',
                },
              ]),
              200,
            );
          }
          if (request.url.path == '/projects') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'proj_1',
                  'name': 'TaskFlow Web',
                  'description': 'Web Application',
                  'team_id': 'team_1',
                  'status': 'active',
                },
              ]),
              200,
            );
          }
          if (request.url.path.contains('/comments')) {
            return http.Response(
              jsonEncode([
                {
                  'id': 'c1',
                  'task_id': 'task_auth_123',
                  'user_id': 'user_neha_1',
                  'content': 'I am looking into this.',
                  'created_at': '2026-09-08T10:00:00Z',
                  'updated_at': '2026-09-08T10:00:00Z',
                },
                {
                  'id': 'c2',
                  'task_id': 'task_auth_123',
                  'user_id': 'user_amit_2',
                  'content': 'Please verify token expiry.',
                  'created_at': '2026-09-08T10:30:00Z',
                  'updated_at': '2026-09-08T10:30:00Z',
                },
              ]),
              200,
            );
          }
          return http.Response(jsonEncode({}), 200);
        });

        final fakeStorage = SecureStorageService();
        final fakeClient = ApiClient(
          client: mockHttpClient,
          storage: fakeStorage,
        );
        final authProv = AuthProvider(
          apiClient: fakeClient,
          storage: fakeStorage,
        );
        final taskProv = TaskProvider(apiClient: fakeClient);
        final projProv = ProjectProvider(apiClient: fakeClient);
        final teamProv = TeamProvider(apiClient: fakeClient);

        authProv.setUserForTesting(
          const User(
            id: 'user_neha_1',
            name: 'Neha',
            email: 'neha@flow.com',
            role: UserRole.employee,
          ),
        );

        await taskProv.getTask('task_auth_123');
        await taskProv.fetchComments('task_auth_123');
        await teamProv.fetchEmployees();
        await projProv.fetchProjects();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authProv),
              ChangeNotifierProvider.value(value: taskProv),
              ChangeNotifierProvider.value(value: projProv),
              ChangeNotifierProvider.value(value: teamProv),
            ],
            child: const MaterialApp(
              home: TaskDetailScreen(taskId: 'task_auth_123'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // 1. Verify Assigned to displays resolved employee name "Amit Sharma"
        expect(find.text('Assigned to: '), findsOneWidget);
        expect(find.text('Amit Sharma'), findsWidgets);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.label == 'Assigned to: Amit Sharma',
          ),
          findsOneWidget,
        );

        // 2. Verify Comments section author names
        expect(find.text('You'), findsOneWidget); // Neha's own comment
        expect(find.text('Amit Sharma'), findsWidgets); // Amit's comment author

        // 3. Verify Comment contents
        expect(find.text('I am looking into this.'), findsOneWidget);
        expect(find.text('Please verify token expiry.'), findsOneWidget);
      },
    );

    testWidgets(
      'TaskDetailScreen handles fallback cleanly when assigned employee cannot be resolved',
      (tester) async {
        final mockHttpClient = MockClient((request) async {
          if (request.url.path == '/tasks/task_unresolved_1') {
            return http.Response(
              jsonEncode({
                'id': 'task_unresolved_1',
                'title': 'Orphaned Task',
                'description': 'Task with unknown assignee',
                'project_id': 'proj_1',
                'assigned_to':
                    '6a9e1e102a53967f3d6c9999', // Unknown raw ObjectId
                'priority': 'low',
                'status': 'todo',
                'due_date': '2026-10-01',
                'created_by': 'emp_raj_3',
              }),
              200,
            );
          }
          if (request.url.path == '/employees') {
            return http.Response(jsonEncode([]), 200);
          }
          if (request.url.path == '/projects') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'proj_1',
                  'name': 'TaskFlow Web',
                  'description': 'Web Application',
                  'team_id': 'team_1',
                  'status': 'active',
                },
              ]),
              200,
            );
          }
          if (request.url.path.contains('/comments')) {
            return http.Response(jsonEncode([]), 200);
          }
          return http.Response(jsonEncode({}), 200);
        });

        final fakeStorage = SecureStorageService();
        final fakeClient = ApiClient(
          client: mockHttpClient,
          storage: fakeStorage,
        );
        final authProv = AuthProvider(
          apiClient: fakeClient,
          storage: fakeStorage,
        );
        final taskProv = TaskProvider(apiClient: fakeClient);
        final projProv = ProjectProvider(apiClient: fakeClient);
        final teamProv = TeamProvider(apiClient: fakeClient);

        authProv.setUserForTesting(
          const User(
            id: 'user_neha_1',
            name: 'Neha',
            email: 'neha@flow.com',
            role: UserRole.employee,
          ),
        );

        await taskProv.getTask('task_unresolved_1');
        await projProv.fetchProjects();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authProv),
              ChangeNotifierProvider.value(value: taskProv),
              ChangeNotifierProvider.value(value: projProv),
              ChangeNotifierProvider.value(value: teamProv),
            ],
            child: const MaterialApp(
              home: TaskDetailScreen(taskId: 'task_unresolved_1'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Raw hex ObjectId should not be displayed; fallback 'Unknown User' is used
        expect(find.text('6a9e1e102a53967f3d6c9999'), findsNothing);
        expect(find.text('Unknown User'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.label == 'Assigned to: Unknown User',
          ),
          findsOneWidget,
        );

        // Empty assigned_to displays 'Unassigned'
        taskProv.setSelectedTaskForTesting(
          taskProv.selectedTask!.copyWith(assignedTo: '', assigneeName: null),
        );
        await tester.pumpAndSettle();
        expect(find.text('Unassigned'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.label == 'Assigned to: Unassigned',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Responsive Layout on narrow mobile viewport (360x640) - TaskDetailScreen',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockHttpClient = MockClient((request) async {
          if (request.url.path == '/tasks/task_101') {
            return http.Response(
              jsonEncode({
                'id': 'task_101',
                'title': 'Implement Comprehensive Feature Title',
                'description': 'Description text here',
                'project_id': 'proj_101',
                'assigned_to': 'emp_amit_2',
                'priority': 'urgent',
                'status': 'in_progress',
                'due_date': '2026-12-31',
                'created_by': 'emp_raj_3',
              }),
              200,
            );
          }
          if (request.url.path == '/employees') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'emp_amit_2',
                  'user_id': 'user_amit_2',
                  'name': 'Amit Sharma Principal Manager',
                  'email': 'amit.sharma.manager@taskfloworganization.com',
                  'role': 'manager',
                  'department': 'Core Engineering Platform',
                  'status': 'active',
                },
              ]),
              200,
            );
          }
          if (request.url.path == '/projects') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'proj_101',
                  'name': 'Enterprise Architecture Redesign 2026',
                  'description': 'Complete overhaul of backend and frontend',
                  'team_id': 'team_101',
                  'status': 'active',
                },
              ]),
              200,
            );
          }
          if (request.url.path.contains('/comments')) {
            return http.Response(jsonEncode([]), 200);
          }
          return http.Response(jsonEncode({}), 200);
        });

        final fakeStorage = SecureStorageService();
        final fakeClient = ApiClient(
          client: mockHttpClient,
          storage: fakeStorage,
        );
        final authProv = AuthProvider(
          apiClient: fakeClient,
          storage: fakeStorage,
        );
        final taskProv = TaskProvider(apiClient: fakeClient);
        final projProv = ProjectProvider(apiClient: fakeClient);
        final teamProv = TeamProvider(apiClient: fakeClient);

        authProv.setUserForTesting(
          const User(
            id: 'user_amit_2',
            name: 'Amit Sharma',
            email: 'amit@taskflow.com',
            role: UserRole.manager,
          ),
        );

        await taskProv.getTask('task_101');
        await teamProv.fetchEmployees();
        await projProv.fetchProjects();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authProv),
              ChangeNotifierProvider.value(value: taskProv),
              ChangeNotifierProvider.value(value: projProv),
              ChangeNotifierProvider.value(value: teamProv),
            ],
            child: const MaterialApp(
              home: TaskDetailScreen(taskId: 'task_101'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('Implement Comprehensive Feature Title'),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Responsive Layout on narrow mobile viewport (360x640) - TaskListScreen',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockHttpClient = MockClient((request) async {
          if (request.url.path == '/tasks') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'task_101',
                  'title': 'Implement Comprehensive Feature Title',
                  'description': 'Description text here',
                  'project_id': 'proj_101',
                  'assigned_to': 'emp_amit_2',
                  'priority': 'urgent',
                  'status': 'in_progress',
                  'due_date': '2026-12-31',
                  'created_by': 'emp_raj_3',
                },
              ]),
              200,
            );
          }
          if (request.url.path == '/projects') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'proj_101',
                  'name': 'Enterprise Architecture Redesign 2026',
                  'description': 'Complete overhaul of backend and frontend',
                  'team_id': 'team_101',
                  'status': 'active',
                },
              ]),
              200,
            );
          }
          return http.Response(jsonEncode([]), 200);
        });

        final fakeStorage = SecureStorageService();
        final fakeClient = ApiClient(
          client: mockHttpClient,
          storage: fakeStorage,
        );
        final authProv = AuthProvider(
          apiClient: fakeClient,
          storage: fakeStorage,
        );
        final taskProv = TaskProvider(apiClient: fakeClient);
        final projProv = ProjectProvider(apiClient: fakeClient);

        authProv.setUserForTesting(
          const User(
            id: 'user_amit_2',
            name: 'Amit Sharma',
            email: 'amit@taskflow.com',
            role: UserRole.manager,
          ),
        );

        await taskProv.fetchTasks();
        await projProv.fetchProjects();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authProv),
              ChangeNotifierProvider.value(value: taskProv),
              ChangeNotifierProvider.value(value: projProv),
            ],
            child: const MaterialApp(home: TaskListScreen()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Responsive Layout on narrow mobile viewport (360x640) - ProjectDetailScreen and TeamDetailScreen',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockHttpClient = MockClient((request) async {
          if (request.url.path == '/projects/proj_101') {
            return http.Response(
              jsonEncode({
                'id': 'proj_101',
                'name': 'Enterprise Architecture Redesign 2026',
                'description': 'Complete overhaul of backend and frontend',
                'team_id': 'team_101',
                'status': 'active',
                'start_date': '2026-01-01',
                'end_date': '2026-12-31',
              }),
              200,
            );
          }
          if (request.url.path == '/tasks') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'task_101',
                  'title': 'Implement Comprehensive Feature Title',
                  'description': 'Description text here',
                  'project_id': 'proj_101',
                  'assigned_to': 'emp_amit_2',
                  'priority': 'urgent',
                  'status': 'in_progress',
                  'due_date': '2026-12-31',
                  'created_by': 'emp_raj_3',
                },
              ]),
              200,
            );
          }
          if (request.url.path == '/teams/team_101') {
            return http.Response(
              jsonEncode({
                'id': 'team_101',
                'name': 'Full Stack Core Engineering Team',
                'description': 'Responsible for end-to-end architecture',
                'manager_id': 'emp_amit_2',
                'member_ids': ['emp_neha_1'],
              }),
              200,
            );
          }
          if (request.url.path == '/employees') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'emp_neha_1',
                  'user_id': 'user_neha_1',
                  'name': 'Neha LongNameEmployee',
                  'email': 'neha.verylongemailaddress@taskfloworganization.com',
                  'role': 'employee',
                  'department': 'Core Engineering Platform',
                  'status': 'active',
                },
                {
                  'id': 'emp_amit_2',
                  'user_id': 'user_amit_2',
                  'name': 'Amit Sharma Principal Manager',
                  'email': 'amit.sharma.manager@taskfloworganization.com',
                  'role': 'manager',
                  'department': 'Core Engineering Platform',
                  'status': 'active',
                },
              ]),
              200,
            );
          }
          return http.Response(jsonEncode({}), 200);
        });

        final fakeStorage = SecureStorageService();
        final fakeClient = ApiClient(
          client: mockHttpClient,
          storage: fakeStorage,
        );
        final authProv = AuthProvider(
          apiClient: fakeClient,
          storage: fakeStorage,
        );
        final taskProv = TaskProvider(apiClient: fakeClient);
        final projProv = ProjectProvider(apiClient: fakeClient);
        final teamProv = TeamProvider(apiClient: fakeClient);

        authProv.setUserForTesting(
          const User(
            id: 'user_amit_2',
            name: 'Amit Sharma',
            email: 'amit@taskflow.com',
            role: UserRole.manager,
          ),
        );

        await projProv.getProject('proj_101');
        await taskProv.fetchTasks(projectId: 'proj_101');
        await teamProv.fetchEmployees();
        await teamProv.fetchTeams();

        // ProjectDetailScreen test
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authProv),
              ChangeNotifierProvider.value(value: taskProv),
              ChangeNotifierProvider.value(value: projProv),
              ChangeNotifierProvider.value(value: teamProv),
            ],
            child: const MaterialApp(
              home: ProjectDetailScreen(projectId: 'proj_101'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);

        // ProjectListScreen test
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authProv),
              ChangeNotifierProvider.value(value: taskProv),
              ChangeNotifierProvider.value(value: projProv),
              ChangeNotifierProvider.value(value: teamProv),
            ],
            child: const MaterialApp(home: ProjectListScreen()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);

        // TeamDetailScreen test
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authProv),
              ChangeNotifierProvider.value(value: taskProv),
              ChangeNotifierProvider.value(value: projProv),
              ChangeNotifierProvider.value(value: teamProv),
            ],
            child: const MaterialApp(
              home: TeamDetailScreen(teamId: 'team_101'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      },
    );

    test('Activity model formats user_role_changed description correctly', () {
      final act = Activity(
        id: 'act_role_1',
        actorUserId: 'admin_user_1',
        actorName: 'Admin User',
        action: 'user_role_changed',
        entityType: 'employee',
        entityId: 'emp_2',
        metadata: {
          'name': 'Employee Two',
          'old_value': 'employee',
          'new_value': 'manager',
        },
        createdAt: DateTime.parse('2026-09-09T10:00:00Z'),
      );

      expect(
        act.formatDescription(),
        "Admin User changed Employee Two's role from Employee to Manager",
      );

      final actNoActor = Activity(
        id: 'act_role_2',
        actorUserId: 'admin_user_1',
        action: 'user_role_changed',
        entityType: 'employee',
        entityId: 'emp_2',
        metadata: {
          'name': 'Employee Two',
          'old_value': 'employee',
          'new_value': 'manager',
        },
        createdAt: DateTime.parse('2026-09-09T10:00:00Z'),
      );

      expect(
        actNoActor.formatDescription(),
        'Role for Employee Two changed from Employee to Manager',
      );
    });

    testWidgets(
      'MainNavigationScreen displays Drawer for Admin and hides for Employee',
      (tester) async {
        final mockHttpClient = MockClient((request) async {
          return http.Response(jsonEncode([]), 200);
        });

        final fakeStorage = SecureStorageService();
        final fakeClient = ApiClient(
          client: mockHttpClient,
          storage: fakeStorage,
        );
        final authProv = AuthProvider(
          apiClient: fakeClient,
          storage: fakeStorage,
        );
        final taskProv = TaskProvider(apiClient: fakeClient);
        final projProv = ProjectProvider(apiClient: fakeClient);
        final teamProv = TeamProvider(apiClient: fakeClient);
        final actProv = ActivityProvider(apiClient: fakeClient);

        // 1. Employee login -> No drawer button in AppBar
        authProv.setUserForTesting(
          const User(
            id: 'user_emp_1',
            name: 'Employee One',
            email: 'e1@taskflow.com',
            role: UserRole.employee,
          ),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authProv),
              ChangeNotifierProvider.value(value: taskProv),
              ChangeNotifierProvider.value(value: projProv),
              ChangeNotifierProvider.value(value: teamProv),
              ChangeNotifierProvider.value(value: actProv),
            ],
            child: const MaterialApp(home: MainNavigationScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Check that there is no drawer menu icon in AppBar for Employee
        expect(find.byIcon(Icons.menu), findsNothing);

        // 2. Admin login -> Drawer menu icon in AppBar exists
        authProv.setUserForTesting(
          const User(
            id: 'user_admin_1',
            name: 'Admin User',
            email: 'admin@taskflow.com',
            role: UserRole.admin,
          ),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authProv),
              ChangeNotifierProvider.value(value: taskProv),
              ChangeNotifierProvider.value(value: projProv),
              ChangeNotifierProvider.value(value: teamProv),
              ChangeNotifierProvider.value(value: actProv),
            ],
            child: const MaterialApp(home: MainNavigationScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.menu), findsOneWidget);

        // Open the drawer
        await tester.tap(find.byIcon(Icons.menu));
        await tester.pumpAndSettle();

        expect(find.text('User Management'), findsOneWidget);
        expect(find.text('Manage employees and roles'), findsOneWidget);
      },
    );

    testWidgets(
      'UserManagementScreen renders list, disables self role edit, and performs role update with confirmation',
      (tester) async {
        final List<Map<String, dynamic>> requestsMade = [];

        final mockHttpClient = MockClient((request) async {
          requestsMade.add({
            'method': request.method,
            'path': request.url.path,
            'body': request.body.isNotEmpty ? jsonDecode(request.body) : null,
          });

          if (request.method == 'GET' && request.url.path == '/employees') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'emp_admin_1',
                  'user_id': 'user_admin_1',
                  'name': 'Raj Admin',
                  'email': 'admin@taskflow.com',
                  'role': 'admin',
                  'department': 'Exec',
                  'status': 'active',
                },
                {
                  'id': 'emp_e2_2',
                  'user_id': 'user_e2_2',
                  'name': 'Employee Two',
                  'email': 'e2@taskflow.com',
                  'role': 'employee',
                  'department': 'Marketing',
                  'status': 'active',
                },
              ]),
              200,
            );
          }

          if (request.method == 'PATCH' &&
              request.url.path == '/employees/emp_e2_2/role') {
            return http.Response(
              jsonEncode({
                'id': 'emp_e2_2',
                'user_id': 'user_e2_2',
                'name': 'Employee Two',
                'email': 'e2@taskflow.com',
                'role': 'manager',
                'department': 'Marketing',
                'status': 'active',
              }),
              200,
            );
          }

          return http.Response(jsonEncode({}), 200);
        });

        final fakeStorage = SecureStorageService();
        final fakeClient = ApiClient(
          client: mockHttpClient,
          storage: fakeStorage,
        );
        final authProv = AuthProvider(
          apiClient: fakeClient,
          storage: fakeStorage,
        );
        final teamProv = TeamProvider(apiClient: fakeClient);

        // Current logged in user is Raj Admin
        authProv.setUserForTesting(
          const User(
            id: 'user_admin_1',
            name: 'Raj Admin',
            email: 'admin@taskflow.com',
            role: UserRole.admin,
          ),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authProv),
              ChangeNotifierProvider.value(value: teamProv),
            ],
            child: const MaterialApp(home: UserManagementScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify employee list is rendered
        expect(find.text('Raj Admin'), findsOneWidget);
        expect(find.text('Employee Two'), findsOneWidget);
        expect(find.text('Admin'), findsOneWidget);
        expect(find.text('Employee'), findsOneWidget);

        // 2. For self (Raj Admin), "Self" is displayed and no "Change Role" button
        expect(find.text('Self'), findsOneWidget);

        // 3. For Employee Two, "Change Role" button is present
        expect(find.text('Change Role'), findsOneWidget);

        // 4. Tap "Change Role" for Employee Two
        await tester.tap(find.text('Change Role'));
        await tester.pumpAndSettle();

        // Role selection dialog is shown
        expect(find.text('Change Role for Employee Two'), findsOneWidget);
        expect(find.text('Current role: Employee'), findsOneWidget);

        // Open dropdown and select Manager role
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Manager').last);
        await tester.pumpAndSettle();

        // Click "Next"
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        // Confirmation dialog is shown
        expect(find.text('Confirm Role Change'), findsOneWidget);
        expect(
          find.text(
            'Are you sure you want to change the role of Employee Two from Employee to Manager?',
          ),
          findsOneWidget,
        );

        // Confirm change
        await tester.tap(find.text('Confirm Change'));
        await tester.pumpAndSettle();

        // Verify PATCH request was sent
        final patchReq = requestsMade.firstWhere((r) => r['method'] == 'PATCH');
        expect(patchReq['path'], '/employees/emp_e2_2/role');
        expect(patchReq['body'], {'role': 'manager'});

        // Verify success snackbar
        expect(
          find.text('Role updated to Manager for Employee Two'),
          findsOneWidget,
        );

        // Verify updated role badge is now Manager
        expect(find.text('Manager'), findsOneWidget);
      },
    );

    testWidgets(
      'UserManagementScreen handles 409 conflict error when changing role',
      (tester) async {
        final mockHttpClient = MockClient((request) async {
          if (request.method == 'GET' && request.url.path == '/employees') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'emp_admin_1',
                  'user_id': 'user_admin_1',
                  'name': 'Raj Admin',
                  'email': 'admin@taskflow.com',
                  'role': 'admin',
                  'department': 'Exec',
                  'status': 'active',
                },
                {
                  'id': 'emp_m1_1',
                  'user_id': 'user_m1_1',
                  'name': 'Manager One',
                  'email': 'm1@taskflow.com',
                  'role': 'manager',
                  'department': 'Engineering',
                  'status': 'active',
                },
              ]),
              200,
            );
          }

          if (request.method == 'PATCH' &&
              request.url.path == '/employees/emp_m1_1/role') {
            return http.Response(
              jsonEncode({
                'detail':
                    'Cannot demote Manager One. They are currently managing 1 team(s). Reassign those teams first.',
              }),
              409,
            );
          }

          return http.Response(jsonEncode({}), 200);
        });

        final fakeStorage = SecureStorageService();
        final fakeClient = ApiClient(
          client: mockHttpClient,
          storage: fakeStorage,
        );
        final authProv = AuthProvider(
          apiClient: fakeClient,
          storage: fakeStorage,
        );
        final teamProv = TeamProvider(apiClient: fakeClient);

        authProv.setUserForTesting(
          const User(
            id: 'user_admin_1',
            name: 'Raj Admin',
            email: 'admin@taskflow.com',
            role: UserRole.admin,
          ),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authProv),
              ChangeNotifierProvider.value(value: teamProv),
            ],
            child: const MaterialApp(home: UserManagementScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Tap "Change Role" for Manager One
        await tester.tap(find.text('Change Role'));
        await tester.pumpAndSettle();

        // Open dropdown and select Employee role
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Employee').last);
        await tester.pumpAndSettle();

        // Click "Next"
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        // Confirm change
        await tester.tap(find.text('Confirm Change'));
        await tester.pumpAndSettle();

        // Verify error message from 409 is displayed in SnackBar
        expect(
          find.text(
            'Cannot demote Manager One. They are currently managing 1 team(s). Reassign those teams first.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'DashboardScreen renders recent activities with human-readable task titles',
      (tester) async {
        final mockHttpClient = MockClient((request) async {
          if (request.url.path.contains('activities')) {
            return http.Response(
              jsonEncode({
                'activities': [
                  {
                    'id': 'act_comment_1',
                    'actor_user_id': 'user_raj_1',
                    'actor_name': 'Raj Admin',
                    'action': 'comment_created',
                    'entity_type': 'comment',
                    'entity_id': 'comm_123',
                    'task_id': 'task_auth_999',
                    'metadata': {'content_preview': 'Looking good'},
                    'created_at': '2026-09-09T12:00:00Z',
                  },
                ],
                'total': 1,
                'skip': 0,
                'limit': 5,
              }),
              200,
            );
          }
          if (request.url.path == '/tasks') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'task_auth_999',
                  'title': 'Implement User Authentication',
                  'description': 'Auth Flow',
                  'project_id': 'proj_1',
                  'assigned_to': 'emp_1',
                  'priority': 'high',
                  'status': 'in_progress',
                  'created_at': '2026-09-01T00:00:00Z',
                },
              ]),
              200,
            );
          }
          return http.Response(jsonEncode([]), 200);
        });

        final fakeStorage = SecureStorageService();
        final fakeClient = ApiClient(
          client: mockHttpClient,
          storage: fakeStorage,
        );
        final authProv = AuthProvider(
          apiClient: fakeClient,
          storage: fakeStorage,
        );
        final teamProv = TeamProvider(apiClient: fakeClient);
        final projProv = ProjectProvider(apiClient: fakeClient);
        final taskProv = TaskProvider(apiClient: fakeClient);
        final actProv = ActivityProvider(apiClient: fakeClient);

        authProv.setUserForTesting(
          const User(
            id: 'user_raj_1',
            name: 'Raj Admin',
            email: 'raj@test.com',
            role: UserRole.admin,
          ),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authProv),
              ChangeNotifierProvider.value(value: teamProv),
              ChangeNotifierProvider.value(value: projProv),
              ChangeNotifierProvider.value(value: taskProv),
              ChangeNotifierProvider.value(value: actProv),
            ],
            child: const MaterialApp(home: DashboardScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Verify task title and actor name are resolved instead of raw task ObjectId
        expect(
          find.text(
            'Raj Admin added a comment on task "Implement User Authentication"',
          ),
          findsOneWidget,
        );
        expect(find.text('task_auth_999'), findsNothing);
      },
    );

    testWidgets(
      'UserManagementScreen supports deactivation, reactivation, and status filtering',
      (tester) async {
        final List<Map<String, dynamic>> requestsMade = [];
        final mockHttpClient = MockClient((request) async {
          requestsMade.add({
            'method': request.method,
            'path': request.url.path,
          });

          if (request.method == 'GET' && request.url.path == '/employees') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'emp_admin_1',
                  'name': 'Raj Admin',
                  'email': 'raj@test.com',
                  'phone': '1234567890',
                  'department': 'Exec',
                  'role': 'admin',
                  'status': 'active',
                  'user_id': 'user_raj_1',
                },
                {
                  'id': 'emp_2',
                  'name': 'Sarah Miller',
                  'email': 'sarah@test.com',
                  'phone': '5550201',
                  'department': 'Engineering',
                  'role': 'employee',
                  'status': 'active',
                  'user_id': 'user_sarah_2',
                },
              ]),
              200,
            );
          }

          if (request.method == 'PATCH' &&
              request.url.path == '/employees/emp_2/deactivate') {
            return http.Response(
              jsonEncode({
                'message': 'Employee deactivated successfully',
                'employee': {
                  'id': 'emp_2',
                  'name': 'Sarah Miller',
                  'email': 'sarah@test.com',
                  'phone': '5550201',
                  'department': 'Engineering',
                  'role': 'employee',
                  'status': 'inactive',
                  'user_id': 'user_sarah_2',
                },
              }),
              200,
            );
          }

          return http.Response(jsonEncode([]), 200);
        });

        final fakeStorage = SecureStorageService();
        final fakeClient = ApiClient(client: mockHttpClient, storage: fakeStorage);
        final authProv = AuthProvider(apiClient: fakeClient, storage: fakeStorage);
        final teamProv = TeamProvider(apiClient: fakeClient);

        authProv.setUserForTesting(
          const User(
            id: 'user_raj_1',
            name: 'Raj Admin',
            email: 'raj@test.com',
            role: UserRole.admin,
          ),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authProv),
              ChangeNotifierProvider.value(value: teamProv),
            ],
            child: const MaterialApp(home: UserManagementScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Deactivate button exists for Sarah Miller
        expect(find.text('Deactivate'), findsOneWidget);

        // Tap Deactivate
        await tester.tap(find.text('Deactivate'));
        await tester.pumpAndSettle();

        // Confirmation dialog is shown
        expect(find.text('Deactivate User'), findsOneWidget);
        expect(find.textContaining('They will not be able to log in'), findsOneWidget);

        // Confirm deactivation
        final deactivateConfirmButton = find.widgetWithText(FilledButton, 'Deactivate');
        await tester.tap(deactivateConfirmButton);
        await tester.pumpAndSettle();

        // Verify request was sent
        expect(
          requestsMade.any((r) => r['method'] == 'PATCH' && r['path'] == '/employees/emp_2/deactivate'),
          isTrue,
        );
        expect(find.text('Sarah Miller has been deactivated'), findsOneWidget);
      },
    );

    testWidgets(
      'TaskListScreen supports search input, filter chips, and clear filters',
      (tester) async {
        final List<Map<String, dynamic>> requestsMade = [];
        final mockHttpClient = MockClient((request) async {
          requestsMade.add({
            'method': request.method,
            'path': request.url.path,
            'query': request.url.queryParameters,
          });

          if (request.url.path == '/projects') {
            return http.Response(jsonEncode([]), 200);
          }
          if (request.url.path == '/tasks') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'task_1',
                  'title': 'Test Authentication Task',
                  'description': 'Description',
                  'project_id': 'proj_1',
                  'assigned_to': 'emp_1',
                  'priority': 'high',
                  'status': 'todo',
                  'due_date': '2026-04-01',
                  'created_at': '2026-01-01T00:00:00.000Z',
                },
              ]),
              200,
            );
          }
          return http.Response(jsonEncode([]), 200);
        });

        final fakeStorage = SecureStorageService();
        final fakeClient = ApiClient(client: mockHttpClient, storage: fakeStorage);
        final authProv = AuthProvider(apiClient: fakeClient, storage: fakeStorage);
        final taskProv = TaskProvider(apiClient: fakeClient);
        final projProv = ProjectProvider(apiClient: fakeClient);

        authProv.setUserForTesting(
          const User(
            id: 'user_1',
            name: 'Test Admin',
            email: 'admin@test.com',
            role: UserRole.admin,
          ),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authProv),
              ChangeNotifierProvider.value(value: taskProv),
              ChangeNotifierProvider.value(value: projProv),
            ],
            child: const MaterialApp(home: TaskListScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify task is rendered
        expect(find.text('Test Authentication Task'), findsOneWidget);

        // 2. Enter search term
        await tester.enterText(find.byType(TextField), 'Authentication');
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        // 3. Toggle Overdue FilterChip
        await tester.tap(find.text('Overdue Only'));
        await tester.pumpAndSettle();

        // 4. Verify Clear Filters button appears and resets filters
        expect(find.text('Clear Filters'), findsOneWidget);
        await tester.ensureVisible(find.text('Clear Filters'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Clear Filters'));
        await tester.pumpAndSettle();

        expect(find.text('Clear Filters'), findsNothing);
      },
    );

    testWidgets(
      'TaskFormScreen creates task without due date',
      (tester) async {
        Map<String, dynamic>? capturedCreateBody;

        final mockHttpClient = MockClient((request) async {
          if (request.url.path == '/employees') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'emp_1',
                  'user_id': 'user_1',
                  'name': 'Neha',
                  'email': 'neha@flow.com',
                  'role': 'employee',
                  'department': 'Engineering',
                  'status': 'active',
                },
              ]),
              200,
            );
          }
          if (request.url.path == '/projects') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'proj_1',
                  'name': 'TaskFlow Mobile',
                  'description': 'Mobile App',
                  'team_id': 'team_1',
                  'status': 'active',
                },
              ]),
              200,
            );
          }
          if (request.method == 'POST' && request.url.path == '/tasks') {
            capturedCreateBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'id': 'new_task_1',
                'title': capturedCreateBody!['title'],
                'description': capturedCreateBody!['description'],
                'project_id': capturedCreateBody!['project_id'],
                'assigned_to': capturedCreateBody!['assigned_to'],
                'priority': capturedCreateBody!['priority'],
                'status': capturedCreateBody!['status'],
                'due_date': capturedCreateBody!['due_date'],
                'created_by': 'user_admin',
                'created_at': '2026-01-01T00:00:00.000Z',
                'updated_at': '2026-01-01T00:00:00.000Z',
              }),
              201,
            );
          }
          return http.Response(jsonEncode([]), 200);
        });

        final fakeStorage = SecureStorageService();
        final fakeClient = ApiClient(client: mockHttpClient, storage: fakeStorage);
        final authProv = AuthProvider(apiClient: fakeClient, storage: fakeStorage);
        final taskProv = TaskProvider(apiClient: fakeClient);
        final projProv = ProjectProvider(apiClient: fakeClient);
        final teamProv = TeamProvider(apiClient: fakeClient);

        authProv.setUserForTesting(
          const User(
            id: 'user_admin',
            name: 'Admin User',
            email: 'admin@test.com',
            role: UserRole.admin,
          ),
        );

        await projProv.fetchProjects();
        await teamProv.fetchEmployees();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authProv),
              ChangeNotifierProvider.value(value: taskProv),
              ChangeNotifierProvider.value(value: projProv),
              ChangeNotifierProvider.value(value: teamProv),
            ],
            child: const MaterialApp(home: TaskFormScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Set Due Date (Optional)'), findsOneWidget);
        await tester.enterText(find.byType(TextFormField).first, 'No Due Date Task');
        await tester.enterText(find.byType(TextFormField).at(1), 'Task description');
        await tester.ensureVisible(find.text('Create Task'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create Task'));
        await tester.pumpAndSettle();

        expect(capturedCreateBody, isNotNull);
        expect(capturedCreateBody!['title'], 'No Due Date Task');
        expect(capturedCreateBody!.containsKey('due_date'), isFalse);
      },
    );

    testWidgets(
      'TaskFormScreen allows clearing existing due date on edit',
      (tester) async {
        Map<String, dynamic>? capturedUpdateBody;

        final mockHttpClient = MockClient((request) async {
          if (request.url.path == '/employees') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'emp_1',
                  'user_id': 'user_1',
                  'name': 'Neha',
                  'email': 'neha@flow.com',
                  'role': 'employee',
                  'department': 'Engineering',
                  'status': 'active',
                },
              ]),
              200,
            );
          }
          if (request.url.path == '/projects') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'proj_1',
                  'name': 'TaskFlow Mobile',
                  'description': 'Mobile App',
                  'team_id': 'team_1',
                  'status': 'active',
                },
              ]),
              200,
            );
          }
          if (request.method == 'PUT' && request.url.path.startsWith('/tasks/')) {
            capturedUpdateBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'id': 'task_existing',
                'title': 'Existing Task',
                'description': 'Existing Description',
                'project_id': 'proj_1',
                'assigned_to': 'emp_1',
                'priority': 'medium',
                'status': 'todo',
                'due_date': capturedUpdateBody!['due_date'],
                'created_by': 'user_admin',
                'created_at': '2026-01-01T00:00:00.000Z',
                'updated_at': '2026-01-01T00:00:00.000Z',
              }),
              200,
            );
          }
          return http.Response(jsonEncode([]), 200);
        });

        final fakeStorage = SecureStorageService();
        final fakeClient = ApiClient(client: mockHttpClient, storage: fakeStorage);
        final authProv = AuthProvider(apiClient: fakeClient, storage: fakeStorage);
        final taskProv = TaskProvider(apiClient: fakeClient);
        final projProv = ProjectProvider(apiClient: fakeClient);
        final teamProv = TeamProvider(apiClient: fakeClient);

        authProv.setUserForTesting(
          const User(
            id: 'user_admin',
            name: 'Admin User',
            email: 'admin@test.com',
            role: UserRole.admin,
          ),
        );

        await projProv.fetchProjects();
        await teamProv.fetchEmployees();

        const existingTask = Task(
          id: 'task_existing',
          title: 'Existing Task',
          description: 'Description',
          projectId: 'proj_1',
          assignedTo: 'emp_1',
          priority: TaskPriority.medium,
          status: TaskStatus.todo,
          dueDate: '2026-05-01',
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authProv),
              ChangeNotifierProvider.value(value: taskProv),
              ChangeNotifierProvider.value(value: projProv),
              ChangeNotifierProvider.value(value: teamProv),
            ],
            child: const MaterialApp(home: TaskFormScreen(task: existingTask)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Due Date: 2026-05-01'), findsOneWidget);
        expect(find.byTooltip('Clear Due Date'), findsOneWidget);

        // Clear due date
        await tester.tap(find.byTooltip('Clear Due Date'));
        await tester.pumpAndSettle();

        expect(find.text('Set Due Date (Optional)'), findsOneWidget);
        await tester.ensureVisible(find.text('Save Changes'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save Changes'));
        await tester.pumpAndSettle();

        expect(capturedUpdateBody, isNotNull);
        expect(capturedUpdateBody!['due_date'], isNull);
      },
    );

    testWidgets(
      'UserManagementScreen View Profile dialog displays all employee details and read-only fields',
      (tester) async {
        final mockHttpClient = MockClient((request) async {
          if (request.method == 'GET' && request.url.path == '/employees') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'emp_swayam_1',
                  'user_id': 'user_swayam_1',
                  'name': 'Swayam',
                  'email': 'swayam@taskflow.com',
                  'phone': '',
                  'department': 'General',
                  'role': 'employee',
                  'joining_date': '2026-09-11',
                  'status': 'active',
                },
              ]),
              200,
            );
          }
          return http.Response(jsonEncode([]), 200);
        });

        final fakeStorage = SecureStorageService();
        final fakeClient = ApiClient(client: mockHttpClient, storage: fakeStorage);
        final authProv = AuthProvider(apiClient: fakeClient, storage: fakeStorage);
        final teamProv = TeamProvider(apiClient: fakeClient);

        authProv.setUserForTesting(
          const User(
            id: 'user_admin',
            name: 'Admin User',
            email: 'admin@test.com',
            role: UserRole.admin,
          ),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authProv),
              ChangeNotifierProvider.value(value: teamProv),
            ],
            child: const MaterialApp(home: UserManagementScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Tap "View Profile"
        expect(find.text('View Profile'), findsOneWidget);
        await tester.tap(find.text('View Profile'));
        await tester.pumpAndSettle();

        // Verify Dialog Title & Contents
        expect(find.text('Employee Profile'), findsOneWidget);
        expect(find.text('swayam@taskflow.com'), findsWidgets);
        expect(find.text('Email cannot be modified'), findsOneWidget);
        expect(find.text('Use "Change Role" action to modify role'), findsOneWidget);
        expect(find.text('2026-09-11'), findsOneWidget);
        expect(find.text('Active'), findsWidgets);
        expect(find.text('Save Changes'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);

        // Close dialog
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Employee Profile'), findsNothing);
      },
    );

    testWidgets(
      'UserManagementScreen View Profile allows editing name, phone, department, and sends PATCH /employees/{id}',
      (tester) async {
        final List<Map<String, dynamic>> requestsMade = [];
        final mockHttpClient = MockClient((request) async {
          if (request.method == 'GET' && request.url.path == '/employees') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'emp_swayam_1',
                  'user_id': 'user_swayam_1',
                  'name': 'Swayam',
                  'email': 'swayam@taskflow.com',
                  'phone': '',
                  'department': 'General',
                  'role': 'employee',
                  'joining_date': '2026-09-11',
                  'status': 'active',
                },
              ]),
              200,
            );
          }

          if (request.method == 'PATCH' &&
              request.url.path == '/employees/emp_swayam_1') {
            final body = jsonDecode(request.body);
            requestsMade.add({
              'method': request.method,
              'path': request.url.path,
              'body': body,
            });
            return http.Response(
              jsonEncode({
                'id': 'emp_swayam_1',
                'user_id': 'user_swayam_1',
                'name': body['name'] ?? 'Swayam',
                'email': 'swayam@taskflow.com',
                'phone': body['phone'] ?? '',
                'department': body['department'] ?? 'General',
                'role': 'employee',
                'joining_date': '2026-09-11',
                'status': 'active',
              }),
              200,
            );
          }

          return http.Response(jsonEncode([]), 200);
        });

        final fakeStorage = SecureStorageService();
        final fakeClient = ApiClient(client: mockHttpClient, storage: fakeStorage);
        final authProv = AuthProvider(apiClient: fakeClient, storage: fakeStorage);
        final teamProv = TeamProvider(apiClient: fakeClient);

        authProv.setUserForTesting(
          const User(
            id: 'user_admin',
            name: 'Admin User',
            email: 'admin@test.com',
            role: UserRole.admin,
          ),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authProv),
              ChangeNotifierProvider.value(value: teamProv),
            ],
            child: const MaterialApp(home: UserManagementScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Tap "View Profile"
        await tester.tap(find.text('View Profile'));
        await tester.pumpAndSettle();

        // Enter phone number and department
        final phoneField = find.widgetWithText(TextFormField, 'Phone Number (Optional)');
        await tester.enterText(phoneField, '+1-555-0199');

        final deptField = find.widgetWithText(TextFormField, 'Department (Optional)');
        await tester.enterText(deptField, 'Development');

        // Tap Save Changes
        await tester.tap(find.text('Save Changes'));
        await tester.pumpAndSettle();

        // Verify request was sent
        expect(requestsMade.length, 1);
        expect(requestsMade[0]['path'], '/employees/emp_swayam_1');
        expect(requestsMade[0]['body']['name'], 'Swayam');
        expect(requestsMade[0]['body']['phone'], '+1-555-0199');
        expect(requestsMade[0]['body']['department'], 'Development');

        // Verify success snackbar
        expect(find.text('Profile updated for Swayam'), findsOneWidget);
      },
    );
  });
}
