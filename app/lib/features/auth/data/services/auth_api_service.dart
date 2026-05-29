import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:rural_tourism_app/core/utils/backend_config.dart';

class AuthApiException implements Exception {
  final String message;

  const AuthApiException(this.message);

  @override
  String toString() => message;
}

class AuthUserAccount {
  final String id;
  final String username;
  final String email;

  const AuthUserAccount({
    required this.id,
    required this.username,
    required this.email,
  });

  factory AuthUserAccount.fromJson(Map<String, dynamic> json) {
    return AuthUserAccount(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
    };
  }
}

class AuthSession {
  final String accessToken;
  final String tokenType;
  final AuthUserAccount user;

  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token']?.toString() ?? '',
      tokenType: json['token_type']?.toString() ?? 'bearer',
      user: AuthUserAccount.fromJson(
        Map<String, dynamic>.from(json['user'] as Map? ?? const {}),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'token_type': tokenType,
      'user': user.toJson(),
    };
  }
}

class AuthApiService {
  final String baseUrl;
  final Duration timeout;

  AuthApiService({
    String? baseUrl,
    this.timeout = const Duration(seconds: 60),
  }) : baseUrl = baseUrl ?? backendBaseUrl;

  Uri _uri(String path) {
    final normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalizedBaseUrl$path');
  }

  Future<AuthSession> register({
    required String username,
    required String email,
    required String password,
  }) async {
    return _postSession('/auth/register', {
      'username': username,
      'email': email,
      'password': password,
    });
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    return _postSession('/auth/login', {
      'email': email,
      'password': password,
    });
  }

  Future<AuthUserAccount> me(String token) async {
    final response = await http.get(
      _uri('/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(timeout);

    final data = _decode(response);
    return AuthUserAccount.fromJson(data);
  }

  Future<AuthSession> _postSession(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .post(
          _uri(path),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(timeout);

    return AuthSession.fromJson(_decode(response));
  }

  Map<String, dynamic> _decode(http.Response response) {
    final Map<String, dynamic> decoded;

    try {
      final raw = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      decoded = raw is Map<String, dynamic>
          ? raw
          : raw is Map
              ? Map<String, dynamic>.from(raw)
              : <String, dynamic>{};
    } catch (_) {
      throw AuthApiException(
        'Backend returned an unreadable response (${response.statusCode}).',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final detail = decoded['detail']?.toString();
    throw AuthApiException(
      detail == null || detail.isEmpty
          ? 'Authentication request failed.'
          : detail,
    );
  }
}
