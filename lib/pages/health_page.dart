import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/agent_service.dart';
import '../services/journal_repository.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/page_header.dart';
import '../widgets/soft_card.dart';
import 'diet_capture_page.dart';
import 'diet_record_guide_page.dart';

Color _tintForMeal(MealType meal) => switch (meal) {
      MealType.breakfast => AppColors.softYellow,
      MealType.lunch => AppColors.softGreen,
      MealType.dinner => AppColors.mistBlue,
      MealType.snack => AppColors.softPink,
    };

class HealthPage extends StatefulWidget {
  const HealthPage({
    required this.agentService,
    required this.userProfileService,
    required this.journalRepository,
    super.key,
  });

  final AgentService agentService;
  final UserProfileService userProfileService;
  final JournalRepository journalRepository;

  @override
  State<HealthPage> createState() => HealthPageState();
}

class HealthPageState extends State<HealthPage> {
  final List<MealRecord> _foodLogs = [];
  final List<WeightRecord> _weights = [];

  var _weight = 52.3;
  var _hasSeenDietGuide = false;
  var _isLoadingData = true;
  MealPlanSuggestion? _mealPlan;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      widget.journalRepository.loadMealRecords(),
      widget.journalRepository.loadWeightRecords(),
      widget.journalRepository.hasSeenDietGuide(),
    ]);
    final meals = results[0] as List<MealRecord>;
    final weights = results[1] as List<WeightRecord>;
    if (!mounted) return;
    setState(() {
      _foodLogs
        ..clear()
        ..addAll(meals);
      _weights
        ..clear()
        ..addAll(weights);
      if (_weights.isNotEmpty) _weight = _weights.last.weight;
      _hasSeenDietGuide = results[2] as bool;
      _isLoadingData = false;
    });
    await _refreshMealPlan();
  }

  Future<void> _recordWeight() async {
    var input = _weight.toStringAsFixed(1);
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('记录今日体重'),
        content: TextFormField(
          initialValue: input,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (value) => input = value,
          onFieldSubmitted: (value) {
            Navigator.pop(context, double.tryParse(value));
          },
          decoration: const InputDecoration(
            hintText: '例如 52.3',
            suffixText: 'kg',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, double.tryParse(input));
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _weight = result;
      final record = WeightRecord(
        date: DateTime.now(),
        weight: result,
      );
      if (_weights.isEmpty) {
        _weights.add(record);
      } else {
        _weights[_weights.length - 1] = record;
      }
    });
    await widget.journalRepository.saveWeightRecords(_weights);
  }

  void startQuickWeight() => _recordWeight();

  void startQuickMeal() => _openDietRecord();

  Future<void> _openDietRecord({MealType? meal}) async {
    final page = _hasSeenDietGuide
        ? DietCapturePage(
            agentService: widget.agentService,
            userProfileService: widget.userProfileService,
            initialMeal: meal,
          )
        : DietRecordGuidePage(
            agentService: widget.agentService,
            userProfileService: widget.userProfileService,
            initialMeal: meal,
          );
    final record = await Navigator.of(context).push<MealRecord>(
      MaterialPageRoute(builder: (_) => page),
    );
    if (!mounted) return;
    _hasSeenDietGuide = true;
    await widget.journalRepository.setHasSeenDietGuide(true);
    if (record == null) return;
    setState(() => _foodLogs.add(record));
    await widget.journalRepository.saveMealRecords(_foodLogs);
    await _refreshMealPlan();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${record.foodName}已贴到今日饮食手帐')),
    );
  }

  Future<void> _refreshMealPlan() async {
    final profile = await widget.userProfileService.loadProfile();
    final plan = await widget.agentService.generateMealPlan(_foodLogs, profile);
    if (mounted) setState(() => _mealPlan = plan);
  }

  Color _mealTint(MealType meal) => _tintForMeal(meal);

  int _mealCalories(MealType meal) {
    return _foodLogs
        .where((food) => food.mealType == meal)
        .fold(0, (sum, food) => sum + food.estimatedCalories);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const SafeArea(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final totalCalories = _foodLogs.fold<int>(
      0,
      (sum, food) => sum + food.estimatedCalories,
    );

    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 126),
        children: [
          PageHeader(
            title: '饮食体重',
            subtitle: '不用称重，轻松记下今天吃过的东西',
            trailing: IconButton.filledTonal(
              onPressed: _recordWeight,
              tooltip: '新增体重',
              style: IconButton.styleFrom(backgroundColor: Colors.white),
              icon: const Icon(Icons.add_chart_rounded),
            ),
          ),
          const SizedBox(height: 20),
          _WeightCard(
            weight: _weight,
            points: _weights,
            onAdd: _recordWeight,
          ),
          const SizedBox(height: 20),
          _DailySummaryCard(
            totalCalories: totalCalories,
            targetCalories: 1800,
            mealCalories: {
              for (final meal in MealType.values) meal: _mealCalories(meal),
            },
            plan: _mealPlan,
          ),
          const SizedBox(height: 20),
          _RecordFoodBanner(onTap: _openDietRecord),
          const SizedBox(height: 20),
          SoftCard(
            color: const Color(0xFFFFFCF6),
            borderColor: const Color(0xFFECE3D5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '今日饮食日记',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    const Icon(Icons.auto_stories_outlined, size: 21),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '把今天吃过的东西，一张张贴在这里',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                for (final meal in MealType.values)
                  _MealLogSection(
                    meal: meal,
                    foods: _foodLogs
                        .where((food) => food.mealType == meal)
                        .toList(),
                    calories: _mealCalories(meal),
                    tint: _mealTint(meal),
                    onAdd: () => _openDietRecord(meal: meal),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordFoodBanner extends StatelessWidget {
  const _RecordFoodBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: const Color(0xFFF5F8F1),
      borderColor: const Color(0xFFDCE7D7),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: AppColors.softGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.camera_alt_outlined),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '拍照或写一句话记录',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'AI Mock 识别热量，再制作成食物贴纸',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded),
        ],
      ),
    );
  }
}

