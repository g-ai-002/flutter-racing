import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_racing/engine/track_geometry.dart';
import 'package:flutter_racing/models/track_def.dart';
import 'package:flutter_racing/utils/constants.dart';

/// 赛道几何回归：与设计期 Python 数值验证（.qwen 侧脚本）同一口径。
/// 若控制点或采样算法被改动，这些断言会先失败。
void main() {
  for (final def in TrackCatalog.all) {
    group('赛道 ${def.name} (${def.id})', () {
      final track = TrackGeometry.fromDef(def);

      test('无自交', () {
        expect(track.selfIntersects(), isFalse);
      });

      test('最小弯道半径 ≥ 半路宽×1.4', () {
        expect(track.minRadius(), greaterThanOrEqualTo(def.halfWidth * 1.4));
      });

      test('车道净空 ≥ 2×半路宽+20', () {
        expect(
          track.minClearance(),
          greaterThanOrEqualTo(2 * def.halfWidth + 20),
        );
      });

      test('检查点等分且起点为 0', () {
        expect(track.checkpoints.length, AppConstants.checkpointCount);
        expect(track.checkpoints[0], 0);
        for (var i = 1; i < track.checkpoints.length; i++) {
          expect(track.checkpoints[i], greaterThan(track.checkpoints[i - 1]));
        }
      });

      test('总长与采样数一致', () {
        expect(
          track.totalLength,
          closeTo(TrackGeometry.spacing * track.pointCount, 1e-6),
        );
      });

      test('包围盒覆盖全部采样点', () {
        for (final p in track.points) {
          expect(p.dx, greaterThanOrEqualTo(track.bounds.left));
          expect(p.dx, lessThanOrEqualTo(track.bounds.right));
          expect(p.dy, greaterThanOrEqualTo(track.bounds.top));
          expect(p.dy, lessThanOrEqualTo(track.bounds.bottom));
        }
      });

      test('project 沿中心线跟踪定位', () {
        var hint = 0;
        // 步进需小于投影搜索窗口（±28 采样点），保证按前一点提示可连续追踪
        for (var i = 0; i < track.pointCount; i += 20) {
          final p = track.pointAt(i);
          final proj = track.project(p.dx, p.dy, hint);
          expect(proj.s, closeTo(i * TrackGeometry.spacing, 4.0));
          expect(proj.lateral.abs(), lessThan(1.0));
          hint = proj.index;
        }
      });

      test('posAtS/project 往返一致', () {
        for (var k = 0; k < 13; k++) {
          final s = track.totalLength * k / 13;
          final p = track.posAtS(s);
          final hint =
              (s / TrackGeometry.spacing).round() % track.pointCount;
          final proj = track.project(p.dx, p.dy, hint);
          expect(proj.s, closeTo(s % track.totalLength, 2.5));
        }
      });
    });
  }
}
