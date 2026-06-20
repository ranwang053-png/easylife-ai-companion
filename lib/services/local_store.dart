import 'package:shared_preferences/shared_preferences.dart';

abstract interface class LocalStore {
  Future<String?> getString(String key);

  Future<void> setString(String key, String value);

  Future<void> remove(String key);
}

class SharedPreferencesLocalStore implements LocalStore {
  SharedPreferencesLocalStore({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> getString(String key) => _preferences.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> remove(String key) => _preferences.remove(key);
}

class MemoryLocalStore implements LocalStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> getString(String key) async => _values[key];

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}

class PrefixedLocalStore implements LocalStore {
  PrefixedLocalStore(this._store, this.prefix);

  final LocalStore _store;
  final String prefix;

  String _key(String key) => '$prefix.$key';

  @override
  Future<String?> getString(String key) => _store.getString(_key(key));

  @override
  Future<void> remove(String key) => _store.remove(_key(key));

  @override
  Future<void> setString(String key, String value) =>
      _store.setString(_key(key), value);
}

Future<void> migrateLegacyStoreToUserScope({
  required LocalStore rootStore,
  required String userPrefix,
  required Iterable<String> keys,
}) async {
  const markerKey = 'easylife.migration.user_scope.v1';
  if (await rootStore.getString(markerKey) != null) return;

  final userStore = PrefixedLocalStore(rootStore, userPrefix);
  for (final key in keys) {
    final legacyValue = await rootStore.getString(key);
    if (legacyValue == null) continue;
    if (await userStore.getString(key) == null) {
      await userStore.setString(key, legacyValue);
    }
    await rootStore.remove(key);
  }
  await rootStore.setString(markerKey, userPrefix);
}
