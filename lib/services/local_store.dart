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
