import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_models.dart';
import 'user_profile_service.dart';

/// Unified AI boundary for the Flutter client.
///
/// The mock implementation is local today. A future implementation can map
/// these same methods to a Node.js / Express API without changing page code.
abstract interface class AgentService {
  Future<EmotionInsight> analyzeEmotion(
    String text,
    UserProfile profile,
  );

  Future<FoodEstimate> estimateCalories(
    String foodDescription,
    String mealType,
    UserProfile profile,
  );

  /// Future implementations should call a self-hosted AI backend that supports
  /// food image recognition, natural-language parsing, ingredient/OCR input
  /// and portion-based calorie conversion. Flutter must not contain AI keys.
  Future<FoodCalorieEstimate> estimateFoodCalories({
    required String description,
    String? imagePath,
    String? ingredientsText,
    required String portionText,
    required String mealType,
    required UserProfile profile,
  });

  Future<MealPlanSuggestion> generateMealPlan(
    List<MealRecord> meals,
    UserProfile profile,
  );

  /// Future implementations must upload the approved image to a self-hosted
  /// backend that calls the image-generation model. Never place an AI API key
  /// or direct model request in the Flutter client.
  Future<String> generatePetAvatarFromPhoto(String imagePath);

  Future<void> updateUserProfile(UserProfile profile);
}

AgentService createAgentService() {
  const baseUrl = String.fromEnvironment('EASYLIFE_API_BASE_URL');
  if (baseUrl.isEmpty) return const MockAgentService();
  return HttpAgentService(
    baseUri: Uri.parse(baseUrl),
    fallback: const MockAgentService(),
  );
}

