import 'package:company_app/main.dart';
import 'package:company_app/models/auth_models.dart';
import 'package:company_app/services/auth_session_service.dart';
import 'package:company_app/services/auth_service.dart';
import 'package:company_app/services/local_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _tokens = AuthTokenPair(
  accessToken: 'test-access-token-with-at-least-twenty-characters',
  accessTokenExpiresIn: 900,
  refreshToken: 'test-refresh-token-with-at-least-twenty-characters',
  refreshTokenExpiresIn: 2592000,
);

class _FakeAuthService implements AuthService {
  _FakeAuthService({
    this.isNewUser = true,
    this.sendError,
    this.verifyError,
  });

  final bool isNewUser;
  final AuthErrorCode? sendError;
  final AuthErrorCode? verifyError;

  @override
  Future<void> logout({
    required String accessToken,
    required String deviceId,
  }) async {}

  @override
  Future<AuthTokenPair> refreshTokens(RefreshTokenRequest request) async =>
      _tokens;

  @override
  Future<SendSmsCodeResponse> sendSmsCode(
    SendSmsCodeRequest request,
  ) async {
    if (sendError != null) {
      throw AuthException(code: sendError!, message: sendError!.wireValue);
    }
    return const SendSmsCodeResponse(
      challengeId: '984e6346-f8a1-4511-8ec2-a960bc338705',
      expiresIn: 300,
      resendAfter: 60,
    );
  }

  @override
  Future<LoginVerificationResponse> verifySmsCode(
    VerifySmsCodeRequest request,
  ) async {
    if (verifyError != null) {
      throw AuthException(code: verifyError!, message: verifyError!.wireValue);
    }
    return LoginVerificationResponse(
      purpose: SmsPurpose.login,
      isNewUser: isNewUser,
      user: const AuthUser(
        id: 'e0e00cc4-f640-4975-b21f-ad93c28b67f0',
        phoneMasked: '138****5678',
      ),
      tokens: _tokens,
    );
  }
}

class _ThrowingAuthSessionStore implements AuthSessionStore {
  @override
  Future<void> clearSession() async => throw Exception('secure storage down');

  @override
  Future<String> getOrCreateDeviceId() async =>
      '6ecb2ba5-6c51-4a40-b908-8be4311c7f85';

  @override
  Future<AuthSession?> readSession() async =>
      throw Exception('secure storage down');

  @override
  Future<void> writeSession(AuthSession session) async {}
}

Future<void> _sendCode(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('phone-field')), '13812345678');
  await tester.tap(find.byKey(const Key('send-code-button')));
  await tester.pump();
}

Future<void> _verifyCode(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('sms-code-field')), '123456');
  await tester.tap(find.byKey(const Key('verify-code-button')));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  test('preview auth bypass only accepts local preview URLs', () {
    expect(
      isPreviewAuthBypassUri(
        Uri.parse(
          'http://127.0.0.1:7358/?preview_auth_bypass=stable-static-20260620',
        ),
        compileTimeBypass: false,
        debugMode: false,
      ),
      isTrue,
    );
    expect(
      isPreviewAuthBypassUri(
        Uri.parse(
          'https://example.com/?preview_auth_bypass=stable-static-20260620',
        ),
        compileTimeBypass: false,
        debugMode: false,
      ),
      isFalse,
    );
  });

  test('local web preview uses fixed example auth without API base URL', () {
    expect(
      shouldUseFixedExampleAuthForPreview(
        uri: Uri.parse('http://127.0.0.1:7358/'),
        isWeb: true,
        apiBaseUrl: '',
      ),
      isTrue,
    );
    expect(
      shouldUseFixedExampleAuthForPreview(
        uri: Uri.parse('https://easylife.example.com/'),
        isWeb: true,
        apiBaseUrl: '',
      ),
      isFalse,
    );
    expect(
      shouldUseFixedExampleAuthForPreview(
        uri: Uri.parse('http://127.0.0.1:7358/'),
        isWeb: true,
        apiBaseUrl: 'https://api.example.com',
      ),
      isFalse,
    );
  });

  testWidgets('storage failures during startup return to login',
      (tester) async {
    await tester.pumpWidget(
      CompanyApp.production(
        authService: _FakeAuthService(),
        authSessionStore: _ThrowingAuthSessionStore(),
        localStore: MemoryLocalStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('phone-field')), findsOneWidget);
  });

  testWidgets('SMS login shows five-minute validity and resend countdown',
      (tester) async {
    await tester.pumpWidget(
      CompanyApp(authService: _FakeAuthService()),
    );

    await _sendCode(tester);

    expect(find.text('验证码 5 分钟内有效。'), findsOneWidget);
    expect(find.text('60s 后重发'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('59s 后重发'), findsOneWidget);
  });

  testWidgets('new phone enters profile and existing phone enters app',
      (tester) async {
    await tester.pumpWidget(
      CompanyApp(authService: _FakeAuthService()),
    );
    await _sendCode(tester);
    await _verifyCode(tester);
    expect(find.text('让easy更懂你'), findsOneWidget);

    await tester.pumpWidget(
      CompanyApp(
        key: const ValueKey('existing-user-app'),
        authService: _FakeAuthService(isNewUser: false),
      ),
    );
    await _sendCode(tester);
    await _verifyCode(tester);
    expect(find.text('Easylife'), findsOneWidget);
    expect(find.text('让easy更懂你'), findsNothing);
  });

  for (final entry in <AuthErrorCode, String>{
    AuthErrorCode.validationError: '请输入有效手机号和 6 位验证码。',
    AuthErrorCode.smsCodeExpired: '验证码已失效，请重新获取。',
    AuthErrorCode.smsCodeInvalid: '验证码错误，请检查后重试。',
    AuthErrorCode.verificationAttemptsExceeded: '验证次数过多，请重新获取验证码。',
    AuthErrorCode.rateLimited: '发送过于频繁，请稍后再试。',
    AuthErrorCode.smsProviderUnavailable: '短信服务暂时不可用，请稍后再试。',
  }.entries) {
    testWidgets('shows ${entry.key.wireValue}', (tester) async {
      final sendFailure = entry.key == AuthErrorCode.validationError ||
          entry.key == AuthErrorCode.rateLimited ||
          entry.key == AuthErrorCode.smsProviderUnavailable;
      await tester.pumpWidget(
        CompanyApp(
          authService: _FakeAuthService(
            sendError: sendFailure ? entry.key : null,
            verifyError: sendFailure ? null : entry.key,
          ),
        ),
      );

      await _sendCode(tester);
      if (!sendFailure) await _verifyCode(tester);

      expect(find.text(entry.value), findsOneWidget);
    });
  }
}
