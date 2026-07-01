import 'dart:convert';

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
      appBar: AppBar(title: const Text('伙伴形象预览')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        child: Column(
          children: [
            const Spacer(),
            SoftCard(
              color: AppColors.primaryMist,
              borderColor: AppColors.outlineSoft,
              child: SizedBox(
                width: double.infinity,
                height: 290,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GeneratedAvatarPreview(imageUrl: generatedAvatarUrl),
                    const SizedBox(height: 12),
                    const Text('以后我来陪你记录生活 💗'),
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
                            agentService: agentService,
                            petProfileService: petProfileService,
                            originalPhotoUrl: imagePath,
                            generatedAvatarUrl: generatedAvatarUrl,
                            onCompleted: onCompleted,
                          ),
                        ),
                      );
                    },
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

class _GeneratedAvatarPreview extends StatelessWidget {
  const _GeneratedAvatarPreview({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('data:image/')) {
      final bytes = base64Decode(imageUrl.split(',').last);
      return ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Image.memory(
          bytes,
          width: 190,
          height: 190,
          fit: BoxFit.contain,
        ),
      );
    }
    if (imageUrl.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Image.network(
          imageUrl,
          width: 190,
          height: 190,
          fit: BoxFit.contain,
        ),
      );
    }
    return const CompanionPet(size: 190);
  }
}
