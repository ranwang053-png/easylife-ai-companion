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
  var _savedUserMessageCount = 0;
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
    final userMessages = _conversation
        .where((turn) => turn.isUser)
        .map((turn) => turn.text)
        .toList(growable: false);
    final unsavedMessages = userMessages.skip(_savedUserMessageCount).toList();
    if (insight == null || unsavedMessages.isEmpty || _isRecorded) return;
    final profile = await widget.userProfileService.loadProfile();
    if (!mounted) return;
    final conversationSummary = unsavedMessages.join('；');
    final journalSummary = _buildJournalSummary(
      messages: unsavedMessages,
      insight: insight,
    );
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
      summary: journalSummary.summary,
      warmSummary: journalSummary.warmSummary,
      possibleReason: journalSummary.possibleReason,
      emotionChange: journalSummary.emotionChange,
      emotionValidation: journalSummary.emotionValidation,
      actionSuggestion: journalSummary.actionSuggestion,
      nextActions: journalSummary.nextActions,
      closingMessage: journalSummary.closingMessage,
    );
    setState(() {
      _history.insert(0, entry);
      _petStatus = _companionStatusForLatestLog(entry);
      _isRecorded = true;
      _savedUserMessageCount = userMessages.length;
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
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      _conversation.clear();
      _insight = null;
      _isRecorded = false;
      _savedUserMessageCount = 0;
    });
    _inputFocusNode.requestFocus();
  }

  _JournalSummaryDraft _buildJournalSummary({
    required List<String> messages,
    required EmotionInsight insight,
  }) {
    final first = messages.first;
    final last = messages.last;
    final labels = insight.allLabels.take(3).join('、');
    final summary =
        messages.length == 1 ? first : '这轮对话里，你从“$first”慢慢说到了“$last”。';
    return _JournalSummaryDraft(
      summary: summary,
      warmSummary: '你今天的感受被好好听见了，不需要急着把它变成答案。',
      possibleReason: insight.possibleReason,
      emotionChange: messages.length == 1
          ? '这次主要浮现的是$labels。'
          : '这段对话里，情绪从一开始的表达慢慢变得更具体，主要围绕$labels。',
      emotionValidation: '这些感受的出现是合理的，它们说明你正在认真对待自己的处境和需要。',
      actionSuggestion: insight.petSuggestion,
      nextActions: const ['今晚留十分钟安静下来喝点水', '明天把最牵挂的一件事写成一句话'],
      closingMessage: '我会陪你慢慢把它放轻一点 🌿',
    );
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

  @override
  Widget build(BuildContext context) {
    final petName = widget.petProfile?.name ?? '一团';
    final userMessageCount = _conversation.where((turn) => turn.isUser).length;
    final canSaveMood = _insight != null &&
        userMessageCount > _savedUserMessageCount &&
        !_isAnalyzing &&
        !_isRecorded;
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
          if (_conversation.isNotEmpty) ...[
            const SizedBox(height: 22),
            _SaveMoodJournalCard(
              canSave: canSaveMood,
              isRecorded: _isRecorded,
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

class _JournalSummaryDraft {
  const _JournalSummaryDraft({
    required this.summary,
    required this.warmSummary,
    required this.possibleReason,
    required this.emotionChange,
    required this.emotionValidation,
    required this.actionSuggestion,
    required this.nextActions,
    required this.closingMessage,
  });

  final String summary;
  final String warmSummary;
  final String possibleReason;
  final String emotionChange;
  final String emotionValidation;
  final String actionSuggestion;
  final List<String> nextActions;
  final String closingMessage;
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

class _SaveMoodJournalCard extends StatelessWidget {
  const _SaveMoodJournalCard({
    required this.canSave,
    required this.isRecorded,
    required this.onRecord,
  });

  final bool canSave;
  final bool isRecorded;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.primaryMist,
      borderColor: AppColors.outlineSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '想留下这一段吗？',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '我会在你点击保存后，再把这段对话整理成情绪日记。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondaryInk,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canSave ? onRecord : null,
              icon: Icon(
                isRecorded ? Icons.check_rounded : Icons.edit_note_rounded,
              ),
              label: Text(isRecorded ? '已保存情绪日记' : '保存情绪日记'),
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
      key: ValueKey('mood-journal-card-${entry.id}'),
      padding: const EdgeInsets.all(15),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _JournalDetailPage(
              entry: entry,
              timeText: _timeText,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_timeText, style: Theme.of(context).textTheme.labelMedium),
              const Spacer(),
              Flexible(child: _EmotionTags(labels: entry.allEmotionLabels)),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.secondaryInk,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            entry.displaySummary,
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
                    entry.displayClosingMessage,
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

class _EmotionTags extends StatelessWidget {
  const _EmotionTags({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 5,
      runSpacing: 5,
      children: [
        for (final label in labels.take(3))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
    );
  }
}

class _JournalDetailPage extends StatelessWidget {
  const _JournalDetailPage({
    required this.entry,
    required this.timeText,
  });

  final PetMoodLog entry;
  final String timeText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: ResponsivePage(
            maxWidth: 820,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: '返回',
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Spacer(),
                    Text(timeText,
                        style: Theme.of(context).textTheme.labelMedium),
                  ],
                ),
                const SizedBox(height: 18),
                Text('情绪日记', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                _EmotionTags(labels: entry.allEmotionLabels),
                const SizedBox(height: 18),
                _JournalDetailSection(
                  emoji: '📝',
                  title: '今天聊到的是',
                  content: entry.displaySummary,
                ),
                _JournalDetailSection(
                  emoji: '🌧️',
                  title: '它可能从这里来',
                  content: entry.displayPossibleReason,
                ),
                _JournalDetailSection(
                  emoji: '🌱',
                  title: '你慢慢看见了',
                  content: entry.displayEmotionChange,
                ),
                _JournalDetailSection(
                  emoji: '🤍',
                  title: '这些感受可以被允许',
                  content: entry.displayEmotionValidation,
                ),
                _JournalActionsSection(actions: entry.displayNextActions),
                _JournalDetailSection(
                  emoji: '✨',
                  title: '留给现在的你',
                  content: entry.displayClosingMessage,
                  highlighted: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JournalDetailSection extends StatelessWidget {
  const _JournalDetailSection({
    required this.emoji,
    required this.title,
    required this.content,
    this.highlighted = false,
  });

  final String emoji;
  final String title;
  final String content;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.primaryMist : AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$emoji  $title', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondaryInk,
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }
}

class _JournalActionsSection extends StatelessWidget {
  const _JournalActionsSection({required this.actions});

  final List<String> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🌤️  可以试试的小事', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          for (final action in actions.take(2)) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• '),
                Expanded(
                  child: Text(
                    action,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.secondaryInk,
                          height: 1.6,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
