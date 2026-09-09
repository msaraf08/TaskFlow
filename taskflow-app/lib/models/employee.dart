class Employee {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String? phone;
  final String department;
  final String role;
  final String? joiningDate;
  final String status;

  const Employee({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    required this.department,
    required this.role,
    this.joiningDate,
    this.status = 'active',
  });

  bool get isActive => status.toLowerCase() == 'active';
  String get formattedJoiningDate => joiningDate ?? 'Not set';

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone']?.toString(),
      department: json['department'] as String? ?? '',
      role: json['role'] as String? ?? 'employee',
      joiningDate: json['joining_date']?.toString(),
      status: json['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'department': department,
      'role': role,
      'joining_date': joiningDate,
      'status': status,
    };
  }

  Employee copyWith({
    String? id,
    String? userId,
    String? name,
    String? email,
    String? phone,
    String? department,
    String? role,
    String? joiningDate,
    String? status,
  }) {
    return Employee(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      department: department ?? this.department,
      role: role ?? this.role,
      joiningDate: joiningDate ?? this.joiningDate,
      status: status ?? this.status,
    );
  }

  @override
  String toString() =>
      'Employee(id: $id, name: $name, department: $department)';
}
