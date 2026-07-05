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
  static const _steps = [
    _GenerationStep(
      title: '上传成功',
      detail: '照片已经收到，马上开始处理。',
    ),
    _GenerationStep(
      title: '读取图片',
      detail: '正在读取五官、轮廓、毛色和服饰线索。',
    ),
    _GenerationStep(
      title: '分析特征',
      detail: '正在整理可用于生成全身形象的关键特征。',
    ),
    _GenerationStep(
      title: '生成形象',
      detail: '正在生成完整伙伴形象，尽量保留头到脚的比例。',
    ),
  ];

  var _step = 1;
  var _statusText = '正在读取图片特征';

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() {
      _step = 1;
      _statusText = '正在读取图片特征';
    });
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _step = 2;
      _statusText = '正在分析全身比例和风格';
    });
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() {
      _step = 3;
      _statusText = '正在生成完整伙伴形象';
    });
    final String avatarUrl;
    try {
      avatarUrl = await widget.agentService.generatePetAvatarFromPhoto(
        widget.imagePath,
      );
    } on AgentServiceException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      Navigator.of(context).pop();
      return;
    }
    if (!mounted) return;
    setState(() {
      _step = _steps.length;
      _statusText = '生成完成，正在准备预览';
    });
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
                  '正在生成你的专属伙伴形象...',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.secondaryInk,
                      ),
                ),
                const SizedBox(height: 24),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: .78),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.outlineSoft),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    child: Column(
                      children: [
                        for (var index = 0; index < _steps.length; index++) ...[
                          _GenerationStepRow(
                            step: _steps[index],
                            isDone: index < _step,
                            isActive: index == _step,
                          ),
                          if (index != _steps.length - 1)
                            const _StepConnector(),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '这个过程可能需要几十秒，请不要关闭页面。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.mutedInk,
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

class _GenerationStep {
  const _GenerationStep({
    required this.title,
    required this.detail,
  });

  final String title;
  final String detail;
}

class _GenerationStepRow extends StatelessWidget {
  const _GenerationStepRow({
    required this.step,
    required this.isDone,
    required this.isActive,
  });

  final _GenerationStep step;
  final bool isDone;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color =
        isDone || isActive ? AppColors.primaryDark : AppColors.mutedInk;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox.square(
          dimension: 24,
          child: Center(
            child: isActive
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    isDone ? Icons.check_circle_rounded : Icons.circle_outlined,
                    size: 20,
                    color: isDone ? AppColors.primary : AppColors.outline,
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                step.detail,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDone || isActive
                          ? AppColors.secondaryInk
                          : AppColors.mutedInk,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  const _StepConnector();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 11, top: 4, bottom: 4),
      child: SizedBox(
        height: 14,
        child: VerticalDivider(
          width: 1,
          thickness: 1,
          color: AppColors.outlineSoft,
        ),
      ),
    );
  }
}
