import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/pet_profile.dart';
import '../services/agent_service.dart';
import '../services/pet_profile_service.dart';
import '../theme/app_colors.dart';
import '../utils/pet_image_picker.dart';
import '../widgets/ai_privacy_dialog.dart';
import '../widgets/responsive_page.dart';
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
  Uint8List? _previewBytes;

  Future<void> _selectPhoto({required bool preferCamera}) async {
    try {
      final image = await pickPetImage(preferCamera: preferCamera);
      if (!mounted || image == null) return;
      setState(() {
        _previewBytes = image.bytes;
        _imagePath = image.dataUrl;
      });
    } on PetImagePickerException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
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
            agentService: widget.agentService,
            petProfileService: widget.petProfileService,
            originalPhotoUrl: imagePath,
            generatedAvatarUrl: null,
            onCompleted: widget.onCompleted,
          );
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('上传伙伴照片')),
      body: ResponsivePageList(
        maxWidth: 720,
        top: 16,
        bottom: 32,
        children: [
          Text('选择一张清晰照片', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            '正面、光线自然的照片会更适合生成陪伴形象。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 22),
          SoftCard(
            color: AppColors.primaryMist,
            borderColor: AppColors.outlineSoft,
            child: SizedBox(
              height: 260,
              child: Center(
                child: _previewBytes == null
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
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: AppColors.softGreen,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Image.memory(_previewBytes!,
                                fit: BoxFit.contain),
                          ),
                          const SizedBox(height: 12),
                          const Text('伙伴照片已选择'),
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
                  onPressed: () => _selectPhoto(preferCamera: true),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('拍照'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectPhoto(preferCamera: false),
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
              child: const Text('下一步'),
            ),
          ),
        ],
      ),
    );
  }
}
