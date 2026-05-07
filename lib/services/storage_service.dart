import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

class StorageService {
  static StorageService? _instance;
  late SharedPreferences _prefs;
  static const _keyReaderChapterCacheCount = 'reader_chapter_cache_count';

  StorageService._();

  static Future<StorageService> get instance async {
    if (_instance != null) return _instance!;
    _instance = StorageService._();
    _instance!._prefs = await SharedPreferences.getInstance();
    return _instance!;
  }

  // Token
  String? get token => _prefs.getString(AppConstants.keyToken);
  Future<void> setToken(String token) =>
      _prefs.setString(AppConstants.keyToken, token);
  Future<void> removeToken() => _prefs.remove(AppConstants.keyToken);

  // BaseUrl
  String? get baseUrl => _prefs.getString(AppConstants.keyBaseUrl);
  Future<void> setBaseUrl(String url) =>
      _prefs.setString(AppConstants.keyBaseUrl, url);

  // ThemeMode
  int? get themeMode => _prefs.getInt(AppConstants.keyThemeMode);
  Future<void> setThemeMode(int mode) =>
      _prefs.setInt(AppConstants.keyThemeMode, mode);

  int get readerChapterCacheCount =>
      _prefs.getInt(_keyReaderChapterCacheCount) ?? 5;
  Future<void> setReaderChapterCacheCount(int count) =>
      _prefs.setInt(_keyReaderChapterCacheCount, count);

  String? readString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  bool get isLoggedIn => token != null && token!.isNotEmpty;

  Future<void> clear() => _prefs.clear();
}
