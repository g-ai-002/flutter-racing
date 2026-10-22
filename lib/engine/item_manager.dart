import 'dart:math' as math;

import '../models/game_enums.dart';
import '../models/kart_state.dart';
import '../models/race_state.dart';
import 'kart_physics.dart';
import 'track_geometry.dart';

/// 道具系统：道具箱 / 追踪导弹 / 水弹 / 香蕉皮 / 护盾。
class ItemManager {
  static const double boxRadius = 11.0;
  static const double missileHitRadius = 13.0;
  static const double missileSpeed = 330.0;
  static const double waterHitRadius = 14.0;
  static const double puddleRadius = 26.0;
  static const double peelRadius = 9.0;
  static const int maxPeels = 12;
  static const double boxRespawnTime = 5.0;

  static void initBoxes(RaceState race, TrackGeometry track, int count) {
    race.itemBoxes.clear();
    for (var i = 0; i < count; i++) {
      final s = (i + 0.5) * track.totalLength / count;
      final p = track.posAtS(s);
      final ang = track.tangentAngleAtS(s);
      final lateral = (i.isEven ? 1.0 : -1.0) * track.halfWidth * 0.45;
      race.itemBoxes.add(
        ItemBox(
          p.dx + math.sin(ang) * lateral,
          p.dy - math.cos(ang) * lateral,
        ),
      );
    }
  }

  static ItemType randomItem(math.Random rng) {
    final r = rng.nextDouble();
    if (r < 0.30) {
      return ItemType.nitro;
    }
    if (r < 0.54) {
      return ItemType.missile;
    }
    if (r < 0.70) {
      return ItemType.waterBomb;
    }
    if (r < 0.88) {
      return ItemType.banana;
    }
    return ItemType.shield;
  }

  /// 使用当前持有的道具（玩家按键或 AI 决策触发）
  static void useItem(
    KartState k,
    RaceState race,
    TrackGeometry track,
    math.Random rng,
  ) {
    final item = k.item;
    if (item == null || k.itemUseCooldown > 0 || k.spinTimer > 0 || k.finished) {
      return;
    }
    switch (item) {
      case ItemType.nitro:
        k.speed += 30;
        k.boostTimer = 1.65;
        k.boostPower = 1.35;
        race.addEvent(EngineEvent.boostStart, kartIndex: k.kartIndex, value: 2);
      case ItemType.missile:
        race.missiles.add(
          Missile(
            x: k.x,
            y: k.y,
            s: k.s,
            lateral: k.lateral,
            speed: missileSpeed,
            ownerIndex: k.kartIndex,
            targetIndex: _targetAhead(k, race),
          ),
        );
        race.addEvent(EngineEvent.missileLaunch, kartIndex: k.kartIndex);
      case ItemType.waterBomb:
        race.waterBombs.add(
          WaterBomb(
            x: k.x,
            y: k.y,
            vx: math.cos(k.angle) * (k.speed + 150),
            vy: math.sin(k.angle) * (k.speed + 150),
            ownerIndex: k.kartIndex,
          )..centerIndex = k.centerIndex,
        );
        race.addEvent(EngineEvent.waterDrop, kartIndex: k.kartIndex);
      case ItemType.banana:
        race.peels.add(
          BananaPeel(
            k.x - math.cos(k.angle) * 16,
            k.y - math.sin(k.angle) * 16,
          ),
        );
        while (race.peels.length > maxPeels) {
          race.peels.removeAt(0);
        }
        race.addEvent(EngineEvent.bananaDrop, kartIndex: k.kartIndex);
      case ItemType.shield:
        k.shieldTimer = 6;
    }
    k.item = null;
    k.itemUseCooldown = 0.5;
  }

  /// 打转 / 护盾抵挡
  static void spinOut(KartState k, RaceState race) {
    if (k.finished) {
      return;
    }
    if (k.shieldTimer > 0) {
      k.shieldTimer = 0;
      race.addEvent(EngineEvent.shieldBlock, kartIndex: k.kartIndex);
      for (var i = 0; i < 6; i++) {
        race.addParticle(
          x: k.x,
          y: k.y,
          kind: 3,
          life: 0.5,
          size: 6,
          vx: math.cos(i * math.pi / 3) * 60,
          vy: math.sin(i * math.pi / 3) * 60,
        );
      }
      return;
    }
    k.spinTimer = KartPhysics.spinDuration;
    k.speed *= 0.35;
    k.drifting = false;
    k.driftCharge = 0;
    k.driftTier = 0;
    k.boostTimer = 0;
    race.addEvent(EngineEvent.spinOut, kartIndex: k.kartIndex);
  }

  static void update(
    RaceState race,
    TrackGeometry track,
    double dt,
    math.Random rng,
  ) {
    _updateBoxes(race, dt, rng);
    _updateMissiles(race, track, dt);
    _updateWaterBombs(race, track, dt);
    _updatePeels(race, dt);
  }

  static void _updateBoxes(RaceState race, double dt, math.Random rng) {
    for (final box in race.itemBoxes) {
      if (!box.active) {
        box.respawnTimer -= dt;
        if (box.respawnTimer <= 0) {
          box.active = true;
        }
        continue;
      }
      for (final k in race.karts) {
        if (k.finished || k.item != null || k.spinTimer > 0) {
          continue;
        }
        final dx = k.x - box.x;
        final dy = k.y - box.y;
        final r = boxRadius + KartPhysics.kartRadius;
        if (dx * dx + dy * dy < r * r) {
          k.item = randomItem(rng);
          box.active = false;
          box.respawnTimer = boxRespawnTime;
          race.addEvent(EngineEvent.itemPickup, kartIndex: k.kartIndex);
          break;
        }
      }
    }
  }

