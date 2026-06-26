enum UserRole { owner, admin, worker }

extension UserRoleX on UserRole {
  String get apiName => switch (this) {
    UserRole.owner => 'OWNER',
    UserRole.admin => 'ADMIN',
    UserRole.worker => 'WORKER',
  };

  String get label => switch (this) {
    UserRole.owner => 'Owner',
    UserRole.admin => 'Admin',
    UserRole.worker => 'Worker',
  };

  static UserRole fromApi(String? value) {
    return switch (value) {
      'OWNER' => UserRole.owner,
      'ADMIN' => UserRole.admin,
      _ => UserRole.worker,
    };
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.firstname,
    required this.lastname,
    required this.role,
    this.email,
    this.address,
    this.enabled = true,
  });

  final int id;
  final String username;
  final String firstname;
  final String lastname;
  final String? email;
  final String? address;
  final bool enabled;
  final UserRole role;

  String get fullName => '$firstname $lastname'.trim();
  bool get hasProfile =>
      username.trim().isNotEmpty ||
      firstname.trim().isNotEmpty ||
      lastname.trim().isNotEmpty ||
      (email?.trim().isNotEmpty ?? false);

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['userId'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      firstname: json['firstname'] as String? ?? '',
      lastname: json['lastname'] as String? ?? '',
      email: json['email'] as String?,
      address: json['address'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      role: UserRoleX.fromApi(json['role'] as String?),
    );
  }

  Map<String, dynamic> toUpdateJson() => {
    'username': username,
    'firstname': firstname,
    'lastname': lastname,
    'email': email,
    'address': address,
    'role': role.apiName,
    'enabled': enabled,
  };
}
