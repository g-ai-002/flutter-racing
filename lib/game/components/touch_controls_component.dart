import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../providers/race_provider.dart';

/// 触屏按钮种类。
enum TouchAction { steerLeft, steerRight, brake, drift, item }

/// 触屏按钮布局（屏幕空间，单位像素）。
///
/// 与旧 Flutter 控件的排布一致：左下转向，右下刹车/道具/漂移。
class TouchLayout {
  const TouchLayout(this.size);

  final Vector2 size;

  static const double margin = 16;
  static const double bottom = 18;
  static const double steerSize = 84;
  static const double driftSize = 96;
  static const double brakeSize = 52;
  static const double itemSize = 72;
  static const double gap = 14;

  Rect rectFor(TouchAction action) {
    final h = size.y;
    final w = size.x;
    switch (action) {
      case TouchAction.steerLeft:
        return Rect.fromLTWH(margin, h - bottom - steerSize, steerSize, steerSize);
      case TouchAction.steerRight:
        return Rect.fromLTWH(
          margin + steerSize + gap,
          h - bottom - steerSize,
          steerSize,
          steerSize,
        );
      case TouchAction.drift:
        return Rect.fromLTWH(
          w - margin - driftSize,
          h - bottom - driftSize,
          driftSize,
          driftSize,
        );
      case TouchAction.item:
        return Rect.fromLTWH(
          w - margin - driftSize - gap - itemSize,
          h - bottom - itemSize,
          itemSize,
          itemSize,
        );
      case TouchAction.brake:
        return Rect.fromLTWH(
          w - margin - driftSize - gap - brakeSize,
          h - bottom - itemSize - 10 - brakeSize,
          brakeSize,
          brakeSize,
        );
    }
  }

  TouchAction? hitTest(Offset point) {
    for (final action in TouchAction.values) {
      if (rectFor(action).contains(point)) {
        return action;
      }
    }
    return null;
  }
}

class TouchControlsComponent extends PositionComponent {
  TouchControlsComponent({required this.provider, super.priority});

  final RaceProvider provider;
  final Map<TouchAction, _TouchButtonComponent> _buttons = {};

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final game = findGame();
    size = game?.size.clone() ?? Vector2.zero();
    for (final action in TouchAction.values) {
      final button = _TouchButtonComponent(
        action: action,
        onPressStart: () => _press(action),
        onPressEnd: () => _release(action),
        itemLabel: () => provider.state.player.item?.label ?? '道具',
      );
      _buttons[action] = button;
      await add(button);
    }
    _layout();
  }

  @override
  void update(double dt) {
    super.update(dt);
    final game = findGame();
    if (game != null && game.size.x > 0 && game.size != size) {
      size = game.size.clone();
      _layout();
    }
  }

  void _layout() {
    final layout = TouchLayout(size);
    for (final entry in _buttons.entries) {
      final rect = layout.rectFor(entry.key);
      entry.value
        ..position = Vector2(rect.left, rect.top)
        ..size = Vector2(rect.width, rect.height);
    }
  }

  void _press(TouchAction action) {
    switch (action) {
      case TouchAction.steerLeft:
        provider.setSteerLeft(true);
      case TouchAction.steerRight:
        provider.setSteerRight(true);
      case TouchAction.brake:
        provider.setBrake(true);
      case TouchAction.drift:
        provider.setDrift(true);
      case TouchAction.item:
        provider.useItem();
    }
  }

  void _release(TouchAction action) {
    switch (action) {
      case TouchAction.steerLeft:
        provider.setSteerLeft(false);
      case TouchAction.steerRight:
        provider.setSteerRight(false);
      case TouchAction.brake:
        provider.setBrake(false);
      case TouchAction.drift:
        provider.setDrift(false);
      case TouchAction.item:
        break;
    }
  }
}

class _TouchButtonComponent extends PositionComponent with TapCallbacks {
  _TouchButtonComponent({
    required this.action,
    required this.onPressStart,
    required this.onPressEnd,
    required this.itemLabel,
  });

  final TouchAction action;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;
  final String Function() itemLabel;

  final Paint _fill = Paint();
  final Paint _border = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;

  bool _pressed = false;

  @override
  void onTapDown(TapDownEvent event) {
    _pressed = true;
    onPressStart();
  }

  @override
  void onTapUp(TapUpEvent event) => _release();

  @override
  void onTapCancel(TapCancelEvent event) => _release();

  void _release() {
    if (!_pressed) {
      return;
    }
    _pressed = false;
    onPressEnd();
  }

  @override
  void render(Canvas canvas) {
    final radius = math.min(size.x, size.y) / 2;
    final center = Offset(radius, radius);
    final baseColor = action == TouchAction.drift
        ? const Color(0xFF0277BD)
        : const Color(0xFF37474F);

    final scale = _pressed ? 0.9 : 1.0;
    _fill.color = baseColor.withValues(alpha: _pressed ? 0.95 : 0.55);
    _border.color = Colors.white.withValues(alpha: 0.35);
    canvas.drawCircle(center, radius * scale, _fill);
    canvas.drawCircle(center, radius * scale, _border);

    final text = switch (action) {
      TouchAction.steerLeft => '‹',
      TouchAction.steerRight => '›',
      TouchAction.brake => '−',
      TouchAction.drift => '漂移',
      TouchAction.item => itemLabel(),
    };
    final fontSize = action == TouchAction.drift
        ? radius * 0.38
        : (action == TouchAction.item ? radius * 0.34 : radius * 0.8);
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }
}
