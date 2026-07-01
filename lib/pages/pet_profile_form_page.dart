import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

import '../models/pet_profile.dart';
import '../services/agent_service.dart';
import '../services/pet_profile_service.dart';
import '../theme/app_colors.dart';
import '../utils/pet_image_picker.dart';
import '../widgets/ai_privacy_dialog.dart';
import '../widgets/companion_avatar.dart';
import '../widgets/responsive_page.dart';
import '../widgets/soft_card.dart';
import 'pet_profile_success_page.dart';

class PetProfileFormPage extends StatefulWidget {
  const PetProfileFormPage({
    required this.agentService,
    required this.onCompleted,
    required this.petProfileService,
    this.originalPhotoUrl,
    this.generatedAvatarUrl,
    this.initialProfile,
    super.key,
  });

  final String? originalPhotoUrl;
  final String? generatedAvatarUrl;
  final PetProfile? initialProfile;
  final AgentService agentService;
  final ValueChanged<PetProfile> onCompleted;
  final PetProfileService petProfileService;

  @override
  State<PetProfileFormPage> createState() => _PetProfileFormPageState();
}

class _PetProfileFormPageState extends State<PetProfileFormPage> {
  late final TextEditingController _nameController;
  late DateTime _birthday;
  String? _gender;
  String _relationship = '';
  late List<String> _selectedTags;
  String _profileSource = '';
  String _personalitySummary = '';
  String? _originalPhotoUrl;
  String? _generatedAvatarUrl;
  String? _nameError;
  var _isSaving = false;
  var _isGeneratingAvatar = false;

