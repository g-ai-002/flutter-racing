import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_racing/game/components/touch_controls_component.dart';

void main() {
  group('TouchLayout', () {
    const size = Vector2(800, 600);

    test('所有按钮完整落在屏幕内', () {
      const layout = TouchLayout(size);
      for (final action in TouchAction.values) {
        final rect = layout.rectFor(action);
        expect(rect.left, greaterThanOrEqualTo(0.0));
        expect(rect.top, greaterThanOrEqualTo(0.0));
        expect(rect.right, lessThanOrEqualTo(size.x));
        expect(rect.bottom, lessThanOrEqualTo(size.y));
      }
    });

    test('按钮之间不重叠', () {
      const layout = TouchLayout(size);
      final actions = TouchAction.values;
      for (var i = 0; i < actions.length; i++) {
        for (var j = i + 1; j < actions.length; j++) {
          final a = layout.rectFor(actions[i]);
          final b = layout.rectFor(actions[j]);
          expect(a.overlaps(b), isFalse, reason: '${actions[i]} 与 ${actions[j]} 重叠');
        }
      }
    });

    test('点击命中对应按钮，空白区域不命中', () {
      const layout = TouchLayout(size);
      for (final action in TouchAction.values) {
        expect(layout.hitTest(layout.rectFor(action).center), action);
      }
      expect(layout.hitTest(const Offset(400, 100)), isNull);
    });

    test('控制区随屏幕尺寸缩放', () {
      const small = TouchLayout(Vector2(480, 320));
      final drift = small.rectFor(TouchAction.drift);
      expect(drift.right, lessThanOrEqualTo(480));
      expect(drift.bottom, lessThanOrEqualTo(320));
    });
  });
}
