import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_models.dart';
import 'auth_service.dart';

class AuthSession {
  const AuthSession({
    required this.user,
    required this.tokens,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
  });

  final AuthUser user;
  final AuthTokenPair tokens;
  final DateTime accessTokenExpiresAt;
  final DateTime refreshTokenExpiresAt;

  factory AuthSession.fromLogin(
    LoginVerificationResponse response, {
    DateTime? now,
  }) {
    final issuedAt = now ?? DateTime.now();
    return AuthSession(
      user: response.user,
      tokens: response.tokens,
      accessTokenExpiresAt: issuedAt.add(
        Duration(seconds: response.tokens.accessTokenExpiresIn),
      ),
      refreshTokenExpiresAt: issuedAt.add(
        Duration(seconds: response.tokens.refreshTokenExpiresIn),
      ),
    );
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      tokens: AuthTokenPair.fromJson(json['tokens'] as Map<String, dynamic>),
      accessTokenExpiresAt:
          DateTime.parse(json['accessTokenExpiresAt'] as String),
      refreshTokenExpiresAt:
          DateTime.parse(json['refreshTokenExpiresAt'] as String),
    );
  }

  AuthSession withTokens(AuthTokenPair next, {DateTime? now}) {
    final issuedAt = now ?? DateTime.now();
    return AuthSession(
      user: user,
      tokens: next,
      accessTokenExpiresAt:
          issuedAt.add(Duration(seconds: next.accessTokenExpiresIn)),
      refreshTokenExpiresAt:
          issuedAt.add(Duration(seconds: next.refreshTokenExpiresIn)),
    );
  }

  Map<String, dynamic> toJson() => {
        'user': user.toJson(),
        'tokens': tokens.toJson(),
        'accessTokenExpiresAt': accessTokenExpiresAt.toIso8601String(),
        'refreshTokenExpiresAt': refreshTokenExpiresAt.toIso8601String(),
      };
}

abstract interface class AuthSessionStore {
  Future<AuthSession?> readSession();

  Future<void> writeSession(AuthSession session);

  Future<void> clearSession();

  Future<String> getOrCreateDeviceId();
}

class SecureAuthSessionStore implements AuthSessionStore {
  SecureAuthSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'easylife.auth.session.v1';
  static const _deviceIdKey = 'easylife.auth.device_id.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<void> clearSession() => _storage.delete(key: _sessionKey);

  @override
  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = _randomUuid();
    await _storage.write(key: _deviceIdKey, value: created);
    return created;
  }

  @override
  Future<AuthSession?> readSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null) return null;
    try {
      return AuthSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on Exception {
      await clearSession();
      return null;
    }
  }

  @override
  Future<void> writeSession(AuthSession session) =>
      _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
}

class MemoryAuthSessionStore implements AuthSessionStore {
  AuthSession? session;
  String? deviceId;

  @override
  Future<void> clearSession() async {
    session = null;
  }

  @override
  Future<String> getOrCreateDeviceId() async =>
      deviceId ??= FixedExampleAuthService.deviceId;

  @override
  Future<AuthSession?> readSession() async => session;

  @override
  Future<void> writeSession(AuthSession value) async {
    session = value;
  }
}

class AuthSessionManager {
  AuthSessionManager({
    required this.authService,
    required this.store,
  });

  final AuthService authService;
  final AuthSessionStore store;

  AuthSession? _session;
  String? _deviceId;

  AuthSession? get session => _session;

  Future<String> get deviceId async =>
      _deviceId ??= await store.getOrCreateDeviceId();

  Future<AuthSession?> restore() async {
    _session = await store.readSession();
    if (_session == null) return null;
    if (!_session!.refreshTokenExpiresAt.isAfter(DateTime.now())) {
      await clear();
      return null;
    }
    try {
      await validAccessToken();
      return _session;
    } on AuthException {
      await clear();
      return null;
    }
  }

  Future<AuthSession> establish(LoginVerificationResponse response) async {
    final next = AuthSession.fromLogin(response);
    _session = next;
    await store.writeSession(next);
    return next;
  }

  Future<String?> validAccessToken() async {
    final current = _session;
    if (current == null) return null;
    final refreshAt =
        current.accessTokenExpiresAt.subtract(const Duration(seconds: 30));
    if (refreshAt.isAfter(DateTime.now())) {
      return current.tokens.accessToken;
    }
    try {
      final nextTokens = await authService.refreshTokens(
        RefreshTokenRequest(
          refreshToken: current.tokens.refreshToken,
          deviceId: await deviceId,
        ),
      );
      final next = current.withTokens(nextTokens);
      _session = next;
      await store.writeSession(next);
      return next.tokens.accessToken;
    } on AuthException {
      await clear();
      rethrow;
    }
  }

  Future<void> logout() async {
    final current = _session;
    if (current != null) {
      try {
        await authService.logout(
          accessToken: current.tokens.accessToken,
          deviceId: await deviceId,
        );
      } on AuthException {
        // Local logout must still complete when the remote session is stale.
      }
    }
    await clear();
  }

  Future<void> clear() async {
    _session = null;
    await store.clearSession();
  }
}

String _randomUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
