import 'dart:math' as math;

const int longTermMemorySoftLimit = 12;
const int longTermMemoryMaxLength = 88;

const List<String> longTermMemoryCategories = [
  '情绪敏感点',
  '恢复方式',
  '近期关注',
  '沟通偏好',
  '生活习惯',
  '身体与健康线索',
  '工作/学习节奏',
  '边界与禁忌',
  '画像摘要',
];

String longTermMemoryCategoryForType(String type, String content) {
  final normalizedType = type.trim().toLowerCase();
  final normalizedContent = content.trim();
  return switch (normalizedType) {
    'emotional_sensitivity' || 'pattern' => '情绪敏感点',
    'coping_strategy' || 'recovery' => '恢复方式',
    'current_focus' || 'goal' => '近期关注',
    'communication_preference' || 'preference' => '沟通偏好',
    'lifestyle_habit' || 'habit' => '生活习惯',
    'health_context' || 'health' => '身体与健康线索',
    'work_study_context' || 'context' => _inferCategory(normalizedContent),
    'boundary' => '边界与禁忌',
    _ => _inferCategory(normalizedContent),
  };
}

String? formatLongTermMemoryCandidate({
  required String type,
  required String content,
}) {
  final normalizedContent = _cleanMemoryText(content);
  if (!isValuableLongTermMemoryCandidate(normalizedContent)) return null;
  return formatLongTermMemoryNote(
    category: longTermMemoryCategoryForType(type, normalizedContent),
    content: normalizedContent,
  );
}

String formatLongTermMemoryNote({
  required String category,
  required String content,
}) {
  final normalizedCategory = longTermMemoryCategories.contains(category)
      ? category
      : _inferCategory(content);
  final normalizedContent = _limitMemoryContent(_cleanMemoryText(content));
  return '$normalizedCategory：$normalizedContent';
}

List<String> organizeLongTermMemoryNotes(Iterable<String> rawMemories) {
  final deduplicated = <String>[];
  final seenKeys = <String>{};
  for (final rawMemory in rawMemories) {
    final memory = rawMemory.trim();
    if (memory.isEmpty) continue;
    final normalized = _normalizeExistingMemory(memory);
    final key = _memoryDedupKey(normalized);
    if (seenKeys.add(key)) deduplicated.add(normalized);
  }
  if (deduplicated.length <= longTermMemorySoftLimit) {
    return deduplicated;
  }
  return _compactLongTermMemoryNotes(deduplicated);
}

List<String> memoryNotesForAiContext(List<String> memories) {
  final organized = organizeLongTermMemoryNotes(memories);
  if (organized.length <= longTermMemorySoftLimit)
    return organized.reversed.toList();
  return organized.reversed.take(longTermMemorySoftLimit).toList();
}

LongTermMemoryView parseLongTermMemoryView(String memory) {
  final trimmed = memory.trim();
  final separatorIndex = _separatorIndex(trimmed);
  if (separatorIndex <= 0) {
    return LongTermMemoryView(
      category: _inferCategory(trimmed),
      content: trimmed,
      isCategorized: false,
    );
  }

  final title = trimmed.substring(0, separatorIndex).trim();
  final content = trimmed.substring(separatorIndex + 1).trim();
  if (longTermMemoryCategories.contains(title)) {
    return LongTermMemoryView(
      category: title,
      content: content,
      isCategorized: true,
    );
  }

  return LongTermMemoryView(
    category: title,
    content: '',
    isCategorized: false,
  );
}

bool isValuableLongTermMemoryCandidate(String content) {
  final normalized = _cleanMemoryText(content);
  if (normalized.length < 6) return false;
  final hasReusableSignal = _reusableSignalKeywords.any(normalized.contains);
  if (hasReusableSignal) return true;
  final isOnlyGenericEmotion =
      _genericEmotionPhrases.any(normalized.contains) &&
          !_concreteContextKeywords.any(normalized.contains);
  return !isOnlyGenericEmotion;
}

class LongTermMemoryView {
  const LongTermMemoryView({
    required this.category,
    required this.content,
    required this.isCategorized,
  });

  final String category;
  final String content;
  final bool isCategorized;

  String get title => category;

  String get subtitle {
    if (isCategorized && content.isNotEmpty) return content;
    return '整理后的长期认知';
  }
}

String _normalizeExistingMemory(String memory) {
  final view = parseLongTermMemoryView(memory);
  if (view.isCategorized) {
    return formatLongTermMemoryNote(
      category: view.category,
      content: view.content,
    );
  }
  return _limitMemoryContent(memory);
}

