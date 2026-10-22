import 'dart:ui';

/// 赛道主题（决定配色与装饰物）
enum TrackTheme {
  /// 滨海：草地 + 树
  seaside,

  /// 沙漠：沙地 + 仙人掌
  desert,

  /// 雪山：雪原 + 雪松
  alpine,
}

/// 赛道定义：闭合 Catmull-Rom 控制点 + 路宽 + 主题
///
/// 控制点经过 `.qwen` 侧 Python 数值验证（自交 / 最小弯道半径 / 车道净空），
/// `test/track_geometry_test.dart` 在 CI 中对同样约束回归把关。
class TrackDef {
  final String id;
  final String name;
  final String description;
  final TrackTheme theme;
  final List<Offset> controlPoints;

  /// 半路宽（世界单位）
  final double halfWidth;

  /// 难度 1~3 星
  final int difficulty;

  const TrackDef({
    required this.id,
    required this.name,
    required this.description,
    required this.theme,
    required this.controlPoints,
    required this.halfWidth,
    required this.difficulty,
  });
}

class TrackCatalog {
  TrackCatalog._();

  static const List<TrackDef> all = [
    TrackDef(
      id: 'seaside',
      name: '滨海公路',
      description: '宽阔流畅的沿海赛道，适合漂移积气',
      theme: TrackTheme.seaside,
      halfWidth: 36,
      difficulty: 1,
      controlPoints: [
        Offset(500, 880),
        Offset(760, 890),
        Offset(1000, 880),
        Offset(1210, 800),
        Offset(1330, 620),
        Offset(1300, 420),
        Offset(1160, 330),
        Offset(1000, 390),
        Offset(830, 330),
        Offset(640, 300),
        Offset(450, 350),
        Offset(300, 480),
        Offset(280, 660),
        Offset(330, 800),
      ],
    ),
    TrackDef(
      id: 'desert',
      name: '沙漠绿洲',
      description: '超长直道加回头弯的耐力赛道',
      theme: TrackTheme.desert,
      halfWidth: 34,
      difficulty: 2,
      controlPoints: [
        Offset(560, 900),
        Offset(950, 905),
        Offset(1300, 880),
        Offset(1395, 690),
        Offset(1335, 480),
        Offset(1395, 310),
        Offset(1245, 165),
        Offset(985, 150),
        Offset(650, 150),
        Offset(360, 180),
        Offset(215, 330),
        Offset(225, 500),
        Offset(370, 565),
        Offset(535, 552),
        Offset(700, 545),
        Offset(895, 548),
        Offset(990, 553),
        Offset(1085, 555),
        Offset(1143, 579),
        Offset(1168, 637),
        Offset(1143, 696),
        Offset(1085, 720),
        Offset(995, 722),
        Offset(900, 725),
        Offset(730, 718),
        Offset(560, 715),
        Offset(330, 690),
        Offset(250, 780),
        Offset(300, 870),
      ],
    ),
    TrackDef(
      id: 'alpine',
      name: '雪山峡谷',
      description: '狭窄多弯的冰雪峡谷，考验走线',
      theme: TrackTheme.alpine,
      halfWidth: 30,
      difficulty: 3,
      controlPoints: [
        Offset(430, 870),
        Offset(820, 890),
        Offset(1190, 830),
        Offset(1290, 745),
        Offset(1340, 650),
        Offset(1320, 575),
        Offset(1290, 505),
        Offset(1305, 430),
        Offset(1355, 320),
        Offset(1210, 165),
        Offset(940, 205),
        Offset(700, 150),
        Offset(470, 180),
        Offset(235, 305),
        Offset(175, 490),
        Offset(290, 660),
        Offset(330, 810),
      ],
    ),
  ];

  static TrackDef byId(String id) {
    return all.firstWhere((t) => t.id == id);
  }
}
