import 'dart:math' as math;

import '../models/character.dart';
import '../models/game_enums.dart';
import '../models/kart_state.dart';
import '../models/race_state.dart';
import '../models/track_def.dart';
import '../utils/constants.dart';
import 'ai_driver.dart';
import 'item_manager.dart';
import 'kart_physics.dart';
import 'track_geometry.dart';

/// 比赛编排：倒计时、物理推进、AI、道具、圈数/名次、结算。
class RaceEngine {
  final TrackDef trackDef;
  final TrackGeometry track;
  final RaceState state;
  final math.Random _rng;
  int _finishCounter = 0;

  RaceEngine._(this.trackDef, this.track, RaceMode mode, this._rng)
      : state = RaceState(
          mode: mode,
          totalLaps: AppConstants.lapsPerRace,
          karts: [],
        );

  factory RaceEngine({
    required TrackDef trackDef,
    required RaceMode mode,
    required int playerCharacterIndex,
    int seed = 7,
  }) {
    final engine = RaceEngine._(
      trackDef,
      TrackGeometry.fromDef(trackDef),
      mode,
      math.Random(seed),
    );
    engine._spawn(mode, playerCharacterIndex);
    return engine;
  }

  void _spawn(RaceMode mode, int playerCharacterIndex) {
    final playerChar = CharacterCatalog.byIndex(playerCharacterIndex);
    if (mode == RaceMode.timeTrial) {
      _addKart(
        character: playerChar,
        isPlayer: true,
        spawnS: track.totalLength - 16,
        lateral: 0,
      );
    } else {
      // AI 角色从玩家之外的池中轮转分配
      final pool = <int>[
        for (var i = 0; i < CharacterCatalog.all.length; i++)
          if (i != playerCharacterIndex % CharacterCatalog.all.length) i,
      ];
      const aiSkills = [0.90, 0.94, 0.97];
      for (var i = 0; i < AppConstants.aiKartCount; i++) {
        _addKart(
          character: CharacterCatalog.byIndex(pool[i % pool.length]),
          isPlayer: false,
          spawnS: track.totalLength - (14 + i * 18),
          lateral: (i % 2 == 0 ? -1.0 : 1.0) * track.halfWidth * 0.35,
          aiSkill: aiSkills[i],
          aiSeed: i * 7.3,
          aiOffset: (_rng.nextDouble() * 2 - 1) * track.halfWidth * 0.3,
        );
      }
      _addKart(
        character: playerChar,
        isPlayer: true,
        spawnS: track.totalLength - (14 + AppConstants.aiKartCount * 18),
        lateral: track.halfWidth * 0.35,
      );
    }
    if (state.itemsEnabled) {
      ItemManager.initBoxes(state, track, AppConstants.itemBoxCount);
    }
    // 初始投影（起跑位在赛道索引尾段，hint 直接从弧长换算）
    for (final k in state.karts) {
      final hint = (k.s / TrackGeometry.spacing).round() % track.pointCount;
      final proj = track.project(k.x, k.y, hint);
      k.centerIndex = proj.index;
      k.s = proj.s;
      k.prevS = k.s;
      k.lateral = proj.lateral;
      k.progress = k.s - track.totalLength;
    }
  }

  KartState _addKart({
    required RacerCharacter character,
    required bool isPlayer,
    required double spawnS,
    required double lateral,
    double aiSkill = 1,
    double aiSeed = 0,
    double aiOffset = 0,
  }) {
    final wrappedS = spawnS % track.totalLength;
    final p = track.posAtS(wrappedS);
    final ang = track.tangentAngleAtS(wrappedS);
    final kart = KartState(
      kartIndex: state.karts.length,
      x: p.dx + math.sin(ang) * lateral,
      y: p.dy - math.cos(ang) * lateral,
      angle: ang,
      characterIndex: CharacterCatalog.all.indexOf(character),
      isPlayer: isPlayer,
      name: isPlayer ? '${character.name}（你）' : character.name,
      statTopSpeedMul: character.topSpeedMul,
      statAccelMul: character.accelMul,
      statHandlingMul: character.handlingMul,
      aiSkill: aiSkill,
      aiSeed: aiSeed,
      aiOffset: aiOffset,
    );
    kart.s = wrappedS;
    state.karts.add(kart);
    return kart;
  }

