import 'package:company_app/services/demo_data_seeder.dart';
import 'package:company_app/services/journal_repository.dart';
import 'package:company_app/services/local_store.dart';
import 'package:company_app/services/pet_profile_service.dart';
import 'package:company_app/services/user_profile_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const seeder = PortfolioDemoDataSeeder();
  final seedTime = DateTime(2026, 6, 26, 15, 30);

  test(
    'fresh portfolio demo user receives the complete starter dataset',
    () async {
      final store = MemoryLocalStore();

      final seeded = await seeder.seedIfNeeded(
        userId: portfolioDemoUserId,
        store: store,
        now: seedTime,
      );

      expect(seeded, isTrue);

      final profile = await LocalUserProfileService(store).loadProfile();
      expect(profile.accountIdentifier, portfolioDemoUserId);
      expect(profile.nickname, '林夏');
      expect(profile.occupation, isNotEmpty);
      expect(profile.mbti, isNotEmpty);
      expect(profile.goals, hasLength(3));
      expect(profile.personalTags, hasLength(3));
      expect(profile.memoryNotes, hasLength(3));

      final pet = await LocalPetProfileService(store).getPetProfile();
      expect(pet?.name, '一团');
      expect(pet?.personalityTags, hasLength(3));

      final journals = LocalJournalRepository(store);
      expect(await journals.loadMoodLogs(), hasLength(2));
      expect(await journals.loadMealRecords(), hasLength(3));
      expect(await journals.loadWeightRecords(), hasLength(3));
    },
  );

  test('subsequent demo entry preserves user edits', () async {
    final store = MemoryLocalStore();
    await seeder.seedIfNeeded(
      userId: portfolioDemoUserId,
      store: store,
      now: seedTime,
    );
    final profiles = LocalUserProfileService(store);
    final edited = (await profiles.loadProfile()).copyWith(
      nickname: '我改过的名字',
      memoryNotes: const ['我自己保留的记忆'],
    );
    await profiles.saveProfile(edited);
    await LocalJournalRepository(store).saveMoodLogs(const []);

    final seededAgain = await seeder.seedIfNeeded(
      userId: portfolioDemoUserId,
      store: store,
      now: seedTime.add(const Duration(days: 1)),
    );

    expect(seededAgain, isFalse);
    expect((await profiles.loadProfile()).nickname, '我改过的名字');
    expect((await profiles.loadProfile()).memoryNotes, ['我自己保留的记忆']);
    expect(await LocalJournalRepository(store).loadMoodLogs(), isEmpty);
  });

  test('any existing demo business data prevents partial seeding', () async {
    final store = MemoryLocalStore();
    await store.setString(LocalJournalRepository.mealRecordsKey, '[]');

    final seeded = await seeder.seedIfNeeded(
      userId: portfolioDemoUserId,
      store: store,
      now: seedTime,
    );

    expect(seeded, isFalse);
    expect(await store.getString(LocalUserProfileService.profileKey), isNull);
    expect(await store.getString(LocalPetProfileService.profileKey), isNull);
    expect(await store.getString(LocalJournalRepository.moodLogsKey), isNull);
    expect(
      await store.getString(LocalJournalRepository.weightRecordsKey),
      isNull,
    );

    await store.remove(LocalJournalRepository.mealRecordsKey);
    expect(
      await seeder.seedIfNeeded(
        userId: portfolioDemoUserId,
        store: store,
        now: seedTime,
      ),
      isFalse,
    );
  });

  test('regular authenticated users are never seeded', () async {
    final store = MemoryLocalStore();

    final seeded = await seeder.seedIfNeeded(
      userId: 'authenticated-user-123',
      store: store,
      now: seedTime,
    );

    expect(seeded, isFalse);
    expect(await store.getString(LocalUserProfileService.profileKey), isNull);
    expect(await store.getString(LocalPetProfileService.profileKey), isNull);
    expect(await store.getString(LocalJournalRepository.moodLogsKey), isNull);
    expect(
      await store.getString(LocalJournalRepository.mealRecordsKey),
      isNull,
    );
    expect(
      await store.getString(LocalJournalRepository.weightRecordsKey),
      isNull,
    );
  });
}
