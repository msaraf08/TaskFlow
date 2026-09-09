import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/api_exceptions.dart';
import '../models/project.dart';

class ProjectProvider extends ChangeNotifier {
  final ApiClient apiClient;
  ApiClient get _apiClient => apiClient;

  List<Project> _projects = [];
  Project? _selectedProject;
  bool _isLoading = false;
  String? _errorMessage;

  ProjectProvider({required this.apiClient});

  List<Project> get projects => _projects;
  Project? get selectedProject => _selectedProject;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void clearSelectedProject() {
    _selectedProject = null;
    notifyListeners();
  }

  Future<void> fetchProjects({
    String? teamId,
    int skip = 0,
    int limit = 100,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final queryParams = <String, String>{
        'skip': skip.toString(),
        'limit': limit.toString(),
      };
      if (teamId != null && teamId.isNotEmpty) {
        queryParams['team_id'] = teamId;
      }

      final data = await _apiClient.get('/projects', queryParams: queryParams);
      if (data is List) {
        _projects = data
            .map((item) => Project.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred while fetching projects';
      notifyListeners();
      rethrow;
    }
  }

  Future<Project> getProject(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _apiClient.get('/projects/$id');
      final project = Project.fromJson(data as Map<String, dynamic>);
      _selectedProject = project;
      _isLoading = false;
      notifyListeners();
      return project;
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred while fetching project';
      notifyListeners();
      rethrow;
    }
  }

  Future<Project> createProject({
    required String name,
    required String description,
    required String teamId,
    DateTime? startDate,
    DateTime? endDate,
    ProjectStatus status = ProjectStatus.planned,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{
        'name': name,
        'description': description,
        'team_id': teamId,
        'status': status.value,
      };
      if (startDate != null) {
        body['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        body['end_date'] = endDate.toIso8601String().split('T')[0];
      }

      final data = await _apiClient.post('/projects', body: body);
      final created = Project.fromJson(data as Map<String, dynamic>);
      _projects.add(created);
      _isLoading = false;
      notifyListeners();
      return created;
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to create project';
      notifyListeners();
      rethrow;
    }
  }

  Future<Project> updateProject(
    String id, {
    String? name,
    String? description,
    String? teamId,
    DateTime? startDate,
    DateTime? endDate,
    ProjectStatus? status,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (description != null) body['description'] = description;
      if (teamId != null) body['team_id'] = teamId;
      if (startDate != null) {
        body['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        body['end_date'] = endDate.toIso8601String().split('T')[0];
      }
      if (status != null) body['status'] = status.value;

      final data = await _apiClient.put('/projects/$id', body: body);
      final updated = Project.fromJson(data as Map<String, dynamic>);

      final index = _projects.indexWhere((p) => p.id == id);
      if (index != -1) {
        _projects[index] = updated;
      }
      if (_selectedProject?.id == id) {
        _selectedProject = updated;
      }

      _isLoading = false;
      notifyListeners();
      return updated;
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to update project';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteProject(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiClient.delete('/projects/$id');
      _projects.removeWhere((p) => p.id == id);
      if (_selectedProject?.id == id) {
        _selectedProject = null;
      }
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to delete project';
      notifyListeners();
      rethrow;
    }
  }
}
