import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static StorageService? _instance;
  SharedPreferences? _prefs;

  StorageService._();

  static Future<StorageService> get instance async {
    if (_instance != null) return _instance!;
    final s = StorageService._();
    s._prefs = await SharedPreferences.getInstance();
    _instance = s;
    return s;
  }

  static StorageService? get instanceSync => _instance;

  SharedPreferences get _p {
    final p = _prefs;
    if (p == null) {
      throw StateError('StorageService 尚未初始化');
    }
    return p;
  }

  static const String _kSoundEnabled = 'sound_enabled';
  static const String _kDarkMode = 'dark_mode';
  static const String _kSelectedCharacter = 'selected_character';
  static const String _kBestLapPrefix = 'best_lap_';
  static const String _kBestTotalPrefix = 'best_total_';

  bool get soundEnabled => _p.getBool(_kSoundEnabled) ?? true;
  Future<void> setSoundEnabled(bool v) => _p.setBool(_kSoundEnabled, v);

  bool get darkMode => _p.getBool(_kDarkMode) ?? false;
  Future<void> setDarkMode(bool v) => _p.setBool(_kDarkMode, v);

  int get selectedCharacter => _p.getInt(_kSelectedCharacter) ?? 0;
  Future<void> setSelectedCharacter(int v) =>
      _p.setInt(_kSelectedCharacter, v);

  /// 赛道最佳圈速（秒），无纪录时为 null
  double? bestLapFor(String trackId) =>
      _p.getDouble('$_kBestLapPrefix$trackId');

  Future<void> setBestLapFor(String trackId, double seconds) =>
      _p.setDouble('$_kBestLapPrefix$trackId', seconds);

  /// 赛道最佳总成绩（秒，计时赛），无纪录时为 null
  double? bestTotalFor(String trackId) =>
      _p.getDouble('$_kBestTotalPrefix$trackId');

  Future<void> setBestTotalFor(String trackId, double seconds) =>
      _p.setDouble('$_kBestTotalPrefix$trackId', seconds);
}
