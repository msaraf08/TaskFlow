import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/api_exceptions.dart';
import '../models/comment.dart';
import '../models/task.dart';

class TaskProvider extends ChangeNotifier {
  final ApiClient apiClient;
  ApiClient get _apiClient => apiClient;

  List<Task> _tasks = [];
  Task? _selectedTask;
  List<Comment> _comments = [];
  bool _isLoading = false;
  bool _isCommentsLoading = false;
  String? _errorMessage;

  TaskProvider({required this.apiClient});

  List<Task> get tasks => _tasks;
  Task? get selectedTask => _selectedTask;
  List<Comment> get comments => _comments;
  bool get isLoading => _isLoading;
  bool get isCommentsLoading => _isCommentsLoading;
  String? get errorMessage => _errorMessage;

  void clearSelectedTask() {
    _selectedTask = null;
    _comments = [];
    notifyListeners();
  }

  @visibleForTesting
  void setSelectedTaskForTesting(Task? task) {
    _selectedTask = task;
    notifyListeners();
  }

  Future<void> fetchTasks({
    String? projectId,
    String? assignedTo,
    TaskStatus? status,
    TaskPriority? priority,
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
      if (projectId != null && projectId.isNotEmpty) {
        queryParams['project_id'] = projectId;
      }
      if (assignedTo != null && assignedTo.isNotEmpty) {
        queryParams['assigned_to'] = assignedTo;
      }
      if (status != null) {
        queryParams['status'] = status.value;
      }
      if (priority != null) {
        queryParams['priority'] = priority.value;
      }

      final data = await _apiClient.get('/tasks', queryParams: queryParams);
      if (data is List) {
        _tasks = data
            .map((item) => Task.fromJson(item as Map<String, dynamic>))
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
      _errorMessage = 'An unexpected error occurred while fetching tasks';
      notifyListeners();
      rethrow;
    }
  }

  Future<Task> getTask(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _apiClient.get('/tasks/$id');
      final task = Task.fromJson(data as Map<String, dynamic>);
      _selectedTask = task;
      _isLoading = false;
      notifyListeners();
      return task;
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred while fetching task';
      notifyListeners();
      rethrow;
    }
  }

  Future<Task> createTask({
    required String title,
    required String description,
    required String projectId,
    required String assignedTo,
    TaskPriority priority = TaskPriority.medium,
    TaskStatus status = TaskStatus.todo,
    DateTime? dueDate,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{
        'title': title,
        'description': description,
        'project_id': projectId,
        'assigned_to': assignedTo,
        'priority': priority.value,
        'status': status.value,
      };
      if (dueDate != null) {
        body['due_date'] = dueDate.toIso8601String().split('T')[0];
      }

      final data = await _apiClient.post('/tasks', body: body);
      final created = Task.fromJson(data as Map<String, dynamic>);
      _tasks.add(created);
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
      _errorMessage = 'Failed to create task';
      notifyListeners();
      rethrow;
    }
  }

  Future<Task> updateTask(
    String id, {
    String? title,
    String? description,
    String? projectId,
    String? assignedTo,
    TaskPriority? priority,
    TaskStatus? status,
    DateTime? dueDate,
    bool isEmployeeRole = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      // If employee, do NOT include project_id or assigned_to in payload (backend rejects with 422)
      if (!isEmployeeRole) {
        if (projectId != null) body['project_id'] = projectId;
        if (assignedTo != null) body['assigned_to'] = assignedTo;
      }
      if (priority != null) body['priority'] = priority.value;
      if (status != null) body['status'] = status.value;
      if (dueDate != null) {
        body['due_date'] = dueDate.toIso8601String().split('T')[0];
      }

      final data = await _apiClient.put('/tasks/$id', body: body);
      final updated = Task.fromJson(data as Map<String, dynamic>);

      final index = _tasks.indexWhere((t) => t.id == id);
      if (index != -1) {
        _tasks[index] = updated;
      }
      if (_selectedTask?.id == id) {
        _selectedTask = updated;
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
      _errorMessage = 'Failed to update task';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteTask(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiClient.delete('/tasks/$id');
      _tasks.removeWhere((t) => t.id == id);
      if (_selectedTask?.id == id) {
        _selectedTask = null;
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
      _errorMessage = 'Failed to delete task';
      notifyListeners();
      rethrow;
    }
  }

  // Comments
  Future<void> fetchComments(String taskId) async {
    _isCommentsLoading = true;
    notifyListeners();

    try {
      final data = await _apiClient.get('/tasks/$taskId/comments');
      if (data is List) {
        _comments = data
            .map((item) => Comment.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      _isCommentsLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _isCommentsLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _isCommentsLoading = false;
      _errorMessage = 'Failed to fetch comments';
      notifyListeners();
      rethrow;
    }
  }

  Future<Comment> addComment(String taskId, String content) async {
    try {
      final data = await _apiClient.post(
        '/tasks/$taskId/comments',
        body: {'content': content},
      );
      final newComment = Comment.fromJson(data as Map<String, dynamic>);
      _comments.insert(0, newComment);
      notifyListeners();
      return newComment;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _errorMessage = 'Failed to add comment';
      notifyListeners();
      rethrow;
    }
  }

  Future<Comment> updateComment(String commentId, String content) async {
    try {
      final data = await _apiClient.put(
        '/comments/$commentId',
        body: {'content': content},
      );
      final updated = Comment.fromJson(data as Map<String, dynamic>);
      final idx = _comments.indexWhere((c) => c.id == commentId);
      if (idx != -1) {
        _comments[idx] = updated;
        notifyListeners();
      }
      return updated;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _errorMessage = 'Failed to update comment';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteComment(String commentId) async {
    try {
      await _apiClient.delete('/comments/$commentId');
      _comments.removeWhere((c) => c.id == commentId);
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _errorMessage = 'Failed to delete comment';
      notifyListeners();
      rethrow;
    }
  }
}
