import 'package:flutter/material.dart';

import 'models/user_profile.dart';
import 'pages/app_shell.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/user_basic_info_page.dart';
import 'services/agent_service.dart';
import 'services/journal_repository.dart';
import 'services/local_store.dart';
import 'services/pet_profile_service.dart';
import 'services/user_profile_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const CompanyApp.production());
}

class CompanyApp extends StatelessWidget {
  const CompanyApp({super.key}) : useLocalStorage = false;

  const CompanyApp.production({super.key}) : useLocalStorage = true;

  final bool useLocalStorage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Easylife',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _AppStartupGate(useLocalStorage: useLocalStorage),
    );
  }
}

class _AppStartupGate extends StatefulWidget {
  const _AppStartupGate({required this.useLocalStorage});

  final bool useLocalStorage;

  @override
  State<_AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends State<_AppStartupGate> {
  late final AgentService _agentService;
  late final PetProfileService _petProfileService;
  late final UserProfileService _userProfileService;
  late final JournalRepository _journalRepository;
  _StartupStep _step = _StartupStep.login;
  String _accountIdentifier = '';
  String _nickname = '';

  @override
  void initState() {
    super.initState();
    if (widget.useLocalStorage) {
      final store = SharedPreferencesLocalStore();
      _agentService = createAgentService();
      _petProfileService = LocalPetProfileService(store);
      _userProfileService = LocalUserProfileService(store);
      _journalRepository = LocalJournalRepository(store);
    } else {
      _agentService = const MockAgentService();
      _petProfileService = const MockPetProfileService();
      _userProfileService = const MockUserProfileService();
      _journalRepository = LocalJournalRepository(MemoryLocalStore());
    }
  }

  void _showBasicInfo({
    required String accountIdentifier,
    required String nickname,
  }) {
    setState(() {
      _accountIdentifier = accountIdentifier;
      _nickname = nickname;
      _step = _StartupStep.basicInfo;
    });
  }

  Future<void> _saveBasicInfo(UserProfile profile) async {
    await _userProfileService.saveProfile(profile);
    if (!mounted) return;
    setState(() => _step = _StartupStep.app);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _StartupStep.login => LoginPage(
          onLogin: _showBasicInfo,
          onRegister: () => setState(() => _step = _StartupStep.register),
        ),
      _StartupStep.register => RegisterPage(
          onRegister: _showBasicInfo,
          onBackToLogin: () => setState(() => _step = _StartupStep.login),
        ),
      _StartupStep.basicInfo => UserBasicInfoPage(
          userProfileService: _userProfileService,
          accountIdentifier: _accountIdentifier,
          initialNickname: _nickname,
          onCompleted: _saveBasicInfo,
        ),
      _StartupStep.app => AppShell(
          agentService: _agentService,
          petProfileService: _petProfileService,
          userProfileService: _userProfileService,
          journalRepository: _journalRepository,
        ),
    };
  }
}

enum _StartupStep { login, register, basicInfo, app }
