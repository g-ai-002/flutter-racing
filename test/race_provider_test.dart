import 'package:flutter_racing/models/game_enums.dart';
import 'package:flutter_racing/models/track_def.dart';
import 'package:flutter_racing/providers/race_provider.dart';
import 'package:flutter_racing/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('advance 将 HUD 通知节流到约 10Hz', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.instance;
    final provider = RaceProvider(
      storage: storage,
      trackDef: TrackCatalog.all.first,
      mode: RaceMode.timeTrial,
      playerCharacterIndex: 0,
      autoThrottle: true,
    );

    var notifications = 0;
    provider.addListener(() => notifications++);

    for (var i = 0; i < 60; i++) {
      provider.advance(1 / 60);
    }

    expect(notifications, greaterThanOrEqualTo(8));
    expect(notifications, lessThanOrEqualTo(12));
    provider.dispose();
  });
}
