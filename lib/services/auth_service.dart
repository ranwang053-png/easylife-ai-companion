import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/auth_models.dart';

abstract interface class AuthService {
  Future<SendSmsCodeResponse> sendSmsCode(SendSmsCodeRequest request);

  Future<LoginVerificationResponse> verifySmsCode(
    VerifySmsCodeRequest request,
  );

  Future<AuthTokenPair> refreshTokens(RefreshTokenRequest request);

  Future<void> logout({
    required String accessToken,
    required String deviceId,
  });
}

AuthService createAuthService() {
  const baseUrl = String.fromEnvironment('EASYLIFE_API_BASE_URL');
  if (baseUrl.isEmpty) return const UnavailableAuthService();
  return HttpAuthService(baseUri: Uri.parse(baseUrl));
}

class HttpAuthService implements AuthService {
  HttpAuthService({required this.baseUri, http.Client? client})
      : _client = client ?? http.Client();

  final Uri baseUri;
  final http.Client _client;

  @override
  Future<SendSmsCodeResponse> sendSmsCode(
    SendSmsCodeRequest request,
  ) async {
    final json = await _postJson(
      '/v1/auth/sms/codes',
      request.toJson(),
    );
    return SendSmsCodeResponse.fromJson(json);
  }

  @override
  Future<LoginVerificationResponse> verifySmsCode(
    VerifySmsCodeRequest request,
  ) async {
    final json = await _postJson(
      '/v1/auth/sms/verify',
      request.toJson(),
    );
    return LoginVerificationResponse.fromJson(json);
  }

  @override
  Future<AuthTokenPair> refreshTokens(RefreshTokenRequest request) async {
    final json = await _postJson(
      '/v1/auth/token/refresh',
      request.toJson(),
    );
    return AuthTokenPair.fromJson(json);
  }

  @override
  Future<void> logout({
    required String accessToken,
    required String deviceId,
  }) async {
    final response = await _client
        .post(
          baseUri.resolve('/v1/auth/logout'),
          headers: _headers(accessToken: accessToken),
          body: jsonEncode({'deviceId': deviceId}),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 204) {
      throw _authException(response);
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client
          .post(
            baseUri.resolve(path),
            headers: _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _authException(response);
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on AuthException {
      rethrow;
    } on Exception {
      throw const AuthException(
        code: AuthErrorCode.smsProviderUnavailable,
        message: '认证服务暂时不可用',
      );
    }
  }

  Map<String, String> _headers({String? accessToken}) => {
        'content-type': 'application/json',
        'X-Request-Id': _randomUuid(),
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

  AuthException _authException(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final error = body['error'] as Map<String, dynamic>;
      return AuthException(
        code: AuthErrorCode.fromWireValue(error['code'] as String),
        message: error['message'] as String,
        requestId: error['requestId'] as String?,
      );
    } on Exception {
      return const AuthException(
        code: AuthErrorCode.smsProviderUnavailable,
        message: '认证服务暂时不可用',
      );
    }
  }
}

class UnavailableAuthService implements AuthService {
  const UnavailableAuthService();

  Never _unavailable() => throw const AuthException(
        code: AuthErrorCode.smsProviderUnavailable,
        message: '尚未配置认证服务地址',
      );

  @override
  Future<void> logout({
    required String accessToken,
    required String deviceId,
  }) async =>
      _unavailable();

  @override
  Future<AuthTokenPair> refreshTokens(RefreshTokenRequest request) async =>
      _unavailable();

  @override
  Future<SendSmsCodeResponse> sendSmsCode(
    SendSmsCodeRequest request,
  ) async =>
      _unavailable();

  @override
  Future<LoginVerificationResponse> verifySmsCode(
    VerifySmsCodeRequest request,
  ) async =>
      _unavailable();
}

class FixedExampleAuthService implements AuthService {
  const FixedExampleAuthService();

  static const deviceId = '6ecb2ba5-6c51-4a40-b908-8be4311c7f85';
  static const exampleCode = '123456';

  static const _sendResponse = <String, dynamic>{
    'challengeId': '984e6346-f8a1-4511-8ec2-a960bc338705',
    'expiresIn': 300,
    'resendAfter': 60,
  };

  static const _verifyResponse = <String, dynamic>{
    'purpose': 'login',
    'isNewUser': true,
    'user': {
      'id': 'e0e00cc4-f640-4975-b21f-ad93c28b67f0',
      'phoneMasked': '138****5678',
    },
    'tokens': {
      'accessToken': 'example-access-token-with-at-least-twenty-characters',
      'accessTokenExpiresIn': 900,
      'refreshToken': 'example-refresh-token-with-at-least-twenty-characters',
      'refreshTokenExpiresIn': 2592000,
    },
  };

  @override
  Future<SendSmsCodeResponse> sendSmsCode(
    SendSmsCodeRequest request,
  ) async {
    _validatePhone(request.phone);
    if (request.purpose != SmsPurpose.login || request.deviceId.isEmpty) {
      throw const AuthException(
        code: AuthErrorCode.validationError,
        message: '请求内容不符合接口要求',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return SendSmsCodeResponse.fromJson(_sendResponse);
  }

  @override
  Future<LoginVerificationResponse> verifySmsCode(
    VerifySmsCodeRequest request,
  ) async {
    _validatePhone(request.phone);
    if (request.challengeId != _sendResponse['challengeId'] ||
        request.deviceId.isEmpty) {
      throw const AuthException(
        code: AuthErrorCode.validationError,
        message: '请求内容不符合接口要求',
      );
    }
    if (request.code != exampleCode) {
      throw const AuthException(
        code: AuthErrorCode.smsCodeInvalid,
        message: '验证码错误',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return LoginVerificationResponse.fromJson(_verifyResponse);
  }

  @override
  Future<AuthTokenPair> refreshTokens(RefreshTokenRequest request) async {
    if (request.refreshToken !=
        'example-refresh-token-with-at-least-twenty-characters') {
      throw const AuthException(
        code: AuthErrorCode.invalidRefreshToken,
        message: '登录状态已失效，请重新登录',
      );
    }
    return const AuthTokenPair(
      accessToken: 'rotated-access-token-with-at-least-twenty-characters',
      accessTokenExpiresIn: 900,
      refreshToken: 'rotated-refresh-token-with-at-least-twenty-characters',
      refreshTokenExpiresIn: 2592000,
    );
  }

  @override
  Future<void> logout({
    required String accessToken,
    required String deviceId,
  }) async {}

  void _validatePhone(String phone) {
    if (!RegExp(r'^\+861[3-9][0-9]{9}$').hasMatch(phone)) {
      throw const AuthException(
        code: AuthErrorCode.validationError,
        message: '请输入有效的中国大陆手机号',
      );
    }
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
