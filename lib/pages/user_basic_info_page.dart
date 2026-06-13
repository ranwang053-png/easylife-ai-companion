import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';

class UserBasicInfoPage extends StatefulWidget {
  const UserBasicInfoPage({
    required this.accountIdentifier,
    required this.initialNickname,
    required this.onCompleted,
    required this.userProfileService,
    super.key,
  });

  final String accountIdentifier;
  final String initialNickname;
  final ValueChanged<UserProfile> onCompleted;
  final UserProfileService userProfileService;

  @override
  State<UserBasicInfoPage> createState() => _UserBasicInfoPageState();
}

class _UserBasicInfoPageState extends State<UserBasicInfoPage> {
  late final TextEditingController _nicknameController;
  final _occupationController = TextEditingController();
  final _mbtiController = TextEditingController();
  final _dietController = TextEditingController();
  DateTime _birthday = DateTime(1998, 1, 1);

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.initialNickname);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _occupationController.dispose();
    _mbtiController.dispose();
    _dietController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    var selectedDate = _birthday;
    final date = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: AppColors.canvas,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: SizedBox(
          height: 320,
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
                      '选择出生日期',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, selectedDate),
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  dateOrder: DatePickerDateOrder.ymd,
                  initialDateTime: _birthday,
                  minimumDate: DateTime(1940),
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (date) => selectedDate = date,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (date != null && mounted) setState(() => _birthday = date);
  }

  Future<void> _submit() async {
    final current = await widget.userProfileService.loadProfile();
    final nickname = _nicknameController.text.trim();
    widget.onCompleted(
      current.copyWith(
        accountIdentifier: widget.accountIdentifier,
        nickname: nickname.isEmpty ? '新朋友' : nickname,
        birthday: _birthday,
        occupation: _occupationController.text.trim(),
        mbti: _mbtiController.text.trim().toUpperCase(),
        dietPreference: _dietController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        automaticallyImplyLeading: false,
        title: const Text('基础信息'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Text('让easy更懂你', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('这些信息会保存在本机，之后可在「我的」继续修改。'),
          const SizedBox(height: 24),
          _field(_nicknameController, '昵称'),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.outline),
            ),
            title: const Text('出生日期'),
            subtitle: Text(_formatDate(_birthday)),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: _pickBirthday,
          ),
          const SizedBox(height: 12),
          _field(_occupationController, '职业'),
          const SizedBox(height: 12),
          _field(_mbtiController, 'MBTI', hint: '例如 INFJ'),
          const SizedBox(height: 12),
          _field(_dietController, '饮食偏好', hint: '例如清淡、低糖、不吃香菜'),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(backgroundColor: AppColors.ink),
              child: const Text('保存档案'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
