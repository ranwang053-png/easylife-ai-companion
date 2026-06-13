import 'dart:convert';

import '../models/app_models.dart';
import 'local_store.dart';

abstract interface class UserProfileService {
  Future<UserProfile> loadProfile();

  Future<void> saveProfile(UserProfile profile);
}

class MockUserProfileService implements UserProfileService {
  const MockUserProfileService();

  static UserProfile _profile = UserProfile(
    accountIdentifier: 'mock@example.com',
    nickname: '小满',
    birthday: DateTime(1998, 6, 16),
    gender: null,
    occupation: '产品经理',
    mbti: 'INFJ',
    zodiac: '双子座',
    goals: const ['规律作息', '情绪稳定', '健康饮食'],
    dietPreference: '清淡、低糖、喜欢蔬菜和咖啡',
    foodRestrictions: '不吃香菜，乳糖摄入适量',
    targetWeight: 48,
    petReminderStyle: '轻提醒',
  );

  static UserProfile get currentProfile => _profile;

  static void setProfile(UserProfile profile) {
    _profile = profile;
  }

  @override
  Future<UserProfile> loadProfile() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _profile;
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    setProfile(profile);
  }
}

class LocalUserProfileService implements UserProfileService {
  LocalUserProfileService(this._store);

  static const _profileKey = 'easylife.v1.user_profile';

  final LocalStore _store;

  @override
  Future<UserProfile> loadProfile() async {
    final raw = await _store.getString(_profileKey);
    if (raw == null) return MockUserProfileService.currentProfile;
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return MockUserProfileService.currentProfile;
    } on TypeError {
      return MockUserProfileService.currentProfile;
    }
  }

  @override
  Future<void> saveProfile(UserProfile profile) =>
      _store.setString(_profileKey, jsonEncode(profile.toJson()));
}
