import 'package:flutter/material.dart';

enum QuickActionType { meal, weight, mood }

class DailyProgressItem {
  const DailyProgressItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.completed = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool completed;
}

class DailyFortune {
  const DailyFortune({
    required this.overall,
    required this.luckyColor,
    required this.luckyFood,
    required this.luckyNumber,
    required this.luckyFlower,
    required this.careerScore,
    required this.wealthScore,
    required this.loveScore,
    required this.socialScore,
    required this.suggestion,
    required this.avoid,
  });

  final String overall;
  final String luckyColor;
  final String luckyFood;
  final String luckyNumber;
  final String luckyFlower;
  final int careerScore;
  final int wealthScore;
  final int loveScore;
  final int socialScore;
  final String suggestion;
  final String avoid;
}

class QuickAction {
  const QuickAction({
    required this.type,
    required this.label,
    required this.icon,
    required this.color,
  });

  final QuickActionType type;
  final String label;
  final IconData icon;
  final Color color;
}
