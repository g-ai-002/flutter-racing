import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_racing/services/audio_service.dart';

/// CI 单测环境无音频插件：所有平台通道调用应被防御性吞掉（记日志不外抛）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('初始化与全部播放接口不抛', () async {
    final audio = await AudioService.instance;
    await audio.playBeep();
    await audio.playGo();
    await audio.playPickup();
    await audio.playBoost();
    await audio.playMissile();
    await audio.playExplosion();
    await audio.playSpin();
    await audio.playLap();
    await audio.playFinish();
    await audio.playShield();
    await audio.playClick();
    await audio.startBgm();
    await audio.stopBgm();
    await audio.startEngine();
    await audio.updateEngineRate(0.5);
    await audio.updateEngineRate(1.5);
    await audio.stopEngine();
    await audio.startDrift();
    await audio.stopDrift();
    audio.dispose();
  });

  test('dispose 后可重新实例化', () async {
    final a1 = await AudioService.instance;
    a1.dispose();
    final a2 = await AudioService.instance;
    expect(identical(a1, a2), isFalse);
    a2.dispose();
  });
}
