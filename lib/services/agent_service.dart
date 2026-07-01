import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
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
    UserProfile profile, {
    PetProfile? companion,
  });

  Future<CompanionReplyResult> generateCompanionReply(
    List<AgentConversationTurn> conversation,
    UserProfile profile, {
    PetProfile? companion,
  });

  Future<EmotionJournalSummaryResult> summarizeEmotionJournal(
    List<AgentConversationTurn> conversation,
    UserProfile profile, {
    PetProfile? companion,
  });

  Future<List<LongTermMemoryCandidate>> extractLongTermMemoryCandidates({
    required String sourceType,
    required Map<String, Object?> sourceContent,
    required List<String> existingMemories,
  });

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

typedef AccessTokenProvider = Future<String?> Function();
typedef AgentFallbackReporter = void Function(String reason);

class AgentServiceException implements Exception {
  const AgentServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AgentConversationTurn {
  const AgentConversationTurn({
    required this.role,
    required this.text,
  });

  const AgentConversationTurn.user(String text)
      : this(role: 'user', text: text);

  const AgentConversationTurn.companion(String text)
      : this(role: 'companion', text: text);

  final String role;
  final String text;

  Map<String, Object> toJson() => {
        'role': role,
        'text': text,
      };
}

class CompanionReplyResult {
  const CompanionReplyResult({
    required this.reply,
    required this.riskLevel,
    this.emotionLabel,
    this.serviceSuggestion,
  });

  final String reply;
  final String? emotionLabel;
  final String riskLevel;
  final String? serviceSuggestion;
}

class EmotionJournalSummaryResult {
  const EmotionJournalSummaryResult({
    required this.recap,
    required this.emotionTags,
    required this.trigger,
    required this.insight,
    required this.nextActions,
    required this.closingWords,
  });

  final String recap;
  final List<String> emotionTags;
  final String trigger;
  final String insight;
  final List<String> nextActions;
  final String closingWords;
}

class LongTermMemoryCandidate {
  const LongTermMemoryCandidate({
    required this.type,
    required this.content,
    required this.usage,
  });

