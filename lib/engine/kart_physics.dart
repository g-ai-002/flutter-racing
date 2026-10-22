import 'dart:math' as math;

import '../models/game_enums.dart';
import '../models/kart_state.dart';
import '../models/race_state.dart';
import 'track_geometry.dart';

/// 卡丁车街机物理：速度相关转向、漂移积气、氮气、路面与墙。
class KartPhysics {
  // ---- 纵向性能 ----
  static const double baseMaxSpeed = 230;
  static const double accelRate = 175;
  static const double brakeRate = 330;
  static const double reverseMaxSpeed = 55;
  static const double coastDrag = 42;
  static const double overSpeedDrop = 90;

  // ---- 转向 ----
  static const double baseTurnRate = 2.75;
  static const double driftTurnMul = 1.5;
  static const double driftMinSpeed = 72;

  // ---- 漂移积气（小喷/大喷） ----
  static const double tier1Charge = 1.0;
  static const double tier2Charge = 2.05;
  static const double tier1Boost = 26;
  static const double tier2Boost = 46;
  static const double tier1BoostTime = 0.5;
  static const double tier2BoostTime = 0.9;
  static const double driftBoostPower = 1.12;

  // ---- 路面 ----
  static const double offroadSpeedMul = 0.42;
  static const double offroadExtraDrag = 95;

  // ---- 状态 ----
  static const double spinDuration = 1.1;
  static const double kartRadius = 8.5;

  static double _c(double v, double lo, double hi) =>
      v < lo ? lo : (v > hi ? hi : v);

  static void step({
    required KartState kart,
    required KartInput input,
    required TrackGeometry track,
    required RaceState race,
    required double dt,
  }) {
    final k = kart;
    if (k.boostTimer > 0) {
      k.boostTimer = math.max(0.0, k.boostTimer - dt);
    }
    if (k.shieldTimer > 0) {
      k.shieldTimer = math.max(0.0, k.shieldTimer - dt);
    }
    if (k.itemUseCooldown > 0) {
      k.itemUseCooldown -= dt;
    }
    k.lastSteer = _c(input.steer, -1, 1);

    // 打转：无操控，快速减速原地旋转
    if (k.spinTimer > 0) {
      k.spinTimer -= dt;
      k.angle += 9.5 * dt;
      k.speed *= math.pow(0.35, dt).toDouble();
      k.drifting = false;
      k.driftCharge = 0;
      k.driftTier = 0;
      _moveAndProject(k, track, race, dt);
      return;
    }

    final steer = _c(input.steer, -1, 1);
    _updateDrift(k, input, race, dt);

    // 速度相关转向：低速转不动、高速略迟钝、漂移更凌厉
    final speedFactor = math.min(1.0, k.speed.abs() / 55);
    final dampRange = _c((k.speed - 120) / 120, 0, 1);
    final highSpeedDamp = 1 - 0.38 * dampRange;
    double turn;
    if (k.drifting) {
      final align = 0.6 + 0.5 * (steer * k.driftDir);
      turn = k.driftDir *
          baseTurnRate *
          driftTurnMul *
          k.statHandlingMul *
          speedFactor *
          highSpeedDamp *
          align;
    } else {
      turn = steer * baseTurnRate * k.statHandlingMul * speedFactor * highSpeedDamp;
    }
    k.angle += turn * dt;

    // 纵向控制
    final maxSpeed = _effectiveMaxSpeed(k);
    if (input.brake) {
      if (k.speed > 1) {
        k.speed = math.max(0.0, k.speed - brakeRate * dt);
      } else {
        k.speed = math.max(-reverseMaxSpeed, k.speed - accelRate * 0.6 * dt);
      }
    } else if (input.throttle) {
      if (k.speed < maxSpeed) {
        k.speed = math.min(maxSpeed, k.speed + accelRate * k.statAccelMul * dt);
      } else {
        k.speed = math.max(maxSpeed, k.speed - overSpeedDrop * dt);
      }
    } else {
      if (k.speed > 0) {
        k.speed = math.max(0.0, k.speed - coastDrag * dt);
      }
      if (k.speed < 0) {
        k.speed = math.min(0.0, k.speed + coastDrag * dt);
      }
    }
    if (k.offRoad && k.speed > maxSpeed) {
      k.speed = math.max(maxSpeed, k.speed - offroadExtraDrag * dt);
    }

    _moveAndProject(k, track, race, dt);
    _updateWrongWay(k, track, dt);
    _emitEffects(k, race, dt);
  }

  static double _effectiveMaxSpeed(KartState k) {
    var maxSpeed = baseMaxSpeed * k.statTopSpeedMul;
    if (!k.isPlayer) {
      maxSpeed *= k.aiSkill * k.aiSpeedMul;
    }
    if (k.offRoad) {
      maxSpeed *= offroadSpeedMul;
    }
    if (k.boostTimer > 0) {
      maxSpeed *= k.boostPower;
    }
    return maxSpeed;
  }

