import 'package:flutter/material.dart';

import '../models/pet_profile.dart';
import '../services/agent_service.dart';
import '../services/pet_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/companion_pet.dart';
import 'pet_photo_upload_page.dart';

class PetProfileOnboardingPage extends StatelessWidget {
  const PetProfileOnboardingPage({
    required this.onSkip,
    required this.onCompleted,
    required this.agentService,
    required this.petProfileService,
    super.key,
  });

  final VoidCallback onSkip;
  final ValueChanged<PetProfile> onCompleted;
  final AgentService agentService;
  final PetProfileService petProfileService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 220,
                height: 220,
                decoration: const BoxDecoration(
                  color: AppColors.primaryMist,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const CompanionPet(size: 180),
              ),
              const SizedBox(height: 34),
              Text(
                '创建你的专属陪伴伙伴',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                '伙伴可以是宠物、家人、朋友、喜欢的人或理想角色',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.secondaryInk),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PetPhotoUploadPage(
                          agentService: agentService,
                          petProfileService: petProfileService,
                          onCompleted: onCompleted,
                        ),
                      ),
                    );
                  },
                  child: const Text('制作伙伴档案'),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(onPressed: onSkip, child: const Text('暂不创建')),
              const SizedBox(height: 12),
              Text(
                '以后也可以在设置页补建或修改伙伴档案',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
