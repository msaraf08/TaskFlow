enum ProjectStatus {
  planned('planned', 'Planned'),
  active('active', 'Active'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled');

  final String value;
  final String label;

  const ProjectStatus(this.value, this.label);

  String get displayName => label;

  static ProjectStatus fromString(String? value) {
    return ProjectStatus.values.firstWhere(
      (s) => s.value.toLowerCase() == (value ?? '').toLowerCase(),
      orElse: () => ProjectStatus.planned,
    );
  }
}

class Project {
  final String id;
  final String name;
  final String description;
  final String teamId;
  final String startDate;
  final String endDate;
  final ProjectStatus status;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Project({
    required this.id,
    required this.name,
    this.description = '',
    required this.teamId,
    this.startDate = '',
    this.endDate = '',
    required this.status,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  DateTime? get startDateTime => DateTime.tryParse(startDate);
  DateTime? get endDateTime => DateTime.tryParse(endDate);

  String get formattedStartDate => startDate.isNotEmpty ? startDate : 'Not set';
  String get formattedEndDate => endDate.isNotEmpty ? endDate : 'Not set';

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      teamId: json['team_id'] as String? ?? '',
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      status: ProjectStatus.fromString(json['status'] as String?),
      createdBy: json['created_by'] as String? ?? '',
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
      'name': name,
      'description': description,
      'team_id': teamId,
      'start_date': startDate,
      'end_date': endDate,
      'status': status.value,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Project copyWith({
    String? id,
    String? name,
    String? description,
    String? teamId,
    String? startDate,
    String? endDate,
    ProjectStatus? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      teamId: teamId ?? this.teamId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'Project(id: $id, name: $name, status: ${status.value})';
}
