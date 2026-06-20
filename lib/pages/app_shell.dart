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
    required this.onLogout,
    super.key,
  });

  final AgentService agentService;
  final PetProfileService petProfileService;
  final UserProfileService userProfileService;
  final JournalRepository journalRepository;
  final Future<void> Function() onLogout;

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
    (label: '陪伴', icon: Icons.favorite_outline_rounded),
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

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          agentService: widget.agentService,
          petProfileService: widget.petProfileService,
          userProfileService: widget.userProfileService,
          onLogout: widget.onLogout,
        ),
      ),
    );
    if (!mounted) return;
    await _loadPetProfile();
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final content = IndexedStack(index: _selectedIndex, children: pages);

        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                _DesktopNavigation(
                  selectedIndex: _selectedIndex,
                  items: _items,
                  onSelected: _selectPage,
                  onQuickAction: _handleQuickAction,
                ),
                const VerticalDivider(width: 1, color: AppColors.outline),
                Expanded(child: content),
              ],
            ),
          );
        }

        return Scaffold(
          extendBody: true,
          body: content,
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: QuickActionFab(
            isOpen: _quickActionsOpen,
            actions: DashboardMock.quickActions,
            onToggle: () {
              setState(() => _quickActionsOpen = !_quickActionsOpen);
            },
            onAction: _handleQuickAction,
          ),
          bottomNavigationBar: NavigationBar(
            height: 78,
            selectedIndex: _selectedIndex,
            backgroundColor: AppColors.cream.withValues(alpha: .98),
            indicatorColor: AppColors.softGreen,
            elevation: 0,
            shadowColor: Colors.transparent,
            destinations: [
              for (final item in _items)
                NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.icon, color: AppColors.primaryDark),
                  label: item.label,
                ),
            ],
            onDestinationSelected: _selectPage,
          ),
        );
      },
    );
  }

  void _selectPage(int index) {
    setState(() {
      _selectedIndex = index;
      _quickActionsOpen = false;
    });
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
    required this.onQuickAction,
  });

  final int selectedIndex;
  final List<({IconData icon, String label})> items;
  final ValueChanged<int> onSelected;
  final ValueChanged<QuickAction> onQuickAction;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        width: 224,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryDark,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Easylife',
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 34),
              for (var index = 0; index < items.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _DesktopNavItem(
                    label: items[index].label,
                    icon: items[index].icon,
                    selected: selectedIndex == index,
                    onTap: () => onSelected(index),
                  ),
                ),
              const Spacer(),
              Text(
                '快捷记录',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 10),
              for (final action in DashboardMock.quickActions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => onQuickAction(action),
                    icon: Icon(action.icon, size: 18),
                    label: Text(action.label),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      backgroundColor: action.color.withValues(alpha: .55),
                      side: BorderSide.none,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopNavItem extends StatelessWidget {
  const _DesktopNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryMist : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 21,
                color:
                    selected ? AppColors.primaryDark : AppColors.secondaryInk,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.ink : AppColors.secondaryInk,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
