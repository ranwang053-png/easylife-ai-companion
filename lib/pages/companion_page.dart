import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/app_models.dart';
import '../services/agent_service.dart';
import '../services/journal_repository.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/companion_pet.dart';
import '../widgets/page_header.dart';
import '../widgets/responsive_page.dart';
import '../widgets/soft_card.dart';

class CompanionPage extends StatefulWidget {
  const CompanionPage({
    required this.agentService,
    required this.userProfileService,
    required this.journalRepository,
    required this.petProfile,
    required this.onCreatePetProfile,
    super.key,
  });

  final AgentService agentService;
  final UserProfileService userProfileService;
  final JournalRepository journalRepository;
  final PetProfile? petProfile;
  final VoidCallback onCreatePetProfile;

  @override
  State<CompanionPage> createState() => CompanionPageState();
}

class CompanionPageState extends State<CompanionPage> {
  final _controller = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _speech = SpeechToText();
  final List<PetMoodLog> _history = [];
  final List<_ConversationTurn> _conversation = [];

  EmotionInsight? _insight;
  var _petStatus = '平静';
  var _isAnalyzing = false;
  var _isRecorded = false;
  var _isLoadingHistory = true;
  var _speechInitialized = false;
  var _isListening = false;
  var _speechPrefix = '';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await widget.journalRepository.loadMoodLogs();
    history.sort((a, b) => b.time.compareTo(a.time));
    if (!mounted) return;
    setState(() {
      _history
        ..clear()
        ..addAll(history);
      _petStatus = _companionStatusForLatestLog(
        history.isEmpty ? null : history.first,
      );
      _isLoadingHistory = false;
    });
  }

  @override
  void dispose() {
    _speech.cancel();
    _controller.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void startQuickEntry() {
    _inputFocusNode.requestFocus();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isAnalyzing) return;

    _controller.clear();
    setState(() {
      _conversation.add(_ConversationTurn.user(text));
      _isAnalyzing = true;
      _isRecorded = false;
      _petStatus = '专注';
    });
    final profile = await widget.userProfileService.loadProfile();
    final conversationText = _conversation
        .where((turn) => turn.isUser)
        .map((turn) => turn.text)
        .join('\n');
    final insight = await widget.agentService.analyzeEmotion(
      conversationText,
      profile,
    );
    if (!mounted) return;
    setState(() {
      _insight = insight;
      _conversation.add(_ConversationTurn.companion(insight.petReply));
      _petStatus = _companionStatusForEmotion(insight.label);
      _isAnalyzing = false;
    });
  }

  Future<void> _recordMood() async {
    final insight = _insight;
    final userMessages =
        _conversation.where((turn) => turn.isUser).map((turn) => turn.text);
    if (insight == null || userMessages.isEmpty || _isRecorded) return;
    final profile = await widget.userProfileService.loadProfile();
    if (!mounted) return;
    final conversationSummary = userMessages.join('；');
    final memory = '${insight.allLabels.join('、')}：$conversationSummary';
    final memories = [...profile.memoryNotes, memory];
    final trimmedMemories = memories.length > 12
        ? memories.sublist(memories.length - 12)
        : memories;
    final entry = PetMoodLog(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      time: DateTime.now(),
      userText: conversationSummary,
      emotionLabel: insight.label,
      emotionLabels: insight.allLabels,
      emotionScore: insight.intensity / 100,
      petReply: insight.petReply,
      suggestion: insight.petSuggestion,
    );
    setState(() {
      _history.insert(0, entry);
      _petStatus = _companionStatusForLatestLog(entry);
      _isRecorded = true;
    });
    await Future.wait([
      widget.journalRepository.saveMoodLogs(_history),
      widget.userProfileService.saveProfile(
        profile.copyWith(memoryNotes: trimmedMemories),
      ),
    ]);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('本轮对话已整理到情绪日记')));
  }

  String _companionStatusForEmotion(String emotion) {
    return switch (emotion) {
      '开心' => '雀跃',
      '疲惫' => '担忧',
      '低落' || '难过' => '心疼',
      '焦虑' || '紧张' => '牵挂',
      _ => '安心',
    };
  }

  String _companionStatusForLatestLog(PetMoodLog? entry) {
    if (entry == null ||
        DateTime.now().difference(entry.time) > const Duration(days: 3)) {
      return '期待';
    }
    return switch (entry.emotionLabel) {
      '开心' => '雀跃',
      '疲惫' => '担忧',
      '低落' || '难过' => '心疼',
      '焦虑' || '紧张' => '牵挂',
      _ => '安心',
    };
  }

  Future<void> _toggleSpeechInput() async {
    if (_isListening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _isListening = false);
      return;
    }

    try {
      if (!_speechInitialized) {
        _speechInitialized = await _speech.initialize(
          onStatus: (status) {
            if (!mounted || (status != 'done' && status != 'notListening')) {
              return;
            }
            setState(() => _isListening = false);
          },
          onError: (error) {
            if (!mounted) return;
            setState(() => _isListening = false);
            _showPlaceholder(
              error.permanent ? '无法使用语音输入，请在系统设置中开启麦克风与语音识别权限' : '没有听清，请再试一次',
            );
          },
        );
      }
      if (!_speechInitialized) {
        _showPlaceholder('当前设备暂不支持语音识别');
        return;
      }

      _speechPrefix = _controller.text.trim();
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          final recognized = result.recognizedWords.trim();
          final text = [
            if (_speechPrefix.isNotEmpty) _speechPrefix,
            if (recognized.isNotEmpty) recognized,
          ].join('，');
          _controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
          setState(() {});
        },
        listenOptions: SpeechListenOptions(
          localeId: 'zh_CN',
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
          autoPunctuation: true,
          pauseFor: const Duration(seconds: 4),
          listenFor: const Duration(minutes: 1),
        ),
      );
      if (!mounted) return;
      setState(() => _isListening = _speech.isListening);
    } on Exception {
      if (!mounted) return;
      setState(() => _isListening = false);
      _showPlaceholder('语音输入启动失败，请检查麦克风权限后重试');
    }
  }

  void _showPlaceholder(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _startBreathing() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('深呼吸练习'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.air_rounded,
              size: 58,
              color: Color(0xFF7A91A8),
            ),
            SizedBox(height: 16),
            Text(
              '吸气 4 秒 · 停留 2 秒 · 呼气 6 秒\n\n跟着自己的节奏重复三轮。',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final petName = widget.petProfile?.name ?? '一团';
    final petReply = _isAnalyzing
        ? '$petName正在认真听，也在帮你整理这份感受…'
        : _insight == null
            ? '今天过得怎么样？开心或疲惫，都可以告诉$petName。'
            : '我在这里。你可以继续说，我们慢慢把这件事聊清楚。';

    return SafeArea(
      bottom: false,
      child: ResponsivePageList(
        maxWidth: 820,
        bottom: ResponsivePage.isWide(context) ? 40 : 126,
        children: [
          PageHeader(
            title: '陪伴',
            subtitle: '记录真实情绪，让$petName安静地陪你理解自己',
          ),
          const SizedBox(height: 20),
          _PetPanel(
            petName: petName,
            hasPetProfile: widget.petProfile != null,
            status: _petStatus,
            reply: petReply,
            onCreatePetProfile: widget.onCreatePetProfile,
          ),
          const SizedBox(height: 22),
          if (_conversation.isNotEmpty) ...[
            _ConversationThread(
              turns: _conversation,
              petName: petName,
              isReplying: _isAnalyzing,
            ),
            const SizedBox(height: 22),
          ],
          const SectionTitle('和伙伴聊聊'),
          const SizedBox(height: 10),
          SoftCard(
            child: Column(
              children: [
                TextField(
                  controller: _controller,
                  focusNode: _inputFocusNode,
                  minLines: 3,
                  maxLines: 6,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: '例如：今天事情很多，我有点累，也担心做得不够好…',
                    filled: true,
                    fillColor: AppColors.canvas,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(bottom: 58),
                      child: IconButton(
                        tooltip: _isListening ? '结束语音输入' : '语音输入',
                        onPressed: _toggleSpeechInput,
                        color: _isListening ? AppColors.accent : null,
                        icon: Icon(
                          _isListening
                              ? Icons.stop_circle_outlined
                              : Icons.mic_none_rounded,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isListening) ...[
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('正在聆听，语音会先转成文字再发送'),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _isAnalyzing ? null : _sendMessage,
                    icon: _isAnalyzing
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      _isAnalyzing ? '$petName正在回复…' : '发送',
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_insight case final insight?) ...[
            const SizedBox(height: 22),
            _EmotionInsightCard(insight: insight),
            const SizedBox(height: 16),
            _ComfortCard(
              comfort: insight.petReply,
              isRecorded: _isRecorded,
              onBreathing: _startBreathing,
              onMusic: () => _showPlaceholder('轻音乐功能已预留'),
              onRecord: _recordMood,
            ),
          ],
          const SizedBox(height: 24),
          SectionTitle('情绪日记', action: '${_history.length} 条'),
          const SizedBox(height: 10),
          if (_isLoadingHistory)
            const Center(child: CircularProgressIndicator())
          else if (_history.isEmpty)
            const SoftCard(child: Text('还没有情绪记录，写下此刻的感受吧。')),
          for (final entry in _history) ...[
            _JournalCard(entry: entry),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ConversationTurn {
  const _ConversationTurn({
    required this.text,
    required this.isUser,
  });

  factory _ConversationTurn.user(String text) =>
      _ConversationTurn(text: text, isUser: true);

  factory _ConversationTurn.companion(String text) =>
      _ConversationTurn(text: text, isUser: false);

  final String text;
  final bool isUser;
}

class _ConversationThread extends StatelessWidget {
  const _ConversationThread({
    required this.turns,
    required this.petName,
    required this.isReplying,
  });

  final List<_ConversationTurn> turns;
  final String petName;
  final bool isReplying;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('本轮对话', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text(
                '${turns.where((turn) => turn.isUser).length} 轮',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final turn in turns) ...[
            Align(
              alignment:
                  turn.isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 590),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color:
                      turn.isUser ? AppColors.primaryDark : AppColors.softGreen,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  turn.text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: turn.isUser ? Colors.white : AppColors.ink,
                        height: 1.55,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 9),
          ],
          if (isReplying)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$petName正在回复…',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.secondaryInk,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PetPanel extends StatelessWidget {
  const _PetPanel({
    required this.petName,
    required this.hasPetProfile,
    required this.status,
    required this.reply,
    required this.onCreatePetProfile,
  });

  final String petName;
  final bool hasPetProfile;
  final String status;
  final String reply;
  final VoidCallback onCreatePetProfile;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.primaryMist,
      borderColor: AppColors.outlineSoft,
      child: Row(
        children: [
          const CompanionPet(size: 132),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      petName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: .88),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: .92),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(5),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    reply,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.ink,
                        ),
                  ),
                ),
                if (!hasPetProfile) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: onCreatePetProfile,
                    icon: const Icon(Icons.pets_outlined, size: 17),
                    label: const Text('创建伙伴档案'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmotionInsightCard extends StatelessWidget {
  const _EmotionInsightCard({required this.insight});

  final EmotionInsight insight;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.primaryMist,
      borderColor: AppColors.outlineSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('情绪洞察', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final label in insight.allLabels)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: .9),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('情绪强度', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: insight.intensity / 100,
                    minHeight: 9,
                    backgroundColor: AppColors.surface,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${insight.intensity}%',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 17),
          _InsightRow(
            icon: Icons.search_rounded,
            title: '可能原因',
            content: insight.possibleReason,
          ),
          const SizedBox(height: 13),
          _InsightRow(
            icon: Icons.favorite_outline_rounded,
            title: '伙伴建议',
            content: insight.petSuggestion,
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.icon,
    required this.title,
    required this.content,
  });

  final IconData icon;
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 3),
              Text(content, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComfortCard extends StatelessWidget {
  const _ComfortCard({
    required this.comfort,
    required this.isRecorded,
    required this.onBreathing,
    required this.onMusic,
    required this.onRecord,
  });

  final String comfort;
  final bool isRecorded;
  final VoidCallback onBreathing;
  final VoidCallback onMusic;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.cream,
      borderColor: AppColors.outlineSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('让自己舒服一点', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Text(
            '“$comfort”',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.ink,
                  height: 1.6,
                ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onBreathing,
                  icon: const Icon(Icons.air_rounded),
                  label: const Text('深呼吸'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onMusic,
                  icon: const Icon(Icons.music_note_rounded),
                  label: const Text('轻音乐'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isRecorded ? null : onRecord,
              icon: Icon(
                isRecorded ? Icons.check_rounded : Icons.edit_note_rounded,
              ),
              label: Text(isRecorded ? '本轮对话已整理' : '整理为情绪日记'),
            ),
          ),
        ],
      ),
    );
  }
}

class _JournalCard extends StatelessWidget {
  const _JournalCard({required this.entry});

  final PetMoodLog entry;

  String get _timeText {
    final now = DateTime.now();
    final date = entry.time;
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (now.year == date.year &&
        now.month == date.month &&
        now.day == date.day) {
      return '今天 $time';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (yesterday.year == date.year &&
        yesterday.month == date.month &&
        yesterday.day == date.day) {
      return '昨天 $time';
    }
    return '${date.month}月${date.day}日 $time';
  }

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_timeText, style: Theme.of(context).textTheme.labelMedium),
              const Spacer(),
              Flexible(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final label in entry.allEmotionLabels)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.softGreen,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            entry.userText,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: 11),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.primaryMist,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.favorite_outline_rounded,
                  size: 18,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.petReply,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.secondaryInk,
                          height: 1.45,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
