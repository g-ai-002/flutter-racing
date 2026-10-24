import 'package:flutter/foundation.dart';

import '../engine/kart_physics.dart';
import '../engine/race_engine.dart';
import '../models/game_enums.dart';
import '../models/kart_state.dart';
import '../models/race_state.dart';
import '../models/track_def.dart';
import '../services/audio_service.dart';
import '../services/log_service.dart';
import '../services/storage_service.dart';

/// 比赛进行器：驱动引擎主循环、输入状态机、事件到音频/纪录的翻译。
class RaceProvider extends ChangeNotifier {
  final StorageService storage;
  final RaceEngine engine;
  final bool autoThrottle;

  AudioService? _audio;
  bool paused = false;

  /// 主循环异常信息（非空时页面展示反馈横幅，且禁止继续比赛）
  String? lastError;

  double _finalLapBannerUntil = -10;
  int _tickCount = 0;
  bool _driftSoundOn = false;
  RacePhase _lastPhase = RacePhase.countdown;

  // ---- 输入状态机 ----
  bool _steerLeft = false;
  bool _steerRight = false;
  bool _throttle = false;
  bool _brake = false;
  bool _drift = false;

  RaceState get state => engine.state;

  RaceProvider({
    required this.storage,
    required TrackDef trackDef,
    required RaceMode mode,
    required int playerCharacterIndex,
    required this.autoThrottle,
    int seed = 7,
  }) : engine = RaceEngine(
          trackDef: trackDef,
          mode: mode,
          playerCharacterIndex: playerCharacterIndex,
          seed: seed,
        );

  /// "最后一圈"横幅是否可见
  bool get finalLapBannerVisible =>
      state.raceTime >= 0 && state.raceTime < _finalLapBannerUntil;

  Future<void> start() async {
    LogService.info(
      '开始比赛: ${engine.trackDef.name} (${state.mode.label})',
    );
    _audio = await AudioService.instance;
    notifyListeners();
  }

  // ---- 输入 ----
  void setSteerLeft(bool v) => _steerLeft = v;
  void setSteerRight(bool v) => _steerRight = v;
  void setThrottle(bool v) => _throttle = v;
  void setBrake(bool v) => _brake = v;
  void setDrift(bool v) => _drift = v;

  void clearInputs() {
    _steerLeft = false;
    _steerRight = false;
    _throttle = false;
    _brake = false;
    _drift = false;
  }

  void useItem() {
    if (paused || state.phase != RacePhase.running) {
      return;
    }
    engine.usePlayerItem();
  }

  // ---- 流程 ----
  void pause() {
    if (paused || state.phase == RacePhase.finished) {
      return;
    }
    paused = true;
    clearInputs();
    _audio?.stopEngine();
    _audio?.stopDrift();
    _driftSoundOn = false;
    LogService.info('比赛暂停');
    notifyListeners();
  }

  void resume() {
    if (!paused || lastError != null) {
      return;
    }
    paused = false;
    clearInputs();
    _audio?.startEngine();
    notifyListeners();
  }

  // ---- 主循环 ----
  KartInput _buildInput() {
    final steer = (_steerRight ? 1.0 : 0.0) - (_steerLeft ? 1.0 : 0.0);
    return KartInput(
      steer: steer,
      throttle: autoThrottle || _throttle,
      brake: _brake,
      drift: _drift,
    );
  }

  /// 由 Flame 的游戏循环每帧调用，替代原来的 16ms Timer。
  void advance(double dt) {
    if (paused || state.phase == RacePhase.finished) {
      return;
    }
    try {
      engine.update(dt, _buildInput());
      _handleEvents();
      _updateAudioTick();
      _tickCount++;
      _logProgress();
      notifyListeners();
    } catch (e, stack) {
      _handleCrash(e, stack);
    }
  }

  /// 主循环异常：记录完整堆栈、暂停比赛并在画面顶部提示反馈日志
  void _handleCrash(Object error, StackTrace stack) {
    lastError = '$error';
    paused = true;
    LogService.error('比赛主循环异常，已暂停并保留错误信息', error, stack);
    _audio?.stopEngine();
    _audio?.stopDrift();
    _driftSoundOn = false;
    notifyListeners();
  }

