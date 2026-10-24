import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../models/track_def.dart';
import '../../widgets/static_track_layer.dart';

/// 静态赛道层：把预录制的矢量赛道回放到世界坐标原点。
///
/// 静态层构建失败时退化为纯色地面，避免整屏黑屏。
class TrackLayerComponent extends PositionComponent {
  TrackLayerComponent({
    required this.layer,
    required this.groundColor,
    super.priority,
  });

  final StaticTrackLayer? layer;
  final Color groundColor;

  final Paint _ground = Paint();

  @override
  void render(Canvas canvas) {
    final staticLayer = layer;
    if (staticLayer != null) {
      canvas.drawPicture(staticLayer.picture);
      return;
    }
    _ground.color = groundColor;
    canvas.drawRect(
      const Rect.fromLTWH(-4000, -4000, 8000, 8000),
      _ground,
    );
  }
}

/// 把主题映射为赛道静态层失败时的地面色。
Color groundColorFor(TrackTheme theme) {
  return switch (theme) {
    TrackTheme.seaside => const Color(0xFF7CB342),
    TrackTheme.desert => const Color(0xFFEDD892),
    TrackTheme.alpine => const Color(0xFFE8F1F5),
  };
}
