export 'models.dart';

class FoodEstimate {
  const FoodEstimate({
    required this.name,
    required this.calories,
    required this.note,
  });

  final String name;
  final int calories;
  final String note;
}

class FoodCalorieEstimate {
  const FoodCalorieEstimate({
    required this.foodName,
    required this.baseCalories,
    required this.estimatedCalories,
    required this.portionText,
    required this.mealType,
    required this.confidence,
    required this.nutritionNote,
    required this.suggestion,
  });

  final String foodName;
  final int baseCalories;
  final int estimatedCalories;
  final String portionText;
  final String mealType;
  final double confidence;
  final String nutritionNote;
  final String suggestion;
}

class MealPlanSuggestion {
  const MealPlanSuggestion({
    required this.totalCalories,
    required this.todayAdvice,
    required this.tomorrowPlan,
  });

  final int totalCalories;
  final String todayAdvice;
  final String tomorrowPlan;
}

class EmotionInsight {
  const EmotionInsight({
    required this.label,
    required this.intensity,
    required this.possibleReason,
    required this.petSuggestion,
    required this.petReply,
    required this.petStatus,
    this.labels = const [],
  });

  final String label;
  final List<String> labels;
  final int intensity;
  final String possibleReason;
  final String petSuggestion;
  final String petReply;
  final String petStatus;

  List<String> get allLabels => labels.isEmpty ? [label] : labels;
}
