import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_racing/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('StorageService 单例', () async {
    final s1 = await StorageService.instance;
    final s2 = await StorageService.instance;
    expect(identical(s1, s2), isTrue);
    expect(StorageService.instanceSync, isNotNull);
  });

  test('默认值', () async {
    final storage = await StorageService.instance;
    expect(storage.soundEnabled, isTrue);
    expect(storage.darkMode, isFalse);
    expect(storage.selectedCharacter, 0);
    expect(storage.bestLapFor('seaside'), isNull);
    expect(storage.bestTotalFor('seaside'), isNull);
  });

  test('设置读写', () async {
    final storage = await StorageService.instance;
    await storage.setSoundEnabled(false);
    await storage.setDarkMode(true);
    await storage.setSelectedCharacter(2);
    expect(storage.soundEnabled, isFalse);
    expect(storage.darkMode, isTrue);
    expect(storage.selectedCharacter, 2);
  });

  test('最佳圈速按赛道独立记录', () async {
    final storage = await StorageService.instance;
    await storage.setBestLapFor('seaside', 18.5);
    await storage.setBestLapFor('desert', 33.2);
    expect(storage.bestLapFor('seaside'), 18.5);
    expect(storage.bestLapFor('desert'), 33.2);
    expect(storage.bestLapFor('alpine'), isNull);
    await storage.setBestTotalFor('alpine', 75.0);
    expect(storage.bestTotalFor('alpine'), 75.0);
  });
}