  static void _updateMissiles(RaceState race, TrackGeometry track, double dt) {
    final dead = <Missile>[];
    for (final m in race.missiles) {
      m.life -= dt;
      m.s += m.speed * dt;
      if (m.s >= track.totalLength) {
        m.s -= track.totalLength;
      }
      final target = m.targetIndex >= 0 ? race.karts[m.targetIndex] : null;
      if (target != null && !target.finished) {
        final wobble = math.min(1.0, 3.0 * dt);
        m.lateral += (target.lateral - m.lateral) * wobble;
      }
      final p = track.posAtS(m.s);
      final ang = track.tangentAngleAtS(m.s);
      m.x = p.dx + math.sin(ang) * m.lateral;
      m.y = p.dy - math.cos(ang) * m.lateral;
      race.addParticle(x: m.x, y: m.y, kind: 0, life: 0.3, size: 2.5);

      var hit = false;
      for (final k in race.karts) {
        if (k.kartIndex == m.ownerIndex || k.finished) {
          continue;
        }
        final dx = k.x - m.x;
        final dy = k.y - m.y;
        if (dx * dx + dy * dy < missileHitRadius * missileHitRadius) {
          spinOut(k, race);
          race.addEvent(EngineEvent.explosion, kartIndex: k.kartIndex);
          for (var i = 0; i < 8; i++) {
            race.addParticle(
              x: k.x,
              y: k.y,
              kind: 2,
              life: 0.6,
              size: 9,
              vx: math.cos(i * math.pi / 4) * 90,
              vy: math.sin(i * math.pi / 4) * 90,
            );
          }
          hit = true;
          break;
        }
      }
      if (hit || m.life <= 0) {
        dead.add(m);
      }
    }
    race.missiles.removeWhere((m) => dead.contains(m));
  }

  static void _updateWaterBombs(
    RaceState race,
    TrackGeometry track,
    double dt,
  ) {
    final dead = <WaterBomb>[];
    for (final w in race.waterBombs) {
      w.life -= dt;
      if (!w.landed) {
        w.x += w.vx * dt;
        w.y += w.vy * dt;
        final decay = math.pow(0.35, dt).toDouble();
        w.vx *= decay;
        w.vy *= decay;
        final proj = track.project(w.x, w.y, w.centerIndex);
        w.centerIndex = proj.index;
        var consumed = false;
        for (final k in race.karts) {
          if (k.kartIndex == w.ownerIndex || k.finished) {
            continue;
          }
          final dx = k.x - w.x;
          final dy = k.y - w.y;
          if (dx * dx + dy * dy < waterHitRadius * waterHitRadius) {
            _splash(race, w.x, w.y);
            spinOut(k, race);
            dead.add(w);
            consumed = true;
            break;
          }
        }
        if (consumed) {
          continue;
        }
        if (proj.lateral.abs() > track.wallLimit || w.life <= 4.1) {
          // 出界或飞行约 0.9s 后落地成水洼
          w.landed = true;
          w.landTimer = 4;
        }
      } else {
        w.landTimer -= dt;
        var consumed = false;
        for (final k in race.karts) {
          if (k.kartIndex == w.ownerIndex || k.finished) {
            continue;
          }
          final dx = k.x - w.x;
          final dy = k.y - w.y;
          if (dx * dx + dy * dy < puddleRadius * puddleRadius && k.speed > 40) {
            _splash(race, w.x, w.y);
            spinOut(k, race);
            dead.add(w);
            consumed = true;
            break;
          }
        }
        if (consumed) {
          continue;
        }
        if (w.landTimer <= 0) {
          dead.add(w);
        }
      }
    }
    race.waterBombs.removeWhere((w) => dead.contains(w));
  }

  static void _splash(RaceState race, double x, double y) {
    for (var i = 0; i < 8; i++) {
      race.addParticle(
        x: x,
        y: y,
        kind: 3,
        life: 0.5,
        size: 6,
        vx: math.cos(i * math.pi / 4) * 70,
        vy: math.sin(i * math.pi / 4) * 70,
      );
    }
  }

  static void _updatePeels(RaceState race, double dt) {
    final dead = <BananaPeel>[];
    for (final p in race.peels) {
      p.life -= dt;
      if (p.life <= 0) {
        dead.add(p);
        continue;
      }
      for (final k in race.karts) {
        if (k.finished) {
          continue;
        }
        final dx = k.x - p.x;
        final dy = k.y - p.y;
        final r = peelRadius + KartPhysics.kartRadius;
        if (dx * dx + dy * dy < r * r && k.speed > 30) {
          spinOut(k, race);
          dead.add(p);
          break;
        }
      }
    }
    race.peels.removeWhere((p) => dead.contains(p));
  }

  /// 导弹目标：进度紧邻其上的车手（无则 -1 直飞）
  static int _targetAhead(KartState k, RaceState race) {
    KartState? best;
    var bestGap = double.infinity;
    for (final other in race.karts) {
      if (other.kartIndex == k.kartIndex || other.finished) {
        continue;
      }
      final gap = other.progress - k.progress;
      if (gap > 0 && gap < bestGap) {
        best = other;
        bestGap = gap;
      }
    }
    return best?.kartIndex ?? -1;
  }
}
