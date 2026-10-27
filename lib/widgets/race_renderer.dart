import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/overlays/race_pause_overlay.dart';
import '../game/race_game.dart';
import '../models/game_enums.dart';
import '../providers/race_provider.dart';
import '../services/log_service.dart';
import 'hud.dart';
import 'results_overlay.dart';

/// 比赛画面组合：Flame 世界画布（含输入与浮层）+ Flutter HUD。
class RaceRenderer extends StatefulWidget {
  final RaceProvider race;
  final bool isMobile;
  final FocusNode focusNode;
  final VoidCallback? onPausePressed;
  final VoidCallback onRestart;
  final VoidCallback onChangeSetup;
  final VoidCallback onExit;
  final VoidCallback onResumeRequested;

  const RaceRenderer({
    super.key,
    required this.race,
    required this.isMobile,
    required this.focusNode,
    required this.onRestart,
    required this.onChangeSetup,
    required this.onExit,
    required this.onResumeRequested,
    this.onPausePressed,
  });

  @override
  State<RaceRenderer> createState() => _RaceRendererState();
}

class _RaceRendererState extends State<RaceRenderer> {
  RaceGame? _game;
  bool _layoutLogged = false;

  @override
  void initState() {
    super.initState();
    _game = RaceGame(
      provider: widget.race,
      trackDef: widget.race.engine.trackDef,
      isMobile: widget.isMobile,
      onPauseRequested: widget.onPausePressed ?? () {},
      onRestart: widget.onRestart,
      onChangeSetup: widget.onChangeSetup,
      onExit: widget.onExit,
    );
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
    if (game == null) {
      return const SizedBox.expand();
    }
    _logLayoutOnce(MediaQuery.sizeOf(context));

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GameWidget<RaceGame>(
            game: game,
            focusNode: widget.focusNode,
            overlayBuilderMap: {
              RaceGame.pauseOverlayId: (context, _) => RacePauseOverlay(
                    race: widget.race,
                    onResume: widget.onResumeRequested,
                    onRestart: widget.onRestart,
                    onExit: widget.onExit,
                  ),
              RaceGame.resultsOverlayId: (context, _) => RaceResultsOverlay(
                    race: widget.race,
                    onRestart: widget.onRestart,
                    onChangeSetup: widget.onChangeSetup,
                    onExit: widget.onExit,
                  ),
              RaceGame.countdownOverlayId: (context, _) => AnimatedBuilder(
                    animation: widget.race,
                    builder: (context, _) =>
                        CountdownOverlay(state: widget.race.state),
                  ),
              RaceGame.wrongWayOverlayId: (context, _) =>
                  const WrongWayBanner(),
              RaceGame.finalLapOverlayId: (context, _) => const FinalLapBanner(),
            },
          ),
        ),
        Positioned.fill(child: _buildHud()),
      ],
    );
  }

  Widget _buildHud() {
    return AnimatedBuilder(
      animation: widget.race,
      builder: (context, _) {
        final race = widget.race;
        final state = race.state;
        if (state.phase == RacePhase.finished || race.paused) {
          return const SizedBox.shrink();
        }
        final player = state.player;
        final bestLap = race.storage.bestLapFor(race.engine.trackDef.id);

        return Stack(
          fit: StackFit.expand,
          children: [
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
                        IgnorePointer(child: StandingsPanel(state: state)),
                      Expanded(
                        child: IgnorePointer(
                          child: Center(
                            child: LapPanel(state: state, bestLap: bestLap),
                          ),
                        ),
                      ),
                      _pauseButton(),
                      const SizedBox(width: 10),
                      IgnorePointer(
                        child: SizedBox(
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: IgnorePointer(
                child: SpeedometerPanel(
                  speed: player.speed,
                  boost: player.boostTimer > 0,
                ),
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
            if (!widget.isMobile) ...[
              Positioned(
                right: 16,
                bottom: 16,
                child: IgnorePointer(child: ItemSlotPanel(item: player.item)),
              ),
              if (state.phase == RacePhase.countdown)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: Center(child: DesktopKeysHint()),
                ),
            ],
            // 触屏端在倒计时期间给一条手势提示，避开底部按钮区域
            if (widget.isMobile && state.phase == RacePhase.countdown)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 132,
                child: Center(child: TouchKeysHint()),
              ),
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
