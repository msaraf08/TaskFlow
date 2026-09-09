import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/api_exceptions.dart';
import '../models/activity.dart';

class ActivityProvider extends ChangeNotifier {
  final ApiClient apiClient;
  ApiClient get _apiClient => apiClient;

  List<Activity> _activities = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;

  ActivityProvider({required this.apiClient});

  List<Activity> get activities => _activities;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;

  Future<void> fetchActivities({
    String? entityType,
    String? action,
    String? taskId,
    String? projectId,
    String? teamId,
    String? actorUserId,
    int skip = 0,
    int limit = 20,
    bool append = false,
  }) async {
    if (append) {
      if (_isLoadingMore || !_hasMore) return;
      _isLoadingMore = true;
    } else {
      _isLoading = true;
      _errorMessage = null;
    }
    notifyListeners();

    try {
      final queryParams = <String, String>{
        'skip': skip.toString(),
        'limit': limit.toString(),
      };
      if (entityType != null && entityType.isNotEmpty) {
        queryParams['entity_type'] = entityType;
      }
      if (action != null && action.isNotEmpty) {
        queryParams['action'] = action;
      }
      if (taskId != null && taskId.isNotEmpty) {
        queryParams['task_id'] = taskId;
      }
      if (projectId != null && projectId.isNotEmpty) {
        queryParams['project_id'] = projectId;
      }
      if (teamId != null && teamId.isNotEmpty) {
        queryParams['team_id'] = teamId;
      }
      if (actorUserId != null && actorUserId.isNotEmpty) {
        queryParams['actor_user_id'] = actorUserId;
      }

      final data = await _apiClient.get(
        '/activities',
        queryParams: queryParams,
      );
      if (data is List) {
        final fetched = data
            .map((item) => Activity.fromJson(item as Map<String, dynamic>))
            .toList();
        if (append) {
          _activities.addAll(fetched);
        } else {
          _activities = fetched;
        }
        _hasMore = fetched.length >= limit;
      } else if (data is Map<String, dynamic> && data['activities'] is List) {
        final fetched = (data['activities'] as List)
            .map((item) => Activity.fromJson(item as Map<String, dynamic>))
            .toList();
        if (append) {
          _activities.addAll(fetched);
        } else {
          _activities = fetched;
        }
        _hasMore = fetched.length >= limit;
      }

      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    } on ApiException catch (e) {
      _isLoading = false;
      _isLoadingMore = false;
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _isLoading = false;
      _isLoadingMore = false;
      _errorMessage = 'An unexpected error occurred while fetching activities';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadMore({
    String? entityType,
    String? action,
    String? taskId,
    String? projectId,
    String? teamId,
    String? actorUserId,
    int limit = 20,
  }) async {
    await fetchActivities(
      entityType: entityType,
      action: action,
      taskId: taskId,
      projectId: projectId,
      teamId: teamId,
      actorUserId: actorUserId,
      skip: _activities.length,
      limit: limit,
      append: true,
    );
  }
}
