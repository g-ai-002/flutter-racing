import 'package:flutter/foundation.dart';

import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService _storage;

  SettingsProvider(this._storage);

  bool get soundEnabled => _storage.soundEnabled;
  bool get darkMode => _storage.darkMode;
  int get selectedCharacter => _storage.selectedCharacter;

  Future<void> setSoundEnabled(bool v) async {
    await _storage.setSoundEnabled(v);
    notifyListeners();
  }

  Future<void> setDarkMode(bool v) async {
    await _storage.setDarkMode(v);
    notifyListeners();
  }

  Future<void> setSelectedCharacter(int v) async {
    await _storage.setSelectedCharacter(v);
    notifyListeners();
  }
}