  static const _tags = ['温柔', '活泼', '理性', '安静', '幽默', '治愈'];
  static const _relationships = ['宠物', '恋人', '朋友', '家人', '偶像', '导师', '其他'];
  static const _genders = ['男', '女', '非二元', '保密'];

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    _nameController = TextEditingController(text: profile?.name ?? '');
    _birthday = profile?.birthday ?? DateTime(2000, 1, 1, 12);
    _gender = switch (profile?.gender) {
      '妹妹' => '女',
      '弟弟' => '男',
      '不公开' || '不适用' => '保密',
      final value when _genders.contains(value) => value,
      _ => null,
    };
    _relationship = profile?.relationshipNote ?? '';
    _selectedTags = [...?profile?.personalityTags];
    _profileSource = profile?.profileSource ?? '';
    _personalitySummary = profile?.personalitySummary ?? '';
    _originalPhotoUrl = widget.originalPhotoUrl ?? profile?.originalPhotoUrl;
    _generatedAvatarUrl =
        widget.generatedAvatarUrl ?? profile?.generatedAvatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final result = await _showDateTimePicker(
      title: '选择 Ta 的生日',
      mode: CupertinoDatePickerMode.date,
      initial: _birthday,
    );
    if (result == null || !mounted) return;
    setState(
      () => _birthday = DateTime(
        result.year,
        result.month,
        result.day,
        _birthday.hour,
        _birthday.minute,
      ),
    );
  }

  Future<DateTime?> _showDateTimePicker({
    required String title,
    required CupertinoDatePickerMode mode,
    required DateTime initial,
    bool use24hFormat = false,
  }) {
    var selected = initial;
    return showModalBottomSheet<DateTime>(
      context: context,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: 340,
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
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    TextButton(
                      onPressed: () => Navigator.pop(context, selected),
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: CupertinoDatePicker(
                  mode: mode,
                  dateOrder: mode == CupertinoDatePickerMode.date
                      ? DatePickerDateOrder.ymd
                      : null,
                  use24hFormat: use24hFormat,
                  initialDateTime: initial,
                  minimumDate: mode == CupertinoDatePickerMode.date
                      ? DateTime(1900)
                      : null,
                  maximumDate: mode == CupertinoDatePickerMode.date
                      ? DateTime.now()
                      : null,
                  onDateTimeChanged: (value) {
                    selected = value;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editTags() async {
    final values = [..._selectedTags];
    final controller = TextEditingController();
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          void addCustom() {
            final value = controller.text.trim();
            if (value.isEmpty || values.contains(value)) return;
            setSheetState(() {
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
                  Text('性格标签', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    onSubmitted: (_) => addCustom(),
                    decoration: InputDecoration(
                      hintText: '输入自定义性格标签',
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
                      for (final tag in _tags)
                        FilterChip(
                          label: Text(tag),
                          selected: values.contains(tag),
                          onSelected: (enabled) => setSheetState(() {
                            enabled ? values.add(tag) : values.remove(tag);
                          }),
                        ),
                    ],
                  ),
                  if (values.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tag in values)
                          InputChip(
                            label: Text(tag),
                            onDeleted: () =>
                                setSheetState(() => values.remove(tag)),
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
    );
    controller.dispose();
    if (result != null && mounted) setState(() => _selectedTags = result);
  }

  Future<void> _replaceAvatar() async {
    if (_isGeneratingAvatar || _isSaving) return;
    try {
      final image = await pickPetImage(preferCamera: false);
      if (!mounted || image == null) return;
      final useAi = await showAiPrivacyDialog(context);
      if (!mounted || useAi == null) return;
      if (!useAi) {
        setState(() {
          _originalPhotoUrl = image.dataUrl;
          _generatedAvatarUrl = image.dataUrl;
        });
        return;
      }
      setState(() => _isGeneratingAvatar = true);
      final generated = await widget.agentService.generatePetAvatarFromPhoto(
        image.dataUrl,
      );
      if (!mounted) return;
      setState(() {
        _originalPhotoUrl = image.dataUrl;
        _generatedAvatarUrl = generated;
      });
    } on PetImagePickerException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on AgentServiceException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('形象生成失败，请稍后再试')));
    } finally {
      if (mounted) setState(() => _isGeneratingAvatar = false);
    }
  }

  Future<String?> _selectOption({
    required String title,
    required List<String> options,
    String? current,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final option in options)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(option),
                  selected: option == current,
                  selectedTileColor: AppColors.primaryMist,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onTap: () => Navigator.pop(context, option),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _analyzeProfile() async {
    final sourceController = TextEditingController(text: _profileSource);
    var importedDocumentName =
        _profileSource.startsWith('document://') ? 'companion-profile.pdf' : '';
    final result = await showModalBottomSheet<(String, String, List<String>)>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> importDocument() async {
            final file = await openFile(
              acceptedTypeGroups: const [
                XTypeGroup(
                  label: 'Documents',
                  extensions: ['pdf', 'doc', 'docx', 'md', 'txt'],
                ),
              ],
            );
            if (file == null) return;
            setSheetState(() {
              importedDocumentName = file.name;
              sourceController.text = 'document://${file.name}';
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
                  Text('伙伴档案分析', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  const Text('可通过网页链接或文档资料辅助生成伙伴档案分析。人物识别需要来源授权、身份核验与隐私保护。'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: sourceController,
                    decoration: const InputDecoration(
                      labelText: '人物网页或公开资料链接',
                      hintText: '例如个人主页、百科或公开采访链接',
                    ),
                    onChanged: (_) => setSheetState(() {
                      importedDocumentName = '';
                    }),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton(
                        onPressed: () => setSheetState(() {
                          importedDocumentName = '';
                          if (sourceController.text.startsWith('document://')) {
                            sourceController.clear();
                          }
                        }),
                        child: const Text('网页链接'),
                      ),
                      OutlinedButton(
                        onPressed: importDocument,
                        child: Text(
                          importedDocumentName.isEmpty ? '导入文档' : '已导入文档',
                        ),
                      ),
                    ],
                  ),
                  if (importedDocumentName.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '已导入文档：$importedDocumentName',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primaryDark,
                          ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '支持 PDF、Word、Markdown 和 TXT。资料仅用于生成伙伴档案分析，请确认你有权使用该资料。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaryInk,
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        final source = sourceController.text.trim();
                        final name = _nameController.text.trim();
                        Navigator.pop(context, (
                          source,
                          '${name.isEmpty ? '这位伙伴' : name}给人的感觉温和、可靠，'
                              '更适合用耐心倾听、适度幽默和明确鼓励的方式陪伴你。',
                          const ['温柔', '可靠', '善于倾听'],
                        ));
                      },
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('开始分析'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    sourceController.dispose();
    if (result == null || !mounted) return;
    setState(() {
      _profileSource = result.$1;
      _personalitySummary = result.$2;
      _selectedTags = {..._selectedTags, ...result.$3}.toList();
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (_isSaving) return;
    if (name.isEmpty) {
      setState(() => _nameError = '请先填写伙伴名字');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先填写伙伴名字')));
      return;
    }
    setState(() => _isSaving = true);
    final existing = widget.initialProfile;
    final profile = PetProfile(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      birthday: _birthday,
      gender: _gender,
      personalityTags:
          _selectedTags.isEmpty ? const ['治愈'] : [..._selectedTags],
      relationshipNote: _relationship.isEmpty ? '伙伴' : _relationship,
      originalPhotoUrl: _originalPhotoUrl,
      generatedAvatarUrl: _generatedAvatarUrl,
      createdAt: existing?.createdAt ?? DateTime.now(),
      profileSource: _profileSource,
      personalitySummary: _personalitySummary,
    );
    try {
      if (existing == null) {
        await widget.petProfileService.savePetProfile(profile);
      } else {
        await widget.petProfileService.updatePetProfile(profile);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败，请稍后再试')));
      return;
    }
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (existing != null) {
      widget.onCompleted(profile);
      Navigator.of(context).pop(profile);
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PetProfileSuccessPage(
          profile: profile,
          onCompleted: widget.onCompleted,
        ),
      ),
    );
  }

  String get _birthdayText =>
      '${_birthday.year}-${_birthday.month.toString().padLeft(2, '0')}-'
      '${_birthday.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final relationshipItems = <String>{
      ..._relationships,
      if (_relationship.isNotEmpty) _relationship,
    }.toList();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(widget.initialProfile == null ? '填写伙伴信息' : '编辑伙伴档案'),
      ),
      body: ResponsivePageList(
        maxWidth: 680,
        top: 12,
        bottom: 32,
        children: [
          SoftCard(
            color: AppColors.primaryMist,
            borderColor: AppColors.outlineSoft,
            child: Row(
              children: [
                CompanionAvatar(
                  profile: widget.initialProfile,
                  imageUrl: _generatedAvatarUrl,
                  size: 88,
                  imageKey: const Key('pet-profile-form-avatar-image'),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.initialProfile == null ? '认识一下你的伙伴' : '完善伙伴档案',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '这些信息会用于调整伙伴的称呼、性格和陪伴方式。',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.secondaryInk,
                              height: 1.45,
                            ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _isSaving || _isGeneratingAvatar
                            ? null
                            : _replaceAvatar,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(
                          _isGeneratingAvatar ? '正在生成形象…' : '更换伙伴形象',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _FormSection(
            title: '基础信息',
            children: [
              TextField(
                controller: _nameController,
                onChanged: (_) {
                  if (_nameError == null) return;
                  setState(() => _nameError = null);
                },
                decoration: const InputDecoration(
                  labelText: '伙伴名字',
                  hintText: '例如：糯米、朋友或喜欢的人',
                ).copyWith(errorText: _nameError),
              ),
              _FormTile(
                title: 'Ta 的生日',
                value: _birthdayText,
                onTap: _pickBirthDate,
              ),
              _FormTile(
                title: 'Ta 的性别（可选）',
                value: _gender ?? '请选择',
                onTap: () async {
                  final value = await _selectOption(
                    title: 'Ta 的性别（可选）',
                    options: _genders,
                    current: _gender,
                  );
                  if (value == null || !mounted) return;
                  setState(() => _gender = value);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FormSection(
            title: '关系与性格',
            children: [
              _FormTile(
                title: '关系',
                value: _relationship.isEmpty ? '请选择' : _relationship,
                onTap: () async {
                  final value = await _selectOption(
                    title: '关系',
                    options: relationshipItems,
                    current: _relationship.isEmpty ? null : _relationship,
                  );
                  if (value == null || !mounted) return;
                  setState(() => _relationship = value);
                },
              ),
              _FormTile(
                title: '性格标签',
                value: _selectedTags.isEmpty
                    ? '请选择或自定义'
                    : _selectedTags.join(' · '),
                onTap: _editTags,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FormSection(
            title: '个性化档案',
            children: [
              _FormTile(
                title: '档案分析',
                value: _personalitySummary.isEmpty
                    ? '添加资料，让伙伴的表达更贴近你期待的样子'
                    : _personalitySummary,
                backgroundColor: AppColors.primarySoft,
                onTap: _analyzeProfile,
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              child: Text(_isSaving ? '正在保存...' : '完成'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _FormTile extends StatelessWidget {
  const _FormTile({
    required this.title,
    required this.value,
    required this.onTap,
    this.backgroundColor = AppColors.surface,
  });

  final String title;
  final String value;
  final VoidCallback onTap;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 70),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.secondaryInk,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.ink,
                              height: 1.35,
                            ),
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
}
