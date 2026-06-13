import 'package:flutter/material.dart';

import '../models/pet_profile.dart';
import '../services/agent_service.dart';
import '../services/pet_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/companion_pet.dart';
import '../widgets/soft_card.dart';
import 'pet_generation_loading_page.dart';
import 'pet_profile_form_page.dart';

class PetAvatarPreviewPage extends StatelessWidget {
  const PetAvatarPreviewPage({
    required this.imagePath,
    required this.generatedAvatarUrl,
    required this.onCompleted,
    required this.agentService,
    required this.petProfileService,
    super.key,
  });

  final String imagePath;
  final String generatedAvatarUrl;
  final ValueChanged<PetProfile> onCompleted;
  final AgentService agentService;
  final PetProfileService petProfileService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('宠物形象预览')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        child: Column(
          children: [
            const Spacer(),
            const SoftCard(
              color: Color(0xFFFFF6FA),
              borderColor: Color(0xFFF0DCE3),
              child: SizedBox(
                width: double.infinity,
                height: 290,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CompanionPet(size: 190),
                    SizedBox(height: 12),
                    Text('以后我来陪你记录生活 💗'),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => PetGenerationLoadingPage(
                            agentService: agentService,
                            petProfileService: petProfileService,
                            imagePath: imagePath,
                            onCompleted: onCompleted,
                          ),
                        ),
                      );
                    },
                    child: const Text('重新生成'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PetProfileFormPage(
                            petProfileService: petProfileService,
                            originalPhotoUrl: imagePath,
                            generatedAvatarUrl: generatedAvatarUrl,
                            onCompleted: onCompleted,
                          ),
                        ),
                      );
                    },
                    style:
                        FilledButton.styleFrom(backgroundColor: AppColors.ink),
                    child: const Text('继续'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
