import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/agent_service.dart';
import '../services/journal_repository.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/page_header.dart';
import '../widgets/responsive_page.dart';
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
  var _targetWeight = 48.0;
  var _hasSeenDietGuide = false;
  var _isLoadingData = true;
  var _isOpeningDietRecord = false;
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
      widget.userProfileService.loadProfile(),
    ]);
    final meals = results[0] as List<MealRecord>;
    final weights = results[1] as List<WeightRecord>;
    final profile = results[3] as UserProfile;
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
      _targetWeight = profile.targetWeight;
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
      final record = WeightRecord(date: DateTime.now(), weight: result);
      final lastRecord = _weights.isEmpty ? null : _weights.last;
      final isSameDay = lastRecord != null &&
          lastRecord.date.year == record.date.year &&
          lastRecord.date.month == record.date.month &&
          lastRecord.date.day == record.date.day;
      if (isSameDay) {
        _weights[_weights.length - 1] = record;
      } else {
        _weights.add(record);
      }
    });
    await widget.journalRepository.saveWeightRecords(_weights);
  }

  void startQuickWeight() => _recordWeight();

  void startQuickMeal() => _openDietRecord();

  Future<void> _openDietRecord({MealType? meal}) async {
    if (_isOpeningDietRecord) return;
    _isOpeningDietRecord = true;
    final page = _hasSeenDietGuide
        ? DietCapturePage(
            agentService: widget.agentService,
            userProfileService: widget.userProfileService,
            initialMeal: meal,
          )
        : DietRecordGuidePage(
            agentService: widget.agentService,
            userProfileService: widget.userProfileService,
            onCaptureStarted: _markDietGuideSeen,
            initialMeal: meal,
          );
    final record = await Navigator.of(
      context,
    ).push<MealRecord>(MaterialPageRoute(builder: (_) => page));
    if (!mounted) return;
    _isOpeningDietRecord = false;
    if (record == null) return;
    setState(() => _foodLogs.add(record));
    await widget.journalRepository.saveMealRecords(_foodLogs);
    await _refreshMealPlan();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${record.foodName}已贴到今日饮食手帐')));
  }

  Future<void> _markDietGuideSeen() async {
    _hasSeenDietGuide = true;
    await widget.journalRepository.setHasSeenDietGuide(true);
  }

  Future<void> _openDietTimeline() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => DietTimelinePage(records: List.of(_foodLogs)),
      ),
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
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }
    final totalCalories = _foodLogs.fold<int>(
      0,
      (sum, food) => sum + food.estimatedCalories,
    );

    return SafeArea(
      bottom: false,
      child: ResponsivePageList(
        maxWidth: 920,
        bottom: ResponsivePage.isWide(context) ? 40 : 126,
        children: [
          const PageHeader(title: '饮食体重', subtitle: '不用称重，轻松记下今天吃过的东西'),
          const SizedBox(height: 20),
          _WeightCard(
            weight: _weight,
            targetWeight: _targetWeight,
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
          _DietTimelineEntryCard(onTap: _openDietTimeline),
          const SizedBox(height: 20),
          SoftCard(
            color: AppColors.surface,
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

class _WeightCard extends StatelessWidget {
  const _WeightCard({
    required this.weight,
    required this.targetWeight,
    required this.points,
    required this.onAdd,
  });

  final double weight;
  final double targetWeight;
  final List<WeightRecord> points;
  final VoidCallback onAdd;

  String _changeLabel(int days) {
    if (points.length < 2) return '${days}天 0.0 kg';
    final latest = points.last;
    final earliestDate = latest.date.subtract(Duration(days: days));
    final start = points.firstWhere(
      (point) => !point.date.isBefore(earliestDate),
      orElse: () => points.first,
    );
    final change = latest.weight - start.weight;
    final value = change > 0
        ? '+${change.toStringAsFixed(1)}'
        : change.toStringAsFixed(1);
    return '$days天 $value kg';
  }

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
              Tooltip(
                message: '新增体重',
                child: OutlinedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('新增体重'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _WeightMetaBadge('目标体重 ${targetWeight.toStringAsFixed(1)} kg'),
              _WeightMetaBadge(_changeLabel(7)),
              _WeightMetaBadge(_changeLabel(30)),
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

class _WeightMetaBadge extends StatelessWidget {
  const _WeightMetaBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _DietTimelineEntryCard extends StatelessWidget {
  const _DietTimelineEntryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.surface,
      borderColor: AppColors.outlineSoft,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.softGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.timeline_rounded, color: AppColors.ink),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('饮食回顾', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '按日、周、月查看复盘和下一期建议',
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

enum _DietTimelineRange {
  day('日'),
  week('周'),
  month('月');

  const _DietTimelineRange(this.label);

  final String label;
}

class DietTimelinePage extends StatefulWidget {
  const DietTimelinePage({required this.records, super.key});

  final List<MealRecord> records;

  @override
  State<DietTimelinePage> createState() => _DietTimelinePageState();
}

class _DietTimelinePageState extends State<DietTimelinePage> {
  var _range = _DietTimelineRange.day;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _startOfWeek(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));

  ({DateTime start, DateTime end}) get _currentPeriod {
    return switch (_range) {
      _DietTimelineRange.day => (
          start: _today,
          end: _today.add(const Duration(days: 1)),
        ),
      _DietTimelineRange.week => (
          start: _startOfWeek(_today),
          end: _startOfWeek(_today).add(const Duration(days: 7)),
        ),
      _DietTimelineRange.month => (
          start: DateTime(_today.year, _today.month),
          end: DateTime(_today.year, _today.month + 1),
        ),
    };
  }

  ({DateTime start, DateTime end}) get _previousPeriod {
    final current = _currentPeriod;
    return switch (_range) {
      _DietTimelineRange.day => (
          start: current.start.subtract(const Duration(days: 1)),
          end: current.start,
        ),
      _DietTimelineRange.week => (
          start: current.start.subtract(const Duration(days: 7)),
          end: current.start,
        ),
      _DietTimelineRange.month => (
          start: DateTime(current.start.year, current.start.month - 1),
          end: current.start,
        ),
    };
  }

  List<MealRecord> _recordsFor(({DateTime start, DateTime end}) period) {
    return widget.records
        .where(
          (record) =>
              !record.date.isBefore(period.start) &&
              record.date.isBefore(period.end),
        )
        .toList()
      ..sort((a, b) => a.recordTime.compareTo(b.recordTime));
  }

  String _periodLabel(({DateTime start, DateTime end}) period) {
    return switch (_range) {
      _DietTimelineRange.day => _dayLabel(period.start),
      _DietTimelineRange.week =>
        '${period.start.month}/${period.start.day} - ${period.end.subtract(const Duration(days: 1)).month}/${period.end.subtract(const Duration(days: 1)).day}',
      _DietTimelineRange.month => '${period.start.year}年${period.start.month}月',
    };
  }

  String _dayLabel(DateTime date) {
    if (date == _today) return '今天';
    if (date == _today.subtract(const Duration(days: 1))) return '昨天';
    if (date == _today.add(const Duration(days: 1))) return '明天';
    return '${date.month}月${date.day}日';
  }

  String get _previousTitle => switch (_range) {
        _DietTimelineRange.day => '前一日数据总结',
        _DietTimelineRange.week => '前一周数据总结',
        _DietTimelineRange.month => '前一月数据总结',
      };

  String get _currentTitle => switch (_range) {
        _DietTimelineRange.day => '当日数据总结',
        _DietTimelineRange.week => '当周数据总结',
        _DietTimelineRange.month => '当月数据总结',
      };

  String get _nextTitle => switch (_range) {
        _DietTimelineRange.day => '下一日饮食建议',
        _DietTimelineRange.week => '下一周饮食建议',
        _DietTimelineRange.month => '下一月饮食建议',
      };

  @override
  Widget build(BuildContext context) {
    final currentPeriod = _currentPeriod;
    final previousPeriod = _previousPeriod;
    final currentRecords = _recordsFor(currentPeriod);
    final previousRecords = _recordsFor(previousPeriod);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: ResponsivePageList(
          maxWidth: 820,
          bottom: 40,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: '返回',
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const Spacer(),
                Text(
                  _periodLabel(currentPeriod),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const PageHeader(title: '饮食回顾', subtitle: '上一期、本期和下一期建议，帮你看见饮食结构'),
            const SizedBox(height: 16),
            _DietRangeSelector(
              selected: _range,
              onChanged: (range) => setState(() => _range = range),
            ),
            const SizedBox(height: 16),
            _DietReviewCard(
              title: _previousTitle,
              period: _periodLabel(previousPeriod),
              records: previousRecords,
              range: _range,
            ),
            const SizedBox(height: 14),
            _DietReviewCard(
              title: _currentTitle,
              period: _periodLabel(currentPeriod),
              records: currentRecords,
              range: _range,
              highlighted: true,
            ),
            const SizedBox(height: 14),
            _DietNextAdviceCard(
              title: _nextTitle,
              records: currentRecords,
              range: _range,
            ),
          ],
        ),
      ),
    );
  }
}

class _DietRangeSelector extends StatelessWidget {
  const _DietRangeSelector({required this.selected, required this.onChanged});

  final _DietTimelineRange selected;
  final ValueChanged<_DietTimelineRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.primaryMist,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.outlineSoft),
      ),
      child: Row(
        children: [
          for (final range in _DietTimelineRange.values)
            Expanded(
              child: _RangeButton(
                range: range,
                selected: selected == range,
                onTap: () => onChanged(range),
              ),
            ),
        ],
      ),
    );
  }
}

class _RangeButton extends StatelessWidget {
  const _RangeButton({
    required this.range,
    required this.selected,
    required this.onTap,
  });

  final _DietTimelineRange range;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            range.label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? AppColors.primaryDark : AppColors.mutedInk,
                ),
          ),
        ),
      ),
    );
  }
}

