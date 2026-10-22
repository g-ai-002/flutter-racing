import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_enums.dart';
import '../models/track_def.dart';
import '../providers/race_provider.dart';
import '../services/storage_service.dart';
import '../widgets/race_renderer.dart';
import '../widgets/results_overlay.dart';

/// 桌面端用键盘操控，移动端锁横屏沉浸 + 触屏按钮。
bool get _isMobile =>
    !Platform.isWindows && !Platform.isMacOS && !Platform.isLinux;

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

  // 常量集合元素不能覆写 ==/hashCode（LogicalKeyboardKey 会），故用 final
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

  static bool _isHoldKey(LogicalKeyboardKey key) {
    return _throttleKeys.contains(key) ||
        _brakeKeys.contains(key) ||
        _leftKeys.contains(key) ||
        _rightKeys.contains(key) ||
        _driftKeys.contains(key);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final race = _race;
    final key = event.logicalKey;

    // 按住期间由主循环持续生效，系统按键重复事件直接吞掉
    if (event is KeyRepeatEvent) {
      return _isHoldKey(key) ? KeyEventResult.handled : KeyEventResult.ignored;
    }

    if (event is KeyUpEvent) {
      if (_throttleKeys.contains(key)) {
        race.setThrottle(false);
      } else if (_brakeKeys.contains(key)) {
        race.setBrake(false);
      } else if (_leftKeys.contains(key)) {
        race.setSteerLeft(false);
      } else if (_rightKeys.contains(key)) {
        race.setSteerRight(false);
      } else if (_driftKeys.contains(key)) {
        race.setDrift(false);
      } else {
        return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    }

    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (_throttleKeys.contains(key)) {
      race.setThrottle(true);
    } else if (_brakeKeys.contains(key)) {
      race.setBrake(true);
    } else if (_leftKeys.contains(key)) {
      race.setSteerLeft(true);
    } else if (_rightKeys.contains(key)) {
      race.setSteerRight(true);
    } else if (_driftKeys.contains(key)) {
      race.setDrift(true);
    } else if (_itemKeys.contains(key)) {
      race.useItem();
    } else if (_pauseKeys.contains(key)) {
      _togglePause();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _togglePause() {
    // 主循环异常时：允许直接退出比赛去查看日志
    if (_race.lastError != null) {
      Navigator.pop(context);
      return;
    }
    if (_race.state.phase != RacePhase.running) {
      return;
    }
    if (_race.paused) {
      return;
    }
    _race.pause();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('比赛暂停'),
          content: const Text('休息一下，随时回来继续比赛'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _race.resume();
                _focusNode.requestFocus();
              },
              child: const Text('继续比赛'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _restart();
              },
              child: const Text('重新开始'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('退出比赛'),
            ),
          ],
        );
      },
    );
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
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      // 失焦（切窗口、点系统按钮）时清掉按住的方向，避免失控
      onFocusChange: (hasFocus) {
        if (!hasFocus) {
          _race.clearInputs();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            RaceRenderer(
              race: _race,
              isMobile: _isMobile,
              onPausePressed: _togglePause,
            ),
            AnimatedBuilder(
              animation: _race,
              builder: (context, _) {
                final state = _race.state;
                if (state.phase != RacePhase.finished ||
                    state.results == null) {
                  return const SizedBox.shrink();
                }
                return RaceResultsOverlay(
                  race: _race,
                  onRestart: _restart,
                  onChangeSetup: () => Navigator.pop(context),
                  onExit: () =>
                      Navigator.popUntil(context, (r) => r.isFirst),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
