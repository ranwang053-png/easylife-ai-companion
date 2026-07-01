enum SmsPurpose {
  login('login'),
  accountDeletion('account_deletion');

  const SmsPurpose(this.wireValue);

  final String wireValue;
}

class SendSmsCodeRequest {
  const SendSmsCodeRequest({
    required this.phone,
    required this.purpose,
    required this.deviceId,
  });

  final String phone;
  final SmsPurpose purpose;
  final String deviceId;

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'purpose': purpose.wireValue,
        'deviceId': deviceId,
      };
}

class SendSmsCodeResponse {
  const SendSmsCodeResponse({
    required this.challengeId,
    required this.expiresIn,
    required this.resendAfter,
  });

  final String challengeId;
  final int expiresIn;
  final int resendAfter;

  factory SendSmsCodeResponse.fromJson(Map<String, dynamic> json) {
    return SendSmsCodeResponse(
      challengeId: json['challengeId'] as String,
      expiresIn: json['expiresIn'] as int,
      resendAfter: json['resendAfter'] as int,
    );
  }
}

class VerifySmsCodeRequest {
  const VerifySmsCodeRequest({
    required this.challengeId,
    required this.phone,
    required this.code,
    required this.deviceId,
  });

  final String challengeId;
  final String phone;
  final String code;
  final String deviceId;

  Map<String, dynamic> toJson() => {
        'challengeId': challengeId,
        'phone': phone,
        'code': code,
        'deviceId': deviceId,
      };
}

class AuthUser {
  const AuthUser({required this.id, required this.phoneMasked});

  final String id;
  final String phoneMasked;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      phoneMasked: json['phoneMasked'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'phoneMasked': phoneMasked};
}

class AuthTokenPair {
  const AuthTokenPair({
    required this.accessToken,
    required this.accessTokenExpiresIn,
    required this.refreshToken,
    required this.refreshTokenExpiresIn,
  });

  final String accessToken;
  final int accessTokenExpiresIn;
  final String refreshToken;
  final int refreshTokenExpiresIn;

  factory AuthTokenPair.fromJson(Map<String, dynamic> json) {
    return AuthTokenPair(
      accessToken: json['accessToken'] as String,
      accessTokenExpiresIn: json['accessTokenExpiresIn'] as int,
      refreshToken: json['refreshToken'] as String,
      refreshTokenExpiresIn: json['refreshTokenExpiresIn'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'accessTokenExpiresIn': accessTokenExpiresIn,
        'refreshToken': refreshToken,
        'refreshTokenExpiresIn': refreshTokenExpiresIn,
      };
}

class RefreshTokenRequest {
  const RefreshTokenRequest({
    required this.refreshToken,
    required this.deviceId,
  });

  final String refreshToken;
  final String deviceId;

  Map<String, dynamic> toJson() => {
        'refreshToken': refreshToken,
        'deviceId': deviceId,
      };
}

class LoginVerificationResponse {
  const LoginVerificationResponse({
    required this.purpose,
    required this.isNewUser,
    required this.user,
    required this.tokens,
  });

  final SmsPurpose purpose;
  final bool isNewUser;
  final AuthUser user;
  final AuthTokenPair tokens;

  factory LoginVerificationResponse.fromJson(Map<String, dynamic> json) {
    return LoginVerificationResponse(
      purpose: SmsPurpose.values.singleWhere(
        (purpose) => purpose.wireValue == json['purpose'],
      ),
      isNewUser: json['isNewUser'] as bool,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      tokens: AuthTokenPair.fromJson(json['tokens'] as Map<String, dynamic>),
    );
  }
}

enum AuthErrorCode {
  validationError('VALIDATION_ERROR'),
  unauthorized('UNAUTHORIZED'),
  smsCodeExpired('SMS_CODE_EXPIRED'),
  smsCodeInvalid('SMS_CODE_INVALID'),
  verificationAttemptsExceeded('VERIFICATION_ATTEMPTS_EXCEEDED'),
  rateLimited('RATE_LIMITED'),
  smsProviderUnavailable('SMS_PROVIDER_UNAVAILABLE'),
  invalidRefreshToken('INVALID_REFRESH_TOKEN');

  const AuthErrorCode(this.wireValue);

  final String wireValue;

  static AuthErrorCode fromWireValue(String value) {
    return AuthErrorCode.values.firstWhere(
      (code) => code.wireValue == value,
      orElse: () => AuthErrorCode.validationError,
    );
  }
}

class AuthException implements Exception {
  const AuthException({
    required this.code,
    required this.message,
    this.requestId,
  });

  final AuthErrorCode code;
  final String message;
  final String? requestId;

  @override
  String toString() => '${code.wireValue}: $message';
}
