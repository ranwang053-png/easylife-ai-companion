import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/pet_profile.dart';
import 'local_store.dart';

abstract interface class PetProfileService {
  Future<PetProfile?> getPetProfile();

  Future<void> savePetProfile(PetProfile profile);

  Future<bool> hasPetProfile();

  Future<void> updatePetProfile(PetProfile profile);
}

class MockPetProfileService implements PetProfileService {
  const MockPetProfileService();

  // Change this to true to simulate a returning user with a pet profile.
  static const bool mockHasPetProfileOnLaunch = false;

  static final ValueNotifier<PetProfile?> profileListenable =
      ValueNotifier<PetProfile?>(
    mockHasPetProfileOnLaunch
        ? PetProfile(
            id: 'mock-pet',
            name: '糯米',
            birthday: DateTime(2022, 6, 1),
            gender: '妹妹',
            personalityTags: const ['粘人', '治愈'],
            relationshipNote: '我的猫',
            originalPhotoUrl: 'mock://pet-photo/gallery',
            generatedAvatarUrl: 'mock://generated/pet-avatar',
            createdAt: DateTime(2026, 6, 8),
          )
        : null,
  );

  static PetProfile? get currentProfile => profileListenable.value;

  @override
  Future<PetProfile?> getPetProfile() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return currentProfile;
  }

  @override
  Future<bool> hasPetProfile() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return currentProfile != null;
  }

  @override
  Future<void> savePetProfile(PetProfile profile) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    profileListenable.value = profile;
  }

  @override
  Future<void> updatePetProfile(PetProfile profile) async {
    await savePetProfile(profile);
  }

  static void resetMockProfile() {
    profileListenable.value = null;
  }
}

class LocalPetProfileService implements PetProfileService {
  LocalPetProfileService(this._store);

  static const profileKey = 'easylife.v1.pet_profile';

  final LocalStore _store;

  @override
  Future<PetProfile?> getPetProfile() async {
    final raw = await _store.getString(profileKey);
    if (raw == null) return null;
    try {
      return PetProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<bool> hasPetProfile() async => await getPetProfile() != null;

  @override
  Future<void> savePetProfile(PetProfile profile) =>
      _store.setString(profileKey, jsonEncode(profile.toJson()));

  @override
  Future<void> updatePetProfile(PetProfile profile) => savePetProfile(profile);
}
