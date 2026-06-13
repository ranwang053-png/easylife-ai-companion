import 'package:flutter/material.dart';

import '../models/pet_profile.dart';
import '../services/pet_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/companion_pet.dart';
import '../widgets/soft_card.dart';
import 'pet_profile_success_page.dart';

class PetProfileFormPage extends StatefulWidget {
  const PetProfileFormPage({
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
  final ValueChanged<PetProfile> onCompleted;
  final PetProfileService petProfileService;

  @override
  State<PetProfileFormPage> createState() => _PetProfileFormPageState();
}

class _PetProfileFormPageState extends State<PetProfileFormPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _relationshipController;
  late DateTime _birthday;
  String? _gender;
  late List<String> _selectedTags;
  var _isSaving = false;

  static const _tags = ['粘人', '活泼', '胆小', '安静', '傲娇', '治愈'];

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    _nameController = TextEditingController(text: profile?.name ?? '');
    _relationshipController = TextEditingController(
      text: profile?.relationshipNote ?? '我的伙伴',
    );
    _birthday = profile?.birthday ?? DateTime(2022, 6, 1);
    _gender = profile?.gender;
    _selectedTags = [...?profile?.personalityTags];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _birthday,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (!mounted || date == null) return;
    setState(() => _birthday = date);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);
    final existing = widget.initialProfile;
    final profile = PetProfile(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      birthday: _birthday,
      gender: _gender,
      personalityTags:
          _selectedTags.isEmpty ? const ['治愈'] : [..._selectedTags],
      relationshipNote: _relationshipController.text.trim().isEmpty
          ? '我的伙伴'
          : _relationshipController.text.trim(),
      originalPhotoUrl: widget.originalPhotoUrl ?? existing?.originalPhotoUrl,
      generatedAvatarUrl:
          widget.generatedAvatarUrl ?? existing?.generatedAvatarUrl,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );
    if (existing == null) {
      await widget.petProfileService.savePetProfile(profile);
    } else {
      await widget.petProfileService.updatePetProfile(profile);
    }
    if (!mounted) return;
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
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
          title: Text(widget.initialProfile == null ? '填写宠物信息' : '编辑宠物档案')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const Center(child: CompanionPet(size: 120)),
          const SizedBox(height: 12),
          SoftCard(
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '宠物名字',
                    hintText: '例如：糯米',
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('宠物生日'),
                  subtitle: Text(_birthdayText),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: _pickBirthday,
                ),
                const Divider(),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: const InputDecoration(labelText: '宠物性别（可选）'),
                  items: const [
                    DropdownMenuItem(value: '妹妹', child: Text('妹妹')),
                    DropdownMenuItem(value: '弟弟', child: Text('弟弟')),
                    DropdownMenuItem(value: '未知', child: Text('暂不确定')),
                  ],
                  onChanged: (value) => setState(() => _gender = value),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '性格标签（影响提醒风格）',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in _tags)
                      FilterChip(
                        label: Text(tag),
                        selected: _selectedTags.contains(tag),
                        onSelected: (_) {
                          setState(() {
                            _selectedTags.contains(tag)
                                ? _selectedTags.remove(tag)
                                : _selectedTags.add(tag);
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _relationshipController,
                  decoration: const InputDecoration(
                    labelText: '和主人的关系备注',
                    hintText: '例如：我的猫、我的狗、我的伙伴',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: AppColors.ink),
              child: Text(_isSaving ? '正在保存...' : '完成'),
            ),
          ),
        ],
      ),
    );
  }
}
