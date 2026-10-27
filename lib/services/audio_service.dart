import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'log_service.dart';
import 'storage_service.dart';

/// 音频服务：短音效 + BGM 循环；引擎/漂移循环声仅在非 Windows 平台启用。
///
/// Windows 上 audioplayers 原生层对"循环 + 变速（setPlaybackRate）"组合
/// 存在不稳定风险（GO 后黑屏且日志无异常，疑似原生崩溃），因此 Windows
/// 关闭引擎/漂移循环声，保留流程中已长期验证稳定的音效与 BGM。
/// 所有平台通道调用均防御性吞异常并记日志。
class AudioService {
  static AudioService? _instance;

  /// Windows 不启用"循环 + 变速"循环音效（原生层风险规避）；
  /// Web 使用 audioplayers 的浏览器实现，可安全启用循环。
  static final bool _loopSoundSupported =
      kIsWeb || defaultTargetPlatform != TargetPlatform.windows;

  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _bgmPlayer = AudioPlayer();
  AudioPlayer? _enginePlayer;
  AudioPlayer? _driftPlayer;
  bool _initialized = false;
  bool _bgmPlaying = false;
  bool _enginePlaying = false;
  bool _driftPlaying = false;
  double _lastEngineRate = -1;

  AudioService._();

  static Future<AudioService> get instance async {
    _instance ??= AudioService._();
    if (!_instance!._initialized) {
      await _instance!._init();
    }
    return _instance!;
  }

  Future<void> _init() async {
    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(0.32);
      await _sfxPlayer.setVolume(0.8);
      if (_loopSoundSupported) {
        _enginePlayer = AudioPlayer();
        _driftPlayer = AudioPlayer();
        await _enginePlayer!.setReleaseMode(ReleaseMode.loop);
        await _enginePlayer!.setVolume(0.22);
        await _driftPlayer!.setReleaseMode(ReleaseMode.loop);
        await _driftPlayer!.setVolume(0.3);
      }
    } catch (e) {
      LogService.warning('音频初始化异常（测试环境可忽略）: $e');
    }
    _initialized = true;
    LogService.info(
      'AudioService 已初始化（引擎/漂移循环声: '
      '${_loopSoundSupported ? '启用' : 'Windows 平台关闭'}）',
    );
  }

  bool get _soundEnabled {
    try {
      return StorageService.instanceSync?.soundEnabled ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _playSfx(String asset) async {
    if (!_soundEnabled) return;
    try {
      await _sfxPlayer.play(AssetSource('audio/$asset'));
    } catch (e) {
      LogService.warning('播放音效失败: $asset ($e)');
    }
  }

  Future<void> playBeep() => _playSfx('beep.wav');
  Future<void> playGo() => _playSfx('go.wav');
  Future<void> playPickup() => _playSfx('pickup.wav');
  Future<void> playBoost() => _playSfx('boost.wav');
  Future<void> playMissile() => _playSfx('missile.wav');
  Future<void> playExplosion() => _playSfx('explosion.wav');
  Future<void> playSpin() => _playSfx('spin.wav');
  Future<void> playLap() => _playSfx('lap.wav');
  Future<void> playFinish() => _playSfx('finish.wav');
  Future<void> playShield() => _playSfx('shield.wav');
  Future<void> playClick() => _playSfx('click.wav');

  Future<void> startBgm() async {
    if (!_soundEnabled || _bgmPlaying) return;
    try {
      await _bgmPlayer.play(AssetSource('audio/bgm.wav'));
      _bgmPlaying = true;
      LogService.info('BGM 开始播放');
    } catch (e) {
      LogService.warning('播放背景音乐失败: $e');
    }
  }

  Future<void> stopBgm() async {
    try {
      await _bgmPlayer.stop();
    } catch (e) {
      LogService.warning('停止背景音乐失败: $e');
    }
    _bgmPlaying = false;
  }

  Future<void> startEngine() async {
    if (!_loopSoundSupported) {
      return;
    }
    final player = _enginePlayer;
    if (!_soundEnabled || _enginePlaying || player == null) {
      return;
    }
    try {
      _lastEngineRate = -1;
      await player.play(AssetSource('audio/engine.wav'));
      _enginePlaying = true;
      LogService.info('引擎声开始播放');
    } catch (e) {
      LogService.warning('播放引擎声失败: $e');
    }
  }

  /// speed01: 当前速度/极速（0~1），映射到 0.75~1.6 倍播放速率。
  /// Windows 已整体关闭引擎循环声，这里自然为空操作。
  Future<void> updateEngineRate(double speed01) async {
    if (!_loopSoundSupported || !_enginePlaying) {
      return;
    }
    final player = _enginePlayer;
    if (player == null) {
      return;
    }
    final clamped = speed01 < 0 ? 0.0 : (speed01 > 1 ? 1.0 : speed01);
    final rate = 0.75 + clamped * 0.85;
    if ((rate - _lastEngineRate).abs() < 0.06) {
      return;
    }
    _lastEngineRate = rate;
    try {
      await player.setPlaybackRate(rate);
    } catch (e) {
      LogService.warning('调整引擎声速失败: $e');
    }
  }

  Future<void> stopEngine() async {
    final player = _enginePlayer;
    if (player == null) {
      _enginePlaying = false;
      return;
    }
    try {
      await player.stop();
    } catch (e) {
      LogService.warning('停止引擎声失败: $e');
    }
    _enginePlaying = false;
  }

  Future<void> startDrift() async {
    if (!_loopSoundSupported) {
      return;
    }
    final player = _driftPlayer;
    if (!_soundEnabled || _driftPlaying || player == null) {
      return;
    }
    try {
      await player.play(AssetSource('audio/drift.wav'));
      _driftPlaying = true;
    } catch (e) {
      LogService.warning('播放漂移声失败: $e');
    }
  }

  Future<void> stopDrift() async {
    final player = _driftPlayer;
    if (player == null) {
      _driftPlaying = false;
      return;
    }
    try {
      await player.stop();
    } catch (e) {
      LogService.warning('停止漂移声失败: $e');
    }
    _driftPlaying = false;
  }

  static Future<void> stopAllGlobal() async {
    if (_instance != null) {
      await _instance!.stopBgm();
      await _instance!.stopEngine();
      await _instance!.stopDrift();
    }
  }

  Future<void> dispose() async {
    // dispose 返回的是异步 Future，未 await 的 try/catch 抓不住平台异常
    final players = <AudioPlayer?>[
      _sfxPlayer,
      _bgmPlayer,
      _enginePlayer,
      _driftPlayer,
    ];
    for (final player in players) {
      if (player == null) {
        continue;
      }
      try {
        await player.dispose();
      } catch (e) {
        LogService.warning('释放音频播放器失败: $e');
      }
    }
    _enginePlayer = null;
    _driftPlayer = null;
    _instance = null;
    _initialized = false;
  }
}
