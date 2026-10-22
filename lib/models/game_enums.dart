/// 比赛模式
enum RaceMode {
  /// 道具赛：可拾取并使用道具
  itemRace,

  /// 竞速赛：无道具，专注漂移与氮气
  sprint,

  /// 计时赛：单人挑战圈速
  timeTrial,
}

/// 比赛阶段
enum RacePhase {
  /// 倒计时
  countdown,

  /// 比赛进行中
  running,

  /// 已结束（玩家冲线）
  finished,
}

/// 道具类型
enum ItemType {
  /// 氮气加速
  nitro,

  /// 追踪导弹（命中前方对手）
  missile,

  /// 水弹（前方抛物，落地成水洼）
  waterBomb,

  /// 香蕉皮（身后掉落）
  banana,

  /// 护盾（抵挡一次攻击）
  shield,
}

extension ItemTypeX on ItemType {
  String get label {
    return switch (this) {
      ItemType.nitro => '氮气',
      ItemType.missile => '追踪导弹',
      ItemType.waterBomb => '水弹',
      ItemType.banana => '香蕉皮',
      ItemType.shield => '护盾',
    };
  }
}

extension RaceModeX on RaceMode {
  String get label {
    return switch (this) {
      RaceMode.itemRace => '道具赛',
      RaceMode.sprint => '竞速赛',
      RaceMode.timeTrial => '计时赛',
    };
  }

  String get description {
    return switch (this) {
      RaceMode.itemRace => '拾取道具，用导弹与氮气对抗 3 名 AI 车手',
      RaceMode.sprint => '纯速度对决，漂移集气释放氮气',
      RaceMode.timeTrial => '单人挑战，刷新每条赛道的最佳圈速',
    };
  }
}

/// 引擎事件（由引擎产生，Provider 翻译为音效/横幅等表现）
enum EngineEvent {
  countdownTick,
  go,
  lapComplete,
  finalLap,
  finish,
  itemPickup,
  boostStart,
  missileLaunch,
  waterDrop,
  bananaDrop,
  shieldBlock,
  spinOut,
  explosion,
  wrongWayStart,
  wrongWayEnd,
}
