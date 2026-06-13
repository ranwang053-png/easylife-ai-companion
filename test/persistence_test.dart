import 'dart:convert';

import 'package:company_app/models/app_models.dart';
import 'package:company_app/services/agent_service.dart';
import 'package:company_app/services/journal_repository.dart';
import 'package:company_app/services/local_store.dart';
import 'package:company_app/services/pet_profile_service.dart';
import 'package:company_app/services/user_profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('core models round-trip through JSON', () {
    final profile = UserProfile(
      accountIdentifier: 'user@example.com',
      nickname: '小满',
      birthday: DateTime(1998, 6, 16),
      gender: '女',
      occupation: '产品经理',
      mbti: 'INFJ',
      zodiac: '双子座',
      goals: const ['规律作息'],
      targetWeight: 48,
      dietPreference: '清淡',
      foodRestrictions: '不吃香菜',
      petReminderStyle: '轻提醒',
    );
    final restored = UserProfile.fromJson(profile.toJson());

    expect(restored.accountIdentifier, profile.accountIdentifier);
    expect(restored.birthday, profile.birthday);
    expect(restored.goals, profile.goals);
    expect(restored.targetWeight, profile.targetWeight);
  });

  test('local profile services restore data across instances', () async {
    final store = MemoryLocalStore();
    final userService = LocalUserProfileService(store);
    final petService = LocalPetProfileService(store);
    final user = MockUserProfileService.currentProfile.copyWith(
      nickname: '内测用户',
    );
    final pet = PetProfile(
      id: 'pet-1',
      name: '糯米',
      birthday: DateTime(2022, 6, 1),
      gender: '妹妹',
      personalityTags: const ['治愈'],
      relationshipNote: '我的猫',
      originalPhotoUrl: null,
      generatedAvatarUrl: 'mock://avatar',
      createdAt: DateTime(2026, 6, 13),
    );

    await userService.saveProfile(user);
    await petService.savePetProfile(pet);

    expect(
      (await LocalUserProfileService(store).loadProfile()).nickname,
      '内测用户',
    );
    expect(
      (await LocalPetProfileService(store).getPetProfile())?.name,
      '糯米',
    );
  });

  test('journal repository restores mood, meals, weights and guide state',
      () async {
    final store = MemoryLocalStore();
    final repository = LocalJournalRepository(store);
    final mood = PetMoodLog(
      id: 'mood-new',
      time: DateTime(2026, 6, 13, 9),
      userText: '今天很平静',
      emotionLabel: '平静',
      emotionScore: .4,
      petReply: '我在这里。',
      suggestion: '保持节奏。',
    );
    final weight = WeightRecord(date: DateTime(2026, 6, 13), weight: 52.1);

    await repository.saveMoodLogs([mood]);
    await repository.saveMealRecords(const []);
    await repository.saveWeightRecords([weight]);
    await repository.setHasSeenDietGuide(true);

    final restored = LocalJournalRepository(store);
    expect((await restored.loadMoodLogs()).single.id, 'mood-new');
    expect(await restored.loadMealRecords(), isEmpty);
    expect((await restored.loadWeightRecords()).single.weight, 52.1);
    expect(await restored.hasSeenDietGuide(), isTrue);
  });

  test('HTTP agent parses real emotion response', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/emotion/analyze');
      expect(jsonDecode(request.body), contains('profile'));
      return http.Response.bytes(
        utf8.encode(jsonEncode({
          'label': '平静',
          'intensity': 55,
          'possibleReason': '节奏稳定',
          'petSuggestion': '继续保持',
          'petReply': '我陪着你。',
          'petStatus': '陪伴中',
        })),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final service = HttpAgentService(
      baseUri: Uri.parse('https://api.example.com'),
      fallback: const MockAgentService(),
      client: client,
    );

    final result = await service.analyzeEmotion(
      '今天还不错',
      MockUserProfileService.currentProfile,
    );

    expect(result.label, '平静');
    expect(result.intensity, 55);
    expect(result.petReply, '我陪着你。');
  });

  test('HTTP agent falls back when backend fails', () async {
    final service = HttpAgentService(
      baseUri: Uri.parse('https://api.example.com'),
      fallback: const MockAgentService(),
      client: MockClient((_) async => http.Response('failed', 503)),
    );

    final result = await service.analyzeEmotion(
      '今天很累',
      MockUserProfileService.currentProfile,
    );

    expect(result.label, '疲惫');
  });
}
