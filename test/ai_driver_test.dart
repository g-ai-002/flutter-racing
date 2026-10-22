import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_racing/engine/ai_driver.dart';
import 'package:flutter_racing/engine/track_geometry.dart';
import 'package:flutter_racing/models/game_enums.dart';
import 'package:flutter_racing/models/kart_state.dart';
import 'package:flutter_racing/models/race_state.dart';
import 'package:flutter_racing/models/track_def.dart';

void main() {
  final track = TrackGeometry.fromDef(TrackCatalog.all[0]);

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

  test('drive 输出转向在 [-1, 1]', () {
    final k = makeKart(0);
    final state = makeState([k]);
    final input = AiDriver.drive(k, state, track);
    expect(input.steer, inInclusiveRange(-1, 1));
  });

  test('导弹：仅前方 260 内有对手时使用', () {
    final k = makeKart(0)..item = ItemType.missile;

    final behind = makeKart(1);
    behind.progress = k.progress - 100;
    final stateBehind = makeState([k, behind]);
    expect(AiDriver.wantsUseItem(k, stateBehind, track), isFalse);

    final ahead = makeKart(2);
    ahead.progress = k.progress + 200;
    final stateAhead = makeState([k, ahead]);
    expect(AiDriver.wantsUseItem(k, stateAhead, track), isTrue);
  });

  test('氮气：直道使用、弯道不用', () {
    final k = makeKart(0)..item = ItemType.nitro;
    final state = makeState([k]);
    // 放到底部大直道（s=200，滨海公路起跑直道段）
    final startPoint = track.posAtS(200);
    k.x = startPoint.dx;
    k.y = startPoint.dy;
    k.angle = track.tangentAngleAt(100);
    k.centerIndex = 100;
    expect(AiDriver.wantsUseItem(k, state, track), isTrue);

    // 移到全赛道最急弯处
    var maxIdx = 0;
    var maxCurv = 0.0;
    for (var i = 0; i < track.pointCount; i++) {
      if (track.curvature[i] > maxCurv) {
        maxCurv = track.curvature[i];
        maxIdx = i;
      }
    }
    final p = track.pointAt(maxIdx);
    k.x = p.dx;
    k.y = p.dy;
    k.angle = track.tangentAngleAt(maxIdx);
    k.centerIndex = maxIdx;
    expect(AiDriver.wantsUseItem(k, state, track), isFalse);
  });

  test('护盾：仅被导弹瞄准时使用', () {
    final k = makeKart(0)..item = ItemType.shield;
    final state = makeState([k]);
    expect(AiDriver.wantsUseItem(k, state, track), isFalse);
    state.missiles.add(
      Missile(
        x: 0,
        y: 0,
        s: 0,
        lateral: 0,
        speed: 330,
        ownerIndex: 1,
        targetIndex: 0,
      ),
    );
    expect(AiDriver.wantsUseItem(k, state, track), isTrue);
  });

  test('香蕉皮：随时丢弃', () {
    final k = makeKart(0)..item = ItemType.banana;
    final state = makeState([k]);
    expect(AiDriver.wantsUseItem(k, state, track), isTrue);
  });

  test('打转时不做道具决策', () {
    final k = makeKart(0)
      ..item = ItemType.banana
      ..spinTimer = 0.5;
    final state = makeState([k]);
    expect(AiDriver.wantsUseItem(k, state, track), isFalse);
  });
}