class _DietReviewCard extends StatelessWidget {
  const _DietReviewCard({
    required this.title,
    required this.period,
    required this.records,
    required this.range,
    this.highlighted = false,
  });

  final String title;
  final String period;
  final List<MealRecord> records;
  final _DietTimelineRange range;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final review = _DietReview.fromRecords(records);

    return SoftCard(
      color: highlighted ? AppColors.primaryMist : AppColors.surface,
      borderColor: AppColors.outlineSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(period, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _TimelineMetric(
                  label: '摄入',
                  value: '${review.totalCalories}',
                  unit: 'kcal',
                ),
              ),
              Expanded(
                child: _TimelineMetric(
                  label: '记录',
                  value: '${review.recordCount}',
                  unit: '次',
                ),
              ),
              Expanded(
                child: _TimelineMetric(
                  label: '日均',
                  value: '${review.dailyAverage(range)}',
                  unit: 'kcal',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            review.summary(range),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.55),
          ),
          const SizedBox(height: 14),
          _DietInsightWrap(review: review),
        ],
      ),
    );
  }
}

class _DietNextAdviceCard extends StatelessWidget {
  const _DietNextAdviceCard({
    required this.title,
    required this.records,
    required this.range,
  });

  final String title;
  final List<MealRecord> records;
  final _DietTimelineRange range;

