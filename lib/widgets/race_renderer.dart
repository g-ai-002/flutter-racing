import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/game_enums.dart';
import '../models/kart_state.dart';
import '../providers/race_provider.dart';
import '../services/log_service.dart';
import 'hud.dart';
import 'race_painter.dart';
import 'static_track_layer.dart';
import 'touch_controls.dart';

/// 比赛画面组合：世界画布 + HUD + 触屏控制。
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
  double _camX = 0;
  double _camY = 0;
  bool _camInit = false;
  StaticTrackLayer? _layer;
  bool _layerRequested = false;

  @override
  void initState() {
    super.initState();
    _ensureLayer();
  }

  Future<void> _ensureLayer() async {
    if (_layerRequested) {
      return;
    }
    _layerRequested = true;
    try {
      final engine = widget.race.engine;
      final layer = await buildStaticTrackLayer(engine.trackDef, engine.track);
      if (!mounted) {
        return;
      }
      setState(() {
        _layer = layer;
      });
    } catch (e) {
      LogService.warning('静态赛道层生成失败: $e');
    }
  }

  void _updateCamera(KartState player) {
    final aheadX = player.x + math.cos(player.angle) * 26;
    final aheadY = player.y + math.sin(player.angle) * 26;
    if (!_camInit) {
      _camX = aheadX;
      _camY = aheadY;
      _camInit = true;
      return;
    }
    _camX += (aheadX - _camX) * 0.14;
    _camY += (aheadY - _camY) * 0.14;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.race,
      builder: (context, _) {
        final race = widget.race;
        final state = race.state;
        final player = state.player;
        final size = MediaQuery.sizeOf(context);
        final zoom = (size.height / 430).clamp(0.8, 2.0).toDouble();
        _updateCamera(player);
        final bestLap = race.storage.bestLapFor(race.engine.trackDef.id);

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: RacePainter(
                  state: state,
                  track: race.engine.track,
                  trackDef: race.engine.trackDef,
                  staticLayer: _layer,
                  camX: _camX,
                  camY: _camY,
                  zoom: zoom,
                ),
              ),
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
