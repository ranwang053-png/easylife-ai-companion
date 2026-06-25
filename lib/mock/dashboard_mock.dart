import 'package:flutter/material.dart';

import '../models/dashboard_models.dart';
import '../theme/app_colors.dart';

abstract final class DashboardMock {
  static const fortune = DailyFortune(
    overallScore: 84,
    overallExplanation: '今天适合用稳定节奏推进重要事项，不必追求一次到位。',
    overallInterpretation:
        '你的本命盘底色里带着一种对秩序和安全感的重视，表达上习惯先观察、再靠近，也更容易在熟悉的节奏里发挥真正的判断力。今天的行运像一阵轻柔的风，推着你把注意力从外界评价收回来，重新看见那些能让生活变稳的小动作：整理、确认、慢慢完成。事业和人际主题会被轻轻点亮，适合把话说清楚，把任务拆小，把关系里的期待放到更舒服的位置。今天不需要急着证明自己走得很快，只要让每一步都更有方向感，你就在自己的轨道上微微校准。',
    luckyColor: '雾霾蓝',
    luckyColorExplanation: '适合用在穿搭或桌面小物上，帮你把节奏放缓一点。',
    luckyFood: '草莓酸奶',
    luckyFoodExplanation: '清爽又有一点甜，适合作为今天的小小补给。',
    luckyNumber: '7',
    luckyNumberExplanation: '提醒你给重要事项留出一个完整的小周期。',
    luckyFlower: '洋甘菊',
    luckyFlowerExplanation: '它的花语像一句轻声提醒：温和也可以很有力量。',
    careerScore: 86,
    careerExplanation: '事业上适合先处理确定性高的任务，上午的推进效率更好。',
    wealthScore: 72,
    wealthExplanation: '财富状态偏稳，适合记账和复盘，不适合冲动消费。',
    loveScore: 78,
    loveExplanation: '关系里更适合轻松表达需求，别把所有感受都憋到最后。',
    socialScore: 90,
    socialExplanation: '人际互动顺滑，适合确认合作、回应消息或主动约见。',
    suggestion: '整理 · 散步 · 早睡',
    avoid: '熬夜 · 硬比较 · 乱投递',
    emotionalClosing: '今天不用急着证明什么，先把自己慢慢带回舒服一点、稳一点的节奏里。',
  );

  static const progress = [
    DailyProgressItem(
      label: '体重记录',
      value: '已记录',
      icon: Icons.check_circle_rounded,
      color: AppColors.primary,
      completed: true,
    ),
    DailyProgressItem(
      label: '饮食记录',
      value: '进行中',
      icon: Icons.restaurant_rounded,
      color: AppColors.primary,
    ),
    DailyProgressItem(
      label: '心情记录',
      value: '待记录',
      icon: Icons.sentiment_satisfied_alt_rounded,
      color: AppColors.primary,
    ),
  ];

  static const quickActions = [
    QuickAction(
      type: QuickActionType.mood,
      label: '记录心情',
      icon: Icons.sentiment_satisfied_alt_rounded,
      color: AppColors.softCoral,
    ),
    QuickAction(
      type: QuickActionType.meal,
      label: '记录饮食',
      icon: Icons.ramen_dining_rounded,
      color: AppColors.softGreen,
    ),
    QuickAction(
      type: QuickActionType.weight,
      label: '记录体重',
      icon: Icons.monitor_weight_outlined,
      color: AppColors.softYellow,
    ),
  ];
}
