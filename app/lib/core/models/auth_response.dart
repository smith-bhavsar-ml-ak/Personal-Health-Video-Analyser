class AuthResponse {
  final String accessToken;
  final String email;

  const AuthResponse({required this.accessToken, required this.email});

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        accessToken: json['access_token'] as String,
        email:       json['email']        as String,
      );
}
