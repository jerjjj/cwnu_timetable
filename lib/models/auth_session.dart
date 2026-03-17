class AuthSession {
  const AuthSession({
    required this.username,
    required this.password,
    required this.jwxtPassword,
  });

  final String username;
  final String password;
  final String jwxtPassword;
}
