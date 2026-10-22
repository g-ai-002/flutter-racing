import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_racing/engine/item_manager.dart';
import 'package:flutter_racing/engine/track_geometry.dart';
import 'package:flutter_racing/models/game_enums.dart';
import 'package:flutter_racing/models/kart_state.dart';
import 'package:flutter_racing/models/race_state.dart';
import 'package:flutter_racing/models/track_def.dart';

void main() {
  final track = TrackGeometry.fromDef(TrackCatalog.all[0]);
  final rng = math.Random(9);

  KartState makeKart(int index) {
    final s = track.totalLength - 100;
    final p = track.posAtS(s);
    final ang = track.tangentAngleAtS(s);
    final k = KartState(
      kartIndex: index,
      x: p.dx,
      y: p.dy,
      angle: ang,
      characterIndex: 0,
      isPlayer: false,
      name: '卡丁车$index',
    );
    final proj = track.project(k.x, k.y, (s / TrackGeometry.spacing).round());
    k.centerIndex = proj.index;
    k.s = proj.s;
    k.prevS = proj.s;
    k.lateral = proj.lateral;
    return k;
  }

  RaceState makeState(List<KartState> karts) {
    return RaceState(mode: RaceMode.itemRace, totalLaps: 3, karts: karts);
  }

  test('道具箱布点在路面内', () {
    final state = makeState([makeKart(0)]);
    ItemManager.initBoxes(state, track, 10);
    expect(state.itemBoxes.length, 10);
    for (var i = 0; i < state.itemBoxes.length; i++) {
      final s = (i + 0.5) * track.totalLength / 10;
      final hint = (s / TrackGeometry.spacing).round() % track.pointCount;
      final box = state.itemBoxes[i];
      final proj = track.project(box.x, box.y, hint);
      expect(proj.lateral.abs(), lessThan(track.halfWidth));
    }
  });

  test('拾取分配道具，道具箱 5 秒后重生', () {
    final k = makeKart(0);
    final state = makeState([k]);
    ItemManager.initBoxes(state, track, 10);
    final box = state.itemBoxes[0];
    k.x = box.x;
    k.y = box.y;

    ItemManager.update(state, track, 1 / 60, rng);
    expect(k.item, isNotNull);
    expect(box.active, isFalse);

    for (var i = 0; i < 60 * 5; i++) {
      ItemManager.update(state, track, 1 / 60, rng);
    }
    expect(box.active, isTrue);
  });

  test('randomItem 权重覆盖全部类型', () {
    final local = math.Random(7);
    final seen = <ItemType>{};
    for (var i = 0; i < 500; i++) {
      seen.add(ItemManager.randomItem(local));
    }
    expect(seen.length, ItemType.values.length);
  });

  test('氮气使用：速度提升并进入喷气状态', () {
    final k = makeKart(0);
    final state = makeState([k]);
    k.item = ItemType.nitro;
    k.speed = 100;
    ItemManager.useItem(k, state, track, rng);
    expect(k.item, isNull);
    expect(k.boostTimer, greaterThan(0));
    expect(k.speed, greaterThan(100));
    expect(state.events.any((e) => e.event == EngineEvent.boostStart), isTrue);
  });

  test('导弹沿赛道追踪并命中前方目标', () {
    final owner = makeKart(0);
    final target = makeKart(1);
    // 目标在 owner 前方 300 单位
    target.s = (owner.s + 300) % track.totalLength;
    final tp = track.posAtS(target.s);
    final ta = track.tangentAngleAtS(target.s);
    target.x = tp.dx;
    target.y = tp.dy;
    target.angle = ta;
    target.centerIndex =
        (target.s / TrackGeometry.spacing).round() % track.pointCount;
    target.progress = owner.progress + 300;

    final state = makeState([owner, target]);
    owner.item = ItemType.missile;
    ItemManager.useItem(owner, state, track, rng);

    expect(state.missiles.length, 1);
    expect(state.missiles.first.targetIndex, target.kartIndex);

    // 导弹 330/s，300 距离 2 秒内必命中
    for (var i = 0; i < 60 * 2 && state.missiles.isNotEmpty; i++) {
      ItemManager.update(state, track, 1 / 60, rng);
    }
    expect(state.missiles, isEmpty);
    expect(target.spinTimer, greaterThan(0));
    expect(state.events.any((e) => e.event == EngineEvent.explosion), isTrue);
  });

  test('护盾抵挡一次攻击后被消耗', () {
    final k = makeKart(0);
    final state = makeState([k]);
    k.shieldTimer = 5;
    k.speed = 200;

    ItemManager.spinOut(k, state);
    expect(k.spinTimer, 0);
    expect(k.shieldTimer, 0);
    expect(state.events.any((e) => e.event == EngineEvent.shieldBlock), isTrue);

    ItemManager.spinOut(k, state);
    expect(k.spinTimer, greaterThan(0));
  });

  test('香蕉皮致打转并消失', () {
    final k = makeKart(0);
    final state = makeState([k]);
    k.speed = 150;
    state.peels.add(BananaPeel(k.x + 5, k.y));
    ItemManager.update(state, track, 1 / 60, rng);
    expect(k.spinTimer, greaterThan(0));
    expect(state.peels, isEmpty);
  });

  test('水弹落地成水洼，碾过致打转', () {
    final owner = makeKart(0);
    final k = makeKart(1);
    // k 先远离水弹落点，避免飞行阶段被误击
    final kp = track.posAtS(owner.s - 200);
    k.x = kp.dx;
    k.y = kp.dy;

    final state = makeState([owner, k]);
    state.waterBombs.add(
      WaterBomb(x: owner.x, y: owner.y, vx: 0, vy: 0, ownerIndex: 0)
        ..centerIndex = owner.centerIndex,
    );

    var steps = 0;
    while (state.waterBombs.isNotEmpty &&
        !state.waterBombs.first.landed &&
        steps < 120) {
      ItemManager.update(state, track, 1 / 60, rng);
      steps++;
    }
    expect(state.waterBombs.first.landed, isTrue);

    // 碾过水洼
    k.speed = 150;
    final w = state.waterBombs.first;
    k.x = w.x;
    k.y = w.y;
    ItemManager.update(state, track, 1 / 60, rng);
    expect(k.spinTimer, greaterThan(0));
    expect(state.waterBombs, isEmpty);
  });

  test('已完赛车手不受道具影响', () {
    final k = makeKart(0);
    k.finishPlace = 1;
    final state = makeState([k]);
    ItemManager.spinOut(k, state);
    expect(k.spinTimer, 0);
  });
}
