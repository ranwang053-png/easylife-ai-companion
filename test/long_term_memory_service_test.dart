import 'package:company_app/services/long_term_memory_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('long-term memory organization', () {
    test('keeps self-reported health context as a categorized memory', () {
      final memory = formatLongTermMemoryCandidate(
        type: 'health_context',
        content: '用户提到自己有胃炎/胃痛，饮食建议需要更温和',
      );

      expect(memory, '身体与健康线索：用户提到自己有胃炎/胃痛，饮食建议需要更温和');
    });

    test('keeps internship and work confusion as current focus', () {
      final memory = formatLongTermMemoryCandidate(
        type: 'current_focus',
        content: '用户近期因实习和工作选择感到困惑',
      );

      expect(memory, '近期关注：用户近期因实习和工作选择感到困惑');
    });

    test('drops generic mood without reusable context', () {
      final memory = formatLongTermMemoryCandidate(
        type: 'emotional_sensitivity',
        content: '用户今天心情不好',
      );

      expect(memory, isNull);
    });

    test('compacts more than twelve memories by category instead of truncating',
        () {
      final raw = [
        for (var index = 0; index < 6; index++) '近期关注：用户最近准备作品集阶段 $index',
        for (var index = 0; index < 5; index++) '沟通偏好：压力大时希望先被倾听 $index',
        for (var index = 0; index < 4; index++) '恢复方式：散步和听轻音乐能帮助自己放松 $index',
      ];

      final organized = organizeLongTermMemoryNotes(raw);

      expect(organized.length, lessThanOrEqualTo(longTermMemorySoftLimit));
      expect(organized.any((memory) => memory.startsWith('近期关注：')), isTrue);
      expect(organized.any((memory) => memory.startsWith('沟通偏好：')), isTrue);
      expect(organized.any((memory) => memory.startsWith('恢复方式：')), isTrue);
      expect(
        organized.join('\n'),
        contains('用户近期主要关注'),
      );
    });
  });
}
