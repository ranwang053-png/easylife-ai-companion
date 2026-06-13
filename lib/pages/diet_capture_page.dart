import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/agent_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/soft_card.dart';
import 'diet_recognition_confirm_page.dart';

class DietCapturePage extends StatefulWidget {
  const DietCapturePage({
    required this.agentService,
    required this.userProfileService,
    this.initialMeal,
    super.key,
  });

  final AgentService agentService;
  final UserProfileService userProfileService;
  final MealType? initialMeal;

  @override
  State<DietCapturePage> createState() => _DietCapturePageState();
}

class _DietCapturePageState extends State<DietCapturePage> {
  final _descriptionController = TextEditingController();
  final _ingredientsController = TextEditingController();
  String? _imagePath;
  late MealType _mealType;
  var _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _mealType = widget.initialMeal ?? MealType.breakfast;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _ingredientsController.dispose();
    super.dispose();
  }

  void _selectMockImage(String source) {
    setState(() => _imagePath = 'mock://diet/$source');
  }

  String _portionFrom(String text) {
    if (text.contains('半袋')) return '半袋';
    if (text.contains('半个')) return '半个';
    if (text.contains('半份')) return '半份';
    if (text.contains('一块')) return '一小块';
    if (text.contains('一杯') || text.contains('喝了')) return '一杯';
    return '一整份';
  }

  Future<void> _analyze() async {
    final description = _descriptionController.text.trim();
    final ingredients = _ingredientsController.text.trim();
    if (_imagePath == null && description.isEmpty && ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('拍张照片，或写下刚刚吃了什么')),
      );
      return;
    }
    setState(() => _isAnalyzing = true);
    final portionText = _portionFrom('$description $ingredients');
    final profile = await widget.userProfileService.loadProfile();
    final estimate = await widget.agentService.estimateFoodCalories(
      description: description,
      imagePath: _imagePath,
      ingredientsText: ingredients.isEmpty ? null : ingredients,
      portionText: portionText,
      mealType: _mealType.label,
      profile: profile,
    );
    if (!mounted) return;
    setState(() => _isAnalyzing = false);
    final sourceType =
        _imagePath != null && (description.isNotEmpty || ingredients.isNotEmpty)
            ? 'mixed'
            : _imagePath != null
                ? 'photo'
                : ingredients.isNotEmpty
                    ? 'ingredients'
                    : 'text';
    final record = await Navigator.of(context).push<MealRecord>(
      MaterialPageRoute(
        builder: (_) => DietRecognitionConfirmPage(
          agentService: widget.agentService,
          userProfileService: widget.userProfileService,
          estimate: estimate,
          description: description,
          imagePath: _imagePath,
          ingredientsText: ingredients,
          mealType: _mealType,
          sourceType: sourceType,
        ),
      ),
    );
    if (!mounted || record == null) return;
    Navigator.of(context).pop(record);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('记录今天吃了什么')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          SoftCard(
            color: const Color(0xFFFFFBF3),
            borderColor: const Color(0xFFF0E4C9),
            child: SizedBox(
              height: 190,
              child: Center(
                child: _imagePath == null
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 54),
                          SizedBox(height: 10),
                          Text('添加食物照片（可选）'),
                        ],
                      )
                    : const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.restaurant_rounded,
                            size: 76,
                            color: Color(0xFF708D69),
                          ),
                          SizedBox(height: 8),
                          Text('Mock 食物照片已选择'),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectMockImage('camera'),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('拍照'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectMockImage('gallery'),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('相册'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _descriptionController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '文字描述',
              hintText: '例如：吃了半袋薯片',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ingredientsController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '配料表 / 包装信息（可选）',
              hintText: '例如：每袋 100g，每 100g 约 500 kcal',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 18),
          Text('选择餐次', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            children: [
              for (final meal in MealType.values)
                ChoiceChip(
                  label: Text(meal.label),
                  selected: meal == _mealType,
                  onSelected: (_) => setState(() => _mealType = meal),
                ),
            ],
          ),
          const SizedBox(height: 26),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _isAnalyzing ? null : _analyze,
              style: FilledButton.styleFrom(backgroundColor: AppColors.ink),
              icon: _isAnalyzing
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_isAnalyzing ? '正在识别与换算...' : 'AI 估算热量'),
            ),
          ),
        ],
      ),
    );
  }
}
