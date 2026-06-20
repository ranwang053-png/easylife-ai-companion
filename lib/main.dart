import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'models/auth_models.dart';
import 'models/user_profile.dart';
import 'pages/app_shell.dart';
import 'pages/login_page.dart';
import 'pages/user_basic_info_page.dart';
import 'services/agent_service.dart';
import 'services/auth_session_service.dart';
import 'services/auth_service.dart';
import 'services/journal_repository.dart';
import 'services/local_store.dart';
import 'services/pet_profile_service.dart';
import 'services/user_profile_service.dart';
import 'theme/app_theme.dart';

const _previewAuthBypass = bool.fromEnvironment(
  'EASYLIFE_PREVIEW_AUTH_BYPASS',
);

const _apiBaseUrl = String.fromEnvironment('EASYLIFE_API_BASE_URL');

const _previewAuthBypassToken = 'stable-static-20260620';

bool get _canBypassAuthForPreview {
  return isPreviewAuthBypassUri(
    Uri.base,
    compileTimeBypass: _previewAuthBypass,
    debugMode: kDebugMode,
  );
}

@visibleForTesting
bool isPreviewAuthBypassUri(
  Uri uri, {
  required bool compileTimeBypass,
  required bool debugMode,
}) {
  return isLocalPreviewHost(uri) &&
      (compileTimeBypass ||
          debugMode ||
          uri.queryParameters['preview_auth_bypass'] ==
              _previewAuthBypassToken);
}

@visibleForTesting
bool isLocalPreviewHost(Uri uri) {
  return uri.host == '127.0.0.1' ||
      uri.host == 'localhost' ||
      uri.host == '::1';
}

@visibleForTesting
bool shouldUseFixedExampleAuthForPreview({
  required Uri uri,
  required bool isWeb,
  required String apiBaseUrl,
}) {
  return isWeb && apiBaseUrl.isEmpty && isLocalPreviewHost(uri);
}

bool get _useFixedExampleAuthForPreview => shouldUseFixedExampleAuthForPreview(
      uri: Uri.base,
      isWeb: kIsWeb,
      apiBaseUrl: _apiBaseUrl,
    );

void main() {
  runApp(const CompanyApp.production());
}

class CompanyApp extends StatelessWidget {
  const CompanyApp({
    this.authService,
    this.authSessionStore,
    this.localStore,
    super.key,
  }) : useLocalStorage = false;

  const CompanyApp.production({
    this.authService,
    this.authSessionStore,
    this.localStore,
    super.key,
  }) : useLocalStorage = true;

  final bool useLocalStorage;
  final AuthService? authService;
  final AuthSessionStore? authSessionStore;
  final LocalStore? localStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Easylife',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _AppStartupGate(
        useLocalStorage: useLocalStorage,
        authService: authService,
        authSessionStore: authSessionStore,
        localStore: localStore,
      ),
    );
  }
}

class _AppStartupGate extends StatefulWidget {
  const _AppStartupGate({
    required this.useLocalStorage,
    required this.authService,
    required this.authSessionStore,
    required this.localStore,
  });

  final bool useLocalStorage;
  final AuthService? authService;
  final AuthSessionStore? authSessionStore;
  final LocalStore? localStore;

  @override
  State<_AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends State<_AppStartupGate> {
  AgentService? _agentService;
  late final AuthService _authService;
  late final AuthSessionManager _sessionManager;
  late final LocalStore _rootStore;
  PetProfileService? _petProfileService;
  UserProfileService? _userProfileService;
  JournalRepository? _journalRepository;
  _StartupStep _step = _StartupStep.loading;
  String _accountIdentifier = '';
  String _nickname = '';

  @override
  void initState() {
    super.initState();
    final injectedStore = widget.localStore;
    if (injectedStore != null) {
      _rootStore = injectedStore;
    } else if (widget.useLocalStorage) {
      _rootStore = SharedPreferencesLocalStore();
    } else {
      _rootStore = MemoryLocalStore();
    }
    _authService = widget.authService ??
        (_useFixedExampleAuthForPreview || !widget.useLocalStorage
            ? const FixedExampleAuthService()
            : createAuthService());
    _sessionManager = AuthSessionManager(
      authService: _authService,
      store: widget.authSessionStore ??
          (widget.useLocalStorage
              ? SecureAuthSessionStore()
              : MemoryAuthSessionStore()),
    );
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      if (widget.useLocalStorage && _canBypassAuthForPreview) {
        await _configureServices('preview-user');
        if (!mounted) return;
        setState(() {
          _accountIdentifier = 'preview-user';
          _step = _StartupStep.app;
        });
        return;
      }

      final session =
          widget.useLocalStorage ? await _sessionManager.restore() : null;
      if (!mounted) return;
      if (session == null) {
        setState(() => _step = _StartupStep.login);
        return;
      }
      await _configureServices(session.user.id);
      if (!mounted) return;
      setState(() {
        _accountIdentifier = session.user.phoneMasked;
        _step = _StartupStep.app;
      });
    } on Exception catch (error) {
      debugPrint('Startup recovery failed: $error');
      await _clearSessionAfterStartupFailure();
      if (!mounted) return;
      setState(() {
        _clearUserServices();
        _accountIdentifier = '';
        _nickname = '';
        _step = _StartupStep.login;
      });
    }
  }

