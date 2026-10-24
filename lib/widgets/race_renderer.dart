import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/race_game.dart';
import '../models/game_enums.dart';
import '../providers/race_provider.dart';
import '../services/log_service.dart';
import 'hud.dart';
import 'static_track_layer.dart';
import 'touch_controls.dart';

/// 比赛画面组合：Flame 世界画布 + HUD + 触屏控制。
class RaceRenderer extends StatefulWidget {
  final RaceProvider race;
  final bool isMobile;
  final VoidCallback? onPausePressed;

  const RaceRenderer({
    super.key,
    required this.race,
    required this.isMobile,
    this.onPausePressed,
  });

  @override
  State<RaceRenderer> createState() => _RaceRendererState();
}

class _RaceRendererState extends State<RaceRenderer> {
  RaceGame? _game;
  StaticTrackLayer? _layer;
  bool _layoutLogged = false;

  @override
  void initState() {
    super.initState();
    _buildLayer();
    _game = RaceGame(
      provider: widget.race,
      trackDef: widget.race.engine.trackDef,
      staticLayer: _layer,
    );
  }

  /// 同步构建矢量赛道层；失败时记录日志并走纯色地面兜底
  void _buildLayer() {
    try {
      final engine = widget.race.engine;
      _layer = buildStaticTrackLayer(engine.trackDef, engine.track);
      LogService.info(
        '静态赛道层已构建（矢量回放）: ${engine.trackDef.name}, '
        '采样点=${engine.track.pointCount}',
      );
    } catch (e, stack) {
      LogService.error('静态赛道层构建失败', e, stack);
    }
  }

  @override
  void dispose() {
    _layer?.picture.dispose();
    super.dispose();
  }

  void _logLayoutOnce(Size size) {
    if (_layoutLogged) {
      return;
    }
    _layoutLogged = true;
    final player = widget.race.state.player;
    final zoom = (size.height / 430).clamp(0.8, 2.0).toDouble();
    LogService.info(
      '比赛画面布局: ${size.width.toStringAsFixed(0)}x'
      '${size.height.toStringAsFixed(0)}, zoom=${zoom.toStringAsFixed(2)}, '
      '玩家=(${player.x.toStringAsFixed(1)}, ${player.y.toStringAsFixed(1)}) '
      '朝向=${player.angle.toStringAsFixed(2)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return AnimatedBuilder(
      animation: widget.race,
      builder: (context, _) {
        final race = widget.race;
        final state = race.state;
        final player = state.player;
        final size = MediaQuery.sizeOf(context);
        _logLayoutOnce(size);
        final bestLap = race.storage.bestLapFor(race.engine.trackDef.id);

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: game == null
                  ? const SizedBox.expand()
                  : GameWidget<RaceGame>(game: game),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (state.mode != RaceMode.timeTrial)
                        StandingsPanel(state: state),
                      Expanded(
                        child: Center(
                          child: LapPanel(state: state, bestLap: bestLap),
                        ),
                      ),
                      _pauseButton(),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.35),
                            child: CustomPaint(
                              painter: MiniMapPainter(
                                track: race.engine.track,
                                state: state,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: SpeedometerPanel(
                speed: player.speed,
                boost: player.boostTimer > 0,
              ),
            ),
            if (race.lastError != null)
              Positioned(
                left: 24,
                right: 24,
                top: 150,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '检测到运行时错误，比赛已暂停。'
                            '请到「设置 → 查看日志」复制日志反馈。',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (widget.isMobile)
              TouchControls(race: race)
            else ...[
              Positioned(
                right: 16,
                bottom: 16,
                child: ItemSlotPanel(item: player.item),
              ),
              if (state.phase == RacePhase.countdown)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: Center(child: DesktopKeysHint()),
                ),
            ],
            CountdownOverlay(state: state),
            if (player.wrongWay) const WrongWayBanner(),
            if (race.finalLapBannerVisible) const FinalLapBanner(),
          ],
        );
      },
    );
  }

  Widget _pauseButton() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: IconButton(
        icon: const Icon(Icons.pause, color: Colors.white, size: 22),
        onPressed: widget.onPausePressed,
      ),
    );
  }
}
