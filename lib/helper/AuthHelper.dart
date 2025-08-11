class AuthHelper {
  // Check if user has any role
  static bool hasAnyRole(Map<String, dynamic> user) {
    return user['roles'] != null && (user['roles'] as List).isNotEmpty;
  }

  // Check if user has a specific role by code
  static bool hasRole(Map<String, dynamic> user, String roleCode) {
    if (user['roles'] == null) return false;
    final roles = user['roles'] as List;
    return roles.any((role) => role['code'] == roleCode);
  }

  // Check if user is admin
  static bool isAdmin(Map<String, dynamic> user) {
    return hasRole(user, 'admin');
  }

  // Get all role codes
  static List<String> getRoleCodes(Map<String, dynamic> user) {
    if (user['roles'] == null) return [];
    final roles = user['roles'] as List;
    return roles.map<String>((role) => role['code'].toString()).toList();
  }

  // Get all role names
  static List<String> getRoleNames(Map<String, dynamic> user) {
    if (user['roles'] == null) return [];
    final roles = user['roles'] as List;
    return roles.map<String>((role) => role['name'].toString()).toList();
  }
}