import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/agent_service.dart';
import '../services/pet_profile_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../utils/pet_image_picker.dart';
import '../widgets/companion_avatar.dart';
import '../widgets/page_header.dart';
import '../widgets/profile_field_pickers.dart';
import '../widgets/responsive_page.dart';
import '../widgets/soft_card.dart';
import '../widgets/user_avatar.dart';
import 'memory_management_page.dart';
import 'pet_profile_form_page.dart';
import 'pet_profile_onboarding_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.agentService,
    required this.petProfileService,
    required this.userProfileService,
    required this.onLogout,
    super.key,
  });

  final AgentService agentService;
  final PetProfileService petProfileService;
  final UserProfileService userProfileService;
  final Future<void> Function() onLogout;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  UserProfile? _profile;
  PetProfile? _petProfile;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadPetProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await widget.userProfileService.loadProfile();
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  Future<void> _loadPetProfile() async {
    final petProfile = await widget.petProfileService.getPetProfile();
    if (!mounted) return;
    setState(() => _petProfile = petProfile);
  }

  Future<void> _openPetProfile() async {
    final petProfile = _petProfile;
    if (petProfile == null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PetProfileOnboardingPage(
            agentService: widget.agentService,
            petProfileService: widget.petProfileService,
            onSkip: () => Navigator.of(context).pop(),
            onCompleted: _onPetProfileCompleted,
          ),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PetProfileFormPage(
            agentService: widget.agentService,
            petProfileService: widget.petProfileService,
            initialProfile: petProfile,
            onCompleted: _onPetProfileCompleted,
          ),
        ),
      );
    }
    if (!mounted) return;
    await _loadPetProfile();
  }

  void _onPetProfileCompleted(PetProfile profile) {
    if (!mounted) return;
    setState(() => _petProfile = profile);
  }

  Future<void> _openMemoryManagement() async {
    final profile = _profile;
    if (profile == null) return;
    final updated = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute<UserProfile>(
        builder: (_) => MemoryManagementPage(
          initialProfile: profile,
          agentService: widget.agentService,
          userProfileService: widget.userProfileService,
        ),
      ),
    );
    if (!mounted || updated == null) return;
    setState(() => _profile = updated);
  }

  Future<void> _saveProfile() async {
    final profile = _profile;
    if (profile == null || _isSaving) return;
    setState(() => _isSaving = true);
    await widget.userProfileService.saveProfile(profile);
    await widget.agentService.updateUserProfile(profile);
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('用户画像已保存到本机')));
  }

  Future<void> _changeAvatar() async {
    final profile = _profile;
    if (profile == null) return;
    try {
      final image = await pickPetImage(preferCamera: false);
      if (!mounted || image == null) return;
      setState(
        () => _profile = profile.copyWith(avatarImageUrl: image.dataUrl),
      );
    } on PetImagePickerException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _logout() async {
    Navigator.of(context).pop();
    await widget.onLogout();
  }

  Future<String?> _editText({
    required String title,
    required String initialValue,
    String? hint,
    TextInputType? keyboardType,
  }) async {
    var input = initialValue;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: initialValue,
          autofocus: true,
          keyboardType: keyboardType,
          minLines: keyboardType == TextInputType.multiline ? 2 : 1,
          maxLines: keyboardType == TextInputType.multiline ? 4 : 1,
          onChanged: (value) => input = value,
          onFieldSubmitted: keyboardType == TextInputType.multiline
              ? null
              : (value) => Navigator.pop(context, value.trim()),
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<String?> _selectOption({
    required String title,
    required List<String> options,
    required String? current,
    bool optional = false,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .72,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      if (optional)
                        ListTile(
                          title: const Text('暂不填写'),
                          trailing: current == null
                              ? const Icon(Icons.check_rounded)
                              : null,
                          onTap: () => Navigator.pop(context, ''),
                        ),
                      for (final option in options)
                        ListTile(
                          title: Text(option),
                          trailing: current == option
                              ? const Icon(Icons.check_rounded)
                              : null,
                          onTap: () => Navigator.pop(context, option),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickBirthday() async {
    final profile = _profile!;
    final date = await showBirthDateTimePicker(
      context,
      initialValue: profile.birthday,
    );
    if (date == null || !mounted) return;
    setState(() => _profile = profile.copyWith(birthday: date));
  }

  Future<void> _pickRegion({required bool isBirthPlace}) async {
    final profile = _profile!;
    final value = await showRegionPicker(
      context,
      title: isBirthPlace ? '出生地' : '现居地',
    );
    if (value == null || !mounted) return;
    setState(
      () => _profile = isBirthPlace
          ? profile.copyWith(birthPlace: value)
          : profile.copyWith(currentResidence: value),
    );
  }

  Future<void> _editRecentGoals() async {
    final profile = _profile!;
    final values = await showChoiceEditor(
      context,
      title: '近期目标',
      options: recentGoalOptions,
      selected: profile.goals,
      customHint: '输入其他近期目标',
      noneIsExclusive: true,
    );
    if (values == null || !mounted) return;
    setState(() => _profile = profile.copyWith(goals: values));
  }

  Future<void> _editDietPreferences() async {
    final profile = _profile!;
    final selected = profile.dietPreference
        .split(RegExp('[、,，]'))
        .where((item) => item.trim().isNotEmpty)
        .map((item) => item.trim())
        .toList();
    final values = await showChoiceEditor(
      context,
      title: '饮食偏好',
      options: dietPreferenceOptions,
      selected: selected,
      customHint: '输入其他饮食偏好',
    );
    if (values == null || !mounted) return;
    setState(
      () => _profile = profile.copyWith(dietPreference: values.join('、')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        title: const Text('用户画像'),
        actions: [
          TextButton(
            onPressed: profile == null || _isSaving ? null : _saveProfile,
            child: Text(_isSaving ? '保存中' : '保存'),
          ),
        ],
      ),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : ResponsivePageList(
              maxWidth: 820,
              top: 6,
              bottom: 40,
              children: [
                PageHeader(
                  title: '你好，${profile.nickname}',
                  subtitle: '这不是普通设置页，而是你的长期 AI 记忆档案',
                ),
                const SizedBox(height: 18),
                _MemoryExplanation(
                  profile: profile,
                  onTap: _openMemoryManagement,
                  onChangeAvatar: _changeAvatar,
                ),
                const SizedBox(height: 22),
                const SectionTitle('伙伴档案'),
                const SizedBox(height: 10),
                _PetProfileCard(profile: _petProfile, onTap: _openPetProfile),
                const SizedBox(height: 22),
                const SectionTitle('基础信息'),
                const SizedBox(height: 10),
                SoftCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _ProfileTile(
                        icon: Icons.badge_outlined,
                        title: '昵称',
                        value: profile.nickname,
                        onTap: () async {
                          final value = await _editText(
                            title: '昵称',
                            initialValue: profile.nickname,
                          );
                          if (!mounted) return;
                          if (value != null && value.isNotEmpty) {
                            setState(
                              () =>
                                  _profile = profile.copyWith(nickname: value),
                            );
                          }
                        },
                      ),
                      const Divider(height: 1, indent: 60),
                      _ProfileTile(
                        icon: Icons.schedule_rounded,
                        title: '出生时间',
                        value: _formatDateTime(profile.birthday),
                        onTap: _pickBirthday,
                      ),
                      const Divider(height: 1, indent: 60),
                      _ProfileTile(
                        icon: Icons.location_on_outlined,
                        title: '出生地',
                        value: profile.birthPlace.isEmpty
                            ? '未填写'
                            : profile.birthPlace,
                        onTap: () => _pickRegion(isBirthPlace: true),
                      ),
                      const Divider(height: 1, indent: 60),
                      _ProfileTile(
                        icon: Icons.home_outlined,
                        title: '现居地',
                        value: profile.currentResidence.isEmpty
                            ? '未填写'
                            : profile.currentResidence,
                        onTap: () => _pickRegion(isBirthPlace: false),
                      ),
                      const Divider(height: 1, indent: 60),
                      _ProfileTile(
                        icon: Icons.person_outline_rounded,
                        title: '性别（可选）',
                        value: profile.gender ?? '未填写',
                        onTap: () async {
                          final value = await _selectOption(
                            title: '性别',
                            options: const ['女', '男', '非二元', '其他'],
                            current: profile.gender,
                            optional: true,
                          );
                          if (!mounted) return;
                          if (value == null) return;
                          setState(
                            () => _profile = value.isEmpty
                                ? profile.copyWith(clearGender: true)
                                : profile.copyWith(gender: value),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 60),
                      _ProfileTile(
                        icon: Icons.work_outline_rounded,
                        title: '职业',
                        value: profile.occupation,
                        onTap: () async {
                          final value = await _editText(
                            title: '职业',
                            initialValue: profile.occupation,
                          );
                          if (!mounted) return;
                          if (value != null && value.isNotEmpty) {
                            setState(
                              () => _profile = profile.copyWith(
                                occupation: value,
                              ),
                            );
                          }
                        },
                      ),
                      const Divider(height: 1, indent: 60),
                      _ProfileTile(
                        icon: Icons.psychology_outlined,
                        title: 'MBTI',
                        value: profile.mbti,
                        onTap: () async {
                          final value = await _editText(
                            title: 'MBTI',
                            initialValue: profile.mbti,
                            hint: '例如 INFJ',
                          );
                          if (!mounted) return;
                          if (value != null && value.isNotEmpty) {
                            setState(
                              () => _profile = profile.copyWith(
                                mbti: value.toUpperCase(),
                              ),
                            );
                          }
                        },
                      ),
                      const Divider(height: 1, indent: 60),
                      _ProfileTile(
                        icon: Icons.auto_awesome_outlined,
                        title: '星座',
                        value: profile.zodiac,
                        onTap: () async {
                          final value = await _selectOption(
                            title: '星座',
                            options: const [
                              '白羊座',
                              '金牛座',
                              '双子座',
                              '巨蟹座',
                              '狮子座',
                              '处女座',
                              '天秤座',
                              '天蝎座',
                              '射手座',
                              '摩羯座',
                              '水瓶座',
                              '双鱼座',
                            ],
                            current: profile.zodiac,
                          );
                          if (!mounted) return;
                          if (value != null) {
                            setState(
                              () => _profile = profile.copyWith(zodiac: value),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SectionTitle('近期目标', action: '编辑', onAction: _editRecentGoals),
                const SizedBox(height: 10),
                _MultiSelectCard(
                  options: recentGoalOptions,
                  selected: profile.goals,
                  onToggle: (_) => _editRecentGoals(),
                ),
                const SizedBox(height: 22),
                const SectionTitle('饮食与身体偏好'),
                const SizedBox(height: 10),
                SoftCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _ProfileTile(
                        icon: Icons.restaurant_menu_rounded,
                        title: '饮食偏好',
                        value: profile.dietPreference.isEmpty
                            ? '未填写'
                            : profile.dietPreference,
                        onTap: _editDietPreferences,
                      ),
                      const Divider(height: 1, indent: 60),
                      _ProfileTile(
                        icon: Icons.no_food_outlined,
                        title: '忌口',
                        value: profile.foodRestrictions,
                        onTap: () async {
                          final value = await _editText(
                            title: '忌口',
                            initialValue: profile.foodRestrictions,
                            keyboardType: TextInputType.multiline,
                          );
                          if (!mounted) return;
                          if (value != null) {
                            setState(
                              () => _profile = profile.copyWith(
                                foodRestrictions: value,
                              ),
                            );
                          }
                        },
                      ),
                      const Divider(height: 1, indent: 60),
                      _ProfileTile(
                        icon: Icons.monitor_weight_outlined,
                        title: '目标体重',
                        value: '${profile.targetWeight.toStringAsFixed(1)} kg',
                        onTap: () async {
                          final value = await _editText(
                            title: '目标体重',
                            initialValue: profile.targetWeight.toString(),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          );
                          if (!mounted) return;
                          final weight = double.tryParse(value ?? '');
                          if (weight != null) {
                            setState(
                              () => _profile = profile.copyWith(
                                targetWeight: weight,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const SectionTitle('陪伴偏好'),
                const SizedBox(height: 10),
                SoftCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _ProfileTile(
                        icon: Icons.notifications_active_outlined,
                        title: '伙伴提醒强度',
                        value: profile.petReminderStyle,
                        onTap: () async {
                          final value = await _selectOption(
                            title: '伙伴提醒强度',
                            options: const ['关闭', '轻提醒', '适中', '积极提醒'],
                            current: profile.petReminderStyle,
                          );
                          if (!mounted) return;
                          if (value != null) {
                            setState(
                              () => _profile = profile.copyWith(
                                petReminderStyle: value,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const SectionTitle('权限与通知'),
                const SizedBox(height: 10),
                _PermissionSettingsCard(
                  profile: profile,
                  onChanged: (updated) => setState(() => _profile = updated),
                ),
                const SizedBox(height: 22),
                const SectionTitle('隐私与数据'),
                const SizedBox(height: 10),
                _PrivacySettingsCard(
                  profile: profile,
                  onChanged: (updated) => setState(() => _profile = updated),
                ),
                const SizedBox(height: 22),
                const _StorageCard(),
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _saveProfile,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_isSaving ? '正在保存…' : '保存'),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('logout-button'),
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('退出登录'),
                ),
              ],
            ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

class _PetProfileCard extends StatelessWidget {
  const _PetProfileCard({required this.profile, required this.onTap});

  final PetProfile? profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pet = profile;
    return SoftCard(
      color: AppColors.primaryMist,
      borderColor: AppColors.outlineSoft,
      onTap: onTap,
      child: Row(
        children: [
          CompanionAvatar(
            profile: pet,
            size: 86,
            imageKey: const Key('settings-companion-avatar-image'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet?.name ?? '创建伙伴档案',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 5),
                Text(
                  pet == null
                      ? '上传照片，制作你的专属陪伴伙伴'
                      : pet.personalityTags.join(' · '),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  pet == null ? '去创建' : '编辑伙伴档案',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.primaryDark,
                      ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _MemoryExplanation extends StatelessWidget {
  const _MemoryExplanation({
    required this.profile,
    required this.onTap,
    required this.onChangeAvatar,
  });

  final UserProfile profile;
  final VoidCallback onTap;
  final VoidCallback onChangeAvatar;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.cream,
      borderColor: AppColors.outlineSoft,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            key: const Key('settings-user-avatar'),
            profile: profile,
            size: 76,
            imageKey: const Key('settings-user-avatar-image'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('长期记忆', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 7),
                Text(
                  profile.memoryNotes.isEmpty
                      ? '你可以亲自添加希望 easy 记住的偏好，也可以管理之后从对话中整理出的认知。'
                      : '已保存 ${profile.memoryNotes.length} 条记忆。你可以查看、添加、修改或删除，之后的 AI 能力会按你的选择调用。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.ink,
                        height: 1.55,
                      ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onChangeAvatar,
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: const Text('更换头像'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: AppColors.primarySoft,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20),
      ),
      title: Text(title),
      subtitle: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.edit_outlined, size: 18),
    );
  }
}

class _MultiSelectCard extends StatelessWidget {
  const _MultiSelectCard({
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final List<String> options;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in {...options, ...selected})
            FilterChip(
              label: Text(option),
              selected: selected.contains(option),
              showCheckmark: false,
              selectedColor: AppColors.softGreen,
              onSelected: (_) => onToggle(option),
            ),
        ],
      ),
    );
  }
}

class _StorageCard extends StatelessWidget {
  const _StorageCard();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.primaryMist,
      borderColor: AppColors.outlineSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storage_outlined),
              const SizedBox(width: 9),
              Text('存储方式', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          const _StorageRow(label: '当前版本', value: '本机持久化存储', active: true),
          const SizedBox(height: 8),
          const _StorageRow(label: '本地持久化', value: '已启用'),
          const SizedBox(height: 8),
          const _StorageRow(label: '跨设备同步', value: '预留自建后端数据库'),
        ],
      ),
    );
  }
}

class _PermissionSettingsCard extends StatelessWidget {
  const _PermissionSettingsCard({
    required this.profile,
    required this.onChanged,
  });

  final UserProfile profile;
  final ValueChanged<UserProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _PreferenceSwitchTile(
            icon: Icons.notifications_active_outlined,
            title: '通知提醒',
            value: profile.notificationsEnabled,
            onChanged: (value) =>
                onChanged(profile.copyWith(notificationsEnabled: value)),
          ),
          const Divider(height: 1, indent: 60),
          _PreferenceSwitchTile(
            icon: Icons.location_on_outlined,
            title: '定位服务',
            value: profile.locationAccessEnabled,
            onChanged: (value) =>
                onChanged(profile.copyWith(locationAccessEnabled: value)),
          ),
          const Divider(height: 1, indent: 60),
          _PreferenceSwitchTile(
            icon: Icons.mic_none_rounded,
            title: '麦克风与语音输入',
            value: profile.microphoneAccessEnabled,
            onChanged: (value) =>
                onChanged(profile.copyWith(microphoneAccessEnabled: value)),
          ),
          const Divider(height: 1, indent: 60),
          _PreferenceSwitchTile(
            icon: Icons.photo_camera_outlined,
            title: '相机与相册',
            value: profile.cameraPhotoAccessEnabled,
            onChanged: (value) =>
                onChanged(profile.copyWith(cameraPhotoAccessEnabled: value)),
          ),
        ],
      ),
    );
  }
}

class _PrivacySettingsCard extends StatelessWidget {
  const _PrivacySettingsCard({required this.profile, required this.onChanged});

  final UserProfile profile;
  final ValueChanged<UserProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _PreferenceSwitchTile(
            icon: Icons.cloud_sync_outlined,
            title: '云端同步',
            value: profile.cloudSyncEnabled,
            onChanged: (value) =>
                onChanged(profile.copyWith(cloudSyncEnabled: value)),
          ),
          const Divider(height: 1, indent: 60),
          _PreferenceSwitchTile(
            icon: Icons.psychology_alt_outlined,
            title: '长期记忆个性化',
            value: profile.aiMemoryEnabled,
            onChanged: (value) =>
                onChanged(profile.copyWith(aiMemoryEnabled: value)),
          ),
          const Divider(height: 1, indent: 60),
          _PreferenceSwitchTile(
            icon: Icons.bug_report_outlined,
            title: '诊断日志',
            value: profile.diagnosticsEnabled,
            onChanged: (value) =>
                onChanged(profile.copyWith(diagnosticsEnabled: value)),
          ),
        ],
      ),
    );
  }
}

class _PreferenceSwitchTile extends StatelessWidget {
  const _PreferenceSwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.primaryDark,
      activeTrackColor: AppColors.primarySoft,
      secondary: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: AppColors.primarySoft,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20),
      ),
      title: Text(title),
    );
  }
}

class _StorageRow extends StatelessWidget {
  const _StorageRow({
    required this.label,
    required this.value,
    this.active = false,
  });

  final String label;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          active ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 18,
          color: active ? AppColors.primary : AppColors.mutedInk,
        ),
        const SizedBox(width: 9),
        SizedBox(
          width: 78,
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
