enum UserRole {
  admin('admin', 'Admin'),
  manager('manager', 'Manager'),
  employee('employee', 'Employee');

  final String value;
  final String label;

  const UserRole(this.value, this.label);

  String get displayName => label;

  static UserRole fromString(String? value) {
    return UserRole.values.firstWhere(
      (r) => r.value.toLowerCase() == (value ?? '').toLowerCase(),
      orElse: () => UserRole.employee,
    );
  }
}

class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String status;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.status = 'active',
  });

  bool get isActive => status.toLowerCase() == 'active';
  bool get isAdmin => role == UserRole.admin;
  bool get isManager => role == UserRole.manager;
  bool get isEmployee => role == UserRole.employee;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String?),
      status: json['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.value,
      'status': status,
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    String? status,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      status: status ?? this.status,
    );
  }

  @override
  String toString() =>
      'User(id: $id, name: $name, email: $email, role: ${role.value})';
}
