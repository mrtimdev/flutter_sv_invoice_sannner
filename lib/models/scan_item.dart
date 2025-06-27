// models/scan_item.dart
class ScanItem {
  final int id;
  final String imagePath; // Full URL from backend response
  final String scannedText;
  final String text;
  final DateTime date; 
  final ScanUser user;      // Nested user object

  ScanItem({
    required this.id,
    required this.imagePath,
    required this.scannedText,
    required this.text,
    required this.date,
    required this.user,
  });

  factory ScanItem.fromJson(Map<String, dynamic> json) {
    return ScanItem(
      id: json['id'] as int,
      imagePath: json['imagePath'] as String, // Full URL
      scannedText: json['scannedText'] as String,
      text: json['scannedText'] as String,
      // Parse the 'timestamp' or 'date' string to DateTime
      // Assuming 'date' is preferred for the actual scan time
      date: DateTime.parse(json['date'] as String),
      user: ScanUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class ScanUser {
  final int id;
  final String? username;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? fullName;

  ScanUser({
    required this.id,
    this.username,
    this.email,
    this.firstName,
    this.lastName,
    this.fullName,
  });

  factory ScanUser.fromJson(Map<String, dynamic> json) {
    return ScanUser(
      id: json['id'] as int,
      username: json['username'] as String?,
      email: json['email'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      fullName: json['full_name'] as String?,
    );
  }
}
