class AppConstants {
  AppConstants._();

  static const String appName = '极速卡丁车';
  static const String version = '0.1.2';

  /// 每场比赛圈数
  static const int lapsPerRace = 3;

  /// AI 对手数量（道具赛/竞速赛）
  static const int aiKartCount = 3;

  /// 每条赛道的道具箱数量
  static const int itemBoxCount = 10;

  /// 检查点数量（含起点线，用于防抄近道与计圈）
  static const int checkpointCount = 10;
}
