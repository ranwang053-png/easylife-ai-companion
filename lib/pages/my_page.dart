import 'package:flutter/material.dart';

import '../models/pet_profile.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/companion_pet.dart';
import '../widgets/page_header.dart';
import '../widgets/soft_card.dart';

class MyPage extends StatelessWidget {
  const MyPage({
    required this.onOpenSettings,
    required this.onOpenPetProfile,
    required this.userProfileService,
    required this.petProfile,
    super.key,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onOpenPetProfile;
  final UserProfileService userProfileService;
  final PetProfile? petProfile;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: userProfileService.loadProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        if (profile == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 130),
            children: [
              PageHeader(
                title: '我的',
                subtitle: '管理个人资料、偏好与 Agent 长期记忆',
                trailing: IconButton(
                  tooltip: '系统偏好',
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_outlined),
                ),
              ),
              const SizedBox(height: 18),
              SoftCard(
                child: Row(
                  children: [
                    const CompanionPet(size: 76),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.nickname,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [profile.occupation, profile.mbti]
                                .where((item) => item.isNotEmpty)
                                .join(' · '),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionTitle('长期记忆'),
              const SizedBox(height: 10),
              SoftCard(
                color: const Color(0xFFFFF7FA),
                borderColor: const Color(0xFFF0DCE3),
                onTap: onOpenSettings,
                child: const Text(
                  '你的基础信息和偏好会供 AgentService 用于饮食建议、情绪陪伴和桌宠互动。',
                ),
              ),
              const SizedBox(height: 20),
              const SectionTitle('档案与偏好'),
              const SizedBox(height: 10),
              SoftCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _MyTile(
                      icon: Icons.pets_outlined,
                      title: '宠物档案',
                      value: petProfile == null
                          ? '未创建'
                          : '${petProfile!.name} · 可修改',
                      onTap: onOpenPetProfile,
                    ),
                    const Divider(height: 1, indent: 60),
                    _MyTile(
                      icon: Icons.restaurant_menu_rounded,
                      title: '饮食偏好',
                      value: profile.dietPreference.isEmpty
                          ? '未填写'
                          : profile.dietPreference,
                      onTap: onOpenSettings,
                    ),
                    const Divider(height: 1, indent: 60),
                    _MyTile(
                      icon: Icons.tune_rounded,
                      title: '系统偏好',
                      value: '提醒、目标与陪伴方式',
                      onTap: onOpenSettings,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MyTile extends StatelessWidget {
  const _MyTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: AppColors.mistBlue,
        child: Icon(icon, color: AppColors.ink),
      ),
      title: Text(title),
      subtitle: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
