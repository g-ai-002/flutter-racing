import 'dart:math' as math;
import 'dart:ui';

import '../models/game_enums.dart';
import '../models/kart_state.dart';
import '../models/race_state.dart';
import 'kart_physics.dart';
import 'track_geometry.dart';

/// AI 驾驶：中心线前瞻转向 + 弯道限速 + 轻微走线噪声 + 道具决策。
class AiDriver {
  static KartInput drive(KartState k, RaceState race, TrackGeometry track) {
    if (k.spinTimer > 0) {
      return KartInput.idle;
    }
    final look = math.min(52.0, math.max(26.0, 24 + k.speed * 0.115));
    final idx = track.wrapIndex(k.centerIndex + (look / TrackGeometry.spacing).round());
    final p = track.pointAt(idx);
    final normal = track.normalAt(idx);
    final target = Offset(
      p.dx + normal.dx * k.aiOffset,
      p.dy + normal.dy * k.aiOffset,
    );
    var diff = math.atan2(target.dy - k.y, target.dx - k.x) - k.angle;
    while (diff > math.pi) {
      diff -= 2 * math.pi;
    }
    while (diff < -math.pi) {
      diff += 2 * math.pi;
    }
    var steer = diff * 2.6 + math.sin(race.raceTime * 2.3 + k.aiSeed) * 0.05;
    steer = steer < -1 ? -1.0 : (steer > 1 ? 1.0 : steer);

    // 前方最大曲率决定弯道限速
    var maxCurv = 1e-4;
    for (var d = 6; d <= 54; d += 4) {
      final c = track.curvature[track.wrapIndex(k.centerIndex + d)];
      if (c > maxCurv) {
        maxCurv = c;
      }
    }
    final cornerSpeed = math.sqrt(300.0 / maxCurv);
    final targetSpeed = math.min(
      KartPhysics.baseMaxSpeed * k.statTopSpeedMul * k.aiSkill * k.aiSpeedMul,
      cornerSpeed,
    );
    return KartInput(
      steer: steer,
      throttle: k.speed < targetSpeed,
      brake: k.speed > targetSpeed * 1.2,
    );
  }

  /// AI 道具使用决策（每 ~0.5s 调用一次）
  static bool wantsUseItem(KartState k, RaceState race, TrackGeometry track) {
    final item = k.item;
    if (item == null || k.itemUseCooldown > 0 || k.spinTimer > 0) {
      return false;
    }
    return switch (item) {
      ItemType.nitro => _straightAhead(k, track),
      ItemType.missile || ItemType.waterBomb => _hasTargetAhead(k, race),
      ItemType.banana => true,
      ItemType.shield => _missileIncoming(k, race),
    };
  }

  static bool _straightAhead(KartState k, TrackGeometry track) {
    var maxCurv = 0.0;
    for (var d = 0; d <= 50; d += 5) {
      final c = track.curvature[track.wrapIndex(k.centerIndex + d)];
      if (c > maxCurv) {
        maxCurv = c;
      }
    }
    return maxCurv < 0.004;
  }

  static bool _hasTargetAhead(KartState k, RaceState race) {
    for (final other in race.karts) {
      if (other.kartIndex == k.kartIndex || other.finished) {
        continue;
      }
      final gap = other.progress - k.progress;
      if (gap > 10 && gap < 260) {
        return true;
      }
    }
    return false;
  }

  static bool _missileIncoming(KartState k, RaceState race) {
    for (final m in race.missiles) {
      if (m.targetIndex == k.kartIndex) {
        return true;
      }
    }
    return false;
  }
}
