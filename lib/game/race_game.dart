import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../models/track_def.dart';
import '../providers/race_provider.dart';
import '../widgets/static_track_layer.dart';
import 'components/race_world_layer_component.dart';
import 'components/track_layer_component.dart';
import 'race_world.dart';

/// 基于 Flame 的比赛画面。
///
/// 主循环由 [FlameGame.update] 驱动（替代原来的 16ms Timer），镜头跟随玩家
/// 车头旋转，静态赛道层直接把预录制的矢量 Picture 回放到世界坐标。
class RaceGame extends FlameGame<RaceWorld> {
  RaceGame({
    required this.provider,
    required this.trackDef,
    required this.staticLayer,
  }) : super(world: RaceWorld(), camera: CameraComponent());

  final RaceProvider provider;
  final TrackDef trackDef;
  final StaticTrackLayer? staticLayer;

  late final RaceWorldLayerComponent _worldLayer;
  bool _initialized = false;
  bool _cameraReady = false;

  double _camX = 0;
  double _camY = 0;
  double _zoom = 1;

  @override
  Color backgroundColor() => const Color(0xFF11151A);

  @override
  Future<void> onLoad() async {
    _worldLayer = RaceWorldLayerComponent(
      provider: provider,
      track: provider.engine.track,
      trackDef: trackDef,
      priority: 1,
    );
    await world.addAll([
      TrackLayerComponent(
        layer: staticLayer,
        groundColor: groundColorFor(trackDef.theme),
        priority: 0,
      ),
      _worldLayer,
    ]);
    await camera.viewport.add(
      SpeedLinesComponent(provider: provider, priority: 10),
    );
    camera.viewfinder.anchor = const Anchor(0.5, 0.58);
    _initialized = true;
  }

  @override
  void update(double dt) {
    provider.advance(dt);
    _updateCamera(dt);
    super.update(dt);
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
    camera.viewfinder.angle = -player.angle - math.pi / 2;
    camera.viewfinder.zoom = _zoom;
  }
}
