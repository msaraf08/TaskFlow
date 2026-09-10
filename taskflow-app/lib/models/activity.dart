class Activity {
  final String id;
  final String actorUserId;
  final String? actorName;
  final String action;
  final String entityType;
  final String entityId;
  final String? taskId;
  final String? projectId;
  final String? teamId;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const Activity({
    required this.id,
    required this.actorUserId,
    this.actorName,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.taskId,
    this.projectId,
    this.teamId,
    this.metadata,
    required this.createdAt,
  });

  String get formattedDate {
    final y = createdAt.year;
    final m = createdAt.month.toString().padLeft(2, '0');
    final d = createdAt.day.toString().padLeft(2, '0');
    final h = createdAt.hour.toString().padLeft(2, '0');
    final min = createdAt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  static String _formatValue(dynamic val) {
    if (val == null) return '';
    final s = val.toString().trim();
    switch (s.toLowerCase()) {
      case 'todo':
        return 'To Do';
      case 'in_progress':
        return 'In Progress';
      case 'review':
        return 'In Review';
      case 'done':
      case 'completed':
        return 'Completed';
      case 'low':
        return 'Low';
      case 'medium':
        return 'Medium';
      case 'high':
        return 'High';
      case 'urgent':
        return 'Urgent';
      case 'employee':
        return 'Employee';
      case 'manager':
        return 'Manager';
      case 'admin':
        return 'Admin';
      case 'planned':
        return 'Planned';
      case 'active':
        return 'Active';
      case 'on_hold':
        return 'On Hold';
      case 'cancelled':
        return 'Cancelled';
      default:
        return s;
    }
  }

  String formatDescription({Map<String, String>? taskTitles}) {
    String title = metadata?['title'] ?? metadata?['name'] ?? '';
    if (title.isEmpty && (entityType == 'task' || taskId != null)) {
      final tid = taskId ?? entityId;
      if (taskTitles != null && taskTitles.containsKey(tid)) {
        title = taskTitles[tid]!;
      }
    }
    if (title.isEmpty) {
      title = entityId;
    }

    final rawOld = metadata?['old_value'];
    final rawNew = metadata?['new_value'];
    final oldValue = _formatValue(rawOld);
    final newValue = _formatValue(rawNew);

    final actor =
        (actorName != null &&
            actorName!.isNotEmpty &&
            actorName != 'Unknown User')
        ? actorName!
        : null;

    final targetName = metadata?['name'] ?? title;

    switch (action) {
      case 'task_created':
        return actor != null
            ? '$actor created task "$title"'
            : 'Task "$title" was created';
      case 'task_updated':
        return actor != null
            ? '$actor updated task "$title"'
            : 'Task "$title" was updated';
      case 'task_deleted':
        return actor != null
            ? '$actor deleted task "$title"'
            : 'Task "$title" was deleted';
      case 'task_status_changed':
        return actor != null
            ? '$actor changed task "$title" status from $oldValue to $newValue'
            : 'Task "$title" status changed from $oldValue to $newValue';
      case 'task_priority_changed':
        return actor != null
            ? '$actor changed task "$title" priority from $oldValue to $newValue'
            : 'Task "$title" priority changed from $oldValue to $newValue';
      case 'task_assigned_changed':
        return actor != null
            ? '$actor reassigned task "$title"'
            : 'Task "$title" was reassigned';
      case 'task_project_changed':
        return actor != null
            ? '$actor moved task "$title" to another project'
            : 'Task "$title" was moved to another project';
      case 'comment_created':
        return actor != null
            ? '$actor added a comment on task "$title"'
            : 'New comment added on task "$title"';
      case 'comment_updated':
        return actor != null
            ? '$actor updated a comment on task "$title"'
            : (title.isNotEmpty && title != entityId
                  ? 'Comment on task "$title" was updated'
                  : 'Comment was updated');
      case 'comment_deleted':
        return actor != null
            ? '$actor deleted a comment on task "$title"'
            : (title.isNotEmpty && title != entityId
                  ? 'Comment on task "$title" was deleted'
                  : 'Comment was deleted');
      case 'user_role_changed':
        final subject = targetName.isNotEmpty && targetName != entityId
            ? targetName
            : 'user';
        return actor != null
            ? '$actor changed $subject\'s role from $oldValue to $newValue'
            : 'Role for $subject changed from $oldValue to $newValue';
      default:
        return actor != null
            ? '$actor performed $action on $entityType'
            : '$entityType was $action';
    }
  }

  String get humanReadableDescription => formatDescription();

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      actorUserId: json['actor_user_id'] as String? ?? '',
      actorName: json['actor_name'] as String?,
      action: json['action'] as String? ?? '',
      entityType: json['entity_type'] as String? ?? '',
      entityId: json['entity_id'] as String? ?? '',
      taskId: json['task_id'] as String?,
      projectId: json['project_id'] as String?,
      teamId: json['team_id'] as String?,
      metadata: json['metadata'] is Map
          ? (json['metadata'] as Map).cast<String, dynamic>()
          : null,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'actor_user_id': actorUserId,
      'actor_name': actorName,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'task_id': taskId,
      'project_id': projectId,
      'team_id': teamId,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'Activity(id: $id, action: $action, actor: $actorUserId)';
}
