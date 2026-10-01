class User {
  final int id;
  final String phone;
  final String? displayName;
  final String? city;
  final bool isAdmin;

  const User({
    required this.id,
    required this.phone,
    this.displayName,
    this.city,
    this.isAdmin = false,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    phone: json['phone'] as String,
    displayName: json['display_name'] as String?,
    city: json['city'] as String?,
    isAdmin: json['is_admin'] as bool? ?? false,
  );

  bool get isProfileComplete => displayName != null && city != null;
}
