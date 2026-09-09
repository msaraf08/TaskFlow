import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'core/api_client.dart';
import 'core/secure_storage.dart';
import 'providers/activity_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/project_provider.dart';
import 'providers/task_provider.dart';
import 'providers/team_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'widgets/app_loading_indicator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskFlowApp());
}

class TaskFlowApp extends StatefulWidget {
  const TaskFlowApp({super.key});

  @override
  State<TaskFlowApp> createState() => _TaskFlowAppState();
}

class _TaskFlowAppState extends State<TaskFlowApp> {
  late final SecureStorageService _storageService;
  late final ApiClient _apiClient;
  late final AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _storageService = SecureStorageService();
    _apiClient = ApiClient(
      baseUrl: AppConfig.apiBaseUrl,
      storage: _storageService,
    );
    _authProvider = AuthProvider(client: _apiClient, storage: _storageService);

    // Auto logout on 401 Unauthorized
    _apiClient.onUnauthorized = () {
      _authProvider.logout();
    };

    // Check existing authentication state on launch
    _authProvider.loadCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SecureStorageService>.value(value: _storageService),
        Provider<ApiClient>.value(value: _apiClient),
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<TeamProvider>(
          create: (_) => TeamProvider(apiClient: _apiClient),
        ),
        ChangeNotifierProvider<ProjectProvider>(
          create: (_) => ProjectProvider(apiClient: _apiClient),
        ),
        ChangeNotifierProvider<TaskProvider>(
          create: (_) => TaskProvider(apiClient: _apiClient),
        ),
        ChangeNotifierProvider<ActivityProvider>(
          create: (_) => ActivityProvider(apiClient: _apiClient),
        ),
      ],
      child: MaterialApp(
        title: 'TaskFlow',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            switch (auth.status) {
              case AuthStatus.initial:
                return const Scaffold(
                  body: AppLoadingIndicator(
                    message: 'Initializing TaskFlow...',
                  ),
                );
              case AuthStatus.authenticated:
                return const MainNavigationScreen();
              case AuthStatus.unauthenticated:
              case AuthStatus.authenticating:
              case AuthStatus.error:
                return const LoginScreen();
            }
          },
        ),
      ),
    );
  }
}
