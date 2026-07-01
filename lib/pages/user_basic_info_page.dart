import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../utils/pet_image_picker.dart';
import '../widgets/profile_field_pickers.dart';
import '../widgets/responsive_page.dart';
import '../widgets/user_avatar.dart';

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
  DateTime _birthday = DateTime(1998, 2, 1, 12);
  String _occupation = '';
  String _mbti = '';
  String _birthPlace = '';
  String _currentResidence = '';
  String _avatarImageUrl = '';
  final List<String> _dietPreferences = [];
  final List<String> _recentGoals = [];
  final List<String> _personalTags = [];

  static const _occupations = <String, List<String>>{
    '互联网与科技': ['产品经理', '软件工程师', '设计师', '数据分析师', '运营', '质量工程师'],
    '教育与科研': ['教师', '学生', '研究人员', '培训师', '教育管理'],
    '医疗与健康': ['医生', '护士', '药师', '心理咨询师', '健康管理师'],
    '商业与金融': ['金融从业者', '会计', '销售', '市场营销', '咨询顾问', '企业管理者'],
    '文化与创意': ['内容创作者', '媒体从业者', '摄影师', '编剧', '艺术工作者'],
    '公共与服务': ['公务员', '法律从业者', '社会服务', '餐饮从业者', '自由职业者'],
    '其他': [],
  };

  static const _mbtiTypes = [
    ('INTJ', '战略家'),
    ('INTP', '逻辑学家'),
    ('ENTJ', '指挥官'),
    ('ENTP', '辩论家'),
    ('INFJ', '提倡者'),
    ('INFP', '治愈诗人'),
    ('ENFJ', '主人公'),
    ('ENFP', '快乐小狗'),
    ('ISTJ', '检查者'),
    ('ISFJ', '守护者'),
    ('ESTJ', '执行官'),
    ('ESFJ', '执政官'),
    ('ISTP', '鉴赏家'),
    ('ISFP', '探险家'),
    ('ESTP', '企业家'),
    ('ESFP', '小太阳'),
  ];

  static const _popularTags = [
    '工作狂',
    '学霸',
    '拖延症',
    '夜猫子',
    '咖啡爱好者',
    '健身达人',
    '社恐',
    '旅行控',
  ];

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.initialNickname);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final value = await showBirthDateTimePicker(
      context,
      initialValue: _birthday,
    );
    if (value != null && mounted) setState(() => _birthday = value);
  }

  Future<void> _pickAvatar() async {
    try {
      final image = await pickPetImage(preferCamera: false);
      if (!mounted || image == null) return;
      setState(() => _avatarImageUrl = image.dataUrl);
    } on PetImagePickerException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _pickOccupation() async {
    String? category;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final jobs = category == null ? null : _occupations[category]!;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: SizedBox(
                height: 500,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (category != null)
                          IconButton(
                            onPressed: () =>
                                setSheetState(() => category = null),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        Expanded(
                          child: Text(
                            category == null ? '选择职业类别' : category!,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (category == null)
                      Expanded(
                        child: ListView(
                          children: [
                            for (final item in _occupations.keys)
                              ListTile(
                                title: Text(item),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                                onTap: () =>
                                    setSheetState(() => category = item),
                              ),
                          ],
                        ),
                      )
                    else if (category == '其他')
                      _CustomOccupation(
                        onSubmit: (value) => Navigator.pop(context, value),
                      )
                    else
                      Expanded(
                        child: ListView(
                          children: [
                            for (final job in jobs!)
                              ListTile(
                                title: Text(job),
                                onTap: () => Navigator.pop(context, job),
                              ),
                            ListTile(
                              leading: const Icon(Icons.add_rounded),
                              title: const Text('其他职业'),
                              onTap: () => setSheetState(() => category = '其他'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (result != null && result.trim().isNotEmpty && mounted) {
      setState(() => _occupation = result.trim());
    }
  }

  Future<void> _pickMbti() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .82,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('选择人格类型', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                Expanded(
                  child: GridView.builder(
                    itemCount: _mbtiTypes.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.08,
                    ),
                    itemBuilder: (context, index) {
                      final item = _mbtiTypes[index];
                      final color = switch (index ~/ 4) {
                        0 => AppColors.mbtiPurple,
                        1 => AppColors.mbtiGreen,
                        2 => AppColors.mbtiBlue,
                        _ => AppColors.mbtiYellow,
                      };
                      final captionColor = switch (index ~/ 4) {
                        0 => const Color(0xFF72549A),
                        1 => AppColors.primaryDark,
                        2 => const Color(0xFF4E7191),
                        _ => const Color(0xFF8A6B25),
                      };
                      return Material(
                        key: ValueKey('mbti-card-${item.$1}'),
                        color: color,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.pop(context, item.$1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.$1,
                                  style: const TextStyle(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.$2,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: captionColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null && mounted) setState(() => _mbti = result);
  }

  Future<void> _editTags() async {
    final selected = [..._personalTags];
    final customController = TextEditingController();
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          void addCustomTag() {
            final value = customController.text.trim();
            if (value.isEmpty || selected.contains(value)) return;
            setSheetState(() {
              selected.add(value);
              customController.clear();
            });
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('添加标签', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 14),
                  TextField(
                    controller: customController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => addCustomTag(),
                    decoration: InputDecoration(
                      hintText: '输入自定义标签',
                      suffixIcon: IconButton(
                        onPressed: addCustomTag,
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('热门标签', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in _popularTags)
                        FilterChip(
                          label: Text(tag),
                          selected: selected.contains(tag),
                          onSelected: (enabled) => setSheetState(() {
                            enabled ? selected.add(tag) : selected.remove(tag);
                          }),
                        ),
                    ],
                  ),
                  if (selected.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text('已选择', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tag in selected)
                          InputChip(
                            label: Text(tag),
                            onDeleted: () =>
                                setSheetState(() => selected.remove(tag)),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, selected),
                      child: const Text('完成'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    customController.dispose();
    if (result != null && mounted) {
      setState(() {
        _personalTags
          ..clear()
          ..addAll(result);
      });
    }
  }

  Future<void> _pickRegion({required bool isBirthPlace}) async {
    final value = await showRegionPicker(
      context,
      title: isBirthPlace ? '出生地' : '现居地',
    );
    if (value == null || !mounted) return;
    setState(() {
      if (isBirthPlace) {
        _birthPlace = value;
      } else {
        _currentResidence = value;
      }
    });
  }

  Future<void> _editDietPreferences() async {
    final values = await showChoiceEditor(
      context,
      title: '饮食偏好',
      options: dietPreferenceOptions,
      selected: _dietPreferences,
      customHint: '输入其他饮食偏好',
    );
    if (values == null || !mounted) return;
    setState(() {
      _dietPreferences
        ..clear()
        ..addAll(values);
    });
  }

  Future<void> _editRecentGoals() async {
    final values = await showChoiceEditor(
      context,
      title: '近期目标',
      options: recentGoalOptions,
      selected: _recentGoals,
      customHint: '输入其他近期目标',
      noneIsExclusive: true,
    );
    if (values == null || !mounted) return;
    setState(() {
      _recentGoals
        ..clear()
        ..addAll(values);
    });
  }

  Future<void> _submit() async {
    final current = await widget.userProfileService.loadProfile();
    final nickname = _nicknameController.text.trim();
    widget.onCompleted(
      current.copyWith(
        accountIdentifier: widget.accountIdentifier,
        avatarImageUrl:
            _avatarImageUrl.isEmpty ? current.avatarImageUrl : _avatarImageUrl,
        nickname: nickname.isEmpty ? '新朋友' : nickname,
        birthday: _birthday,
        occupation: _occupation,
        mbti: _mbti,
        dietPreference: _dietPreferences.join('、'),
        birthPlace: _birthPlace,
        currentResidence: _currentResidence,
        goals: List.unmodifiable(_recentGoals),
        personalTags: List.unmodifiable(_personalTags),
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
      body: ResponsivePageList(
        maxWidth: 640,
        top: 10,
        bottom: 32,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.hero,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '让easy更懂你',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text('这些信息只保存在本机，之后可在「我的」继续修改。'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              UserAvatar(
                imageUrl: _avatarImageUrl,
                size: 76,
                imageKey: const Key('basic-info-user-avatar-image'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickAvatar,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(_avatarImageUrl.isEmpty ? '上传头像' : '更换头像'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _field(_nicknameController, '昵称'),
          const SizedBox(height: 12),
          _SelectionTile(
            title: '出生时间',
            value: _formatDateTime(_birthday),
            icon: Icons.schedule_rounded,
            onTap: _pickBirthday,
          ),
          const SizedBox(height: 12),
          _SelectionTile(
            title: '出生地',
            value: _birthPlace.isEmpty ? '请选择' : _birthPlace,
            icon: Icons.location_on_outlined,
            onTap: () => _pickRegion(isBirthPlace: true),
          ),
          const SizedBox(height: 12),
          _SelectionTile(
            title: '现居地',
            value: _currentResidence.isEmpty ? '请选择' : _currentResidence,
            icon: Icons.home_outlined,
            onTap: () => _pickRegion(isBirthPlace: false),
          ),
          const SizedBox(height: 12),
          _SelectionTile(
            title: '职业',
            value: _occupation.isEmpty ? '请选择' : _occupation,
            icon: Icons.work_outline_rounded,
            onTap: _pickOccupation,
          ),
          const SizedBox(height: 12),
          _SelectionTile(
            title: 'MBTI',
            value: _mbti.isEmpty ? '请选择' : _mbti,
            icon: Icons.psychology_outlined,
            onTap: _pickMbti,
          ),
          const SizedBox(height: 12),
          _SelectionTile(
            title: '添加标签',
            value: _personalTags.isEmpty ? '请选择' : _personalTags.join(' · '),
            icon: Icons.sell_outlined,
            onTap: _editTags,
          ),
          const SizedBox(height: 12),
          _SelectionTile(
            title: '饮食偏好',
            value:
                _dietPreferences.isEmpty ? '请选择' : _dietPreferences.join(' · '),
            icon: Icons.restaurant_menu_rounded,
            onTap: _editDietPreferences,
          ),
          const SizedBox(height: 12),
          _SelectionTile(
            title: '近期目标',
            value: _recentGoals.isEmpty ? '请选择' : _recentGoals.join(' · '),
            icon: Icons.flag_outlined,
            onTap: _editRecentGoals,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(onPressed: _submit, child: const Text('保存档案')),
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
        constraints: const BoxConstraints(minHeight: 72),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 22,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.outline),
      ),
      tileColor: AppColors.surface,
      title: Text(title),
      subtitle: Text(value),
      trailing: Icon(icon),
      onTap: onTap,
    );
  }
}

class _CustomOccupation extends StatefulWidget {
  const _CustomOccupation({required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  State<_CustomOccupation> createState() => _CustomOccupationState();
}

class _CustomOccupationState extends State<_CustomOccupation> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '自定义职业',
            hintText: '请输入你的职业',
          ),
          onSubmitted: widget.onSubmit,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => widget.onSubmit(_controller.text.trim()),
          child: const Text('确认'),
        ),
      ],
    );
  }
}
