class ApiEndpoints {
  static const String rootUrl = 'http://192.168.1.160:3000';
  static const String baseUrl = '$rootUrl/api';

  // Auth endpoints
  static const String login = '$baseUrl/auth/login';
  static const String register = '$baseUrl/auth/register';

  // Scan endpoints
  static const String createScan = '$baseUrl/scans';
  static const String getScans = '$baseUrl/scans';
  static String deleteScan(String id) => '$baseUrl/scans/$id';

  // User endpoints
  static const String getUserProfile = '$baseUrl/auth/me';
}
