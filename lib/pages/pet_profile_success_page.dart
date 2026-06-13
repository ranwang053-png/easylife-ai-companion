import 'package:flutter/material.dart';

import '../models/pet_profile.dart';
import '../theme/app_colors.dart';
import '../widgets/companion_pet.dart';

class PetProfileSuccessPage extends StatelessWidget {
  const PetProfileSuccessPage({
    required this.profile,
    required this.onCompleted,
    super.key,
  });

  final PetProfile profile;
  final ValueChanged<PetProfile> onCompleted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
          child: Column(
            children: [
              const Spacer(),
              const Icon(
                Icons.check_circle_rounded,
                size: 52,
                color: Color(0xFF68A77B),
              ),
              const SizedBox(height: 18),
              Text(
                '宠物档案已创建',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              const CompanionPet(size: 190),
              const SizedBox(height: 10),
              Text(profile.name,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                children: [
                  for (final tag in profile.personalityTags)
                    Chip(label: Text(tag)),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                '它会在 Easylife 里陪你记录心情、饮食和体重变化',
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    onCompleted(profile);
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: FilledButton.styleFrom(backgroundColor: AppColors.ink),
                  child: const Text('进入首页'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
