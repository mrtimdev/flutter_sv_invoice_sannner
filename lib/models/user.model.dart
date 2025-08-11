class Role {
  final int id;
  final String code;
  final String name;
  final String description;

  Role({required this.id, required this.code, required this.name, required this.description});

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'],
      code: json['code'],
      name: json['name'],
      description: json['description'],
    );
  }
}

class User {
  final int id;
  final String username;
  final String email;
  final List<Role> roles;

  User({required this.id, required this.username, required this.email, required this.roles});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      roles: (json['roles'] as List).map((role) => Role.fromJson(role)).toList(),
    );
  }

  bool hasRole(String roleCode) => roles.any((role) => role.code == roleCode);
  bool get isAdmin => hasRole('admin');
}