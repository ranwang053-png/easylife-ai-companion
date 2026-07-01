import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/agent_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/page_header.dart';
import '../widgets/responsive_page.dart';
import '../widgets/soft_card.dart';

class MemoryManagementPage extends StatefulWidget {
  const MemoryManagementPage({
    required this.initialProfile,
    required this.agentService,
    required this.userProfileService,
    super.key,
  });

  final UserProfile initialProfile;
  final AgentService agentService;
  final UserProfileService userProfileService;

  @override
  State<MemoryManagementPage> createState() => _MemoryManagementPageState();
}

class _MemoryManagementPageState extends State<MemoryManagementPage> {
  static const _maximumMemories = 12;
  static const _maximumMemoryLength = 60;

  late UserProfile _profile;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
  }

  Future<void> _persist(List<String> memories) async {
    if (_isSaving) return;
    final updated = _profile.copyWith(memoryNotes: memories);
    setState(() {
      _profile = updated;
      _isSaving = true;
    });
    await widget.userProfileService.saveProfile(updated);
    await widget.agentService.updateUserProfile(updated);
    if (!mounted) return;
    setState(() => _isSaving = false);
  }

  Future<String?> _showMemoryEditor({
    required String title,
    String initialValue = '',
  }) {
    var input = initialValue;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          key: const Key('memory-editor-field'),
          initialValue: initialValue,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          maxLength: _maximumMemoryLength,
          onChanged: (value) => input = value,
          decoration: const InputDecoration(hintText: '例如：我压力大时更希望先被倾听'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('confirm-memory-button'),
            onPressed: () {
              final value = input.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _addMemory() async {
    if (_profile.memoryNotes.length >= _maximumMemories) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('最多保留 12 条长期记忆，请先整理已有内容')));
      return;
    }
    final value = await _showMemoryEditor(title: '添加长期记忆');
    if (value == null || !mounted) return;
    final memories = [
      ..._profile.memoryNotes.where((memory) => memory != value),
      value,
    ];
    await _persist(memories);
  }

  Future<void> _editMemory(int index) async {
    final current = _profile.memoryNotes[index];
    final value = await _showMemoryEditor(
      title: '修改长期记忆',
      initialValue: current,
    );
    if (value == null || !mounted || value == current) return;
    final memories = [..._profile.memoryNotes];
    memories[index] = value;
    final deduplicated = <String>[];
    for (final memory in memories) {
      if (!deduplicated.contains(memory)) deduplicated.add(memory);
    }
    await _persist(deduplicated);
  }

  Future<void> _deleteMemory(int index) async {
    final memory = _profile.memoryNotes[index];
    final displayMemory = _memoryDisplayText(memory);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这条记忆？'),
        content: Text('删除后，easy 将不再使用“$displayMemory”进行个性化。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('confirm-delete-memory-button'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final memories = [..._profile.memoryNotes]..removeAt(index);
    await _persist(memories);
  }

  void _close() => Navigator.pop(context, _profile);

  @override
  Widget build(BuildContext context) {
    final memories = _profile.memoryNotes;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          backgroundColor: AppColors.canvas,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            onPressed: _close,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text('长期记忆'),
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.only(right: 20),
                child: Center(
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
        body: ResponsivePageList(
          maxWidth: 820,
          top: 6,
          bottom: 40,
          children: [
            PageHeader(
              title: '让 easy 记住重要的你',
              subtitle: '这里既有对话中整理出的认知，也可以由你亲自添加和修改',
              trailing: FilledButton.icon(
                key: const Key('add-memory-button'),
                onPressed: _isSaving ? null : _addMemory,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('添加'),
              ),
            ),
            const SizedBox(height: 18),
            SoftCard(
              color: AppColors.primaryMist,
              borderColor: AppColors.outlineSoft,
              child: Text(
                '后续陪伴、饮食建议和每日运势只会调用你允许保留的记忆。'
                '最多保留 $_maximumMemories 条，你随时可以改写或删除。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.secondaryInk,
                      height: 1.55,
                    ),
              ),
            ),
            const SizedBox(height: 18),
            if (memories.isEmpty)
              SoftCard(
                child: Column(
                  children: [
                    const Icon(
                      Icons.auto_awesome_outlined,
                      size: 36,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '还没有长期记忆',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '可以先写下一条希望 easy 长期记住的偏好。',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              SoftCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var reversedIndex = 0;
                        reversedIndex < memories.length;
                        reversedIndex++) ...[
                      Builder(
                        builder: (context) {
                          final index = memories.length - 1 - reversedIndex;
                          return _MemoryTile(
                            index: index,
                            text: _memoryDisplayText(memories[index]),
                            enabled: !_isSaving,
                            onEdit: () => _editMemory(index),
                            onDelete: () => _deleteMemory(index),
                          );
                        },
                      ),
                      if (reversedIndex != memories.length - 1)
                        const Divider(height: 1, indent: 64),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _memoryDisplayText(String memory) {
  final separator = memory.contains('：') ? '：' : ':';
  final separatorIndex = memory.indexOf(separator);
  if (separatorIndex <= 0) return memory;
  return memory.substring(0, separatorIndex).trim();
}

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({
    required this.index,
    required this.text,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final String text;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey('memory-item-$index'),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      leading: const CircleAvatar(
        backgroundColor: AppColors.primarySoft,
        child: Icon(
          Icons.psychology_alt_outlined,
          color: AppColors.primaryDark,
        ),
      ),
      title: Text(text),
      subtitle: const Text('整理后的长期认知'),
      trailing: PopupMenuButton<String>(
        enabled: enabled,
        tooltip: '管理这条记忆',
        onSelected: (action) {
          if (action == 'edit') onEdit();
          if (action == 'delete') onDelete();
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'edit', child: Text('修改')),
          PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
      ),
    );
  }
}
