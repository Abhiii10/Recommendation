import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rural_tourism_app/features/auth/data/services/auth_api_service.dart';

class AuthSessionService extends ChangeNotifier {
  AuthSessionService({AuthApiService? apiService})
      : _apiService = apiService ?? AuthApiService();

  static final AuthSessionService instance = AuthSessionService();

  static const String _sessionKey = 'auth_session';

  final AuthApiService _apiService;
  AuthSession? _session;
  bool _initialized = false;

  AuthSession? get session => _session;
  AuthUserAccount? get user => _session?.user;
  String? get token => _session?.accessToken;
  bool get isAuthenticated => _session != null;
  String get displayName => user?.username.trim().isNotEmpty == true
      ? user!.username
      : user?.email ?? 'Guest';

  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);

    if (raw != null && raw.isNotEmpty) {
      try {
        _session = AuthSession.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {
        await prefs.remove(_sessionKey);
      }
    }

    _initialized = true;
    notifyListeners();
  }

  Future<String?> currentUserId() async {
    await init();
    final id = _session?.user.id.trim();
    return id == null || id.isEmpty ? null : id;
  }

  Future<String?> currentToken() async {
    await init();
    final value = _session?.accessToken.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final session = await _apiService.register(
      username: username,
      email: email,
      password: password,
    );
    await _saveSession(session);
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final session = await _apiService.login(
      email: email,
      password: password,
    );
    await _saveSession(session);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    _session = null;
    _initialized = true;
    notifyListeners();
  }

  Future<void> refreshCurrentUser() async {
    await init();
    final existing = _session;
    if (existing == null) return;

    final user = await _apiService.me(existing.accessToken);
    await _saveSession(
      AuthSession(
        accessToken: existing.accessToken,
        tokenType: existing.tokenType,
        user: user,
      ),
    );
  }

  Future<void> _saveSession(AuthSession session) async {
    _session = session;
    _initialized = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
    } catch (error) {
      debugPrint('Auth session memory-only save: $error');
    }
  }
}
