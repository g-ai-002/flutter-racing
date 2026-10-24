import 'dart:math' as math;
import 'dart:ui' as ui;

import '../engine/track_geometry.dart';
import '../models/track_def.dart';

/// 静态赛道层（地面/路面/路缘/格纹起跑线/装饰）。
///
/// 以世界坐标录制为矢量 [ui.Picture]，比赛画面逐帧用 `drawPicture` 回放。
/// 相比"离屏位图（Picture.toImage）+ drawImage"方案，不依赖异步栅格化与
/// 位图绘制——后者在 Windows 上曾导致静默黑屏（无 Dart 异常、日志为空）。
class StaticTrackLayer {
  final ui.Picture picture;

  const StaticTrackLayer(this.picture);
}

class _Palette {
  final ui.Color ground;
  final ui.Color patch;
  final ui.Color road;
  final ui.Color border;
  final ui.Color curbA;
  final ui.Color curbB;

  const _Palette({
    required this.ground,
    required this.patch,
    required this.road,
    required this.border,
    required this.curbA,
    required this.curbB,
  });

  static _Palette of(TrackTheme theme) {
    return switch (theme) {
      TrackTheme.seaside => const _Palette(
        ground: ui.Color(0xFF7CB342),
        patch: ui.Color(0xFF689F38),
        road: ui.Color(0xFF546E7A),
        border: ui.Color(0xFF37474F),
        curbA: ui.Color(0xFFE53935),
        curbB: ui.Color(0xFFFAFAFA),
      ),
      TrackTheme.desert => const _Palette(
        ground: ui.Color(0xFFEDD892),
        patch: ui.Color(0xFFE0C275),
        road: ui.Color(0xFF546E7A),
        border: ui.Color(0xFF37474F),
        curbA: ui.Color(0xFFE53935),
        curbB: ui.Color(0xFFFAFAFA),
      ),
      TrackTheme.alpine => const _Palette(
        ground: ui.Color(0xFFE8F1F5),
        patch: ui.Color(0xFFD3E5EE),
        road: ui.Color(0xFF4A6572),
        border: ui.Color(0xFF2F4550),
        curbA: ui.Color(0xFFE53935),
        curbB: ui.Color(0xFFFAFAFA),
      ),
    };
  }
}

