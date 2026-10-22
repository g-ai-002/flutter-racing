import 'package:flutter/material.dart';

import '../providers/race_provider.dart';
import 'item_icon.dart';

/// 移动端触屏控制：左下转向，右下 道具/刹车/漂移。
/// 油门默认自动（RaceProvider.autoThrottle）。
class TouchControls extends StatelessWidget {
  final RaceProvider race;

  const TouchControls({super.key, required this.race});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 16,
          bottom: 18,
          child: Row(
            children: [
              HoldButton(
                key: const Key('btn_left'),
                icon: Icons.keyboard_arrow_left,
                size: 84,
                onPressStart: () => race.setSteerLeft(true),
                onPressEnd: () => race.setSteerLeft(false),
              ),
              const SizedBox(width: 14),
              HoldButton(
                key: const Key('btn_right'),
                icon: Icons.keyboard_arrow_right,
                size: 84,
                onPressStart: () => race.setSteerRight(true),
                onPressEnd: () => race.setSteerRight(false),
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 18,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HoldButton(
                    key: const Key('btn_brake'),
                    icon: Icons.remove,
                    size: 52,
                    onPressStart: () => race.setBrake(true),
                    onPressEnd: () => race.setBrake(false),
                  ),
                  const SizedBox(height: 10),
                  _ItemButton(race: race),
                ],
              ),
              const SizedBox(width: 14),
              HoldButton(
                key: const Key('btn_drift'),
                label: '漂移',
                size: 96,
                color: const Color(0xFF0277BD),
                onPressStart: () => race.setDrift(true),
                onPressEnd: () => race.setDrift(false),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 按住生效、松开失效的圆形按钮（转向/漂移/刹车）。
class HoldButton extends StatefulWidget {
  final IconData? icon;
  final String? label;
  final double size;
  final Color color;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;

  const HoldButton({
    super.key,
    this.icon,
    this.label,
    required this.size,
    required this.onPressStart,
    required this.onPressEnd,
    this.color = const Color(0xFF37474F),
  });

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton> {
  bool _pressed = false;

  void _release() {
    // 组件销毁后可能有迟到的抬起事件送达，先判 mounted 再 setState/回调
    if (!mounted || !_pressed) {
      return;
    }
    setState(() => _pressed = false);
    widget.onPressEnd();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        if (!mounted) {
          return;
        }
        setState(() => _pressed = true);
        widget.onPressStart();
      },
      onTapUp: (_) => _release(),
      onTapCancel: _release,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _pressed
                ? widget.color.withValues(alpha: 0.95)
                : widget.color.withValues(alpha: 0.55),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Center(
            child: widget.icon != null
                ? Icon(widget.icon, color: Colors.white, size: widget.size * 0.42)
                : Text(
                    widget.label ?? '',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: widget.size * 0.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ItemButton extends StatelessWidget {
  final RaceProvider race;

  const _ItemButton({required this.race});

  @override
  Widget build(BuildContext context) {
    final item = race.state.player.item;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => race.useItem(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: item == null ? 0.08 : 0.18),
              border: Border.all(
                color: item == null
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0xFFFFC107),
                width: item == null ? 1 : 2,
              ),
            ),
            child: Center(child: ItemIcon(item: item, size: 42)),
          ),
          const SizedBox(height: 4),
          const Text(
            '道具',
            style: TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
