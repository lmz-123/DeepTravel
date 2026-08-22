class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.accountKind,
  });

  final String id;
  final String? username;
  final String accountKind;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        username: json['username'] as String?,
        accountKind: json['account_kind'] as String,
      );
}

class AuthSession {
  const AuthSession({required this.user, required this.token});

  final AuthUser user;
  final String token;
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}
