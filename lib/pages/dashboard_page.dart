import 'package:flutter/material.dart';

import '../mock/dashboard_mock.dart';
import '../models/pet_profile.dart';
import '../services/agent_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../utils/fortune_icon_resolver.dart';
import '../widgets/companion_avatar.dart';
import '../widgets/responsive_page.dart';
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
  var _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    _messageController.clear();
    FocusScope.of(context).unfocus();
    final profile = await widget.userProfileService.loadProfile();
    final insight = await widget.agentService.analyzeEmotion(
      message,
      profile,
      companion: widget.petProfile,
    );
    if (!mounted) return;
    setState(() {
      _petReply = insight.petReply;
      _isSending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final split = constraints.maxWidth >= 760;
          final bottom = constraints.maxWidth >= 900 ? 40.0 : 148.0;
          final companion = _PetCompanionCard(
            profile: widget.petProfile,
            quote: _petReply ?? DashboardMock.fortune.emotionalClosing,
            controller: _messageController,
            isSending: _isSending,
            onSend: _sendMessage,
            onOpenPetProfile: widget.onOpenPetProfile,
            onOpenCompanion: () => widget.onOpenModule('桌宠陪伴'),
          );

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(top: 12, bottom: bottom),
            child: ResponsivePage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(onOpenSettings: widget.onOpenSettings),
                  const SizedBox(height: 22),
                  if (split)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: companion),
                        const SizedBox(width: 18),
                        const Expanded(
                          flex: 5,
                          child: Column(
                            children: [
                              _DailyFortuneCard(),
                              SizedBox(height: 16),
                              _ProgressCard(),
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    companion,
                    const SizedBox(height: 14),
                    const _DailyFortuneCard(),
                    const SizedBox(height: 14),
                    const _ProgressCard(),
                  ],
                ],
              ),
            ),
          );
        },
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
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primaryMist,
            foregroundColor: AppColors.primaryDark,
          ),
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
    required this.isSending,
    required this.onSend,
    required this.onOpenPetProfile,
    required this.onOpenCompanion,
  });

  final PetProfile? profile;
  final String quote;
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onOpenPetProfile;
  final VoidCallback onOpenCompanion;

  @override
  Widget build(BuildContext context) {
    final petName = profile?.name ?? '你的陪伴伙伴';
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      color: AppColors.primaryMist,
      borderColor: AppColors.outlineSoft,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 172),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: .86),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(99),
                          ),
                        ),
                        child: const Text(
                          '今天也在这里',
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        petName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: Text(
                          quote,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.ink, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: ResponsivePage.isMedium(context) ? 160 : 132,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CompanionAvatar(
                      profile: profile,
                      size: ResponsivePage.isMedium(context) ? 150 : 124,
                      imageKey: const Key('dashboard-companion-avatar-image'),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: profile == null
                            ? onOpenPetProfile
                            : onOpenCompanion,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(38),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          backgroundColor: AppColors.surface.withValues(
                            alpha: .75,
                          ),
                        ),
                        child: Text(
                          profile == null ? '创建伙伴档案' : '进入陪伴',
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            enabled: !isSending,
            textInputAction: TextInputAction.send,
            onSubmitted: isSending ? null : (_) => onSend(),
            decoration: InputDecoration(
              hintText: '和我说说今天的心情吧...',
              fillColor: AppColors.surface.withValues(alpha: .92),
              suffixIcon: IconButton(
                tooltip: '发送',
                onPressed: isSending ? null : onSend,
                icon: isSending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
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
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.champagneSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wb_sunny_outlined,
                  size: 21,
                  color: AppColors.champagne,
                ),
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
                  _OverallFortuneEntry(
                    score: fortune.overallScore,
                    explanation: fortune.overallExplanation,
                    interpretation: fortune.overallInterpretation,
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
                          child: _FortuneInfoItem(
                            type: FortuneIconTypes.color,
                            label: '幸运色',
                            value: fortune.luckyColor,
                            explanation: fortune.luckyColorExplanation,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _FortuneInfoItem(
                            type: FortuneIconTypes.food,
                            label: '幸运食物',
                            value: fortune.luckyFood,
                            explanation: fortune.luckyFoodExplanation,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _FortuneInfoItem(
                            type: FortuneIconTypes.number,
                            label: '幸运数字',
                            value: fortune.luckyNumber,
                            explanation: fortune.luckyNumberExplanation,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _FortuneInfoItem(
                            type: FortuneIconTypes.flower,
                            label: '幸运花',
                            value: fortune.luckyFlower,
                            explanation: fortune.luckyFlowerExplanation,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(width: 1, height: 116, color: AppColors.outline),
              const SizedBox(width: 14),
              Expanded(
                flex: 4,
                child: _FortuneScoreChart(
                  career: fortune.careerScore,
                  careerExplanation: fortune.careerExplanation,
                  wealth: fortune.wealthScore,
                  wealthExplanation: fortune.wealthExplanation,
                  love: fortune.loveScore,
                  loveExplanation: fortune.loveExplanation,
                  social: fortune.socialScore,
                  socialExplanation: fortune.socialExplanation,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _FortuneAdvice(
            icon: Icons.lightbulb_outline_rounded,
            label: '建议',
            text: fortune.suggestion,
            color: AppColors.primaryDark,
            backgroundColor: AppColors.primaryMist,
          ),
          const SizedBox(height: 10),
          _FortuneAdvice(
            icon: Icons.do_not_disturb_alt_outlined,
            label: '避免',
            text: fortune.avoid,
            color: AppColors.secondaryInk,
            backgroundColor: AppColors.cream,
          ),
        ],
      ),
    );
  }
}

class _OverallFortuneEntry extends StatelessWidget {
  const _OverallFortuneEntry({
    required this.score,
    required this.explanation,
    required this.interpretation,
  });

  final int score;
  final String explanation;
  final String interpretation;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _OverallFortunePage(
              score: score,
              explanation: explanation,
              interpretation: interpretation,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('整体运势', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(width: 3),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppColors.secondaryInk,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '$score分',
            semanticsLabel: '整体运势 $score 分',
            style: const TextStyle(
              color: AppColors.champagne,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverallFortunePage extends StatelessWidget {
  const _OverallFortunePage({
    required this.score,
    required this.explanation,
    required this.interpretation,
  });

  final int score;
  final String explanation;
  final String interpretation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: ResponsivePage(
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.champagneSoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '$score分',
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('整体解读', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text(
                  explanation,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.secondaryInk,
                        height: 1.55,
                      ),
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMist.withValues(alpha: .72),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.outlineSoft),
                  ),
                  child: Text(
                    interpretation,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.ink,
                          height: 1.8,
                        ),
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

class _FortuneScoreChart extends StatelessWidget {
  const _FortuneScoreChart({
    required this.career,
    required this.careerExplanation,
    required this.wealth,
    required this.wealthExplanation,
    required this.love,
    required this.loveExplanation,
    required this.social,
    required this.socialExplanation,
  });

  final int career;
  final String careerExplanation;
  final int wealth;
  final String wealthExplanation;
  final int love;
  final String loveExplanation;
  final int social;
  final String socialExplanation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('运势分数', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        _FortuneScoreBar(
          label: '事业',
          score: career,
          explanation: careerExplanation,
          color: AppColors.primary,
        ),
        const SizedBox(height: 7),
        _FortuneScoreBar(
          label: '财富',
          score: wealth,
          explanation: wealthExplanation,
          color: AppColors.champagne,
        ),
        const SizedBox(height: 7),
        _FortuneScoreBar(
          label: '爱情',
          score: love,
          explanation: loveExplanation,
          color: const Color(0xFF91BCAA),
        ),
        const SizedBox(height: 7),
        _FortuneScoreBar(
          label: '人际',
          score: social,
          explanation: socialExplanation,
          color: const Color(0xFF5F9B88),
        ),
      ],
    );
  }
}

class _FortuneScoreBar extends StatelessWidget {
  const _FortuneScoreBar({
    required this.label,
    required this.score,
    required this.explanation,
    required this.color,
  });

  final String label;
  final int score;
  final String explanation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _InfoBubble(
      title: '$label运势',
      message: explanation,
      child: Row(
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
                backgroundColor: color.withValues(alpha: .16),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 5),
          SizedBox(
            width: 24,
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
      ),
    );
  }
}

class _FortuneInfoItem extends StatelessWidget {
  const _FortuneInfoItem({
    required this.type,
    required this.label,
    required this.value,
    required this.explanation,
  });

  final String type;
  final String label;
  final String value;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final iconPath = getFortuneIconPath(type: type, value: value);
    return _InfoBubble(
      title: label,
      message: explanation,
      child: Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: Center(
              child: type == FortuneIconTypes.number
                  ? _LuckyNumberIcon(value: value)
                  : _FortuneAssetIcon(
                      iconPath: iconPath,
                      fallback: _FortuneIconFallback(type: type),
                    ),
            ),
          ),
          const SizedBox(width: 9),
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
      ),
    );
  }
}

class _InfoBubble extends StatefulWidget {
  const _InfoBubble({
    required this.title,
    required this.message,
    required this.child,
  });

  final String title;
  final String message;
  final Widget child;

  @override
  State<_InfoBubble> createState() => _InfoBubbleState();
}

class _InfoBubbleState extends State<_InfoBubble> {
  final _layerLink = LayerLink();
  OverlayEntry? _entry;

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  void _toggle() => _entry == null ? _show() : _hide();

  void _show() {
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hide,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomCenter,
              followerAnchor: Alignment.topCenter,
              offset: const Offset(0, 8),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 220,
                  constraints: const BoxConstraints(maxWidth: 340),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: .9),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: .18),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        widget.message,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .9),
                          fontSize: 12,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(_entry!);
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: widget.child,
      ),
    );
  }
}

