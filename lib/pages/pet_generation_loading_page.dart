import 'package:flutter/material.dart';

import '../models/pet_profile.dart';
import '../services/agent_service.dart';
import '../services/pet_profile_service.dart';
import '../theme/app_colors.dart';
import 'pet_avatar_preview_page.dart';

class PetGenerationLoadingPage extends StatefulWidget {
  const PetGenerationLoadingPage({
    required this.imagePath,
    required this.onCompleted,
    required this.agentService,
    required this.petProfileService,
    super.key,
  });

  final String imagePath;
  final ValueChanged<PetProfile> onCompleted;
  final AgentService agentService;
  final PetProfileService petProfileService;

  @override
  State<PetGenerationLoadingPage> createState() =>
      _PetGenerationLoadingPageState();
}

class _PetGenerationLoadingPageState extends State<PetGenerationLoadingPage> {
  var _step = 0;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    setState(() => _step = 1);
    final avatarUrl = await widget.agentService.generatePetAvatarFromPhoto(
      widget.imagePath,
    );
    if (!mounted) return;
    setState(() => _step = 2);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PetAvatarPreviewPage(
          agentService: widget.agentService,
          petProfileService: widget.petProfileService,
          imagePath: widget.imagePath,
          generatedAvatarUrl: avatarUrl,
          onCompleted: widget.onCompleted,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const steps = ['正在识别宠物特征', '正在生成陪伴形象', '正在准备第一次见面'];
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox.square(
                  dimension: 62,
                  child: CircularProgressIndicator(strokeWidth: 5),
                ),
                const SizedBox(height: 30),
                Text(
                  '正在生成你的专属宠物形象...',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                for (var index = 0; index < steps.length; index++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          index <= _step
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          size: 18,
                          color: index <= _step
                              ? const Color(0xFF8B72DA)
                              : AppColors.mutedInk,
                        ),
                        const SizedBox(width: 8),
                        Text(steps[index]),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
