import 'package:flutter/material.dart';

import '../models/meal_record.dart';
import '../theme/app_colors.dart';

class FoodStickerEditorPage extends StatefulWidget {
  const FoodStickerEditorPage({required this.record, super.key});

  final MealRecord record;

  @override
  State<FoodStickerEditorPage> createState() => _FoodStickerEditorPageState();
}

class _FoodStickerEditorPageState extends State<FoodStickerEditorPage> {
  var _style = '白色描边';

  static const _styles = ['白色描边', '浅绿色描边', '浅黄色描边'];

  Color _borderColor(String style) => switch (style) {
        '浅绿色描边' => const Color(0xFFB9D7B8),
        '浅黄色描边' => const Color(0xFFF0D58F),
        _ => Colors.white,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('制作食物贴纸')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 245,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _borderColor(_style),
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: .08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(29),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.champagneSoft,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Center(
                        child: Icon(
                          widget.record.imageUrl == null
                              ? Icons.fastfood_rounded
                              : Icons.image_rounded,
                          size: 64,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.record.foodName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _StickerLabel(
                          text: widget.record.mealType.label,
                          color: AppColors.softGreen,
                        ),
                        const SizedBox(width: 7),
                        _StickerLabel(
                          text: '${widget.record.estimatedCalories} kcal',
                          color: AppColors.softYellow,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '选择贴纸描边',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final style in _styles)
                  ChoiceChip(
                    label: Text(style),
                    selected: style == _style,
                    onSelected: (_) => setState(() => _style = style),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(
                    widget.record.copyWith(stickerStyle: _style),
                  );
                },
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('贴到今日手帐'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('重新编辑'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StickerLabel extends StatelessWidget {
  const _StickerLabel({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
