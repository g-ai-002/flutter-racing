import 'platform_info.dart';

/// 各界面展示的玩法提示：桌面端讲键盘，移动端/浏览器讲触屏按钮。
class GameHints {
  GameHints._();

  /// 首页/设置页的单个操作说明条目。
  static List<GameHintRow> get instructions => [
        GameHintRow(throttle, throttleDesc),
        GameHintRow(steering, steeringDesc),
        GameHintRow(drift, driftDesc),
        GameHintRow(item, itemDesc),
        GameHintRow(pause, pauseDesc),
        const GameHintRow('检查点顺序过线', '防止抄近道，逆行会提示'),
      ];

  /// 油门
  static String get throttle => isDesktopPlatform ? '↑ / W' : '自动油门';

  static String get throttleDesc => isDesktopPlatform ? '踩油门加速' : '触屏自动保持油门';

  /// 转向
  static String get steering => isDesktopPlatform ? '← → / A D' : '左右按钮';

  static String get steeringDesc => '转向';

  /// 漂移
  static String get drift => isDesktopPlatform ? '空格（按住）' : '漂移按钮（按住）';

  static String get driftDesc => '按住漂移集气，松开按档位喷气';

  /// 道具
  static String get item => isDesktopPlatform ? 'Ctrl / E' : '道具按钮';

  static String get itemDesc => '使用道具';

  /// 暂停
  static String get pause => isDesktopPlatform ? 'P / Esc' : '右上角暂停按钮';

  static String get pauseDesc => '暂停 / 继续比赛';

  /// 比赛画面倒计时期间显示的一行键位提示。
  static String get inGameLine => isDesktopPlatform
      ? '↑/W 油门 · ←→/AD 转向 · 空格 漂移(集气) · Ctrl/E 道具 · P/Esc 暂停'
      : '左侧方向按钮转向 · 右下漂移按钮集气 · 右侧道具按钮 · 右上角暂停';

  /// 设置页的一句话玩法提示。
  static String get settingsTip => isDesktopPlatform
      ? '按住空格漂移过弯集气，能量条满一档松开小喷、满两档大喷；'
          '直道用氮气道具冲刺，弯道前丢香蕉皮防守。'
      : '按住漂移按钮过弯集气，能量条满一档松开小喷、满两档大喷；'
          '直道点道具按钮用氮气冲刺，弯道前丢香蕉皮防守。';
}

/// 一条「操作 → 说明」提示。
class GameHintRow {
  final String key;
  final String desc;

  const GameHintRow(this.key, this.desc);
}
