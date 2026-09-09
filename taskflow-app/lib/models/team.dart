class Team {
  final String id;
  final String name;
  final String? description;
  final String? managerId;
  final List<String> memberIds;

  const Team({
    required this.id,
    required this.name,
    this.description,
    this.managerId,
    this.memberIds = const [],
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      managerId: json['manager_id'] as String?,
      memberIds:
          (json['member_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'manager_id': managerId,
      'member_ids': memberIds,
    };
  }

  Team copyWith({
    String? id,
    String? name,
    String? description,
    String? managerId,
    List<String>? memberIds,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      managerId: managerId ?? this.managerId,
      memberIds: memberIds ?? this.memberIds,
    );
  }

  @override
  String toString() =>
      'Team(id: $id, name: $name, members: ${memberIds.length})';
}
