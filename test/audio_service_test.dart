import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_racing/services/audio_service.dart';

/// CI 单测环境无音频插件：用 mock 通道替代原生实现，验证服务全部接口可用且不抛。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channels = [
    'xyz.luan/audioplayers',
    'xyz.luan/audioplayers.global',
    'xyz.luan/audioplayers/events',
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    for (final name in channels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (call) async => null);
    }
  });

  tearDown(() {
    for (final name in channels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), null);
    }
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
    await audio.dispose();
  });

  test('dispose 后可重新实例化', () async {
    final a1 = await AudioService.instance;
    await a1.dispose();
    final a2 = await AudioService.instance;
    expect(identical(a1, a2), isFalse);
    await a2.dispose();
  });
}
