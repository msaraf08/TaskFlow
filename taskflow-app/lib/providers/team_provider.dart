import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../models/employee.dart';
import '../models/team.dart';

class TeamProvider extends ChangeNotifier {
  final ApiClient _client;

  List<Team> _teams = [];
  Team? _selectedTeam;
  List<Employee> _employees = [];
  bool _isLoading = false;
  String? _errorMessage;

  TeamProvider({required ApiClient apiClient, ApiClient? client})
    : _client = client ?? apiClient;

  List<Team> get teams => _teams;
  Team? get selectedTeam => _selectedTeam;
  List<Employee> get employees => _employees;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void clearSelectedTeam() {
    _selectedTeam = null;
    notifyListeners();
  }

  Future<void> fetchTeams() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.get('/teams');
      if (response is List) {
        _teams = response
            .map((item) => Team.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      _isLoading = false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> fetchEmployees() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.get('/employees');
      if (response is List) {
        _employees = response
            .map((item) => Employee.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      _isLoading = false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<Employee> updateEmployeeRole(String employeeId, String newRole) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.patch(
        '/employees/$employeeId/role',
        body: {'role': newRole},
      );
      final updated = Employee.fromJson(response as Map<String, dynamic>);
      final index = _employees.indexWhere((e) => e.id == employeeId);
      if (index != -1) {
        _employees[index] = updated;
      }
      _isLoading = false;
      notifyListeners();
      return updated;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Employee> updateEmployeeProfile(
    String employeeId, {
    String? name,
    String? phone,
    String? department,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (phone != null) body['phone'] = phone;
      if (department != null) body['department'] = department;

      final response = await _client.patch(
        '/employees/$employeeId',
        body: body,
      );
      final updated = Employee.fromJson(response as Map<String, dynamic>);
      final index = _employees.indexWhere((e) => e.id == employeeId);
      if (index != -1) {
        _employees[index] = updated;
      }
      _isLoading = false;
      notifyListeners();
      return updated;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deactivateEmployee(String employeeId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.patch(
        '/employees/$employeeId/deactivate',
      );
      if (response is Map<String, dynamic> && response['employee'] != null) {
        final updated = Employee.fromJson(response['employee'] as Map<String, dynamic>);
        final index = _employees.indexWhere((e) => e.id == employeeId);
        if (index != -1) {
          _employees[index] = updated;
        }
      } else {
        await fetchEmployees();
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> reactivateEmployee(String employeeId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.patch(
        '/employees/$employeeId/reactivate',
      );
      if (response is Map<String, dynamic> && response['employee'] != null) {
        final updated = Employee.fromJson(response['employee'] as Map<String, dynamic>);
        final index = _employees.indexWhere((e) => e.id == employeeId);
        if (index != -1) {
          _employees[index] = updated;
        }
      } else {
        await fetchEmployees();
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Team?> getTeam(String teamId) async {
    try {
      final response = await _client.get('/teams/$teamId');
      final team = Team.fromJson(response as Map<String, dynamic>);
      _selectedTeam = team;
      final index = _teams.indexWhere((t) => t.id == teamId);
      if (index != -1) {
        _teams[index] = team;
      }
      notifyListeners();
      return team;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<Team> createTeam({
    required String name,
    required String description,
    required String managerId,
    List<String>? memberIds,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{
        'name': name,
        'description': description,
        'manager_id': managerId,
      };

      final response = await _client.post('/teams', body: body);
      var newTeam = Team.fromJson(response as Map<String, dynamic>);

      // Add selected initial members using POST /teams/{team_id}/members
      if (memberIds != null && memberIds.isNotEmpty) {
        for (final memberId in memberIds) {
          try {
            final memberResponse = await _client.post(
              '/teams/${newTeam.id}/members',
              body: {'employee_id': memberId},
            );
            newTeam = Team.fromJson(memberResponse as Map<String, dynamic>);
          } catch (_) {
            // Member addition error logged/handled without failing whole team creation
          }
        }
      }

      _teams.add(newTeam);
      _isLoading = false;
      notifyListeners();
      return newTeam;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Team> updateTeam(
    String id, {
    String? name,
    String? description,
    String? managerId,
    List<String>? memberIds,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (description != null) body['description'] = description;
      if (managerId != null) body['manager_id'] = managerId;

      final response = await _client.put('/teams/$id', body: body);
      var updated = Team.fromJson(response as Map<String, dynamic>);

      if (memberIds != null) {
        final currentMemberIds = Set<String>.from(updated.memberIds);
        final targetMemberIds = Set<String>.from(memberIds);

        final toAdd = targetMemberIds.difference(currentMemberIds);
        final toRemove = currentMemberIds.difference(targetMemberIds);

        for (final addId in toAdd) {
          try {
            final resp = await _client.post(
              '/teams/$id/members',
              body: {'employee_id': addId},
            );
            updated = Team.fromJson(resp as Map<String, dynamic>);
          } catch (_) {}
        }

        for (final remId in toRemove) {
          try {
            await _client.delete('/teams/$id/members/$remId');
            final currentList = List<String>.from(updated.memberIds);
            currentList.remove(remId);
            updated = updated.copyWith(memberIds: currentList);
          } catch (_) {}
        }
      }

      final index = _teams.indexWhere((t) => t.id == id);
      if (index != -1) {
        _teams[index] = updated;
      }
      if (_selectedTeam?.id == id) {
        _selectedTeam = updated;
      }
      _isLoading = false;
      notifyListeners();
      return updated;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> deleteTeam(String id) async {
    try {
      await _client.delete('/teams/$id');
      _teams.removeWhere((t) => t.id == id);
      if (_selectedTeam?.id == id) {
        _selectedTeam = null;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Team> addMember(String teamId, String employeeId) async {
    try {
      final response = await _client.post(
        '/teams/$teamId/members',
        body: {'employee_id': employeeId},
      );
      final updated = Team.fromJson(response as Map<String, dynamic>);
      final index = _teams.indexWhere((t) => t.id == teamId);
      if (index != -1) {
        _teams[index] = updated;
      }
      if (_selectedTeam?.id == teamId) {
        _selectedTeam = updated;
      }
      notifyListeners();
      return updated;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> removeMember(String teamId, String employeeId) async {
    try {
      await _client.delete('/teams/$teamId/members/$employeeId');
      final index = _teams.indexWhere((t) => t.id == teamId);
      if (index != -1) {
        final currentMembers = List<String>.from(_teams[index].memberIds);
        currentMembers.remove(employeeId);
        _teams[index] = _teams[index].copyWith(memberIds: currentMembers);
      }
      if (_selectedTeam?.id == teamId) {
        final currentMembers = List<String>.from(_selectedTeam!.memberIds);
        currentMembers.remove(employeeId);
        _selectedTeam = _selectedTeam!.copyWith(memberIds: currentMembers);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}
