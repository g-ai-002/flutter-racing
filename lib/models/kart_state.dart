import 'game_enums.dart';

/// 每帧驾驶输入
class KartInput {
  /// 转向 -1（左）~ 1（右）
  final double steer;
  final bool throttle;
  final bool brake;
  final bool drift;

  const KartInput({
    this.steer = 0,
    this.throttle = false,
    this.brake = false,
    this.drift = false,
  });

  static const KartInput idle = KartInput();
}

/// 卡丁车运行时状态
class KartState {
  // ---- 运动学 ----
  double x;
  double y;
  double angle;
  double speed;

  // ---- 赛道投影 ----
  int centerIndex = 0;
  double s = 0;
  double prevS = 0;
  double lateral = 0;
  bool offRoad = false;

  // ---- 圈数进度 ----
  int lapsCompleted = 0;
  int lineCrossings = 0;
  int nextCheckpoint = 0;
  double currentLapTime = 0;
  final List<double> lapTimes = [];

  /// 总进度 = 已完成圈数 * 赛道长度 + 当前弧长
  double progress = 0;

  // ---- 漂移 / 氮气 ----
  bool drifting = false;
  double driftCharge = 0;
  int driftTier = 0;
  int driftDir = 1;
  double boostTimer = 0;
  double boostPower = 1.0;

  // ---- 状态效果 ----
  double spinTimer = 0;
  double shieldTimer = 0;

  // ---- 道具 ----
  ItemType? item;
  double itemUseCooldown = 0;

  // ---- 身份 ----
  final int kartIndex;
  final int characterIndex;
  final bool isPlayer;
  final String name;
  final double statTopSpeedMul;
  final double statAccelMul;
  final double statHandlingMul;

  // ---- 名次 ----
  int position = 1;
  int finishPlace = 0;
  double finishTime = 0;

  // ---- AI ----
  final double aiSkill;
  final double aiSeed;
  double aiSpeedMul = 1.0;
  final double aiOffset;
  double aiThinkTimer = 0;

  // ---- 逆行 ----
  double wrongWayTimer = 0;
  bool wrongWay = false;

  // ---- 视觉缓存 ----
  double lastSteer = 0;
  double skidAccumulator = 0;

  bool get finished => finishPlace > 0;

  /// 当前圈（显示用，1-based）
  int get lapDisplay => lapsCompleted + 1;

  KartState({
    required this.kartIndex,
    required this.x,
    required this.y,
    required this.angle,
    this.speed = 0,
    required this.characterIndex,
    required this.isPlayer,
    required this.name,
    this.statTopSpeedMul = 1.0,
    this.statAccelMul = 1.0,
    this.statHandlingMul = 1.0,
    this.aiSkill = 1.0,
    this.aiSeed = 0,
    this.aiOffset = 0,
  });
}