List<String> _compactLongTermMemoryNotes(List<String> memories) {
  final buckets = <String, List<String>>{};
  final uncategorized = <String>[];
  for (final memory in memories) {
    final view = parseLongTermMemoryView(memory);
    if (view.isCategorized && view.content.isNotEmpty) {
      buckets.putIfAbsent(view.category, () => []).add(view.content);
    } else {
      uncategorized.add(memory);
    }
  }

  final compacted = <String>[];
  for (final category in longTermMemoryCategories) {
    if (category == '画像摘要') continue;
    final contents = buckets[category];
    if (contents == null || contents.isEmpty) continue;
    if (contents.length == 1) {
      compacted.add(formatLongTermMemoryNote(
        category: category,
        content: contents.single,
      ));
    } else {
      compacted.add(formatLongTermMemoryNote(
        category: category,
        content: _summarizeCategory(category, contents),
      ));
    }
  }

  if (uncategorized.isNotEmpty) {
    final summary = uncategorized
        .map((memory) => parseLongTermMemoryView(memory).title)
        .take(5)
        .join('；');
    compacted.add(formatLongTermMemoryNote(
      category: '画像摘要',
      content: summary,
    ));
  }

  if (compacted.length <= longTermMemorySoftLimit) return compacted;
  return compacted.sublist(
      0, math.min(longTermMemorySoftLimit, compacted.length));
}

String _summarizeCategory(String category, List<String> contents) {
  final unique = <String>[];
  final seen = <String>{};
  for (final content in contents) {
    final cleaned = _cleanMemoryText(content);
    final key = _compactKey(cleaned);
    if (seen.add(key)) unique.add(cleaned);
  }
  final joined = unique.take(4).join('；');
  final prefix = switch (category) {
    '身体与健康线索' => '用户提到过：',
    '恢复方式' => '对用户有帮助的方式包括：',
    '沟通偏好' => '用户希望被回应的方式包括：',
    '近期关注' => '用户近期主要关注：',
    '工作/学习节奏' => '用户当前工作/学习状态包括：',
    '情绪敏感点' => '用户容易被这些情境影响：',
    '生活习惯' => '用户稳定出现的生活习惯包括：',
    '边界与禁忌' => '需要尊重的边界包括：',
    _ => '用户画像包括：',
  };
  return _limitMemoryContent('$prefix$joined');
}

String _inferCategory(String content) {
  final text = content.trim();
  if (_healthKeywords.any(text.contains)) return '身体与健康线索';
  if (_recoveryKeywords.any(text.contains)) return '恢复方式';
  if (_communicationKeywords.any(text.contains)) return '沟通偏好';
  if (_habitKeywords.any(text.contains)) return '生活习惯';
  if (_workStudyKeywords.any(text.contains)) return '工作/学习节奏';
  if (_focusKeywords.any(text.contains)) return '近期关注';
  if (_boundaryKeywords.any(text.contains)) return '边界与禁忌';
  return '情绪敏感点';
}

String _cleanMemoryText(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String _limitMemoryContent(String value) {
  final cleaned = _cleanMemoryText(value);
  if (cleaned.length <= longTermMemoryMaxLength) return cleaned;
  return cleaned.substring(0, longTermMemoryMaxLength);
}

String _memoryDedupKey(String memory) {
  final view = parseLongTermMemoryView(memory);
  return '${view.category}:${_compactKey(view.content.isEmpty ? view.title : view.content)}';
}

String _compactKey(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[\s，。！？、；：:,.!?;|｜“”"（）()]'), '');
}

int _separatorIndex(String memory) {
  final chinese = memory.indexOf('：');
  if (chinese > 0) return chinese;
  final ascii = memory.indexOf(':');
  if (ascii > 0) return ascii;
  return -1;
}

const _healthKeywords = [
  '胃',
  '胃炎',
  '胃痛',
  '过敏',
  '忌口',
  '不耐受',
  '失眠',
  '睡眠',
  '头痛',
  '身体',
];

const _recoveryKeywords = ['散步', '音乐', '放松', '休息', '呼吸', '冥想', '运动'];

const _communicationKeywords = ['倾听', '建议', '回应', '安慰', '陪', '催促', '语气'];

const _habitKeywords = ['早餐', '咖啡', '作息', '饮食', '晚睡', '早睡', '习惯'];

const _workStudyKeywords = ['工作', '实习', '加班', '面试', '作品集', '学习', '考试'];

const _focusKeywords = ['最近', '近期', '准备', '目标', '选择', '任务', '计划'];

const _boundaryKeywords = ['不喜欢', '不要', '避免', '边界', '不能', '拒绝'];

const _reusableSignalKeywords = [
  ..._healthKeywords,
  ..._recoveryKeywords,
  ..._communicationKeywords,
  ..._habitKeywords,
  ..._workStudyKeywords,
  ..._focusKeywords,
  ..._boundaryKeywords,
  '希望',
  '容易',
  '偏好',
  '喜欢',
];

const _concreteContextKeywords = [
  ..._healthKeywords,
  ..._workStudyKeywords,
  ..._focusKeywords,
  ..._communicationKeywords,
  ..._habitKeywords,
];

const _genericEmotionPhrases = [
  '心情不好',
  '难过',
  '焦虑',
  '低落',
  '有点累',
  '很累',
  '压力',
  '烦',
];
