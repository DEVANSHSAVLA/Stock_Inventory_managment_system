class UserModel {
  final int id;
  final String email;
  final String username;
  final String firstName;
  final String lastName;
  final String role;
  final bool isActive;
  final String? phone;

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.isActive,
    this.phone,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'],
    email: json['email'],
    username: json['username'] ?? '',
    firstName: json['first_name'] ?? '',
    lastName: json['last_name'] ?? '',
    role: json['role'] ?? 'STAFF',
    isActive: json['is_active'] ?? true,
    phone: json['phone'],
  );

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? email : name;
  }

  bool get isAdmin => role == 'ADMIN';
  bool get isManager => role == 'MANAGER';
  bool get isStaff => role == 'STAFF';
  bool get isWarehouse => role == 'WAREHOUSE';
  bool get isSales => role == 'SALES';
  bool get isViewer => role == 'VIEWER';

  bool get canApprove => isAdmin || isManager;
  bool get canViewReports => isAdmin || isManager;
  bool get canManageUsers => isAdmin;
  bool get canCreateOrders => isAdmin || isManager || isSales || isStaff;
  bool get canDispatchOrders => isAdmin || isWarehouse;
}
