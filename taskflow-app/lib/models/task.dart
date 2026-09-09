enum TaskPriority {
  low('low', 'Low'),
  medium('medium', 'Medium'),
  high('high', 'High'),
  urgent('urgent', 'Urgent');

  final String value;
  final String label;

  const TaskPriority(this.value, this.label);

  String get displayName => label;

  static TaskPriority fromString(String? value) {
    return TaskPriority.values.firstWhere(
      (p) => p.value.toLowerCase() == (value ?? '').toLowerCase(),
      orElse: () => TaskPriority.medium,
    );
  }
}

enum TaskStatus {
  todo('todo', 'To Do'),
  inProgress('in_progress', 'In Progress'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled');

  final String value;
  final String label;

  const TaskStatus(this.value, this.label);

  String get displayName => label;

  static TaskStatus fromString(String? value) {
    return TaskStatus.values.firstWhere(
      (s) => s.value.toLowerCase() == (value ?? '').toLowerCase(),
      orElse: () => TaskStatus.todo,
    );
  }
}

class Task {
  final String id;
  final String title;
  final String description;
  final String projectId;
  final String assignedTo;
  final String? assigneeName;
  final TaskPriority priority;
  final TaskStatus status;
  final String dueDate;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Task({
    required this.id,
    required this.title,
    this.description = '',
    required this.projectId,
    required this.assignedTo,
    this.assigneeName,
    required this.priority,
    required this.status,
    this.dueDate = '',
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  DateTime? get dueDateTime => DateTime.tryParse(dueDate);
  String get formattedDueDate => dueDate.isNotEmpty ? dueDate : 'Not set';
  bool get hasDueDate => dueDate.isNotEmpty;

  bool get isOverdue {
    final d = dueDateTime;
    if (d == null ||
        status == TaskStatus.completed ||
        status == TaskStatus.cancelled) {
      return false;
    }
    final now = DateTime.now();
    return d.isBefore(DateTime(now.year, now.month, now.day));
  }

  bool get isDueSoon {
    final d = dueDateTime;
    if (d == null ||
        status == TaskStatus.completed ||
        status == TaskStatus.cancelled) {
      return false;
    }
    final now = DateTime.now();
    final diff = d.difference(DateTime(now.year, now.month, now.day)).inDays;
    return diff >= 0 && diff <= 2;
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      projectId: json['project_id'] as String? ?? '',
      assignedTo: json['assigned_to'] as String? ?? '',
      assigneeName: json['assignee_name'] as String?,
      priority: TaskPriority.fromString(json['priority'] as String?),
      status: TaskStatus.fromString(json['status'] as String?),
      dueDate: json['due_date']?.toString() ?? '',
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'project_id': projectId,
      'assigned_to': assignedTo,
      'assignee_name': assigneeName,
      'priority': priority.value,
      'status': status.value,
      'due_date': dueDate,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? projectId,
    String? assignedTo,
    String? assigneeName,
    TaskPriority? priority,
    TaskStatus? status,
    String? dueDate,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      projectId: projectId ?? this.projectId,
      assignedTo: assignedTo ?? this.assignedTo,
      assigneeName: assigneeName ?? this.assigneeName,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'Task(id: $id, title: $title, status: ${status.value}, priority: ${priority.value})';
}
