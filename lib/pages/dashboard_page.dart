import 'package:flutter/material.dart';

import '../mock/dashboard_mock.dart';
import '../models/pet_profile.dart';
import '../services/agent_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/companion_pet.dart';
import '../widgets/soft_card.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    required this.petProfile,
    required this.agentService,
    required this.userProfileService,
    required this.onOpenModule,
    required this.onOpenSettings,
    required this.onOpenPetProfile,
    super.key,
  });

  final PetProfile? petProfile;
  final AgentService agentService;
  final UserProfileService userProfileService;
  final ValueChanged<String> onOpenModule;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenPetProfile;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _messageController = TextEditingController();
  String? _petReply;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    _messageController.clear();
    FocusScope.of(context).unfocus();
    final profile = await widget.userProfileService.loadProfile();
    final insight = await widget.agentService.analyzeEmotion(message, profile);
    if (mounted) setState(() => _petReply = insight.petReply);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 150),
        children: [
          _Header(onOpenSettings: widget.onOpenSettings),
          const SizedBox(height: 18),
          _PetCompanionCard(
            profile: widget.petProfile,
            quote: _petReply ?? '今天也可以慢一点，我会陪你照顾好自己。',
            controller: _messageController,
            onSend: _sendMessage,
            onOpenPetProfile: widget.onOpenPetProfile,
            onOpenCompanion: () => widget.onOpenModule('桌宠陪伴'),
          ),
          const SizedBox(height: 12),
          const _DailyFortuneCard(),
          const SizedBox(height: 12),
          const _ProgressCard(),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    final dateText = '${now.month}月${now.day}日 ${weekdays[now.weekday - 1]}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Easylife',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 7),
              Text(dateText, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: onOpenSettings,
          tooltip: '设置',
          style: IconButton.styleFrom(backgroundColor: Colors.white),
          icon: const Icon(Icons.settings_outlined, size: 22),
        ),
      ],
    );
  }
}

class _PetCompanionCard extends StatelessWidget {
  const _PetCompanionCard({
    required this.profile,
    required this.quote,
    required this.controller,
    required this.onSend,
    required this.onOpenPetProfile,
    required this.onOpenCompanion,
  });

  final PetProfile? profile;
  final String quote;
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onOpenPetProfile;
  final VoidCallback onOpenCompanion;

  @override
  Widget build(BuildContext context) {
    final petName = profile?.name ?? '你的陪伴伙伴';
    return SoftCard(
      color: const Color(0xFFFFF7FA),
      borderColor: const Color(0xFFF0DCE3),
      child: Column(
        children: [
          Row(
            children: [
              const CompanionPet(size: 112),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      petName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      quote,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.ink,
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed:
                          profile == null ? onOpenPetProfile : onOpenCompanion,
                      child: Text(profile == null ? '创建宠物档案' : '进入陪伴'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
            decoration: InputDecoration(
              hintText: '和我说说今天的心情吧...',
              suffixIcon: IconButton(
                tooltip: '发送',
                onPressed: onSend,
                icon: const Icon(Icons.send_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyFortuneCard extends StatelessWidget {
  const _DailyFortuneCard();

  @override
  Widget build(BuildContext context) {
    final fortune = DashboardMock.fortune;
    return SoftCard(
      color: const Color(0xFFFFFBF0),
      borderColor: const Color(0xFFF1E2B8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.softYellow,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wb_sunny_outlined, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '今日运势',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '整体运势',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fortune.overall,
                    semanticsLabel: '整体运势四星',
                    style: const TextStyle(
                      color: Color(0xFFE2A93B),
                      fontSize: 17,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _FortuneItem(
                            icon: Icons.palette_outlined,
                            label: '幸运色',
                            value: fortune.luckyColor,
                            color: const Color(0xFF7898B8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _FortuneItem(
                            icon: Icons.restaurant_outlined,
                            label: '幸运食物',
                            value: fortune.luckyFood,
                            color: const Color(0xFFE89999),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _FortuneItem(
                            icon: Icons.tag_rounded,
                            label: '幸运数字',
                            value: fortune.luckyNumber,
                            color: const Color(0xFF8B7CC1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _FortuneItem(
                            icon: Icons.local_florist_outlined,
                            label: '幸运花',
                            value: fortune.luckyFlower,
                            color: const Color(0xFF71A67D),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 1,
                height: 116,
                color: const Color(0xFFE7D9B5),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 4,
                child: _FortuneScoreChart(
                  career: fortune.careerScore,
                  wealth: fortune.wealthScore,
                  love: fortune.loveScore,
                  social: fortune.socialScore,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _FortuneAdvice(
            icon: Icons.lightbulb_outline_rounded,
            label: '建议',
            text: fortune.suggestion,
            color: const Color(0xFF5E8D6A),
            backgroundColor: const Color(0xFFEAF4E9),
          ),
          const SizedBox(height: 10),
          _FortuneAdvice(
            icon: Icons.do_not_disturb_alt_outlined,
            label: '避免',
            text: fortune.avoid,
            color: const Color(0xFFB66A6A),
            backgroundColor: const Color(0xFFFBECEC),
          ),
        ],
      ),
    );
  }
}

class _FortuneScoreChart extends StatelessWidget {
  const _FortuneScoreChart({
    required this.career,
    required this.wealth,
    required this.love,
    required this.social,
  });

  final int career;
  final int wealth;
  final int love;
  final int social;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('运势分数', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        _FortuneScoreBar(label: '事业', score: career),
        const SizedBox(height: 7),
        _FortuneScoreBar(label: '财富', score: wealth),
        const SizedBox(height: 7),
        _FortuneScoreBar(label: '爱情', score: love),
        const SizedBox(height: 7),
        _FortuneScoreBar(label: '人际', score: social),
      ],
    );
  }
}

class _FortuneScoreBar extends StatelessWidget {
  const _FortuneScoreBar({required this.label, required this.score});

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontSize: 11,
                  color: AppColors.ink,
                ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 6,
              backgroundColor: const Color(0xFFEDE6D4),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFD6A94E)),
            ),
          ),
        ),
        const SizedBox(width: 5),
        SizedBox(
          width: 20,
          child: Text(
            '$score',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontSize: 10,
                  color: AppColors.secondaryInk,
                ),
          ),
        ),
      ],
    );
  }
}

class _FortuneItem extends StatelessWidget {
  const _FortuneItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FortuneAdvice extends StatelessWidget {
  const _FortuneAdvice({
    required this.icon,
    required this.label,
    required this.text,
    required this.color,
    required this.backgroundColor,
  });

  final IconData icon;
  final String label;
  final String text;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label：',
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: text,
                    style: const TextStyle(color: AppColors.secondaryInk),
                  ),
                ],
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('今日状态', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final item in DashboardMock.progress)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Icon(item.icon, color: item.color, size: 21),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item.label)),
                  Text(
                    item.value,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: item.color,
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
