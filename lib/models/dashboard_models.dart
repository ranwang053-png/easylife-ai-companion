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
    required this.overallScore,
    required this.overallExplanation,
    required this.overallInterpretation,
    required this.luckyColor,
    required this.luckyColorExplanation,
    required this.luckyFood,
    required this.luckyFoodExplanation,
    required this.luckyNumber,
    required this.luckyNumberExplanation,
    required this.luckyFlower,
    required this.luckyFlowerExplanation,
    required this.careerScore,
    required this.careerExplanation,
    required this.wealthScore,
    required this.wealthExplanation,
    required this.loveScore,
    required this.loveExplanation,
    required this.socialScore,
    required this.socialExplanation,
    required this.suggestion,
    required this.avoid,
    required this.emotionalClosing,
  });

  final int overallScore;
  final String overallExplanation;
  final String overallInterpretation;
  final String luckyColor;
  final String luckyColorExplanation;
  final String luckyFood;
  final String luckyFoodExplanation;
  final String luckyNumber;
  final String luckyNumberExplanation;
  final String luckyFlower;
  final String luckyFlowerExplanation;
  final int careerScore;
  final String careerExplanation;
  final int wealthScore;
  final String wealthExplanation;
  final int loveScore;
  final String loveExplanation;
  final int socialScore;
  final String socialExplanation;
  final String suggestion;
  final String avoid;
  final String emotionalClosing;
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
