import 'dart:math' as math;
import 'dart:ui';

import '../models/track_def.dart';
import '../utils/constants.dart';

/// 中心线投影结果
class TrackProjection {
  final int index;
  final double s;
  final double lateral;
  final double along;

  const TrackProjection({
    required this.index,
    required this.s,
    required this.lateral,
    required this.along,
  });
}

/// 赛道几何：闭合 Catmull-Rom 样条 -> 等距采样中心线。
///
/// 采样算法与验证脚本完全一致（每段 40 步、等距 2.0 单位重采样），
/// 控制点的自交 / 最小半径 / 净空由 test/track_geometry_test.dart 回归把关。
class TrackGeometry {
  static const int segSteps = 40;
  static const double spacing = 2.0;

  /// 最近点搜索窗口（±28 个采样点 = ±56 单位）
  static const int searchWindow = 28;

  final TrackDef def;
  late final List<Offset> points;
  late final int pointCount;
  late final double totalLength;
  late final double halfWidth;
  late final List<double> curvature;
  late final List<int> checkpoints;

  TrackGeometry.fromDef(this.def) {
    halfWidth = def.halfWidth;
    _build();
  }

  /// 路肩宽度（草地减速区），墙在 halfWidth + shoulder
  double get shoulder => halfWidth * 0.5;
  double get wallLimit => halfWidth + shoulder;

  void _build() {
    final control = def.controlPoints;
    final n = control.length;
    final dense = <Offset>[];
    for (var i = 0; i < n; i++) {
      final p0 = control[(i - 1) % n];
      final p1 = control[i];
      final p2 = control[(i + 1) % n];
      final p3 = control[(i + 2) % n];
      for (var j = 0; j < segSteps; j++) {
        dense.add(_catmull(p0, p1, p2, p3, j / segSteps));
      }
    }
    points = _resampleLoop(dense);
    pointCount = points.length;
    totalLength = spacing * pointCount;
    curvature = _buildCurvature();
    checkpoints = List<int>.generate(
      AppConstants.checkpointCount,
      (i) => (i * pointCount / AppConstants.checkpointCount).round() % pointCount,
    );
  }

  static Offset _catmull(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final t2 = t * t;
    final t3 = t2 * t;
    final x = 0.5 *
        ((2 * p1.dx) +
            (-p0.dx + p2.dx) * t +
            (2 * p0.dx - 5 * p1.dx + 4 * p2.dx - p3.dx) * t2 +
            (-p0.dx + 3 * p1.dx - 3 * p2.dx + p3.dx) * t3);
    final y = 0.5 *
        ((2 * p1.dy) +
            (-p0.dy + p2.dy) * t +
            (2 * p0.dy - 5 * p1.dy + 4 * p2.dy - p3.dy) * t2 +
            (-p0.dy + 3 * p1.dy - 3 * p2.dy + p3.dy) * t3);
    return Offset(x, y);
  }

  List<Offset> _resampleLoop(List<Offset> dense) {
    final out = <Offset>[dense[0]];
    var acc = 0.0;
    final m = dense.length;
    for (var k = 1; k <= m; k++) {
      var a = dense[k - 1];
      final b = dense[k % m];
      var seg = (b - a).distance;
      if (seg < 1e-9) {
        continue;
      }
      while (acc + seg >= spacing) {
        final t = (spacing - acc) / seg;
        final p = Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
        out.add(p);
        a = p;
        seg = (b - a).distance;
        acc = 0.0;
      }
      acc += seg;
    }
    if ((out[0] - out[out.length - 1]).distance < spacing * 0.9) {
      out.removeLast();
    }
    return out;
  }

  List<double> _buildCurvature() {
    final raw = List<double>.generate(
      pointCount,
      (i) => _curvatureAt(points, i),
    );
    final smooth = List<double>.filled(pointCount, 0);
    for (var i = 0; i < pointCount; i++) {
      var sum = 0.0;
      for (var w = -3; w <= 3; w++) {
        sum += raw[wrapIndex(i + w)];
      }
      smooth[i] = sum / 7;
    }
    return smooth;
  }

  static double _curvatureAt(List<Offset> pts, int i) {
    final n = pts.length;
    final a = pts[(i - 1) % n];
    final b = pts[i];
    final c = pts[(i + 1) % n];
    final v1x = b.dx - a.dx;
    final v1y = b.dy - a.dy;
    final v2x = c.dx - b.dx;
    final v2y = c.dy - b.dy;
    final d1 = math.sqrt(v1x * v1x + v1y * v1y);
    final d2 = math.sqrt(v2x * v2x + v2y * v2y);
    if (d1 < 1e-9 || d2 < 1e-9) {
      return 0.0;
    }
    final cross = (v1x * v2y - v1y * v2x).abs();
    return cross / (d1 * d2 * (d1 + d2) / 2);
  }

  int wrapIndex(int i) {
    final n = pointCount;
    return ((i % n) + n) % n;
  }

  Offset pointAt(int i) => points[wrapIndex(i)];

  double tangentAngleAt(int i) {
    final a = points[wrapIndex(i)];
    final b = points[wrapIndex(i + 1)];
    return math.atan2(b.dy - a.dy, b.dx - a.dx);
  }