  void update(double dt, KartInput playerInput) {
    state.events.clear();
    switch (state.phase) {
      case RacePhase.countdown:
        _updateCountdown(dt);
        return;
      case RacePhase.finished:
        return;
      case RacePhase.running:
        break;
    }
    state.raceTime += dt;
    for (final k in state.karts) {
      final input = k.isPlayer ? playerInput : AiDriver.drive(k, state, track);
      KartPhysics.step(
        kart: k,
        input: input,
        track: track,
        race: state,
        dt: dt,
      );
      if (!k.finished) {
        k.currentLapTime += dt;
        _updateProgress(k);
      }
    }
    _resolveCollisions();
    if (state.itemsEnabled) {
      ItemManager.update(state, track, dt, _rng);
      _aiThinkItems(dt);
    }
    _updateRubberBand(dt);
    _updateParticles(dt);
    _updatePositions();
    _updateWrongWayEvents();
  }

  /// 玩家使用当前道具
  void usePlayerItem() {
    ItemManager.useItem(state.player, state, track, _rng);
  }

  void _updateCountdown(double dt) {
    final prev = state.countdown.ceil();
    state.countdown -= dt;
    final now = state.countdown.ceil();
    if (now != prev && now >= 1 && now <= 3) {
      state.addEvent(EngineEvent.countdownTick, value: now);
    }
    if (state.countdown <= 0) {
      state.phase = RacePhase.running;
      state.raceTime = 0;
      state.addEvent(EngineEvent.go);
    }
  }

  /// 检查点顺序推进 + 起跑线计圈（正向跨越判定，含回绕）
  void _updateProgress(KartState k) {
    final cpCount = track.checkpoints.length;
    var guard = 0;
    while (guard++ < cpCount) {
      final next = k.nextCheckpoint;
      final cpS = track.checkpoints[next] * TrackGeometry.spacing;
      if (!_crossedForward(k.prevS, k.s, cpS)) {
        break;
      }
      k.nextCheckpoint = (next + 1) % cpCount;
      if (next == 0) {
        _onCrossStartLine(k);
      }
    }
    final us = k.lineCrossings == 0 ? k.s - track.totalLength : k.s;
    k.progress = k.lapsCompleted * track.totalLength + us;
  }

  /// [prevS, s) 是否正向跨越 target（s 单调回绕）
  static bool _crossedForward(double prevS, double s, double target) {
    if (prevS <= s) {
      return prevS <= target && target < s;
    }
    return target >= prevS || target < s;
  }

  void _onCrossStartLine(KartState k) {
    k.lineCrossings++;
    if (k.lineCrossings >= 2) {
      k.lapsCompleted = k.lineCrossings - 1;
      k.lapTimes.add(k.currentLapTime);
      if (k.lapsCompleted >= state.totalLaps) {
        k.finishPlace = ++_finishCounter;
        k.finishTime = state.raceTime;
        if (k.isPlayer) {
          _finishRace();
        }
      } else if (k.isPlayer) {
        state.addEvent(
          k.lapsCompleted == state.totalLaps - 1
              ? EngineEvent.finalLap
              : EngineEvent.lapComplete,
          kartIndex: k.kartIndex,
        );
      }
    }
    k.currentLapTime = 0;
  }

