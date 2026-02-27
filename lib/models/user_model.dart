class User {
  final String email;
  final String name;
  final String createdAt;

  User({
    required this.email,
    required this.name,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      email: json['email'] as String,
      name: json['name'] as String,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
      'created_at': createdAt,
    };
  }

  @override
  String toString() => 'User(email: $email, name: $name)';
}
