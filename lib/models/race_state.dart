import 'game_enums.dart';
import 'kart_state.dart';

/// 引擎事件记录（Provider 消费后清空）
class EngineEventRecord {
  final EngineEvent event;
  final int kartIndex;
  final int value;

  const EngineEventRecord(this.event, {this.kartIndex = -1, this.value = 0});
}

/// 道具箱
class ItemBox {
  double x;
  double y;
  bool active = true;
  double respawnTimer = 0;

  ItemBox(this.x, this.y);
}

/// 追踪导弹：沿赛道中心线推进，横向向目标靠拢
class Missile {
  double x;
  double y;
  double s;
  double lateral;
  final double speed;
  double life = 4.0;
  final int ownerIndex;
  final int targetIndex;

  Missile({
    required this.x,
    required this.y,
    required this.s,
    required this.lateral,
    required this.speed,
    required this.ownerIndex,
    required this.targetIndex,
  });
}

/// 水弹：先飞行，落地成水洼
class WaterBomb {
  double x;
  double y;
  double vx;
  double vy;
  double life = 5.0;
  bool landed = false;
  double landTimer = 0;
  int centerIndex = 0;
  final int ownerIndex;

  WaterBomb({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.ownerIndex,
  });
}

/// 香蕉皮
class BananaPeel {
  double x;
  double y;
  double life = 30;

  BananaPeel(this.x, this.y);
}

/// 粒子：0 烟雾 / 1 火花 / 2 爆炸 / 3 水花
class Particle {
  double x;
  double y;
  double vx;
  double vy;
  double life;
  final double maxLife;
  final double size;
  final int kind;

  Particle({
    required this.x,
    required this.y,
    required this.life,
    required this.kind,
    this.vx = 0,
    this.vy = 0,
    this.size = 4,
  }) : maxLife = life;
}

/// 漂移胎痕
class SkidMark {
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  double age = 0;

  SkidMark(this.x1, this.y1, this.x2, this.y2);
}

/// 结算行
class ResultRow {
  final int kartIndex;
  final int place;
  final bool finished;
  final double totalTime;
  final double bestLap;

  const ResultRow({
    required this.kartIndex,
    required this.place,
    required this.finished,
    required this.totalTime,
    required this.bestLap,
  });
}

/// 比赛总状态
class RaceState {
  final RaceMode mode;
  final int totalLaps;
  final List<KartState> karts;
  final List<ItemBox> itemBoxes;
  final List<Missile> missiles;
  final List<WaterBomb> waterBombs;
  final List<BananaPeel> peels;
  final List<Particle> particles;
  final List<SkidMark> skidMarks;
  final List<EngineEventRecord> events;
  List<ResultRow>? results;

  RacePhase phase = RacePhase.countdown;
  double countdown = 3.6;
  double raceTime = 0;

  static const int _maxParticles = 260;
  static const int _maxSkidMarks = 420;

  RaceState({
    required this.mode,
    required this.totalLaps,
    required this.karts,
  })  : itemBoxes = [],
        missiles = [],
        waterBombs = [],
        peels = [],
        particles = [],
        skidMarks = [],
        events = [];

  bool get itemsEnabled => mode == RaceMode.itemRace;

  KartState get player => karts.firstWhere((k) => k.isPlayer);

  void addEvent(EngineEvent event, {int kartIndex = -1, int value = 0}) {
    events.add(EngineEventRecord(event, kartIndex: kartIndex, value: value));
  }

  void addParticle({
    required double x,
    required double y,
    required int kind,
    double vx = 0,
    double vy = 0,
    double life = 0.6,
    double size = 4,
  }) {
    if (particles.length >= _maxParticles) {
      particles.removeRange(0, particles.length - _maxParticles + 1);
    }
    particles.add(
      Particle(x: x, y: y, life: life, kind: kind, vx: vx, vy: vy, size: size),
    );
  }

  void addSkid(double x1, double y1, double x2, double y2) {
    if (skidMarks.length >= _maxSkidMarks) {
      skidMarks.removeRange(0, skidMarks.length - _maxSkidMarks + 1);
    }
    skidMarks.add(SkidMark(x1, y1, x2, y2));
  }
}