  final String type;
  final String content;
  final String usage;
}

AgentService createAgentService({
  required AccessTokenProvider accessTokenProvider,
}) {
  const baseUrl = String.fromEnvironment('EASYLIFE_API_BASE_URL');
  if (baseUrl.isEmpty) return const MockAgentService();
  return HttpAgentService(
    baseUri: Uri.parse(baseUrl),
    fallback: const MockAgentService(),
    accessTokenProvider: accessTokenProvider,
    onFallback: (reason) {
      debugPrint('AgentService fallback: $reason');
    },
  );
}

class HttpAgentService implements AgentService {
  HttpAgentService({
    required this.baseUri,
    required this.fallback,
    required this.accessTokenProvider,
    this.onFallback,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri baseUri;
  final AgentService fallback;
  final AccessTokenProvider accessTokenProvider;
  final AgentFallbackReporter? onFallback;
  final http.Client _client;

  @override
  Future<EmotionInsight> analyzeEmotion(
    String text,
    UserProfile profile, {
    PetProfile? companion,
  }) async {
    try {
      final accessToken = await accessTokenProvider();
      if (accessToken == null) {
        return _fallbackEmotion(
          text,
          profile,
          'missing_access_token',
          companion: companion,
        );
      }
      final response = await _client
          .post(
            baseUri.resolve('/v1/emotion/analyze'),
            headers: {
              'content-type': 'application/json',
              'Authorization': 'Bearer $accessToken',
              'X-Request-Id': _randomUuid(),
            },
            body: jsonEncode({
              'text': text,
              'context': {
                'nickname': profile.nickname,
                'goals': profile.goals.take(10).toList(),
                'personalTags': profile.personalTags.take(20).toList(),
                'memoryNotes': profile.memoryNotes.reversed.take(12).toList(),
                'petReminderStyle': profile.petReminderStyle,
                if (companion != null)
                  'companion': _companionContext(companion),
              },
              'client': {
                'platform': _clientPlatform(),
                'appVersion': '0.3.0+3',
                'locale': 'zh-CN',
              },
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _fallbackEmotion(
          text,
          profile,
          'http_${response.statusCode}',
          companion: companion,
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return EmotionInsight(
        label: json['label'] as String,
        labels:
            (json['labels'] as List<dynamic>?)?.whereType<String>().toList() ??
                const [],
        intensity: (json['intensity'] as num).round().clamp(0, 100),
        possibleReason: json['possibleReason'] as String,
        petSuggestion: json['petSuggestion'] as String,
        petReply: json['petReply'] as String,
        petStatus: json['petStatus'] as String,
      );
    } on Exception catch (error) {
      return _fallbackEmotion(
        text,
        profile,
        error.runtimeType.toString(),
        companion: companion,
      );
    }
  }

  Future<EmotionInsight> _fallbackEmotion(
    String text,
    UserProfile profile,
    String reason, {
    PetProfile? companion,
  }) async {
    onFallback?.call(reason);
    final insight = await fallback.analyzeEmotion(
      text,
      profile,
      companion: companion,
    );
    return EmotionInsight(
      label: insight.label,
      labels: insight.labels,
      intensity: insight.intensity,
      possibleReason: '当前网络分析不可用，以下为本地分析结果。${insight.possibleReason}',
      petSuggestion: insight.petSuggestion,
      petReply: insight.petReply,
      petStatus: insight.petStatus,
    );
  }

  @override
  Future<CompanionReplyResult> generateCompanionReply(
    List<AgentConversationTurn> conversation,
    UserProfile profile, {
    PetProfile? companion,
  }) async {
    try {
      final accessToken = await accessTokenProvider();
      if (accessToken == null) {
        return _fallbackCompanionReply(
          conversation,
          profile,
          'missing_access_token',
          companion: companion,
        );
      }
      final response = await _client
          .post(
            baseUri.resolve('/v1/companion/reply'),
            headers: _jsonHeaders(accessToken),
            body: jsonEncode({
              'conversation':
                  conversation.map((turn) => turn.toJson()).toList(),
              'context': _emotionContext(profile, companion),
              'client': _clientContext(),
            }),
          )
          .timeout(const Duration(seconds: 18));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _fallbackCompanionReply(
          conversation,
          profile,
          'companion_http_${response.statusCode}',
          companion: companion,
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return CompanionReplyResult(
        reply: json['reply'] as String,
        emotionLabel: json['emotionLabel'] as String?,
        riskLevel: json['riskLevel'] as String,
        serviceSuggestion: json['serviceSuggestion'] as String?,
      );
    } on Exception catch (error) {
      return _fallbackCompanionReply(
        conversation,
        profile,
        'companion_${error.runtimeType}',
        companion: companion,
      );
    }
  }

  Future<CompanionReplyResult> _fallbackCompanionReply(
    List<AgentConversationTurn> conversation,
    UserProfile profile,
    String reason, {
    PetProfile? companion,
  }) async {
    onFallback?.call(reason);
    return fallback.generateCompanionReply(
      conversation,
      profile,
      companion: companion,
    );
  }

  @override
  Future<EmotionJournalSummaryResult> summarizeEmotionJournal(
    List<AgentConversationTurn> conversation,
    UserProfile profile, {
    PetProfile? companion,
  }) async {
    try {
      final accessToken = await accessTokenProvider();
      if (accessToken == null) {
        return _fallbackJournalSummary(
          conversation,
          profile,
          'journal_missing_access_token',
          companion: companion,
        );
      }
      final response = await _client
          .post(
            baseUri.resolve('/v1/emotion-journals/summarize'),
            headers: _jsonHeaders(accessToken),
            body: jsonEncode({
              'conversation':
                  conversation.map((turn) => turn.toJson()).toList(),
              'context': _emotionContext(profile, companion),
              'client': _clientContext(),
            }),
          )
          .timeout(const Duration(seconds: 24));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _fallbackJournalSummary(
          conversation,
          profile,
          'journal_http_${response.statusCode}',
          companion: companion,
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return EmotionJournalSummaryResult(
        recap: json['recap'] as String,
        emotionTags:
            (json['emotionTags'] as List<dynamic>).whereType<String>().toList(),
        trigger: json['trigger'] as String,
        insight: json['insight'] as String,
        nextActions:
            (json['nextActions'] as List<dynamic>).whereType<String>().toList(),
        closingWords: json['closingWords'] as String,
      );
    } on Exception catch (error) {
      return _fallbackJournalSummary(
        conversation,
        profile,
        'journal_${error.runtimeType}',
        companion: companion,
      );
    }
  }

  Future<EmotionJournalSummaryResult> _fallbackJournalSummary(
    List<AgentConversationTurn> conversation,
    UserProfile profile,
    String reason, {
    PetProfile? companion,
  }) async {
    onFallback?.call(reason);
    return fallback.summarizeEmotionJournal(
      conversation,
      profile,
      companion: companion,
    );
  }

  @override
  Future<List<LongTermMemoryCandidate>> extractLongTermMemoryCandidates({
    required String sourceType,
    required Map<String, Object?> sourceContent,
    required List<String> existingMemories,
  }) async {
    try {
      final accessToken = await accessTokenProvider();
      if (accessToken == null) {
        return _fallbackMemoryExtraction(
          sourceType: sourceType,
          sourceContent: sourceContent,
          existingMemories: existingMemories,
          reason: 'memory_missing_access_token',
        );
      }
      final response = await _client
          .post(
            baseUri.resolve('/v1/memories/extract'),
            headers: _jsonHeaders(accessToken),
            body: jsonEncode({
              'sourceType': sourceType,
              'sourceContent': sourceContent,
              'existingMemories': existingMemories.reversed.take(12).toList(),
              'client': _clientContext(),
            }),
          )
          .timeout(const Duration(seconds: 18));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _fallbackMemoryExtraction(
          sourceType: sourceType,
          sourceContent: sourceContent,
          existingMemories: existingMemories,
          reason: 'memory_http_${response.statusCode}',
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = json['memoryCandidates'] as List<dynamic>;
      return candidates
          .whereType<Map<String, dynamic>>()
          .map(
            (candidate) => LongTermMemoryCandidate(
              type: candidate['type'] as String,
              content: candidate['content'] as String,
              usage: candidate['usage'] as String,
            ),
          )
          .toList();
    } on Exception catch (error) {
      return _fallbackMemoryExtraction(
        sourceType: sourceType,
        sourceContent: sourceContent,
        existingMemories: existingMemories,
        reason: 'memory_${error.runtimeType}',
      );
    }
  }

  Future<List<LongTermMemoryCandidate>> _fallbackMemoryExtraction({
    required String sourceType,
    required Map<String, Object?> sourceContent,
    required List<String> existingMemories,
    required String reason,
  }) async {
    onFallback?.call(reason);
    return fallback.extractLongTermMemoryCandidates(
      sourceType: sourceType,
      sourceContent: sourceContent,
      existingMemories: existingMemories,
    );
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
  Future<String> generatePetAvatarFromPhoto(String imagePath) async {
    if (!imagePath.startsWith('data:image/')) {
      return fallback.generatePetAvatarFromPhoto(imagePath);
    }
    if (imagePath.length > 8 * 1024 * 1024) {
      onFallback?.call('pet_avatar_payload_too_large');
      throw AgentServiceException(_petAvatarErrorMessage(413));
    }
    try {
      final accessToken = await accessTokenProvider();
      if (accessToken == null) {
        onFallback?.call('pet_avatar_missing_access_token');
        return fallback.generatePetAvatarFromPhoto(imagePath);
      }
      final response = await _client
          .post(
            baseUri.resolve('/v1/pet-avatar/generate'),
            headers: {
              'content-type': 'application/json',
              'Authorization': 'Bearer $accessToken',
              'X-Request-Id': _randomUuid(),
            },
            body: jsonEncode({
              'imageDataUrl': imagePath,
              'client': {
                'platform': _clientPlatform(),
                'appVersion': '0.3.0+3',
                'locale': 'zh-CN',
              },
            }),
          )
          .timeout(const Duration(seconds: 90));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        onFallback?.call('pet_avatar_http_${response.statusCode}');
        return fallback.generatePetAvatarFromPhoto(imagePath);
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final generatedAvatarUrl = json['generatedAvatarUrl'] as String?;
      if (generatedAvatarUrl == null || generatedAvatarUrl.isEmpty) {
        onFallback?.call('pet_avatar_invalid_response');
        return fallback.generatePetAvatarFromPhoto(imagePath);
      }
      return generatedAvatarUrl;
    } on AgentServiceException {
      rethrow;
    } on Exception catch (error) {
      onFallback?.call('pet_avatar_${error.runtimeType}');
      return fallback.generatePetAvatarFromPhoto(imagePath);
    }
  }

  @override
  Future<void> updateUserProfile(UserProfile profile) =>
      fallback.updateUserProfile(profile);
}

String _petAvatarErrorMessage(int statusCode) {
  if (statusCode == 400 || statusCode == 413) {
    return '这张图片可能过大或格式不支持，请换一张 5MB 以内的 PNG、JPG 或 WebP 图片';
  }
  if (statusCode == 401) {
    return '生成形象需要重新进入 Demo 后再试';
  }
  if (statusCode == 403) {
    return '图片模型账号额度不足或权限不可用，请检查后端 API Key 与账户余额';
  }
  if (statusCode == 429) {
    return 'AI 形象生成有点忙，请稍后再试';
  }
  return 'AI 形象生成暂时不可用，请稍后重试';
}

Map<String, Object> _companionContext(PetProfile companion) {
  final relationshipNote = _limitedText(companion.relationshipNote, 120);
  final personalitySummary = _limitedText(companion.personalitySummary, 200);
  return {
    'name': _limitedText(companion.name, 50),
    'personalityTags': companion.personalityTags
        .map((tag) => _limitedText(tag, 30))
        .where((tag) => tag.isNotEmpty)
        .take(8)
        .toList(),
    if (relationshipNote.isNotEmpty) 'relationshipNote': relationshipNote,
    if (personalitySummary.isNotEmpty) 'personalitySummary': personalitySummary,
  };
}

Map<String, String> _jsonHeaders(String accessToken) => {
      'content-type': 'application/json',
      'Authorization': 'Bearer $accessToken',
      'X-Request-Id': _randomUuid(),
    };

Map<String, Object> _clientContext() => {
      'platform': _clientPlatform(),
      'appVersion': '0.3.0+3',
      'locale': 'zh-CN',
    };

Map<String, Object> _emotionContext(
  UserProfile profile,
  PetProfile? companion,
) =>
    {
      'nickname': profile.nickname,
      'goals': profile.goals.take(10).toList(),
      'personalTags': profile.personalTags.take(20).toList(),
      'memoryNotes': profile.memoryNotes.reversed.take(12).toList(),
      'petReminderStyle': profile.petReminderStyle,
      if (companion != null) 'companion': _companionContext(companion),
    };

String _limitedText(String value, int maxLength) {
  final trimmed = value.trim();
  if (trimmed.length <= maxLength) return trimmed;
  return trimmed.substring(0, maxLength);
}

String _clientPlatform() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    _ => 'web',
  };
}

String _randomUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

class MockAgentService implements AgentService {
  const MockAgentService();

  @override
  Future<EmotionInsight> analyzeEmotion(
    String text,
    UserProfile profile, {
    PetProfile? companion,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final normalized = text.toLowerCase();
    final recentPatterns = profile.memoryNotes.reversed
        .take(3)
        .map((note) => note.split('：').first)
        .toSet()
        .join('、');
    String withMemory(String content) => recentPatterns.isEmpty
        ? content
        : '$content 结合你近期记录里出现过的“$recentPatterns”，这次感受可能也与之前的状态有关。';

    if (normalized.contains('累') ||
        normalized.contains('疲惫') ||
        normalized.contains('加班') ||
        normalized.contains('没睡')) {
      return EmotionInsight(
        label: '疲惫',
        labels: const ['疲惫', '压力', '需要休息'],
        intensity: 72,
        possibleReason: withMemory(
          '你描述的不只是身体累，也可能包含持续处理任务后的注意力耗竭，以及担心停下来就会落后的压力。',
        ),
        petSuggestion: profile.goals.contains('规律作息')
            ? '先把今晚必须完成的事情缩减到一项，再留出十分钟不带目标的休息，尽量按计划时间入睡。'
            : '先区分“今天必须做”和“可以明天再做”，只保留最重要的一件事，然后给身体十分钟彻底停下来。',
        petReply: '我听见你已经撑着走了很久，这种累不是一句“再坚持一下”就能解决的。\n\n'
            '我们先把今天缩小一点：只挑一件真正重要的小事，剩下的先放到明天。你不用立刻振作，我会陪你慢下来。\n\n'
            '现在更累的是身体，还是脑子里停不下来的事情？',
        petStatus: '疲惫',
      );
    }

    if (normalized.contains('难过') ||
        normalized.contains('低落') ||
        normalized.contains('委屈') ||
        normalized.contains('焦虑') ||
        normalized.contains('烦')) {
      return EmotionInsight(
        label: '低落',
        labels: const ['低落', '委屈', '需要被理解'],
        intensity: 68,
        possibleReason: withMemory(
          '你可能同时经历了期待落空、没有被充分理解，以及暂时找不到出口的无力感。真正难受的也许不是事情本身，而是已经努力过却仍觉得自己不够好。',
        ),
        petSuggestion: '先不急着评价自己。写下“发生了什么、我最在意什么、我现在需要什么”三句话，只处理其中最清楚的一项。',
        petReply: '我能感觉到这件事压在你心里，不只是难过，可能还有一点委屈和对自己的怀疑。\n\n'
            '你不需要马上证明自己没事。我们可以先把最刺痛你的那一小部分说清楚，其他的暂时不用解决。\n\n'
            '如果只能选一个，你更希望我先听你讲经过，还是陪你想下一步？',
        petStatus: '陪伴中',
      );
    }

    if (normalized.contains('开心') ||
        normalized.contains('顺利') ||
        normalized.contains('喜欢') ||
        normalized.contains('完成')) {
      return EmotionInsight(
        label: '开心',
        labels: const ['开心', '成就感', '放松'],
        intensity: 82,
        possibleReason: withMemory('这份开心可能来自事情顺利完成后的掌控感，也包含努力被看见、紧张终于放下来的轻松。'),
        petSuggestion: '用一句话记下“我做对了什么”，再给这次完成一个小小的庆祝，让成就感真正停留一会儿。',
        petReply: '我也跟着你松了一口气。这份开心不是偶然，是你前面的投入终于有了回应。\n\n'
            '先别急着奔向下一件事，让我们把这一刻多留一会儿。你今天最想为自己的哪一点鼓掌？',
        petStatus: '开心',
      );
    }

    return EmotionInsight(
      label: '平静',
      labels: const ['平静', '稳定', '自我觉察'],
      intensity: 45,
      possibleReason: withMemory(
        '情绪目前相对稳定，你有余力观察自己的状态。平静也可能是忙碌后的缓冲期，值得留意身体是否仍有尚未被注意到的疲劳。',
      ),
      petSuggestion: '保持当前节奏，花一分钟感受呼吸、肩颈和胃口，再决定今天是继续推进，还是提前为自己留一点空白。',
      petReply: '现在的你像是慢慢站稳了，不需要急着给今天下结论。\n\n'
          '我们可以趁这份平静听一听身体：有没有哪个地方还绷着，或者有什么小愿望一直没顾上？\n\n'
          '你想继续聊今天发生的事，还是一起安排一个轻松的小计划？',
      petStatus: '安静听你说',
    );
  }

  @override
  Future<CompanionReplyResult> generateCompanionReply(
    List<AgentConversationTurn> conversation,
    UserProfile profile, {
    PetProfile? companion,
  }) async {
    final userText = conversation
        .where((turn) => turn.role == 'user')
        .map((turn) => turn.text)
        .join('\n');
    final insight = await analyzeEmotion(
      userText.isEmpty ? '今天有点说不上来的情绪。' : userText,
      profile,
      companion: companion,
    );
    final reply = insight.petReply.split('\n\n').first;
    return CompanionReplyResult(
      reply: reply.length > 120 ? '${reply.substring(0, 120)}…' : reply,
      emotionLabel:
          insight.allLabels.isEmpty ? insight.label : insight.allLabels.first,
      riskLevel: 'none',
    );
  }

  @override
  Future<EmotionJournalSummaryResult> summarizeEmotionJournal(
    List<AgentConversationTurn> conversation,
    UserProfile profile, {
    PetProfile? companion,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 360));
    final userMessages = conversation
        .where((turn) => turn.role == 'user')
        .map((turn) => turn.text.trim())
        .where((text) => text.isNotEmpty)
        .toList(growable: false);
    final fullText = userMessages.join('；');
    final insight = await analyzeEmotion(
      fullText.isEmpty ? '今天有一点复杂的感受。' : fullText,
      profile,
      companion: companion,
    );
    final tags = insight.allLabels.take(3).toList();
    return EmotionJournalSummaryResult(
      recap: userMessages.length <= 1
          ? (fullText.isEmpty ? '今天记录了一段当下的感受。' : fullText)
          : '这轮对话里，你从“${userMessages.first}”慢慢说到了“${userMessages.last}”。',
      emotionTags: tags.isEmpty ? [insight.label] : tags,
      trigger: insight.possibleReason,
      insight: '这份感受正在被你一点点看见，不需要马上变成答案。',
      nextActions: const [
        '今晚只保留一件必须完成的小事',
        '睡前把明天最重要的事写成一句话',
      ],
      closingWords: '你不用一次把所有事都扛好 🌿',
    );
  }

  @override
  Future<List<LongTermMemoryCandidate>> extractLongTermMemoryCandidates({
    required String sourceType,
    required Map<String, Object?> sourceContent,
    required List<String> existingMemories,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final tags = (sourceContent['emotionTags'] as List?)
            ?.whereType<String>()
            .take(2)
            .join('、') ??
        '';
    if (tags.isEmpty) return const [];
    final content = '$tags时更适合先被倾听';
    if (existingMemories.any((memory) => memory.contains(content))) {
      return const [];
    }
    return [
      LongTermMemoryCandidate(
        type: 'preference',
        content: content.length > 30 ? content.substring(0, 30) : content,
        usage: 'companion',
      ),
    ];
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
    var note = '基于常见份量估算';

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
    var nutritionNote = '根据常见份量进行热量估算。';
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
      nutritionNote = '这是基于图片识别的常见份量估算。';
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