class _WeightCard extends StatelessWidget {
  const _WeightCard({
    required this.weight,
    required this.points,
    required this.onAdd,
  });

  final double weight;
  final List<WeightRecord> points;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今日体重',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        text: weight.toStringAsFixed(1),
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(fontSize: 38),
                        children: const [
                          TextSpan(
                            text: ' kg',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('新增'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const _TrendBadge(),
              const Spacer(),
              Text(
                '最近 7 天',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            width: double.infinity,
            child: CustomPaint(painter: _WeightChartPainter(points)),
          ),
        ],
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Text(
        '7 天 -0.6 kg',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MealLogSection extends StatelessWidget {
  const _MealLogSection({
    required this.meal,
    required this.foods,
    required this.calories,
    required this.tint,
    required this.onAdd,
  });

  final MealType meal;
  final List<MealRecord> foods;
  final int calories;
  final Color tint;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(meal.label, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text(
                '$calories kcal',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 146,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: foods.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (index == foods.length) {
                  return _AddFoodCard(meal: meal, tint: tint, onTap: onAdd);
                }
                return _FoodCard(food: foods[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodCard extends StatelessWidget {
  const _FoodCard({required this.food});

  final MealRecord food;

  @override
  Widget build(BuildContext context) {
    final stickerBorder = switch (food.stickerStyle) {
      '浅绿色描边' => const Color(0xFFB9D7B8),
      '浅黄色描边' => const Color(0xFFF0D58F),
      _ => Colors.white,
    };
    return Container(
      width: 132,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: stickerBorder, width: 5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x13000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 68,
            decoration: BoxDecoration(
              color: _tintForMeal(food.mealType),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(
              child: Icon(
                food.imageUrl != null
                    ? Icons.image_outlined
                    : Icons.restaurant_rounded,
                size: 31,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            food.foodName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.ink,
                ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Text(
                  food.mealType.label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(fontSize: 9),
                ),
              ),
              Text(
                '${food.estimatedCalories} kcal',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.ink,
                      fontSize: 10,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddFoodCard extends StatelessWidget {
  const _AddFoodCard({
    required this.meal,
    required this.tint,
    required this.onTap,
  });

  final MealType meal;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tint.withValues(alpha: .35),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 112,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_circle_outline_rounded, size: 30),
              const SizedBox(height: 8),
              Text('添加${meal.label}',
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 3),
              const Text(
                '制作贴纸',
                style: TextStyle(fontSize: 10, color: AppColors.mutedInk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailySummaryCard extends StatelessWidget {
  const _DailySummaryCard({
    required this.totalCalories,
    required this.targetCalories,
    required this.mealCalories,
    required this.plan,
  });

  final int totalCalories;
  final int targetCalories;
  final Map<MealType, int> mealCalories;
  final MealPlanSuggestion? plan;

  @override
  Widget build(BuildContext context) {
    final progress = (totalCalories / targetCalories).clamp(0.0, 1.0);
    return SoftCard(
      color: const Color(0xFFFFFBF3),
      borderColor: const Color(0xFFF0E4C9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('今日摄入', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text(
                '$totalCalories kcal',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontSize: 22),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: Colors.white,
              color: const Color(0xFF9CB58D),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '目标 $targetCalories kcal · 已完成 ${(progress * 100).round()}%',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final meal in MealType.values)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        meal.label,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${mealCalories[meal] ?? 0}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Text(
                        'kcal',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColors.mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Divider(height: 28),
          _AdviceRow(
            icon: Icons.auto_awesome_rounded,
            title: 'AI 饮食建议',
            text: plan?.todayAdvice ?? '正在生成个性化饮食建议…',
          ),
          const SizedBox(height: 14),
          _AdviceRow(
            icon: Icons.event_note_outlined,
            title: '明日饮食规划',
            text: plan?.tomorrowPlan ?? '正在生成明日饮食规划…',
          ),
        ],
      ),
    );
  }
}

class _AdviceRow extends StatelessWidget {
  const _AdviceRow({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 19),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 3),
              Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeightChartPainter extends CustomPainter {
  const _WeightChartPainter(this.points);

  final List<WeightRecord> points;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF9B83D4)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final gridPaint = Paint()
      ..color = AppColors.outline
      ..strokeWidth = 1;
    final dotPaint = Paint()..color = const Color(0xFF9B83D4);
    const labelStyle = TextStyle(color: AppColors.mutedInk, fontSize: 9);

    for (var row = 0; row < 3; row++) {
      final y = 10 + (size.height - 32) / 2 * row;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final minValue = points.map((point) => point.weight).reduce(math.min) - .2;
    final maxValue = points.map((point) => point.weight).reduce(math.max) + .2;
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final x = size.width / (points.length - 1) * index;
      final normalized =
          (points[index].weight - minValue) / (maxValue - minValue);
      final y = 10 + (1 - normalized) * (size.height - 42);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
      final painter = TextPainter(
        text: TextSpan(
          text: index == points.length - 1
              ? '今天'
              : '${points[index].date.month}/${points[index].date.day}',
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(x - painter.width / 2, size.height - painter.height),
      );
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) =>
      oldDelegate.points != points;
}