  void _logProgress() {
    final phase = state.phase;
    if (phase != _lastPhase) {
      _lastPhase = phase;
      LogService.info('比赛阶段变更: $phase');
    }
    // 每约 5 秒记录一次比赛遥测，便于定位卡死/黑屏发生的时间点
    if (phase == RacePhase.running && _tickCount % 300 == 0) {
      final p = state.player;
      LogService.info(
        '比赛进行中: t=${state.raceTime.toStringAsFixed(1)}s '
        '速度=${p.speed.round()} 圈=${p.lapDisplay} 位置=${p.position}',
      );
    }
  }

  void _handleEvents() {
    final playerIndex = state.player.kartIndex;
    for (final record in state.events) {
      final fromPlayer = record.kartIndex == playerIndex;
      switch (record.event) {
        case EngineEvent.countdownTick:
          _audio?.playBeep();
        case EngineEvent.go:
          LogService.info('GO! 比赛开始');
          _audio?.playGo();
          _audio?.startBgm();
          _audio?.startEngine();
        case EngineEvent.itemPickup:
          if (fromPlayer) {
            _audio?.playPickup();
          }
        case EngineEvent.boostStart:
          if (fromPlayer) {
            _audio?.playBoost();
          }
        case EngineEvent.missileLaunch:
          _audio?.playMissile();
        case EngineEvent.waterDrop:
        case EngineEvent.bananaDrop:
          if (fromPlayer) {
            _audio?.playClick();
          }
        case EngineEvent.spinOut:
          _audio?.playSpin();
        case EngineEvent.shieldBlock:
          _audio?.playShield();
        case EngineEvent.explosion:
          _audio?.playExplosion();
        case EngineEvent.lapComplete:
          _audio?.playLap();
          _saveBestLap();
        case EngineEvent.finalLap:
          _audio?.playLap();
          _saveBestLap();
          _finalLapBannerUntil = state.raceTime + 1.6;
        case EngineEvent.finish:
          _audio?.playFinish();
          _audio?.stopBgm();
          _audio?.stopEngine();
          _audio?.stopDrift();
          _driftSoundOn = false;
          _saveBestLap();
          _saveBestTotal();
          LogService.info('比赛结束: 玩家名次 ${state.player.position}');
        case EngineEvent.wrongWayStart:
        case EngineEvent.wrongWayEnd:
          break;
      }
    }
  }

  void _updateAudioTick() {
    final player = state.player;
    final wantDrift = player.drifting && state.phase == RacePhase.running;
    if (wantDrift != _driftSoundOn) {
      _driftSoundOn = wantDrift;
      if (wantDrift) {
        _audio?.startDrift();
      } else {
        _audio?.stopDrift();
      }
    }
    if (_tickCount % 8 == 0) {
      _audio?.updateEngineRate(player.speed / KartPhysics.baseMaxSpeed);
    }
  }

  void _saveBestLap() {
    final player = state.player;
    if (player.lapTimes.isEmpty) {
      return;
    }
    final lap = player.lapTimes.last;
    final trackId = engine.trackDef.id;
    final best = storage.bestLapFor(trackId);
    if (best == null || lap < best) {
      storage.setBestLapFor(trackId, lap);
      LogService.info(
        '刷新最佳圈速: ${engine.trackDef.name} ${lap.toStringAsFixed(2)}s',
      );
    }
  }

  void _saveBestTotal() {
    if (state.mode != RaceMode.timeTrial) {
      return;
    }
    final player = state.player;
    final trackId = engine.trackDef.id;
    final best = storage.bestTotalFor(trackId);
    if (best == null || player.finishTime < best) {
      storage.setBestTotalFor(trackId, player.finishTime);
    }
  }

  @override
  void dispose() {
    final audio = _audio;
    if (audio != null) {
      audio.stopBgm();
      audio.stopEngine();
      audio.stopDrift();
      audio.dispose();
    }
    super.dispose();
  }
}