  /// 中心线法线（lateral 正方向）
  Offset normalAt(int i) {
    final ang = tangentAngleAt(i);
    return Offset(math.sin(ang), -math.cos(ang));
  }

  /// 弧长定位：返回中心线上的点
  Offset posAtS(double s) {
    var ss = s % totalLength;
    if (ss < 0) {
      ss += totalLength;
    }
    final fi = ss / spacing;
    final i = fi.floor() % pointCount;
    final frac = fi - fi.floor();
    final a = points[i];
    final b = points[wrapIndex(i + 1)];
    return Offset(a.dx + (b.dx - a.dx) * frac, a.dy + (b.dy - a.dy) * frac);
  }

  double tangentAngleAtS(double s) {
    var ss = s % totalLength;
    if (ss < 0) {
      ss += totalLength;
    }
    final fi = ss / spacing;
    final i = fi.floor() % pointCount;
    final frac = fi - fi.floor();
    final a = points[i];
    final b = points[wrapIndex(i + 1)];
    final dx = (b.dx - a.dx);
    final dy = (b.dy - a.dy);
    final len = math.sqrt(dx * dx + dy * dy);
    // 用邻段切线按弧长插值，避免相邻段夹角突变
    final angA = tangentAngleAt(i);
    final angB = tangentAngleAt(i + 1);
    final nextLen = len;
    if (nextLen < 1e-9) {
      return angA;
    }
    var dAng = angB - angA;
    while (dAng > math.pi) {
      dAng -= 2 * math.pi;
    }
    while (dAng < -math.pi) {
      dAng += 2 * math.pi;
    }
    return angA + dAng * frac;
  }

  /// 最近点投影：带索引提示的局部窗口搜索
  TrackProjection project(double px, double py, int hint) {
    var best = wrapIndex(hint);
    var bestDx = points[best].dx - px;
    var bestDy = points[best].dy - py;
    var bestD2 = bestDx * bestDx + bestDy * bestDy;
    for (var k = -searchWindow; k <= searchWindow; k++) {
      final i = wrapIndex(hint + k);
      final dx = points[i].dx - px;
      final dy = points[i].dy - py;
      final d2 = dx * dx + dy * dy;
      if (d2 < bestD2) {
        best = i;
        bestD2 = d2;
      }
    }
    final p = points[best];
    final ang = tangentAngleAt(best);
    final cosA = math.cos(ang);
    final sinA = math.sin(ang);
    final rx = px - p.dx;
    final ry = py - p.dy;
    final along = rx * cosA + ry * sinA;
    final lateral = rx * sinA - ry * cosA;
    var s = best * spacing + along;
    s %= totalLength;
    if (s < 0) {
      s += totalLength;
    }
    return TrackProjection(index: best, s: s, lateral: lateral, along: along);
  }

  /// 从投影重建位置（墙钳制用）
  static Offset rebuildPosition(TrackProjection proj, TrackGeometry track, double lateralOverride) {
    final p = track.pointAt(proj.index);
    final ang = track.tangentAngleAt(proj.index);
    return Offset(
      p.dx + math.cos(ang) * proj.along + math.sin(ang) * lateralOverride,
      p.dy + math.sin(ang) * proj.along - math.cos(ang) * lateralOverride,
    );
  }

  // ---- 以下为几何体检（供单元测试回归把关，与 Python 验证脚本同一口径） ----

  double minRadius() {
    var maxCurv = 0.0;
    for (final c in curvature) {
      if (c > maxCurv) {
        maxCurv = c;
      }
    }
    return maxCurv > 0 ? 1 / maxCurv : double.infinity;
  }

  double minClearance({int idxSkip = 120}) {
    var minClear = double.infinity;
    final n = pointCount;
    for (var i = 0; i < n; i++) {
      final a = points[i];
      for (var j = i + idxSkip; j < n; j++) {
        if (n - (j - i) <= idxSkip) {
          continue;
        }
        final b = points[j];
        final dx = a.dx - b.dx;
        final dy = a.dy - b.dy;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d < minClear) {
          minClear = d;
        }
      }
    }
    return minClear;
  }

  bool selfIntersects() {
    final stride = 3;
    final m = pointCount ~/ stride;
    for (var i = 0; i < m; i++) {
      final a1 = points[i * stride];
      final a2 = points[wrapIndex((i + 1) * stride)];
      for (var j = i + 2; j < m; j++) {
        if (i == 0 && j == m - 1) {
          continue;
        }
        final dIdx = j - i;
        if (dIdx <= 1 || dIdx >= m - 1) {
          continue;
        }
        final b1 = points[j * stride];
        final b2 = points[wrapIndex((j + 1) * stride)];
        if (_segmentsIntersect(a1, a2, b1, b2)) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _segmentsIntersect(Offset p1, Offset p2, Offset p3, Offset p4) {
    bool ccw(Offset a, Offset b, Offset c) {
      return (c.dy - a.dy) * (b.dx - a.dx) > (b.dy - a.dy) * (c.dx - a.dx);
    }

    return ccw(p1, p3, p4) != ccw(p2, p3, p4) &&
        ccw(p1, p2, p3) != ccw(p1, p2, p4);
  }
}
