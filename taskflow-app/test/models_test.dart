import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/activity.dart';
import 'package:taskflow/models/comment.dart';
import 'package:taskflow/models/employee.dart';
import 'package:taskflow/models/project.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/models/team.dart';
import 'package:taskflow/models/user.dart';

void main() {
  group('Models Test Suite', () {
    test('User model serialization and role mapping', () {
      final json = {
        'id': '64f1a2b3c4d5e6f7a8b9c0d1',
        'name': 'Alice Admin',
        'email': 'alice@example.com',
        'role': 'admin',
        'status': 'active',
      };
      final user = User.fromJson(json);
      expect(user.id, '64f1a2b3c4d5e6f7a8b9c0d1');
      expect(user.role, UserRole.admin);
      expect(user.role.displayName, 'Admin');
      expect(user.toJson()['role'], 'admin');
    });

    test('Employee model serialization', () {
      final json = {
        'id': '64f1a2b3c4d5e6f7a8b9c0d2',
        'user_id': '64f1a2b3c4d5e6f7a8b9c0d1',
        'name': 'Bob Employee',
        'email': 'bob@example.com',
        'department': 'Engineering',
        'role': 'Developer',
        'status': 'active',
        'joining_date': '2026-01-15',
      };
      final employee = Employee.fromJson(json);
      expect(employee.department, 'Engineering');
      expect(employee.formattedJoiningDate, '2026-01-15');
      expect(employee.toJson()['user_id'], '64f1a2b3c4d5e6f7a8b9c0d1');
    });

    test('Team model serialization', () {
      final json = {
        'id': '64f1a2b3c4d5e6f7a8b9c0d3',
        'name': 'Backend Team',
        'description': 'Responsible for API and databases',
        'manager_id': '64f1a2b3c4d5e6f7a8b9c0d2',
        'member_ids': ['64f1a2b3c4d5e6f7a8b9c0d2', '64f1a2b3c4d5e6f7a8b9c0d4'],
      };
      final team = Team.fromJson(json);
      expect(team.name, 'Backend Team');
      expect(team.memberIds.length, 2);
      expect(team.toJson()['manager_id'], '64f1a2b3c4d5e6f7a8b9c0d2');
    });

    test('Project model and status handling', () {
      final json = {
        'id': '64f1a2b3c4d5e6f7a8b9c0d5',
        'name': 'TaskFlow Mobile',
        'description': 'Flutter client app',
        'team_id': '64f1a2b3c4d5e6f7a8b9c0d3',
        'status': 'active',
        'start_date': '2026-02-01',
        'end_date': '2026-06-30',
        'created_by': '64f1a2b3c4d5e6f7a8b9c0d1',
      };
      final project = Project.fromJson(json);
      expect(project.status, ProjectStatus.active);
      expect(project.status.displayName, 'Active');
      expect(project.formattedStartDate, '2026-02-01');
      expect(project.toJson()['status'], 'active');
    });

    test('Task model overdue calculation and status', () {
      final pastDate = '2020-01-01';
      final futureDate = '2030-01-01';

      final taskPast = Task.fromJson({
        'id': 'task-1',
        'title': 'Overdue Task',
        'description': 'Description',
        'project_id': 'proj-1',
        'assigned_to': 'emp-1',
        'priority': 'urgent',
        'status': 'todo',
        'due_date': pastDate,
      });
      expect(taskPast.isOverdue, isTrue);
      expect(taskPast.priority, TaskPriority.urgent);

      final taskFuture = Task.fromJson({
        'id': 'task-2',
        'title': 'Future Task',
        'description': 'Description',
        'project_id': 'proj-1',
        'assigned_to': 'emp-1',
        'priority': 'medium',
        'status': 'todo',
        'due_date': futureDate,
      });
      expect(taskFuture.isOverdue, isFalse);

      final taskCompleted = taskPast.copyWith(status: TaskStatus.completed);
      expect(taskCompleted.isOverdue, isFalse);
    });

    test('Comment model serialization', () {
      final json = {
        'id': 'comment-1',
        'task_id': 'task-1',
        'user_id': 'user-1',
        'content': 'Great progress!',
        'created_at': '2026-03-01T12:00:00Z',
      };
      final comment = Comment.fromJson(json);
      expect(comment.content, 'Great progress!');
      expect(comment.taskId, 'task-1');
      expect(comment.toJson()['content'], 'Great progress!');
    });

    test('Activity model and humanReadableDescription for all actions', () {
      final jsonCreated = {
        'id': 'act-1',
        'actor_user_id': 'user-1',
        'action': 'task_created',
        'entity_type': 'task',
        'entity_id': 'task-1',
        'metadata': {'title': 'Design Login UI'},
      };
      final actCreated = Activity.fromJson(jsonCreated);
      expect(actCreated.action, 'task_created');
      expect(
        actCreated.humanReadableDescription,
        'Task "Design Login UI" was created',
      );

      final jsonStatus = {
        'id': 'act-2',
        'actor_user_id': 'user-1',
        'action': 'task_status_changed',
        'entity_type': 'task',
        'entity_id': 'task-1',
        'metadata': {
          'title': 'Implement Auth',
          'old_value': 'todo',
          'new_value': 'in_progress',
        },
      };
      final actStatus = Activity.fromJson(jsonStatus);
      expect(
        actStatus.humanReadableDescription,
        'Task "Implement Auth" status changed from To Do to In Progress',
      );

      final jsonPriority = {
        'id': 'act-3',
        'actor_user_id': 'user-1',
        'action': 'task_priority_changed',
        'entity_type': 'task',
        'entity_id': 'task-1',
        'metadata': {
          'title': 'Implement Auth',
          'old_value': 'high',
          'new_value': 'low',
        },
      };
      final actPriority = Activity.fromJson(jsonPriority);
      expect(
        actPriority.humanReadableDescription,
        'Task "Implement Auth" priority changed from High to Low',
      );

      final jsonFallbackTitle = {
        'id': 'act-4',
        'actor_user_id': 'user-1',
        'actor_name': 'Amit Sharma',
        'action': 'task_priority_changed',
        'entity_type': 'task',
        'entity_id': '6a9e2c3430b37adc41d8ae55',
        'task_id': '6a9e2c3430b37adc41d8ae55',
        'metadata': {'old_value': 'high', 'new_value': 'low'},
      };
      final actFallback = Activity.fromJson(jsonFallbackTitle);
      expect(actFallback.actorName, 'Amit Sharma');
      expect(actFallback.toJson()['actor_name'], 'Amit Sharma');
      expect(
        actFallback.formatDescription(
          taskTitles: {'6a9e2c3430b37adc41d8ae55': 'Resolved Task Name'},
        ),
        'Task "Resolved Task Name" priority changed from High to Low',
      );
    });

    test('Comment model author_name serialization', () {
      final json = {
        'id': 'comment-2',
        'task_id': 'task-1',
        'user_id': 'user-1',
        'author_name': 'Neha',
        'content': 'Test with author name',
        'created_at': '2026-03-01T12:00:00Z',
        'updated_at': '2026-03-01T12:00:00Z',
      };
      final comment = Comment.fromJson(json);
      expect(comment.authorName, 'Neha');
      expect(comment.toJson()['author_name'], 'Neha');
      final updatedComment = comment.copyWith(authorName: 'Updated Name');
      expect(updatedComment.authorName, 'Updated Name');
    });

    test('Task model assignee_name serialization', () {
      final json = {
        'id': 'task-3',
        'title': 'Task with Assignee Name',
        'description': 'Description',
        'project_id': 'proj-1',
        'assigned_to': 'emp-1',
        'assignee_name': 'Amit Sharma',
        'priority': 'medium',
        'status': 'todo',
        'due_date': '2030-01-01',
      };
      final task = Task.fromJson(json);
      expect(task.assigneeName, 'Amit Sharma');
      expect(task.toJson()['assignee_name'], 'Amit Sharma');
      final updatedTask = task.copyWith(assigneeName: 'New Assignee');
      expect(updatedTask.assigneeName, 'New Assignee');
    });
  });
}
