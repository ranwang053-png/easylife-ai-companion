import 'package:flutter/material.dart';

import '../models/meal_record.dart';
import '../services/agent_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import 'diet_capture_page.dart';

class DietRecordGuidePage extends StatefulWidget {
  const DietRecordGuidePage({
    required this.agentService,
    required this.userProfileService,
    this.initialMeal,
    super.key,
  });

  final AgentService agentService;
  final UserProfileService userProfileService;
  final MealType? initialMeal;

  @override
  State<DietRecordGuidePage> createState() => _DietRecordGuidePageState();
}

class _DietRecordGuidePageState extends State<DietRecordGuidePage> {
  final _pageController = PageController();
  var _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openCapture() async {
    final record = await Navigator.of(context).push<MealRecord>(
      MaterialPageRoute(
        builder: (_) => DietCapturePage(
          agentService: widget.agentService,
          userProfileService: widget.userProfileService,
          initialMeal: widget.initialMeal,
        ),
      ),
    );
    if (!mounted || record == null) return;
    Navigator.of(context).pop(record);
  }

  void _continue() {
    if (_page == 0) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    } else {
      _openCapture();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('记录饮食'),
        actions: [
          TextButton(onPressed: _openCapture, child: const Text('跳过')),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (value) => setState(() => _page = value),
                children: const [
                  _GuidePanel(
                    icon: Icons.auto_awesome_rounded,
                    color: AppColors.mistBlue,
                    title: '一句话，也能轻松记录',
                    description: '拍照或输入一句话，Easylife 会帮你估算热量。',
                  ),
                  _GuidePanel(
                    icon: Icons.bookmark_added_outlined,
                    color: AppColors.softYellow,
                    title: '把食物变成今日贴纸',
                    description: '记录会变成可爱的食物贴纸，贴到你的饮食日记里。',
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < 2; index++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: index == _page ? 22 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: index == _page ? AppColors.ink : AppColors.outline,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _continue,
                style: FilledButton.styleFrom(backgroundColor: AppColors.ink),
                child: Text(_page == 0 ? '继续' : '开始记录'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidePanel extends StatelessWidget {
  const _GuidePanel({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 210,
          height: 210,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(56),
          ),
          child: Icon(icon, size: 88, color: AppColors.ink),
        ),
        const SizedBox(height: 34),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          description,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.secondaryInk,
                height: 1.6,
              ),
        ),
      ],
    );
  }
}