  void _finishRace() {
    state.phase = RacePhase.finished;
    // 未完赛的 AI 按进度补齐名次
    final rest = state.karts.where((k) => !k.finished).toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));
    for (final k in rest) {
      k.finishPlace = ++_finishCounter;
      k.finishTime = state.raceTime;
    }
    final sorted = [...state.karts]
      ..sort((a, b) => a.finishPlace.compareTo(b.finishPlace));
    state.results = [
      for (final k in sorted)
        ResultRow(
          kartIndex: k.kartIndex,
          place: k.finishPlace,
          finished: k.lapsCompleted >= state.totalLaps,
          totalTime: k.finishTime,
          bestLap: k.lapTimes.isEmpty ? 0 : k.lapTimes.reduce(math.min),
        ),
    ];
  }

  void _resolveCollisions() {
    final karts = state.karts;
    final minD = KartPhysics.kartRadius * 2;
    for (var i = 0; i < karts.length; i++) {
      for (var j = i + 1; j < karts.length; j++) {
        final a = karts[i];
        final b = karts[j];
        final dx = b.x - a.x;
        final dy = b.y - a.y;
        final d2 = dx * dx + dy * dy;
        if (d2 > minD * minD || d2 < 1e-9) {
          continue;
        }
        final d = math.sqrt(d2);
        final overlap = (minD - d) / 2;
        final nx = dx / d;
        final ny = dy / d;
        a.x -= nx * overlap;
        a.y -= ny * overlap;
        b.x += nx * overlap;
        b.y += ny * overlap;
        a.speed *= 0.97;
        b.speed *= 0.97;
        state.addParticle(
          x: (a.x + b.x) / 2,
          y: (a.y + b.y) / 2,
          kind: 1,
          life: 0.25,
          size: 3.5,
        );
      }
    }
  }

  void _aiThinkItems(double dt) {
    for (final k in state.karts) {
      if (k.isPlayer || k.finished) {
        continue;
      }
      k.aiThinkTimer -= dt;
      if (k.aiThinkTimer > 0) {
        continue;
      }
      k.aiThinkTimer = 0.5;
      if (AiDriver.wantsUseItem(k, state, track)) {
        ItemManager.useItem(k, state, track, _rng);
      }
    }
  }

  /// 橡皮筋难度：AI 落后提速、领先减速，保持与玩家的追逐感
  void _updateRubberBand(double dt) {
    if (state.mode == RaceMode.timeTrial) {
      return;
    }
    final player = state.player;
    for (final k in state.karts) {
      if (k.isPlayer || k.finished) {
        continue;
      }
      final diff = player.progress - k.progress;
      double target = 1.0;
      if (diff > 150) {
        target = 1.07;
      } else if (diff < -150) {
        target = 0.92;
      }
      k.aiSpeedMul += (target - k.aiSpeedMul) * math.min(1.0, dt * 0.8);
    }
  }

  void _updateParticles(double dt) {
    final dead = <dynamic>[];
    for (final p in state.particles) {
      p.life -= dt;
      if (p.life <= 0) {
        dead.add(p);
        continue;
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      final decay = math.pow(0.5, dt).toDouble();
      p.vx *= decay;
      p.vy *= decay;
    }
    state.particles.removeWhere((p) => dead.contains(p));
    state.skidMarks.removeWhere((sk) => (sk.age += dt) > 6);
  }

  void _updatePositions() {
    final sorted = [...state.karts]
      ..sort((a, b) {
        if (a.finished && b.finished) {
          return a.finishPlace - b.finishPlace;
        }
        if (a.finished) {
          return -1;
        }
        if (b.finished) {
          return 1;
        }
        return b.progress.compareTo(a.progress);
      });
    for (var i = 0; i < sorted.length; i++) {
      sorted[i].position = i + 1;
    }
  }

  void _updateWrongWayEvents() {
    final player = state.player;
    final was = player.wrongWay;
    final now = player.wrongWayTimer > 0.7;
    player.wrongWay = now;
    if (now && !was) {
      state.addEvent(EngineEvent.wrongWayStart, kartIndex: player.kartIndex);
    } else if (!now && was) {
      state.addEvent(EngineEvent.wrongWayEnd, kartIndex: player.kartIndex);
    }
  }
}
