/// 车手角色：颜色与三项属性（极速 / 加速 / 操控）
class RacerCharacter {
  final String id;
  final String name;
  final String tagline;

  /// 车身主色（ARGB，渲染层转 Color）
  final int colorValue;

  /// 极速倍率
  final double topSpeedMul;

  /// 加速倍率
  final double accelMul;

  /// 操控（转向）倍率
  final double handlingMul;

  const RacerCharacter({
    required this.id,
    required this.name,
    required this.tagline,
    required this.colorValue,
    this.topSpeedMul = 1.0,
    this.accelMul = 1.0,
    this.handlingMul = 1.0,
  });
}

class CharacterCatalog {
  CharacterCatalog._();

  static const List<RacerCharacter> all = [
    RacerCharacter(
      id: 'blue',
      name: '蓝隼',
      tagline: '均衡型 · 全能起步',
      colorValue: 0xFF1E88E5,
    ),
    RacerCharacter(
      id: 'red',
      name: '红狐',
      tagline: '极速型 · 直道之王',
      colorValue: 0xFFE53935,
      topSpeedMul: 1.06,
      accelMul: 0.94,
      handlingMul: 0.95,
    ),
    RacerCharacter(
      id: 'green',
      name: '青竹',
      tagline: '爆发型 · 起步迅猛',
      colorValue: 0xFF43A047,
      topSpeedMul: 0.95,
      accelMul: 1.1,
    ),
    RacerCharacter(
      id: 'gold',
      name: '鎏金',
      tagline: '灵动型 · 弯道精灵',
      colorValue: 0xFFFB8C00,
      topSpeedMul: 0.94,
      accelMul: 0.97,
      handlingMul: 1.12,
    ),
  ];

  static RacerCharacter byIndex(int index) {
    return all[index % all.length];
  }
}