  static void _updateDrift(KartState k, KartInput input, RaceState race, double dt) {
    final steer = _c(input.steer, -1, 1);
    final canDrift = input.drift && k.speed > driftMinSpeed && steer.abs() > 0.1;
    if (canDrift && !k.drifting) {
      k.drifting = true;
      k.driftCharge = 0;
      k.driftTier = 0;
      k.driftDir = steer >= 0 ? 1 : -1;
    }
    if (!k.drifting) {
      return;
    }
    if (!input.drift || k.speed < driftMinSpeed * 0.7) {
      // 松开漂移：按积攒档位触发小喷/大喷
      if (k.driftTier > 0) {
        k.speed += k.driftTier == 2 ? tier2Boost : tier1Boost;
        k.boostTimer = k.driftTier == 2 ? tier2BoostTime : tier1BoostTime;
        k.boostPower = driftBoostPower;
        race.addEvent(
          EngineEvent.boostStart,
          kartIndex: k.kartIndex,
          value: k.driftTier,
        );
      }
      k.drifting = false;
      k.driftCharge = 0;
      k.driftTier = 0;
      return;
    }
    k.driftCharge += dt * (0.7 + 0.55 * steer.abs());
    k.driftTier = k.driftCharge >= tier2Charge
        ? 2
        : (k.driftCharge >= tier1Charge ? 1 : 0);
    k.speed -= 6 * dt;
  }

  static void _moveAndProject(
    KartState k,
    TrackGeometry track,
    RaceState race,
    double dt,
  ) {
    k.x += math.cos(k.angle) * k.speed * dt;
    k.y += math.sin(k.angle) * k.speed * dt;

    final proj = track.project(k.x, k.y, k.centerIndex);
    k.centerIndex = proj.index;
    k.prevS = k.s;
    k.s = proj.s;
    k.offRoad = proj.lateral.abs() > track.halfWidth;

    var lateral = proj.lateral;
    final wall = track.wallLimit;
    if (lateral.abs() > wall) {
      // 撞墙：位置钳制回赛道，冲墙分量大时惩罚速度
      final ang = track.tangentAngleAt(proj.index);
      final nx = math.sin(ang);
      final ny = -math.cos(ang);
      final sign = lateral >= 0 ? 1.0 : -1.0;
      final velOut =
          (math.cos(k.angle) * k.speed * nx + math.sin(k.angle) * k.speed * ny) *
              sign;
      lateral = (wall - 0.6) * sign;
      final pos = TrackGeometry.rebuildPosition(proj, track, lateral);
      k.x = pos.dx;
      k.y = pos.dy;
      if (velOut > 60 && k.speed > 60) {
        k.speed *= 0.55;
        race.addParticle(
          x: k.x,
          y: k.y,
          kind: 1,
          life: 0.35,
          size: 5,
          vx: -nx * sign * 50,
          vy: -ny * sign * 50,
        );
      }
    }
    k.lateral = lateral;
  }

  static void _updateWrongWay(KartState k, TrackGeometry track, double dt) {
    if (k.speed < 20) {
      k.wrongWayTimer = 0;
      return;
    }
    final ang = track.tangentAngleAt(k.centerIndex);
    final dot = math.cos(k.angle) * math.cos(ang) +
        math.sin(k.angle) * math.sin(ang);
    if (dot < -0.25) {
      k.wrongWayTimer += dt;
    } else {
      k.wrongWayTimer = 0;
    }
  }

  static void _emitEffects(KartState k, RaceState race, double dt) {
    k.skidAccumulator += dt;
    final cosA = math.cos(k.angle);
    final sinA = math.sin(k.angle);
    if (k.drifting && k.speed > 80) {
      if (k.skidAccumulator >= 0.045) {
        k.skidAccumulator = 0;
        for (final side in const [-4.4, 4.4]) {
          final wx = k.x - cosA * 6.5 - sinA * side;
          final wy = k.y - sinA * 6.5 + cosA * side;
          race.addSkid(
            wx - cosA * k.speed * 0.045,
            wy - sinA * k.speed * 0.045,
            wx,
            wy,
          );
        }
        race.addParticle(
          x: k.x - cosA * 8,
          y: k.y - sinA * 8,
          kind: 0,
          life: 0.55,
          size: 5,
          vx: -cosA * 30 + math.sin(race.raceTime * 17) * 20,
          vy: -sinA * 30 + math.cos(race.raceTime * 13) * 20,
        );
      }
    } else if (k.boostTimer > 0) {
      if (k.skidAccumulator >= 0.03) {
        k.skidAccumulator = 0;
        race.addParticle(
          x: k.x - cosA * 10,
          y: k.y - sinA * 10,
          kind: 2,
          life: 0.28,
          size: 3.5,
          vx: -cosA * 60,
          vy: -sinA * 60,
        );
      }
    }
  }
}
