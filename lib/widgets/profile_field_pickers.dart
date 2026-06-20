import 'package:city_pickers/city_pickers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

const dietPreferenceOptions = [
  '不吃香菜',
  '爱吃辣',
  '少油少盐',
  '低糖',
  '高蛋白',
  '素食',
  '乳糖不耐',
  '不吃海鲜',
];

const recentGoalOptions = ['减脂', '健身', '创作', '抗炎', '无'];

Future<DateTime?> showBirthDateTimePicker(
  BuildContext context, {
  required DateTime initialValue,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _BirthDateTimePicker(initialValue: initialValue),
  );
}

Future<String?> showRegionPicker(
  BuildContext context, {
  required String title,
}) async {
  final result = await CityPickers.showCityPicker(
    context: context,
    showType: ShowType.pca,
    height: 390,
    itemExtent: 48,
    borderRadius: 24,
    cancelWidget: const Text('取消'),
    confirmWidget: const Text(
      '完成',
      style: TextStyle(
        color: AppColors.primaryDark,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
  if (result == null) return null;
  return [
    result.provinceName,
    result.cityName,
    result.areaName,
  ].whereType<String>().where((value) => value.isNotEmpty).join('-');
}

class _BirthDateTimePicker extends StatefulWidget {
  const _BirthDateTimePicker({required this.initialValue});

  final DateTime initialValue;

  @override
  State<_BirthDateTimePicker> createState() => _BirthDateTimePickerState();
}

class _BirthDateTimePickerState extends State<_BirthDateTimePicker> {
  static const _firstYear = 1940;
  late int _year;
  late int _month;
  late int _day;
  late int _hour;
  late int _minute;
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _dayController;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  int get _daysInMonth => DateUtils.getDaysInMonth(_year, _month);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final value = widget.initialValue.isAfter(now) ? now : widget.initialValue;
    _year = value.year;
    _month = value.month;
    _day = value.day;
    _hour = value.hour;
    _minute = value.minute;
    _yearController =
        FixedExtentScrollController(initialItem: _year - _firstYear);
    _monthController = FixedExtentScrollController(initialItem: _month - 1);
    _dayController = FixedExtentScrollController(initialItem: _day - 1);
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _normalizeDay() {
    final nextDay = _day.clamp(1, _daysInMonth);
    if (nextDay == _day) return;
    _day = nextDay;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_dayController.hasClients) {
        _dayController.jumpToItem(_day - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 430,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  Text(
                    '出生日期与时间',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      DateTime(_year, _month, _day, _hour, _minute),
                    ),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Text(
                '若出生时间不详，可选择默认 12:00',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  _wheel(
                    controller: _yearController,
                    count: currentYear - _firstYear + 1,
                    label: (index) => '${_firstYear + index}年',
                    onChanged: (index) => setState(() {
                      _year = _firstYear + index;
                      _normalizeDay();
                    }),
                  ),
                  _wheel(
                    controller: _monthController,
                    count: 12,
                    label: (index) =>
                        '${(index + 1).toString().padLeft(2, '0')}月',
                    onChanged: (index) => setState(() {
                      _month = index + 1;
                      _normalizeDay();
                    }),
                  ),
                  Expanded(
                    child: CupertinoPicker.builder(
                      scrollController: _dayController,
                      itemExtent: 48,
                      useMagnifier: true,
                      magnification: 1.08,
                      onSelectedItemChanged: (index) =>
                          setState(() => _day = index + 1),
                      childCount: _daysInMonth,
                      itemBuilder: (context, index) => _wheelItem(
                        '${(index + 1).toString().padLeft(2, '0')}日',
                      ),
                    ),
                  ),
                  _wheel(
                    controller: _hourController,
                    count: 24,
                    label: (index) => '${index.toString().padLeft(2, '0')}时',
                    onChanged: (index) => setState(() => _hour = index),
                  ),
                  _wheel(
                    controller: _minuteController,
                    count: 60,
                    label: (index) => '${index.toString().padLeft(2, '0')}分',
                    onChanged: (index) => setState(() => _minute = index),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required String Function(int index) label,
    required ValueChanged<int> onChanged,
  }) {
    return Expanded(
      child: CupertinoPicker.builder(
        scrollController: controller,
        itemExtent: 48,
        useMagnifier: true,
        magnification: 1.08,
        onSelectedItemChanged: onChanged,
        childCount: count,
        itemBuilder: (context, index) => _wheelItem(label(index)),
      ),
    );
  }

  Widget _wheelItem(String label) {
    return Center(
      child: Text(
        label,
        maxLines: 1,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

Future<List<String>?> showChoiceEditor(
  BuildContext context, {
  required String title,
  required List<String> options,
  required List<String> selected,
  required String customHint,
  bool noneIsExclusive = false,
}) {
  final values = [...selected];
  final controller = TextEditingController();
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) {
        void addCustom() {
          final value = controller.text.trim();
          if (value.isEmpty || values.contains(value)) return;
          setSheetState(() {
            if (noneIsExclusive) values.remove('无');
            values.add(value);
            controller.clear();
          });
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  onSubmitted: (_) => addCustom(),
                  decoration: InputDecoration(
                    hintText: customHint,
                    suffixIcon: IconButton(
                      onPressed: addCustom,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in options)
                      FilterChip(
                        label: Text(option),
                        selected: values.contains(option),
                        selectedColor: AppColors.softGreen,
                        onSelected: (enabled) => setSheetState(() {
                          if (noneIsExclusive && option == '无') {
                            values
                              ..clear()
                              ..add('无');
                          } else if (enabled) {
                            if (noneIsExclusive) values.remove('无');
                            values.add(option);
                          } else {
                            values.remove(option);
                          }
                        }),
                      ),
                  ],
                ),
                if (values.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('已选择', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final value in values)
                        InputChip(
                          label: Text(value),
                          onDeleted: () =>
                              setSheetState(() => values.remove(value)),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, values),
                    child: const Text('完成'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  ).whenComplete(controller.dispose);
}
