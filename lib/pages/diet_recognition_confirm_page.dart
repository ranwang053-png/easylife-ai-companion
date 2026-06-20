import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/agent_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/responsive_page.dart';
import '../widgets/soft_card.dart';
import 'food_sticker_editor_page.dart';

class DietRecognitionConfirmPage extends StatefulWidget {
  const DietRecognitionConfirmPage({
    required this.estimate,
    required this.description,
    required this.imagePath,
    required this.ingredientsText,
    required this.mealType,
    required this.sourceType,
    required this.agentService,
    required this.userProfileService,
    super.key,
  });

  final FoodCalorieEstimate estimate;
  final String description;
  final String? imagePath;
  final String ingredientsText;
  final MealType mealType;
  final String sourceType;
  final AgentService agentService;
  final UserProfileService userProfileService;

  @override
  State<DietRecognitionConfirmPage> createState() =>
      _DietRecognitionConfirmPageState();
}

class _DietRecognitionConfirmPageState
    extends State<DietRecognitionConfirmPage> {
  late final TextEditingController _nameController;
  final _noteController = TextEditingController();
  late FoodCalorieEstimate _estimate;
  late String _portionText;
  late MealType _mealType;
  late DateTime _recordTime;
  var _isCalculating = false;

  static const _portions = ['一整份', '半份', '半袋', '半个', '一小块', '一杯'];

  @override
  void initState() {
    super.initState();
    _estimate = widget.estimate;
    _portionText = widget.estimate.portionText;
    _mealType = widget.mealType;
    _recordTime = DateTime.now();
    _nameController = TextEditingController(text: widget.estimate.foodName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _recalculate() async {
    setState(() => _isCalculating = true);
    final profile = await widget.userProfileService.loadProfile();
    final estimate = await widget.agentService.estimateFoodCalories(
      description: _nameController.text.trim(),
      imagePath: widget.imagePath,
      ingredientsText:
          widget.ingredientsText.isEmpty ? null : widget.ingredientsText,
      portionText: _portionText,
      mealType: _mealType.label,
      profile: profile,
    );
    if (!mounted) return;
    setState(() {
      _estimate = estimate;
      _isCalculating = false;
    });
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_recordTime),
    );
    if (!mounted || time == null) return;
    final now = DateTime.now();
    setState(() {
      _recordTime =
          DateTime(now.year, now.month, now.day, time.hour, time.minute);
    });
  }

  Future<void> _confirm() async {
    final record = MealRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: DateTime.now(),
      mealType: _mealType,
      foodName: _nameController.text.trim().isEmpty
          ? _estimate.foodName
          : _nameController.text.trim(),
      description: widget.description,
      estimatedCalories: _estimate.estimatedCalories,
      imageUrl: widget.imagePath,
      portionText: _portionText,
      ingredientsText: widget.ingredientsText,
      note: _noteController.text.trim(),
      recordTime: _recordTime,
      stickerStyle: '白色描边',
      sourceType: widget.sourceType,
    );
    final result = await Navigator.of(context).push<MealRecord>(
      MaterialPageRoute(builder: (_) => FoodStickerEditorPage(record: record)),
    );
    if (!mounted || result == null) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('确认识别结果')),
      body: ResponsivePageList(
        maxWidth: 720,
        top: 12,
        bottom: 30,
        children: [
          SoftCard(
            color: AppColors.primaryMist,
            borderColor: AppColors.outlineSoft,
            child: Column(
              children: [
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: AppColors.champagneSoft,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Icon(
                      widget.imagePath == null
                          ? Icons.fastfood_outlined
                          : Icons.image_outlined,
                      size: 70,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '约 ${_estimate.estimatedCalories} kcal',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  '识别置信度 ${(_estimate.confidence * 100).round()}%',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: '食物名称'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _portionText,
            decoration: const InputDecoration(labelText: '食用比例'),
            items: [
              for (final portion in _portions)
                DropdownMenuItem(value: portion, child: Text(portion)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _portionText = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MealType>(
            initialValue: _mealType,
            decoration: const InputDecoration(labelText: '餐次'),
            items: [
              for (final meal in MealType.values)
                DropdownMenuItem(value: meal, child: Text(meal.label)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _mealType = value);
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('记录时间'),
            subtitle: Text(
              '${_recordTime.hour.toString().padLeft(2, '0')}:'
              '${_recordTime.minute.toString().padLeft(2, '0')}',
            ),
            trailing: const Icon(Icons.schedule_rounded),
            onTap: _pickTime,
          ),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: '备注',
              hintText: '例如：今天很想吃甜的',
            ),
          ),
          const SizedBox(height: 16),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_estimate.nutritionNote),
                const SizedBox(height: 8),
                Text(
                  _estimate.suggestion,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.secondaryInk,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _isCalculating ? null : _recalculate,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_isCalculating ? '重新计算中...' : '重新计算热量'),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _confirm,
              child: const Text('确认，制作贴纸'),
            ),
          ),
        ],
      ),
    );
  }
}
