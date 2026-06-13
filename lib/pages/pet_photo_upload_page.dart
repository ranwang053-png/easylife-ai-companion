import 'package:flutter/material.dart';

import '../models/pet_profile.dart';
import '../services/agent_service.dart';
import '../services/pet_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ai_privacy_dialog.dart';
import '../widgets/soft_card.dart';
import 'pet_generation_loading_page.dart';
import 'pet_profile_form_page.dart';

class PetPhotoUploadPage extends StatefulWidget {
  const PetPhotoUploadPage({
    required this.onCompleted,
    required this.agentService,
    required this.petProfileService,
    super.key,
  });

  final ValueChanged<PetProfile> onCompleted;
  final AgentService agentService;
  final PetProfileService petProfileService;

  @override
  State<PetPhotoUploadPage> createState() => _PetPhotoUploadPageState();
}

class _PetPhotoUploadPageState extends State<PetPhotoUploadPage> {
  String? _imagePath;

  void _selectMockPhoto(String source) {
    setState(() => _imagePath = 'mock://pet-photo/$source');
  }

  Future<void> _continue() async {
    final imagePath = _imagePath;
    if (imagePath == null) return;
    final useAi = await showAiPrivacyDialog(context);
    if (!mounted || useAi == null) return;

    final page = useAi
        ? PetGenerationLoadingPage(
            agentService: widget.agentService,
            petProfileService: widget.petProfileService,
            imagePath: imagePath,
            onCompleted: widget.onCompleted,
          )
        : PetProfileFormPage(
            petProfileService: widget.petProfileService,
            originalPhotoUrl: imagePath,
            generatedAvatarUrl: null,
            onCompleted: widget.onCompleted,
          );
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('上传宠物照片')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('选择一张清晰照片', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            '正面、光线自然的照片会更适合生成陪伴形象。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 22),
          SoftCard(
            color: const Color(0xFFFFF8FA),
            borderColor: const Color(0xFFF0DCE3),
            child: SizedBox(
              height: 260,
              child: Center(
                child: _imagePath == null
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 64),
                          SizedBox(height: 12),
                          Text('还没有选择照片'),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              color: AppColors.softPurple,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Icon(
                              Icons.pets_rounded,
                              size: 78,
                              color: Color(0xFF7459A8),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text('Mock 宠物照片已选择'),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectMockPhoto('camera'),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('拍照'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectMockPhoto('gallery'),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('从相册选择'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _imagePath == null ? null : _continue,
              style: FilledButton.styleFrom(backgroundColor: AppColors.ink),
              child: const Text('下一步'),
            ),
          ),
        ],
      ),
    );
  }
}
