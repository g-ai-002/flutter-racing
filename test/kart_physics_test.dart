import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_racing/engine/kart_physics.dart';
import 'package:flutter_racing/engine/track_geometry.dart';
import 'package:flutter_racing/models/game_enums.dart';
import 'package:flutter_racing/models/kart_state.dart';
import 'package:flutter_racing/models/race_state.dart';
import 'package:flutter_racing/models/track_def.dart';

void main() {
  final track = TrackGeometry.fromDef(TrackCatalog.all[0]);
  const dt = 1.0 / 60.0;

  KartState makeKart() {
    final s = track.totalLength - 100;
    final p = track.posAtS(s);
    final ang = track.tangentAngleAtS(s);
    final k = KartState(
      kartIndex: 0,
      x: p.dx,
      y: p.dy,
      angle: ang,
      characterIndex: 0,
      isPlayer: true,
      name: '玩家',
    );
    final proj = track.project(k.x, k.y, (s / TrackGeometry.spacing).round());
    k.centerIndex = proj.index;
    k.s = proj.s;
    k.prevS = proj.s;
    k.lateral = proj.lateral;
    return k;
  }

  RaceState makeState(KartState k) {
    return RaceState(mode: RaceMode.sprint, totalLaps: 3, karts: [k]);
  }

  test('油门加速到极速并保持', () {
    final k = makeKart();
    final state = makeState(k);
    const input = KartInput(throttle: true);
    for (var i = 0; i < 600; i++) {
      KartPhysics.step(kart: k, input: input, track: track, race: state, dt: dt);
    }
    expect(k.speed, closeTo(KartPhysics.baseMaxSpeed, 0.5));
  });

  test('刹车减速到零并可倒车', () {
    final k = makeKart();
    final state = makeState(k);
    k.speed = 120;
    const input = KartInput(brake: true);
    for (var i = 0; i < 60; i++) {
      KartPhysics.step(kart: k, input: input, track: track, race: state, dt: dt);
    }
    expect(k.speed, 0);
    for (var i = 0; i < 60; i++) {
      KartPhysics.step(kart: k, input: input, track: track, race: state, dt: dt);
    }
    expect(k.speed, closeTo(-KartPhysics.reverseMaxSpeed, 2));
  });

  test('转向改变车头方向', () {
    final k = makeKart();
    final state = makeState(k);
    for (var i = 0; i < 60; i++) {
      KartPhysics.step(
        kart: k,
        input: const KartInput(throttle: true),
        track: track,
        race: state,
        dt: dt,
      );
    }
    final before = k.angle;
    for (var i = 0; i < 30; i++) {
      KartPhysics.step(
        kart: k,
        input: const KartInput(steer: 1, throttle: true),
        track: track,
        race: state,
        dt: dt,
      );
    }
    var diff = k.angle - before;
    while (diff > math.pi) {
      diff -= 2 * math.pi;
    }
    while (diff < -math.pi) {
      diff += 2 * math.pi;
    }
    expect(diff, greaterThan(0.3));
  });

  test('漂移积气，松开按档位喷气', () {
    final k = makeKart();
    final state = makeState(k);
    for (var i = 0; i < 150; i++) {
      KartPhysics.step(
        kart: k,
        input: const KartInput(throttle: true),
        track: track,
        race: state,
        dt: dt,
      );
    }
    expect(k.speed, greaterThan(KartPhysics.driftMinSpeed));

    for (var i = 0; i < 100; i++) {
      KartPhysics.step(
        kart: k,
        input: const KartInput(steer: 1, throttle: true, drift: true),
        track: track,
        race: state,
        dt: dt,
      );
    }
    expect(k.drifting, isTrue);
    expect(k.driftTier, greaterThan(0));
    expect(k.driftCharge, greaterThan(KartPhysics.tier1Charge));

    final speedBefore = k.speed;
    state.events.clear();
    for (var i = 0; i < 6; i++) {
      KartPhysics.step(
        kart: k,
        input: const KartInput(throttle: true),
        track: track,
        race: state,
        dt: dt,
      );
    }
    expect(k.drifting, isFalse);
    expect(k.boostTimer, greaterThan(0));
    expect(k.speed, greaterThan(speedBefore));
    final boostEvents = state.events
        .where((e) => e.event == EngineEvent.boostStart)
        .toList();
    expect(boostEvents, isNotEmpty);
    expect(boostEvents.first.value, greaterThan(0));
  });

  test('草地限速', () {
    final k = makeKart();
    final state = makeState(k);
    // 物理上放到路肩草地（半路宽外、墙内）
    final ang = track.tangentAngleAt(k.centerIndex);
    k.x += math.sin(ang) * (track.halfWidth + 8);
    k.y -= math.cos(ang) * (track.halfWidth + 8);
    k.speed = 200;
    const input = KartInput(throttle: true);
    for (var i = 0; i < 120; i++) {
      KartPhysics.step(kart: k, input: input, track: track, race: state, dt: dt);
    }
    expect(k.offRoad, isTrue);
    expect(
      k.speed,
      lessThan(KartPhysics.baseMaxSpeed * KartPhysics.offroadSpeedMul + 2),
    );
  });

  test('撞墙被钳制回赛道', () {
    final k = makeKart();
    final state = makeState(k);
    final ang = track.tangentAngleAt(k.centerIndex);
    k.x += math.sin(ang) * (track.wallLimit + 40);
    k.y -= math.cos(ang) * (track.wallLimit + 40);
    k.speed = 180;
    for (var i = 0; i < 5; i++) {
      KartPhysics.step(
        kart: k,
        input: const KartInput(throttle: true),
        track: track,
        race: state,
        dt: dt,
      );
    }
    expect(k.lateral.abs(), lessThan(track.wallLimit));
  });

  test('打转期间失去操控且快速减速', () {
    final k = makeKart();
    final state = makeState(k);
    k.speed = 200;
    k.spinTimer = 0.6;
    final beforeAngle = k.angle;
    for (var i = 0; i < 30; i++) {
      KartPhysics.step(
        kart: k,
        input: const KartInput(steer: -1, throttle: true),
        track: track,
        race: state,
        dt: dt,
      );
    }
    expect((k.angle - beforeAngle).abs(), greaterThan(1.0));
    expect(k.speed, lessThan(140));
  });
}
