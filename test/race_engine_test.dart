import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_racing/engine/ai_driver.dart';
import 'package:flutter_racing/engine/race_engine.dart';
import 'package:flutter_racing/models/game_enums.dart';
import 'package:flutter_racing/models/kart_state.dart';
import 'package:flutter_racing/models/race_state.dart';
import 'package:flutter_racing/models/track_def.dart';

/// 全链路集成：倒计时事件、AI 驾驶、计圈、结算。
/// 用 AI 输入驱动"玩家"卡丁车，任何物理/进度/名次缺陷都会在这里暴露。
void main() {
  group('倒计时', () {
    test('3-2-1-GO 事件序列', () {
      final engine = RaceEngine(
        trackDef: TrackCatalog.all[0],
        mode: RaceMode.timeTrial,
        playerCharacterIndex: 0,
      );
      final events = <EngineEventRecord>[];
      for (var i = 0; i < 60 * 4; i++) {
        engine.update(1 / 60, KartInput.idle);
        events.addAll(engine.state.events);
      }
      final ticks = events
          .where((e) => e.event == EngineEvent.countdownTick)
          .map((e) => e.value)
          .toList();
      expect(ticks, [3, 2, 1]);
      expect(events.any((e) => e.event == EngineEvent.go), isTrue);
      expect(engine.state.phase, RacePhase.running);
    });
  });

  test('起跑位在起点线后（负进度），玩家原地不动时名次殿后', () {
    final engine = RaceEngine(
      trackDef: TrackCatalog.all[0],
      mode: RaceMode.sprint,
      playerCharacterIndex: 0,
    );
    final player = engine.state.player;
    expect(player.progress, lessThan(0));
    // AI 出发，玩家原地不动
    for (var i = 0; i < 60 * 3; i++) {
      engine.update(1 / 60, KartInput.idle);
    }
    expect(player.position, 4);
  });

  test('计时赛：AI 输入驱动玩家完成 3 圈并结算', () {
    final engine = RaceEngine(
      trackDef: TrackCatalog.all[0],
      mode: RaceMode.timeTrial,
      playerCharacterIndex: 0,
      seed: 11,
    );
    const dt = 1 / 60;
    var steps = 0;
    while (engine.state.phase != RacePhase.finished && steps < 60 * 100) {
      final input = AiDriver.drive(
        engine.state.player,
        engine.state,
        engine.track,
      );
      engine.update(dt, input);
      steps++;
    }
    expect(engine.state.phase, RacePhase.finished);
    final player = engine.state.player;
    expect(player.lapTimes.length, 3);
    expect(player.finishTime, greaterThan(0));
    for (final t in player.lapTimes) {
      expect(t, inExclusiveRange(5, 90));
    }
    final results = engine.state.results;
    expect(results, isNotNull);
    expect(results!.length, 1);
    expect(results.first.place, 1);
  }, timeout: const Timeout(Duration(minutes: 2)));

  for (final def in TrackCatalog.all) {
    test('竞速赛(${def.name})：全链路完成比赛，名次 1-4 唯一', () {
      final engine = RaceEngine(
        trackDef: def,
        mode: RaceMode.sprint,
        playerCharacterIndex: 0,
        seed: 13,
      );
      const dt = 1 / 60;
      var steps = 0;
      while (engine.state.phase != RacePhase.finished && steps < 60 * 130) {
        final input = AiDriver.drive(
          engine.state.player,
          engine.state,
          engine.track,
        );
        engine.update(dt, input);
        steps++;
      }
      expect(engine.state.phase, RacePhase.finished);
      final results = engine.state.results!;
      expect(results.length, 4);
      final places = results.map((r) => r.place).toList()..sort();
      expect(places, [1, 2, 3, 4]);
      final player = engine.state.player;
      expect(player.lapTimes.length, 3);
      // 结束时所有卡丁车仍在赛道边界附近
      for (final k in engine.state.karts) {
        expect(k.lateral.abs(), lessThan(def.halfWidth + 45));
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
