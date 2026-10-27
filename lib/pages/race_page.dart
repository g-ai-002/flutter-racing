import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_enums.dart';
import '../models/track_def.dart';
import '../providers/race_provider.dart';
import '../services/storage_service.dart';
import '../utils/platform_info.dart';
import '../widgets/race_renderer.dart';

/// 桌面端用键盘操控，移动端/浏览器锁横屏沉浸 + 触屏按钮。
///
/// 键盘与触屏输入由 [RaceGame] 处理，本页只负责生命周期与导航。
bool get _isMobile => !isDesktopPlatform;

class RacePage extends StatefulWidget {
  final TrackDef track;
  final int characterIndex;
  final RaceMode mode;

  const RacePage({
    super.key,
    required this.track,
    required this.characterIndex,
    required this.mode,
  });

  @override
  State<RacePage> createState() => _RacePageState();
}

class _RacePageState extends State<RacePage> {
  final FocusNode _focusNode = FocusNode();
  late final RaceProvider _race;

  @override
  void initState() {
    super.initState();
    final storage = StorageService.instanceSync;
    if (storage == null) {
      throw StateError('StorageService 未初始化：main() 必须先完成初始化');
    }
    _race = RaceProvider(
      storage: storage,
      trackDef: widget.track,
      mode: widget.mode,
      playerCharacterIndex: widget.characterIndex,
      autoThrottle: _isMobile,
    );
    if (_isMobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _race.start();
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _race.clearInputs();
    _race.dispose();
    if (_isMobile) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _togglePause() {
    // 主循环异常时：允许直接退出比赛去查看日志
    if (_race.lastError != null) {
      Navigator.pop(context);
      return;
    }
    if (_race.state.phase == RacePhase.finished) {
      return;
    }
    if (_race.paused) {
      _resume();
      return;
    }
    if (_race.state.phase != RacePhase.running) {
      return;
    }
    _race.pause();
  }

  void _resume() {
    _race.resume();
    _focusNode.requestFocus();
  }

  void _restart() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RacePage(
          track: widget.track,
          characterIndex: widget.characterIndex,
          mode: widget.mode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: RaceRenderer(
        race: _race,
        isMobile: _isMobile,
        focusNode: _focusNode,
        onPausePressed: _togglePause,
        onResumeRequested: _resume,
        onRestart: _restart,
        onChangeSetup: () => Navigator.pop(context),
        onExit: () => Navigator.popUntil(context, (r) => r.isFirst),
      ),
    );
  }
}
