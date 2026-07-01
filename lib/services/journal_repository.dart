import 'dart:convert';

import '../mock/app_mock.dart';
import '../models/app_models.dart';
import 'local_store.dart';

abstract interface class JournalRepository {
  Future<List<PetMoodLog>> loadMoodLogs();

  Future<void> saveMoodLogs(List<PetMoodLog> logs);

  Future<List<MealRecord>> loadMealRecords();

  Future<void> saveMealRecords(List<MealRecord> records);

  Future<List<WeightRecord>> loadWeightRecords();

  Future<void> saveWeightRecords(List<WeightRecord> records);

  Future<bool> hasSeenDietGuide();

  Future<void> setHasSeenDietGuide(bool value);
}

class LocalJournalRepository implements JournalRepository {
  LocalJournalRepository(this._store);

  static const moodLogsKey = 'easylife.v1.mood_logs';
  static const mealRecordsKey = 'easylife.v1.meal_records';
  static const weightRecordsKey = 'easylife.v1.weight_records';
  static const dietGuideKey = 'easylife.v1.has_seen_diet_guide';

  final LocalStore _store;

  @override
  Future<List<PetMoodLog>> loadMoodLogs() => _loadList(
        key: moodLogsKey,
        fallback: AppMock.moodJournal,
        fromJson: PetMoodLog.fromJson,
      );

  @override
  Future<void> saveMoodLogs(List<PetMoodLog> logs) =>
      _saveList(moodLogsKey, logs.map((entry) => entry.toJson()).toList());

  @override
  Future<List<MealRecord>> loadMealRecords() => _loadList(
        key: mealRecordsKey,
        fallback: AppMock.foodLogs,
        fromJson: MealRecord.fromJson,
      );

  @override
  Future<void> saveMealRecords(List<MealRecord> records) => _saveList(
        mealRecordsKey,
        records.map((entry) => entry.toJson()).toList(),
      );

  @override
  Future<List<WeightRecord>> loadWeightRecords() => _loadList(
        key: weightRecordsKey,
        fallback: AppMock.weights,
        fromJson: WeightRecord.fromJson,
      );

  @override
  Future<void> saveWeightRecords(List<WeightRecord> records) => _saveList(
        weightRecordsKey,
        records.map((entry) => entry.toJson()).toList(),
      );

  @override
  Future<bool> hasSeenDietGuide() async =>
      await _store.getString(dietGuideKey) == 'true';

  @override
  Future<void> setHasSeenDietGuide(bool value) =>
      _store.setString(dietGuideKey, value.toString());

  Future<List<T>> _loadList<T>({
    required String key,
    required List<T> fallback,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final raw = await _store.getString(key);
    if (raw == null) return List<T>.from(fallback);
    try {
      final values = jsonDecode(raw) as List<dynamic>;
      return values
          .map((value) => fromJson(value as Map<String, dynamic>))
          .toList();
    } on FormatException {
      return List<T>.from(fallback);
    } on TypeError {
      return List<T>.from(fallback);
    }
  }

  Future<void> _saveList(String key, List<Map<String, dynamic>> values) =>
      _store.setString(key, jsonEncode(values));
}