  Future<void> _configureServices(String userId) async {
    if (widget.useLocalStorage) {
      final prefix = 'easylife.user.$userId';
      try {
        await migrateLegacyStoreToUserScope(
          rootStore: _rootStore,
          userPrefix: prefix,
          keys: const [
            'easylife.v1.user_profile',
            'easylife.v1.pet_profile',
            'easylife.v1.mood_logs',
            'easylife.v1.meal_records',
            'easylife.v1.weight_records',
            'easylife.v1.has_seen_diet_guide',
          ],
        );
      } on Exception catch (error) {
        debugPrint('Legacy local data migration skipped: $error');
      }
      final store = PrefixedLocalStore(_rootStore, prefix);
      _agentService = createAgentService(
        accessTokenProvider: _validAccessToken,
      );
      _petProfileService = LocalPetProfileService(store);
      _userProfileService = LocalUserProfileService(store);
      _journalRepository = LocalJournalRepository(store);
      return;
    }
    _agentService = const MockAgentService();
    _petProfileService = const MockPetProfileService();
    _userProfileService = const MockUserProfileService();
    _journalRepository = LocalJournalRepository(MemoryLocalStore());
  }

  Future<void> _clearSessionAfterStartupFailure() async {
    try {
      await _sessionManager.clear();
    } on Exception catch (error) {
      debugPrint('Failed to clear startup session: $error');
    }
  }

  Future<String?> _validAccessToken() async {
    try {
      return await _sessionManager.validAccessToken();
    } on AuthException {
      if (mounted) {
        setState(() {
          _clearUserServices();
          _step = _StartupStep.login;
        });
      }
      return null;
    }
  }

  Future<void> _handleAuthenticated(
    LoginVerificationResponse response,
  ) async {
    await _sessionManager.establish(response);
    await _configureServices(response.user.id);
    if (!mounted) return;
    setState(() {
      _accountIdentifier = response.user.phoneMasked;
      _nickname = '';
      _step = response.isNewUser ? _StartupStep.basicInfo : _StartupStep.app;
    });
  }

  Future<void> _saveBasicInfo(UserProfile profile) async {
    await _userProfileService!.saveProfile(profile);
    if (!mounted) return;
    setState(() => _step = _StartupStep.app);
  }

  Future<void> _handleLogout() async {
    await _sessionManager.logout();
    if (!mounted) return;
    setState(() {
      _clearUserServices();
      _accountIdentifier = '';
      _nickname = '';
      _step = _StartupStep.login;
    });
  }

  void _clearUserServices() {
    _agentService = null;
    _petProfileService = null;
    _userProfileService = null;
    _journalRepository = null;
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _StartupStep.loading => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      _StartupStep.login => LoginPage(
          authService: _authService,
          deviceId: _sessionManager.deviceId,
          showExampleCode: _authService is FixedExampleAuthService,
          onAuthenticated: _handleAuthenticated,
        ),
      _StartupStep.basicInfo => UserBasicInfoPage(
          userProfileService: _userProfileService!,
          accountIdentifier: _accountIdentifier,
          initialNickname: _nickname,
          onCompleted: _saveBasicInfo,
        ),
      _StartupStep.app => AppShell(
          agentService: _agentService!,
          petProfileService: _petProfileService!,
          userProfileService: _userProfileService!,
          journalRepository: _journalRepository!,
          onLogout: _handleLogout,
        ),
    };
  }
}

enum _StartupStep { loading, login, basicInfo, app }
