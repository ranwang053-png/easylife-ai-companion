import 'package:flutter/material.dart';

import '../mock/dashboard_mock.dart';
import '../models/pet_profile.dart';
import '../models/dashboard_models.dart';
import '../services/agent_service.dart';
import '../services/journal_repository.dart';
import '../services/pet_profile_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/quick_action_fab.dart';
import 'companion_page.dart';
import 'dashboard_page.dart';
import 'health_page.dart';
import 'my_page.dart';
import 'pet_profile_form_page.dart';
import 'pet_profile_onboarding_page.dart';
import 'settings_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.agentService,
    required this.petProfileService,
    required this.userProfileService,
    required this.journalRepository,
    super.key,
  });

  final AgentService agentService;
  final PetProfileService petProfileService;
  final UserProfileService userProfileService;
  final JournalRepository journalRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _companionKey = GlobalKey<CompanionPageState>();
  final _healthKey = GlobalKey<HealthPageState>();
  var _selectedIndex = 0;
  var _quickActionsOpen = false;
  PetProfile? _petProfile;

  static const _items = [
    (label: '首页', icon: Icons.home_rounded),
    (label: '陪伴', icon: Icons.smart_toy_outlined),
    (label: '饮食', icon: Icons.restaurant_outlined),
    (label: '我的', icon: Icons.person_outline_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _loadPetProfile();
  }

  Future<void> _loadPetProfile() async {
    final profile = await widget.petProfileService.getPetProfile();
    if (mounted) setState(() => _petProfile = profile);
  }

  void _openSettings() {
    Navigator.of(
      context,
    ).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          agentService: widget.agentService,
          petProfileService: widget.petProfileService,
          userProfileService: widget.userProfileService,
        ),
      ),
    );
  }

  void _openPetProfileFlow() {
    final petProfile = _petProfile;
    if (petProfile != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PetProfileFormPage(
            petProfileService: widget.petProfileService,
            initialProfile: petProfile,
            onCompleted: _onPetProfileCompleted,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PetProfileOnboardingPage(
          agentService: widget.agentService,
          petProfileService: widget.petProfileService,
          onSkip: () => Navigator.of(context).pop(),
          onCompleted: _onPetProfileCompleted,
        ),
      ),
    );
  }

  void _onPetProfileCompleted(PetProfile profile) {
    if (!mounted) return;
    setState(() => _petProfile = profile);
  }

  void _openDashboardModule(String module) {
    final index = switch (module) {
      '桌宠陪伴' || '情绪日记' => 1,
      '饮食体重' => 2,
      _ => 0,
    };
    if (index == 0) {
      return;
    }
    setState(() => _selectedIndex = index);
  }

  void _handleQuickAction(QuickAction action) {
    setState(() => _quickActionsOpen = false);
    final targetIndex = action.type == QuickActionType.mood ? 1 : 2;
    setState(() => _selectedIndex = targetIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (action.type) {
        case QuickActionType.mood:
          _companionKey.currentState?.startQuickEntry();
        case QuickActionType.meal:
          _healthKey.currentState?.startQuickMeal();
        case QuickActionType.weight:
          _healthKey.currentState?.startQuickWeight();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
        petProfile: _petProfile,
        agentService: widget.agentService,
        userProfileService: widget.userProfileService,
        onOpenModule: _openDashboardModule,
        onOpenSettings: _openSettings,
        onOpenPetProfile: _openPetProfileFlow,
      ),
      CompanionPage(
        key: _companionKey,
        agentService: widget.agentService,
        userProfileService: widget.userProfileService,
        journalRepository: widget.journalRepository,
        petProfile: _petProfile,
        onCreatePetProfile: _openPetProfileFlow,
      ),
      HealthPage(
        key: _healthKey,
        agentService: widget.agentService,
        userProfileService: widget.userProfileService,
        journalRepository: widget.journalRepository,
      ),
      MyPage(
        userProfileService: widget.userProfileService,
        petProfile: _petProfile,
        onOpenSettings: _openSettings,
        onOpenPetProfile: _openPetProfileFlow,
      ),
    ];
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _selectedIndex, children: pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: QuickActionFab(
        isOpen: _quickActionsOpen,
        actions: DashboardMock.quickActions,
        onToggle: () {
          setState(() => _quickActionsOpen = !_quickActionsOpen);
        },
        onAction: _handleQuickAction,
      ),
      bottomNavigationBar: NavigationBar(
        height: 74,
        selectedIndex: _selectedIndex,
        backgroundColor: Colors.white.withValues(alpha: .96),
        indicatorColor: AppColors.mistBlue,
        destinations: [
          for (final item in _items)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.icon, color: AppColors.ink),
              label: item.label,
            ),
        ],
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
            _quickActionsOpen = false;
          });
        },
      ),
    );
  }
}