/// 构建静态赛道层（同步：仅录制矢量指令，不做栅格化）。
StaticTrackLayer buildStaticTrackLayer(TrackDef def, TrackGeometry track) {
  const margin = 150.0;
  final bounds = track.bounds.inflate(margin);

  final palette = _Palette.of(def.theme);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  // 1. 地面
  canvas.drawRect(bounds, ui.Paint()..color = palette.ground);

  // 2. 地面斑块
  final rng = math.Random(def.id.hashCode & 0x7fffffff);
  final groundPaint = ui.Paint()..color = palette.patch;
  for (var i = 0; i < 260; i++) {
    final px = bounds.left + rng.nextDouble() * bounds.width;
    final py = bounds.top + rng.nextDouble() * bounds.height;
    final r = 8 + rng.nextDouble() * 26;
    canvas.drawOval(
      ui.Rect.fromCircle(center: ui.Offset(px, py), radius: r),
      groundPaint,
    );
  }

  // 3. 路面：外描边 + 沥青主体
  final centerPath = ui.Path();
  centerPath.moveTo(track.points[0].dx, track.points[0].dy);
  for (var i = 1; i < track.pointCount; i++) {
    centerPath.lineTo(track.points[i].dx, track.points[i].dy);
  }
  centerPath.close();
  canvas.drawPath(
    centerPath,
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = track.halfWidth * 2 + 12
      ..strokeJoin = ui.StrokeJoin.round
      ..color = palette.border,
  );
  canvas.drawPath(
    centerPath,
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = track.halfWidth * 2
      ..strokeJoin = ui.StrokeJoin.round
      ..color = palette.road,
  );

  // 4. 路缘石（弯道处红白相间）
  final curbTickSize = ui.Rect.fromCenter(
    center: ui.Offset.zero,
    width: 2.6,
    height: 10,
  );
  for (var i = 0; i < track.pointCount; i += 2) {
    if (track.curvature[i] < 0.0055) {
      continue;
    }
    final p = track.pointAt(i);
    final ang = track.tangentAngleAt(i);
    final nx = math.sin(ang);
    final ny = -math.cos(ang);
    final phase = ((i * TrackGeometry.spacing) / 10).floor() % 2;
    final paint = ui.Paint()..color = phase == 0 ? palette.curbA : palette.curbB;
    for (final side in const [1.0, -1.0]) {
      canvas.save();
      canvas.translate(
        p.dx + nx * side * (track.halfWidth + 3),
        p.dy + ny * side * (track.halfWidth + 3),
      );
      canvas.rotate(ang);
      canvas.drawRect(curbTickSize, paint);
      canvas.restore();
    }
  }

  // 5. 路边白线
  final edgePaint = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 2.2
    ..color = const ui.Color(0xDDECEFF1);
  for (final side in const [1.0, -1.0]) {
    final edge = ui.Path();
    for (var i = 0; i <= track.pointCount; i += 4) {
      final p = track.pointAt(i);
      final ang = track.tangentAngleAt(i);
      final ex = p.dx + math.sin(ang) * side * (track.halfWidth - 3);
      final ey = p.dy - math.cos(ang) * side * (track.halfWidth - 3);
      if (i == 0) {
        edge.moveTo(ex, ey);
      } else {
        edge.lineTo(ex, ey);
      }
    }
    edge.close();
    canvas.drawPath(edge, edgePaint);
  }

  // 6. 起点格纹带 + 门柱
  final p0 = track.pointAt(0);
  final ang0 = track.tangentAngleAt(0);
  final t0 = ui.Offset(math.cos(ang0), math.sin(ang0));
  final n0 = ui.Offset(math.sin(ang0), -math.cos(ang0));
  for (var row = 0; row < 2; row++) {
    var col = 0;
    for (var lat = -track.halfWidth + 4; lat < track.halfWidth - 4; lat += 8) {
      final center = ui.Offset(
        p0.dx + t0.dx * row * 8 + n0.dx * lat,
        p0.dy + t0.dy * row * 8 + n0.dy * lat,
      );
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(ang0);
      canvas.drawRect(
        ui.Rect.fromCenter(center: ui.Offset.zero, width: 8, height: 8),
        ui.Paint()
          ..color = (row + col) % 2 == 0
              ? const ui.Color(0xFFFAFAFA)
              : const ui.Color(0xFF212121),
      );
      canvas.restore();
      col++;
    }
  }
  final postPaint = ui.Paint()..color = const ui.Color(0xFF37474F);
  for (final side in const [1.0, -1.0]) {
    canvas.drawCircle(
      ui.Offset(
        p0.dx + n0.dx * side * (track.halfWidth + 9),
        p0.dy + n0.dy * side * (track.halfWidth + 9),
      ),
      4,
      postPaint,
    );
  }

  // 7. 主题装饰（树/仙人掌/雪松/岩石），避开路面
  _drawDecorations(canvas, def, track, rng, bounds);

  return StaticTrackLayer(recorder.endRecording());
}