class HttpAgentService implements AgentService {
  HttpAgentService({
    required this.baseUri,
    required this.fallback,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri baseUri;
  final AgentService fallback;
  final http.Client _client;

  @override
  Future<EmotionInsight> analyzeEmotion(
    String text,
    UserProfile profile,
  ) async {
    try {
      final response = await _client
          .post(
            baseUri.resolve('/v1/emotion/analyze'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'text': text,
              'profile': profile.toJson(),
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return fallback.analyzeEmotion(text, profile);
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return EmotionInsight(
        label: json['label'] as String,
        intensity: (json['intensity'] as num).round().clamp(0, 100),
        possibleReason: json['possibleReason'] as String,
        petSuggestion: json['petSuggestion'] as String,
        petReply: json['petReply'] as String,
        petStatus: json['petStatus'] as String,
      );
    } on Exception {
      return fallback.analyzeEmotion(text, profile);
    }
  }

  @override
  Future<FoodEstimate> estimateCalories(
    String foodDescription,
    String mealType,
    UserProfile profile,
  ) =>
      fallback.estimateCalories(foodDescription, mealType, profile);

  @override
  Future<FoodCalorieEstimate> estimateFoodCalories({
    required String description,
    String? imagePath,
    String? ingredientsText,
    required String portionText,
    required String mealType,
    required UserProfile profile,
  }) =>
      fallback.estimateFoodCalories(
        description: description,
        imagePath: imagePath,
        ingredientsText: ingredientsText,
        portionText: portionText,
        mealType: mealType,
        profile: profile,
      );

  @override
  Future<MealPlanSuggestion> generateMealPlan(
    List<MealRecord> meals,
    UserProfile profile,
  ) =>
      fallback.generateMealPlan(meals, profile);

  @override
  Future<String> generatePetAvatarFromPhoto(String imagePath) =>
      fallback.generatePetAvatarFromPhoto(imagePath);

  @override
  Future<void> updateUserProfile(UserProfile profile) =>
      fallback.updateUserProfile(profile);
}

class MockAgentService implements AgentService {
  const MockAgentService();

  @override
  Future<EmotionInsight> analyzeEmotion(
    String text,
    UserProfile profile,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final normalized = text.toLowerCase();

    if (normalized.contains('累') ||
        normalized.contains('疲惫') ||
        normalized.contains('加班') ||
        normalized.contains('没睡')) {
      return EmotionInsight(
        label: '疲惫',
        intensity: 72,
        possibleReason: '持续消耗了较多精力，身体和注意力都在提醒你需要暂停。',
        petSuggestion: profile.goals.contains('规律作息')
            ? '今晚把按时休息放在第一位，只完成最低限度的事情。'
            : '给自己安排十分钟不带目标的休息。',
        petReply: '听起来你真的撑了很久。先靠一会儿，我陪你把今天放慢一点。',
        petStatus: '疲惫',
      );
    }

    if (normalized.contains('难过') ||
        normalized.contains('低落') ||
        normalized.contains('委屈') ||
        normalized.contains('焦虑') ||
        normalized.contains('烦')) {
      return const EmotionInsight(
        label: '低落',
        intensity: 68,
        possibleReason: '期待没有被满足，或有些压力暂时找不到出口。',
        petSuggestion: '先说出最让你难受的一件事，不急着马上解决全部问题。',
        petReply: '你的感受不是小题大做。我会安静听着，你可以慢慢说。',
        petStatus: '陪伴中',
      );
    }

    if (normalized.contains('开心') ||
        normalized.contains('顺利') ||
        normalized.contains('喜欢') ||
        normalized.contains('完成')) {
      return const EmotionInsight(
        label: '开心',
        intensity: 82,
        possibleReason: '今天发生了让你有掌控感或被认可的事情。',
        petSuggestion: '把这件开心的小事记下来，让它成为以后低落时的能量。',
        petReply: '我也替你开心！这一刻很值得被好好收藏起来。',
        petStatus: '开心',
      );
    }

    return const EmotionInsight(
      label: '平静',
      intensity: 45,
      possibleReason: '情绪处在相对稳定的区间，你正在观察和整理自己的感受。',
      petSuggestion: '保持现在的节奏，留意身体最需要的是什么。',
      petReply: '不用急着给感受下结论，我就在这里陪你慢慢看清它。',
      petStatus: '安静听你说',
    );
  }

  @override
  Future<FoodEstimate> estimateCalories(
    String foodDescription,
    String mealType,
    UserProfile profile,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 420));
    final text = foodDescription.trim();
    final normalized = text.toLowerCase();
    var calories = 280;
    var note = '基于常见份量的 Mock 估算';

    if (normalized.contains('海盐焦糖拿铁')) {
      calories = 300;
      note = '按常规中杯、含糖奶咖估算';
    } else if (normalized.contains('拿铁') || normalized.contains('奶茶')) {
      calories = 260;
      note = '按常规中杯饮品估算';
    } else if (normalized.contains('鸡蛋')) {
      calories = 90;
      note = '按 1 个常规鸡蛋估算';
    } else if (normalized.contains('饭') || normalized.contains('面')) {
      calories = 520;
      note = '按一份常规主食套餐估算';
    } else if (normalized.contains('苹果') || normalized.contains('水果')) {
      calories = 110;
      note = '按一份常规水果估算';
    }

    if (profile.foodRestrictions.isNotEmpty &&
        text.contains(profile.foodRestrictions)) {
      note = '$note；请留意你的忌口设置';
    }
    return FoodEstimate(
      name: text,
      calories: calories,
      note: '$mealType · $note',
    );
  }

  @override
  Future<FoodCalorieEstimate> estimateFoodCalories({
    required String description,
    String? imagePath,
    String? ingredientsText,
    required String portionText,
    required String mealType,
    required UserProfile profile,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 520));
    final text = '$description ${ingredientsText ?? ''}'.toLowerCase();
    var foodName = description.trim().isEmpty ? '图片中的餐食' : description.trim();
    var baseCalories = 360;
    var nutritionNote = '根据常见份量进行 Mock 热量估算。';
    var suggestion = '留意今天整体的蛋白质和蔬菜摄入。';

    if (text.contains('海盐焦糖拿铁') || text.contains('瑞幸')) {
      foodName = '海盐焦糖拿铁';
      baseCalories = 300;
      nutritionNote = '含糖饮品热量较高，建议今天其他餐减少甜食。';
      suggestion = '可以搭配高蛋白正餐，避免血糖波动。';
    } else if (text.contains('薯片')) {
      foodName = '薯片';
      baseCalories = 500;
      nutritionNote = '高油高盐零食，建议多喝水。';
      suggestion = '晚餐可以选择清淡一点。';
    } else if (text.contains('蛋糕')) {
      foodName = '奶油蛋糕';
      baseCalories = 420;
      nutritionNote = '甜点的糖和脂肪含量通常较高。';
      suggestion = '下一餐可以搭配蔬菜和优质蛋白。';
    } else if (text.contains('三明治')) {
      foodName = '三明治';
      baseCalories = 380;
      nutritionNote = '热量会随酱料和夹馅变化。';
      suggestion = '搭配无糖饮品会更轻盈。';
    } else if (imagePath != null) {
      foodName = description.trim().isEmpty ? '番茄鸡肉饭' : description.trim();
      baseCalories = 520;
      nutritionNote = '这是基于 Mock 图片识别的常见份量估算。';
      suggestion = '可以补充一份深色蔬菜。';
    }

    final ratio = switch (portionText) {
      '半份' || '半袋' || '半个' => .5,
      '一小块' => .3,
      _ => 1.0,
    };
    return FoodCalorieEstimate(
      foodName: foodName,
      baseCalories: baseCalories,
      estimatedCalories: (baseCalories * ratio).round(),
      portionText: portionText,
      mealType: mealType,
      confidence: imagePath == null ? .88 : .82,
      nutritionNote: nutritionNote,
      suggestion: suggestion,
    );
  }

  @override
  Future<MealPlanSuggestion> generateMealPlan(
    List<MealRecord> meals,
    UserProfile profile,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final total = meals.fold<int>(
      0,
      (sum, meal) => sum + meal.estimatedCalories,
    );
    return MealPlanSuggestion(
      totalCalories: total,
      todayAdvice: total > 1600
          ? '今天摄入相对充足，后续优先选择清淡蛋白质和深色蔬菜。'
          : '今天整体较轻盈，可以关注蛋白质和蔬菜是否充足。',
      tomorrowPlan:
          '结合你的目标体重 ${profile.targetWeight.toStringAsFixed(1)} kg，明天早餐保留蛋白质，午餐主食适量，下午准备低糖水果。',
    );
  }

  @override
  Future<String> generatePetAvatarFromPhoto(String imagePath) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return 'mock://generated/pet-avatar';
  }

  @override
  Future<void> updateUserProfile(UserProfile profile) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    MockUserProfileService.setProfile(profile);
  }
}
