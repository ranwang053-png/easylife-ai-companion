import 'package:company_app/models/auth_models.dart';
import 'package:company_app/services/auth_service.dart';
import 'package:company_app/services/auth_session_service.dart';
import 'package:company_app/services/local_store.dart';
import 'package:company_app/services/user_profile_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = AuthUser(
  id: 'e0e00cc4-f640-4975-b21f-ad93c28b67f0',
  phoneMasked: '138****5678',
);

LoginVerificationResponse _login({
  int accessTokenExpiresIn = 900,
  int refreshTokenExpiresIn = 2592000,
}) {
  return LoginVerificationResponse(
    purpose: SmsPurpose.login,
    isNewUser: false,
    user: _user,
    tokens: AuthTokenPair(
      accessToken: 'initial-access-token-with-at-least-twenty-characters',
      accessTokenExpiresIn: accessTokenExpiresIn,
      refreshToken: 'initial-refresh-token-with-at-least-twenty-characters',
      refreshTokenExpiresIn: refreshTokenExpiresIn,
    ),
  );
}

class _SessionAuthService implements AuthService {
  _SessionAuthService({this.refreshError});

  final AuthException? refreshError;
  var refreshCount = 0;
  var logoutCount = 0;

  @override
  Future<void> logout({
    required String accessToken,
    required String deviceId,
  }) async {
    logoutCount += 1;
  }

  @override
  Future<AuthTokenPair> refreshTokens(RefreshTokenRequest request) async {
    refreshCount += 1;
    if (refreshError case final error?) throw error;
    return const AuthTokenPair(
      accessToken: 'rotated-access-token-with-at-least-twenty-characters',
      accessTokenExpiresIn: 900,
      refreshToken: 'rotated-refresh-token-with-at-least-twenty-characters',
      refreshTokenExpiresIn: 2592000,
    );
  }

  @override
  Future<SendSmsCodeResponse> sendSmsCode(
    SendSmsCodeRequest request,
  ) =>
      throw UnimplementedError();

  @override
  Future<LoginVerificationResponse> verifySmsCode(
    VerifySmsCodeRequest request,
  ) =>
      throw UnimplementedError();
}

void main() {
  test('restores a valid secure session without refreshing', () async {
    final store = MemoryAuthSessionStore();
    final auth = _SessionAuthService();
    final manager = AuthSessionManager(authService: auth, store: store);
    await manager.establish(_login());

    final restored = AuthSessionManager(
      authService: auth,
      store: store,
    );

    expect(await restored.restore(), isNotNull);
    expect(await restored.validAccessToken(), startsWith('initial-access'));
    expect(auth.refreshCount, 0);
  });

  test('refreshes an expiring token and persists the rotation', () async {
    final store = MemoryAuthSessionStore();
    final auth = _SessionAuthService();
    final manager = AuthSessionManager(authService: auth, store: store);
    await manager.establish(_login(accessTokenExpiresIn: 0));

    expect(await manager.validAccessToken(), startsWith('rotated-access'));
    expect(auth.refreshCount, 1);
    expect(store.session?.tokens.refreshToken, startsWith('rotated-refresh'));
  });

  test('clears the local session when refresh is rejected', () async {
    final store = MemoryAuthSessionStore();
    final auth = _SessionAuthService(
      refreshError: const AuthException(
        code: AuthErrorCode.invalidRefreshToken,
        message: 'expired',
      ),
    );
    final manager = AuthSessionManager(authService: auth, store: store);
    await manager.establish(_login(accessTokenExpiresIn: 0));

    await expectLater(
        manager.validAccessToken(), throwsA(isA<AuthException>()));
    expect(manager.session, isNull);
    expect(store.session, isNull);
  });

  test('logout revokes remotely and always clears locally', () async {
    final store = MemoryAuthSessionStore();
    final auth = _SessionAuthService();
    final manager = AuthSessionManager(authService: auth, store: store);
    await manager.establish(_login());

    await manager.logout();

    expect(auth.logoutCount, 1);
    expect(manager.session, isNull);
    expect(store.session, isNull);
  });

  test('prefixed stores isolate local data between users', () async {
    final root = MemoryLocalStore();
    final first = LocalUserProfileService(
      PrefixedLocalStore(root, 'easylife.user.first'),
    );
    final second = LocalUserProfileService(
      PrefixedLocalStore(root, 'easylife.user.second'),
    );
    final base = MockUserProfileService.currentProfile;

    await first.saveProfile(base.copyWith(nickname: '用户一'));
    await second.saveProfile(base.copyWith(nickname: '用户二'));

    expect((await first.loadProfile()).nickname, '用户一');
    expect((await second.loadProfile()).nickname, '用户二');
  });

  test('legacy local data migrates once to the first authenticated user',
      () async {
    final root = MemoryLocalStore();
    const key = 'easylife.v1.user_profile';
    await root.setString(key, 'legacy');

    await migrateLegacyStoreToUserScope(
      rootStore: root,
      userPrefix: 'easylife.user.first',
      keys: const [key],
    );
    await migrateLegacyStoreToUserScope(
      rootStore: root,
      userPrefix: 'easylife.user.second',
      keys: const [key],
    );

    expect(
      await PrefixedLocalStore(root, 'easylife.user.first').getString(key),
      'legacy',
    );
    expect(
      await PrefixedLocalStore(root, 'easylife.user.second').getString(key),
      isNull,
    );
    expect(await root.getString(key), isNull);
  });
}
