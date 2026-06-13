import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/agent_service.dart';
import '../services/journal_repository.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/companion_pet.dart';
import '../widgets/page_header.dart';
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
  final List<PetMoodLog> _history = [];

  EmotionInsight? _insight;
  var _petStatus = '陪伴中';
  var _lastMoodText = '';
  var _isAnalyzing = false;
  var _isRecorded = false;
  var _isLoadingHistory = true;

  static const _petStatuses = ['开心', '疲惫', '陪伴中', '安静听你说'];

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
      _isLoadingHistory = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void startQuickEntry() {
    _inputFocusNode.requestFocus();
  }

  Future<void> _analyzeMood() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isAnalyzing) return;

    setState(() {
      _isAnalyzing = true;
      _petStatus = '安静听你说';
      _isRecorded = false;
    });
    final profile = await widget.userProfileService.loadProfile();
    final insight = await widget.agentService.analyzeEmotion(text, profile);
    if (!mounted) return;
    setState(() {
      _insight = insight;
      _lastMoodText = text;
      _petStatus = insight.petStatus;
      _isAnalyzing = false;
    });
  }

  Future<void> _recordMood() async {
    final insight = _insight;
    if (insight == null || _lastMoodText.isEmpty || _isRecorded) return;
    final entry = PetMoodLog(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      time: DateTime.now(),
      userText: _lastMoodText,
      emotionLabel: insight.label,
      emotionScore: insight.intensity / 100,
      petReply: insight.petReply,
      suggestion: insight.petSuggestion,
    );
    setState(() {
      _history.insert(0, entry);
      _isRecorded = true;
    });
    await widget.journalRepository.saveMoodLogs(_history);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已记录到情绪日记')));
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
            : '$petName想对你说：${_insight!.petReply}';

    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 126),
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
          const SizedBox(height: 12),
          _PetStatusStrip(
            statuses: _petStatuses,
            selected: _petStatus,
          ),
          const SizedBox(height: 22),
          const SectionTitle('写下此刻的心情'),
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
                        tooltip: '语音输入',
                        onPressed: () => _showPlaceholder('语音输入将在后续版本接入'),
                        icon: const Icon(Icons.mic_none_rounded),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _isAnalyzing ? null : _analyzeMood,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _isAnalyzing
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(
                      _isAnalyzing ? '$petName正在感受…' : '分析我的情绪',
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
      color: const Color(0xFFFFF7FA),
      borderColor: const Color(0xFFF1D9E2),
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
                        color: AppColors.softPurple,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          color: Color(0xFF7156A8),
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
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
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
                    label: const Text('创建宠物档案'),
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

class _PetStatusStrip extends StatelessWidget {
  const _PetStatusStrip({required this.statuses, required this.selected});

  final List<String> statuses;
  final String selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final status = statuses[index];
          final active = status == selected;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: active ? AppColors.ink : Colors.white,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: active ? AppColors.ink : AppColors.outline,
              ),
            ),
            child: Text(
              status,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: active ? Colors.white : AppColors.secondaryInk,
                    fontSize: 10,
                  ),
            ),
          );
        },
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
      color: const Color(0xFFF7F5FC),
      borderColor: const Color(0xFFE3DCF2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('情绪洞察', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.softPurple,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  insight.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
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
                    backgroundColor: Colors.white,
                    color: const Color(0xFF9A7AD1),
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
            title: '桌宠建议',
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
            color: Colors.white,
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
      color: const Color(0xFFFFFBF3),
      borderColor: const Color(0xFFF0E4C9),
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
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8A70BF),
              ),
              icon: Icon(
                isRecorded ? Icons.check_rounded : Icons.edit_note_rounded,
              ),
              label: Text(isRecorded ? '已记录到情绪日记' : '记录到情绪日记'),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.mistBlue,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  entry.emotionLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
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
              color: const Color(0xFFFFF7FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.smart_toy_outlined,
                  size: 18,
                  color: Color(0xFF8064B8),
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
