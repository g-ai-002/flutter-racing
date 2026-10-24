import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import '../models/game_enums.dart';
import '../models/track_def.dart';
import '../providers/race_provider.dart';
import '../services/log_service.dart';
import '../widgets/static_track_layer.dart';
import 'components/race_world_layer_component.dart';
import 'components/touch_controls_component.dart';
import 'components/track_layer_component.dart';
import 'race_world.dart';

/// 基于 Flame 的比赛画面。
///
/// 渲染、主循环、键盘/触屏输入与比赛内浮层都由 Flame 承担；HUD 的
/// 文本与面板仍由 Flutter 绘制，通过 overlay 与本组件协同。
class RaceGame extends FlameGame<RaceWorld> with KeyboardEvents {
  RaceGame({
    required this.provider,
    required this.trackDef,
    required this.isMobile,
    required this.onPauseRequested,
    required this.onRestart,
    required this.onChangeSetup,
    required this.onExit,
  }) : super(world: RaceWorld(), camera: CameraComponent());

  static const String pauseOverlayId = 'racePause';
  static const String resultsOverlayId = 'raceResults';
  static const String countdownOverlayId = 'raceCountdown';
  static const String wrongWayOverlayId = 'raceWrongWay';
  static const String finalLapOverlayId = 'raceFinalLap';

  static final Set<LogicalKeyboardKey> _throttleKeys = {
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.keyW,
  };
  static final Set<LogicalKeyboardKey> _brakeKeys = {
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.keyS,
  };
  static final Set<LogicalKeyboardKey> _leftKeys = {
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.keyA,
  };
  static final Set<LogicalKeyboardKey> _rightKeys = {
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.keyD,
  };
  static final Set<LogicalKeyboardKey> _driftKeys = {
    LogicalKeyboardKey.space,
  };
  static final Set<LogicalKeyboardKey> _itemKeys = {
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.keyE,
  };
  static final Set<LogicalKeyboardKey> _pauseKeys = {
    LogicalKeyboardKey.keyP,
    LogicalKeyboardKey.escape,
  };

  final RaceProvider provider;
  final TrackDef trackDef;
  final bool isMobile;
  final VoidCallback onPauseRequested;
  final VoidCallback onRestart;
  final VoidCallback onChangeSetup;
  final VoidCallback onExit;

  StaticTrackLayer? _staticLayer;
  final Set<String> _activeOverlays = {};

  bool _initialized = false;
  bool _cameraReady = false;
  double _camX = 0;
  double _camY = 0;
  double _zoom = 1;

  @override
  Color backgroundColor() => const Color(0xFF11151A);

  @override
  Future<void> onLoad() async {
    try {
      _staticLayer = buildStaticTrackLayer(trackDef, provider.engine.track);
      LogService.info(
        '静态赛道层已构建（矢量回放）: ${trackDef.name}, '
        '采样点=${provider.engine.track.pointCount}',
      );
    } catch (e, stack) {
      LogService.error('静态赛道层构建失败', e, stack);
    }

    await world.addAll([
      TrackLayerComponent(
        layer: _staticLayer,
        groundColor: groundColorFor(trackDef.theme),
        priority: 0,
      ),
      RaceWorldLayerComponent(
        provider: provider,
        track: provider.engine.track,
        trackDef: trackDef,
        priority: 1,
      ),
    ]);
    await camera.viewport.add(
      SpeedLinesComponent(provider: provider, priority: 10),
    );
    if (isMobile) {
      await camera.viewport.add(
        TouchControlsComponent(provider: provider, priority: 20),
      );
    }
    camera.viewfinder.anchor = const Anchor(0.5, 0.58);
    _initialized = true;
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final key = event.logicalKey;

    if (event is KeyRepeatEvent) {
      return _isHoldKey(key) ? KeyEventResult.handled : KeyEventResult.ignored;
    }

    if (event is KeyUpEvent) {
      if (_throttleKeys.contains(key)) {
        provider.setThrottle(false);
      } else if (_brakeKeys.contains(key)) {
        provider.setBrake(false);
      } else if (_leftKeys.contains(key)) {
        provider.setSteerLeft(false);
      } else if (_rightKeys.contains(key)) {
        provider.setSteerRight(false);
      } else if (_driftKeys.contains(key)) {
        provider.setDrift(false);
      } else {
        return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    }

    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (_throttleKeys.contains(key)) {
      provider.setThrottle(true);
    } else if (_brakeKeys.contains(key)) {
      provider.setBrake(true);
    } else if (_leftKeys.contains(key)) {
      provider.setSteerLeft(true);
    } else if (_rightKeys.contains(key)) {
      provider.setSteerRight(true);
    } else if (_driftKeys.contains(key)) {
      provider.setDrift(true);
    } else if (_itemKeys.contains(key)) {
      provider.useItem();
    } else if (_pauseKeys.contains(key)) {
      onPauseRequested();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  static bool _isHoldKey(LogicalKeyboardKey key) {
    return _throttleKeys.contains(key) ||
        _brakeKeys.contains(key) ||
        _leftKeys.contains(key) ||
        _rightKeys.contains(key) ||
        _driftKeys.contains(key);
  }

  @override
  void update(double dt) {
    provider.advance(dt);
    _updateCamera(dt);
    _syncOverlays();
    super.update(dt);
  }

  void _syncOverlays() {
    final state = provider.state;
    final countdownVisible = state.phase == RacePhase.countdown ||
        (state.phase == RacePhase.running && state.raceTime < 0.75);
    _sync(pauseOverlayId, provider.paused, 100);
    _sync(
      resultsOverlayId,
      state.phase == RacePhase.finished && state.results != null,
      90,
    );
    _sync(countdownOverlayId, countdownVisible, 80);
    _sync(wrongWayOverlayId, state.player.wrongWay, 70);
    _sync(finalLapOverlayId, provider.finalLapBannerVisible, 70);
  }

  void _sync(String id, bool visible, int priority) {
    if (visible && !_activeOverlays.contains(id)) {
      overlays.add(id, priority: priority);
      _activeOverlays.add(id);
    } else if (!visible && _activeOverlays.contains(id)) {
      overlays.remove(id);
      _activeOverlays.remove(id);
    }
  }

  void _updateCamera(double dt) {
    if (!_initialized || size.y <= 0) {
      return;
    }
    final player = provider.state.player;
    if (!player.x.isFinite || !player.y.isFinite || !player.angle.isFinite) {
      return;
    }

    _zoom = (size.y / 430).clamp(0.8, 2.0).toDouble();
    final aheadX = player.x + math.cos(player.angle) * 26;
    final aheadY = player.y + math.sin(player.angle) * 26;
    if (!_cameraReady) {
      _camX = aheadX;
      _camY = aheadY;
      _cameraReady = true;
    } else {
      final follow = 1 - math.pow(1 - 0.14, dt * 60).toDouble();
      _camX += (aheadX - _camX) * follow;
      _camY += (aheadY - _camY) * follow;
    }

    camera.viewfinder.position = Vector2(_camX, _camY);
    // viewfinder.angle 与画布旋转方向相反，故用 + 抵消车头角度，
    // 车头才会始终朝屏幕上方（等价于旧 RacePainter 的 canvas.rotate(-angle - π/2)）。
    camera.viewfinder.angle = player.angle + math.pi / 2;
    camera.viewfinder.zoom = _zoom;
  }
}