class _FortuneAssetIcon extends StatelessWidget {
  const _FortuneAssetIcon({required this.iconPath, required this.fallback});

  final String? iconPath;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final path = iconPath;
    if (path == null) return fallback;
    return Image.asset(
      path,
      width: 27,
      height: 27,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _FortuneIconFallback extends StatelessWidget {
  const _FortuneIconFallback({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      FortuneIconTypes.food => Icons.restaurant_outlined,
      FortuneIconTypes.flower => Icons.local_florist_outlined,
      FortuneIconTypes.color => Icons.palette_outlined,
      _ => Icons.auto_awesome_rounded,
    };
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: AppColors.primaryMist,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 15, color: AppColors.primaryDark),
    );
  }
}

class _LuckyNumberIcon extends StatelessWidget {
  const _LuckyNumberIcon({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 23,
      height: 23,
      decoration: BoxDecoration(
        color: AppColors.champagneSoft,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.champagne),
        boxShadow: [
          BoxShadow(
            color: AppColors.champagne.withValues(alpha: .22),
            offset: const Offset(0, 3),
            blurRadius: 4,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        value,
        maxLines: 1,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
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
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: item.completed ? AppColors.primaryMist : AppColors.cream,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(item.icon, color: AppColors.primary, size: 21),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item.label)),
                  Text(
                    item.value,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.primaryDark,
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
