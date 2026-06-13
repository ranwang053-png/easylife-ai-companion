import 'package:flutter/material.dart';

import '../models/dashboard_models.dart';
import '../theme/app_colors.dart';

abstract final class DashboardMock {
  static const fortune = DailyFortune(
    overall: '★★★★☆',
    luckyColor: '雾霾蓝',
    luckyFood: '草莓酸奶',
    luckyNumber: '7',
    luckyFlower: '洋甘菊',
    careerScore: 86,
    wealthScore: 72,
    loveScore: 78,
    socialScore: 90,
    suggestion: '把重要的事放在上午完成，给自己留一点从容。',
    avoid: '避免同时答应太多事情，也别忘了按时吃饭。',
  );

  static const progress = [
    DailyProgressItem(
      label: '体重记录',
      value: '已记录',
      icon: Icons.check_circle_rounded,
      color: Color(0xFF48A865),
      completed: true,
    ),
    DailyProgressItem(
      label: '饮食记录',
      value: '进行中',
      icon: Icons.restaurant_rounded,
      color: Color(0xFFF2B84B),
    ),
    DailyProgressItem(
      label: '心情记录',
      value: '待记录',
      icon: Icons.sentiment_satisfied_alt_rounded,
      color: AppColors.softPurple,
    ),
  ];

  static const quickActions = [
    QuickAction(
      type: QuickActionType.mood,
      label: '记录心情',
      icon: Icons.sentiment_satisfied_alt_rounded,
      color: AppColors.softPurple,
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