void _drawDecorations(
  ui.Canvas canvas,
  TrackDef def,
  TrackGeometry track,
  math.Random rng,
  ui.Rect bounds,
) {
  const decorCount = 90;
  var placed = 0;
  var attempts = 0;
  final minDist = track.halfWidth + 26;
  while (placed < decorCount && attempts < decorCount * 6) {
    attempts++;
    final idx = rng.nextInt(track.pointCount);
    final base = track.pointAt(idx);
    final ang = track.tangentAngleAt(idx);
    final nx = math.sin(ang);
    final ny = -math.cos(ang);
    final side = rng.nextBool() ? 1.0 : -1.0;
    final dist = track.halfWidth + 30 + rng.nextDouble() * 80;
    final px = base.dx + nx * side * dist;
    final py = base.dy + ny * side * dist;

    // 画布内 & 不贴路面
    if (px < bounds.left + 16 ||
        px > bounds.right - 16 ||
        py < bounds.top + 16 ||
        py > bounds.bottom - 16) {
      continue;
    }
    var tooClose = false;
    for (var j = 0; j < track.pointCount; j += 6) {
      final q = track.pointAt(j);
      final dx = q.dx - px;
      final dy = q.dy - py;
      if (dx * dx + dy * dy < minDist * minDist) {
        tooClose = true;
        break;
      }
    }
    if (tooClose) {
      continue;
    }

    final scale = 0.7 + rng.nextDouble() * 0.6;
    canvas.save();
    canvas.translate(px, py);
    canvas.scale(scale);
    switch (def.theme) {
      case TrackTheme.seaside:
        _drawTree(canvas, rng);
      case TrackTheme.desert:
        rng.nextDouble() < 0.6
            ? _drawCactus(canvas, rng)
            : _drawRock(canvas, rng);
      case TrackTheme.alpine:
        rng.nextDouble() < 0.7
            ? _drawPine(canvas, rng)
            : _drawRock(canvas, rng);
    }
    canvas.restore();
    placed++;
  }
}

void _drawTree(ui.Canvas canvas, math.Random rng) {
  canvas.drawCircle(
    const ui.Offset(0, -9),
    2.4,
    ui.Paint()..color = const ui.Color(0xFF6D4C41),
  );
  final green = ui.Paint()..color = const ui.Color(0xFF2E7D32);
  final darkGreen = ui.Paint()..color = const ui.Color(0xFF1B5E20);
  canvas.drawCircle(const ui.Offset(-5, -16), 7.5, darkGreen);
  canvas.drawCircle(const ui.Offset(5, -16), 7.5, darkGreen);
  canvas.drawCircle(const ui.Offset(0, -22), 8, green);
}

void _drawCactus(ui.Canvas canvas, math.Random rng) {
  final paint = ui.Paint()..color = const ui.Color(0xFF388E3C);
  final rrect = ui.RRect.fromRectAndRadius(
    ui.Rect.fromCenter(center: const ui.Offset(0, -8), width: 7, height: 20),
    const ui.Radius.circular(3.5),
  );
  canvas.drawRRect(rrect, paint);
  canvas.drawRRect(
    ui.RRect.fromRectAndRadius(
      ui.Rect.fromCenter(center: const ui.Offset(-7, -12), width: 6, height: 10),
      const ui.Radius.circular(3),
    ),
    paint,
  );
  canvas.drawRRect(
    ui.RRect.fromRectAndRadius(
      ui.Rect.fromCenter(center: const ui.Offset(7, -15), width: 6, height: 10),
      const ui.Radius.circular(3),
    ),
    paint,
  );
}

void _drawPine(ui.Canvas canvas, math.Random rng) {
  final paint = ui.Paint()..color = const ui.Color(0xFF2E5D46);
  final snow = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
  canvas.drawRect(
    ui.Rect.fromCenter(center: const ui.Offset(0, -3), width: 4, height: 7),
    ui.Paint()..color = const ui.Color(0xFF5D4037),
  );
  final path = ui.Path()
    ..moveTo(-9, -4)
    ..lineTo(0, -12)
    ..lineTo(9, -4)
    ..close();
  canvas.drawPath(path, paint);
  final path2 = ui.Path()
    ..moveTo(-6.5, -10)
    ..lineTo(0, -18)
    ..lineTo(6.5, -10)
    ..close();
  canvas.drawPath(path2, paint);
  final cap = ui.Path()
    ..moveTo(-4, -14)
    ..lineTo(0, -18)
    ..lineTo(4, -14)
    ..close();
  canvas.drawPath(cap, snow);
}

void _drawRock(ui.Canvas canvas, math.Random rng) {
  canvas.drawCircle(
    const ui.Offset(0, -3),
    5.5,
    ui.Paint()..color = const ui.Color(0xFF9E9E9E),
  );
  canvas.drawCircle(
    const ui.Offset(-4, 0),
    3.5,
    ui.Paint()..color = const ui.Color(0xFF8D8D8D),
  );
}