  @override
  Widget build(BuildContext context) {
    final review = _DietReview.fromRecords(records);

    return SoftCard(
      color: AppColors.surface,
      borderColor: AppColors.outlineSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.softYellow,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lightbulb_outline_rounded, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final advice in review.nextSuggestions(range)) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '• ',
                  style: TextStyle(color: AppColors.primaryDark),
                ),
                Expanded(
                  child: Text(
                    advice,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.55),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _TimelineMetric extends StatelessWidget {
  const _TimelineMetric({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            text: value,
            style: Theme.of(context).textTheme.titleLarge,
            children: [
              TextSpan(
                text: ' $unit',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.secondaryInk,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DietInsightWrap extends StatelessWidget {
  const _DietInsightWrap({required this.review});

  final _DietReview review;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _DietInsightChip(label: '最常吃', value: review.favoriteFood),
        _DietInsightChip(label: '热量最高', value: review.highestFoodLabel),
        _DietInsightChip(label: '摄入最多', value: review.highestDayLabel),
        _DietInsightChip(label: '高频餐次', value: review.topMealLabel),
      ],
    );
  }
}

class _DietInsightChip extends StatelessWidget {
  const _DietInsightChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 3),
          Text(value, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _DietReview {
  const _DietReview({
    required this.totalCalories,
    required this.recordCount,
    required this.favoriteFood,
    required this.highestFoodLabel,
    required this.highestDayLabel,
    required this.topMealLabel,
    required this.topMealType,
  });

  final int totalCalories;
  final int recordCount;
  final String favoriteFood;
  final String highestFoodLabel;
  final String highestDayLabel;
  final String topMealLabel;
  final MealType? topMealType;

  static _DietReview fromRecords(List<MealRecord> records) {
    if (records.isEmpty) {
      return const _DietReview(
        totalCalories: 0,
        recordCount: 0,
        favoriteFood: '暂无',
        highestFoodLabel: '暂无',
        highestDayLabel: '暂无',
        topMealLabel: '暂无',
        topMealType: null,
      );
    }

    final totalCalories = records.fold<int>(
      0,
      (sum, record) => sum + record.estimatedCalories,
    );
    final favoriteFood = _topByCount(records.map((record) => record.foodName));
    final highestFood = records.reduce(
      (current, next) =>
          current.estimatedCalories >= next.estimatedCalories ? current : next,
    );
    final mealTypeName = _topByCount(
      records.map((record) => record.mealType.name),
    );
    final topMealType = MealType.values.firstWhere(
      (mealType) => mealType.name == mealTypeName,
    );
    final dayTotals = <DateTime, int>{};
    for (final record in records) {
      final date = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      dayTotals[date] = (dayTotals[date] ?? 0) + record.estimatedCalories;
    }
    final highestDay = dayTotals.entries.reduce(
      (current, next) => current.value >= next.value ? current : next,
    );

    return _DietReview(
      totalCalories: totalCalories,
      recordCount: records.length,
      favoriteFood: favoriteFood,
      highestFoodLabel:
          '${highestFood.foodName} ${highestFood.estimatedCalories} kcal',
      highestDayLabel:
          '${highestDay.key.month}/${highestDay.key.day} ${highestDay.value} kcal',
      topMealLabel: topMealType.label,
      topMealType: topMealType,
    );
  }

  static String _topByCount(Iterable<String> values) {
    final counts = <String, int>{};
    for (final value in values) {
      counts[value] = (counts[value] ?? 0) + 1;
    }
    return counts.entries
        .reduce((current, next) => current.value >= next.value ? current : next)
        .key;
  }

  int dailyAverage(_DietTimelineRange range) {
    final days = switch (range) {
      _DietTimelineRange.day => 1,
      _DietTimelineRange.week => 7,
      _DietTimelineRange.month => 30,
    };
    return recordCount == 0 ? 0 : (totalCalories / days).round();
  }

  String summary(_DietTimelineRange range) {
    if (recordCount == 0) {
      return '这段时间还没有饮食记录。先从一餐开始记录，之后 easy 会帮你看见饮食结构里的变化。';
    }
    final scope = switch (range) {
      _DietTimelineRange.day => '这一天',
      _DietTimelineRange.week => '这一周',
      _DietTimelineRange.month => '这个月',
    };
    return '$scope共记录了 $recordCount 次饮食，摄入约 $totalCalories kcal。最常出现的是 $favoriteFood，热量最高的是 $highestFoodLabel，摄入最多的一天是 $highestDayLabel。';
  }

  List<String> nextSuggestions(_DietTimelineRange range) {
    if (recordCount == 0) {
      return const [
        '先记录下一餐吃了什么，不用追求完整，积累几次后再看结构。',
        '如果方便，可以补充份量或图片，这会让后续热量估算更稳定。',
      ];
    }
    final scope = switch (range) {
      _DietTimelineRange.day => '明天',
      _DietTimelineRange.week => '下一周',
      _DietTimelineRange.month => '下个月',
    };
    final mealAdvice = switch (topMealType) {
      MealType.snack => '加餐出现比较多，$scope可以优先把零食换成水果、酸奶或坚果小份。',
      MealType.dinner => '晚餐占比偏明显，$scope可以把主食和油脂稍微前移到午餐。',
      MealType.lunch => '午餐是主要摄入点，$scope可以保留蛋白质，同时补一份蔬菜。',
      MealType.breakfast => '早餐记录比较集中，$scope可以继续保持稳定开场，再观察午晚餐节奏。',
      null => '$scope先保持记录，积累更多数据后再看结构。',
    };
    return [
      mealAdvice,
      '$scope不用追求吃得完美，先观察热量最高的食物是否真的带来了足够的饱腹感。',
      '下一次记录时，尽量补一句份量描述，比如“半碗”“一杯”“一小份”。',
    ];
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
        border: Border.all(
          color: stickerBorder.withValues(alpha: .7),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: .07),
            blurRadius: 14,
            offset: const Offset(0, 6),
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
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.ink),
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
              Text(
                '添加${meal.label}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
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
      color: AppColors.primaryMist,
      borderColor: AppColors.outlineSoft,
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
              backgroundColor: AppColors.surface,
              color: AppColors.primary,
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
      ..color = AppColors.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final gridPaint = Paint()
      ..color = AppColors.outline
      ..strokeWidth = 1;
    final dotPaint = Paint()..color = AppColors.primary;
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
      canvas.drawCircle(Offset(x, y), 3.2, dotPaint);
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
