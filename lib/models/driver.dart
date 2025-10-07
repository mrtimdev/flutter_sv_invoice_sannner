class Driver {
  final int? id;
  final String firstName;
  final String lastName;
  final String phone;
  final String plateNumber;

  Driver({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.plateNumber,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      phone: json['phone'],
      plateNumber: json['plateNumber'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'plateNumber': plateNumber,
    };
  }
}