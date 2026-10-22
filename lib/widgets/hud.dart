import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/kart_physics.dart';
import '../engine/track_geometry.dart';
import '../models/character.dart';
import '../models/game_enums.dart';
import '../models/race_state.dart';
import 'item_icon.dart';

/// 时间格式化：95.34s → '1:35.34'
String formatRaceTime(double seconds) {
  if (seconds <= 0) {
    return '—';
  }
  final m = (seconds / 60).floor();
  final s = seconds - m * 60;
  if (m == 0) {
    return '${s.toStringAsFixed(2)}s';
  }
  return '$m:${s.toStringAsFixed(2).padLeft(5, '0')}';
}

/// 小地图画笔（比赛实时 + 赛道选择静态预览共用）。
/// [state] 为 null 时仅画赛道轮廓（静态预览）。
class MiniMapPainter extends CustomPainter {
  final TrackGeometry track;
  final RaceState? state;

  const MiniMapPainter({required this.track, this.state});

  @override
  void paint(Canvas canvas, Size size) {
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final p in track.points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    final w = math.max(1.0, maxX - minX);
    final h = math.max(1.0, maxY - minY);
    final scale = math.min(
      (size.width - 14) / w,
      (size.height - 14) / h,
    );
    final offsetX = (size.width - w * scale) / 2 - minX * scale;
    final offsetY = (size.height - h * scale) / 2 - minY * scale;

    Offset map(Offset p) {
      return Offset(p.dx * scale + offsetX, p.dy * scale + offsetY);
    }

    final path = Path()..moveTo(map(track.points[0]).dx, map(track.points[0]).dy);
    for (var i = 6; i <= track.pointCount; i += 6) {
      final p = map(track.pointAt(i));
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..color = Colors.white.withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      map(track.points[0]),
      2.2,
      Paint()..color = const Color(0xFFFFC107),
    );

    final live = state;
    if (live != null) {
      for (final k in live.karts) {
        final pos = map(Offset(k.x, k.y));
        if (k.isPlayer) {
          canvas.drawCircle(
            pos,
            5,
            Paint()..color = Colors.white.withValues(alpha: 0.9),
          );
        }
        canvas.drawCircle(
          pos,
          k.isPlayer ? 3.2 : 2.6,
          Paint()..color = Color(CharacterCatalog.byIndex(k.characterIndex).colorValue),
        );
      }
    }
  }

  @override
  bool shouldRepaint(MiniMapPainter oldDelegate) {
    return state != null || oldDelegate.state != null;
  }
}

/// 左上名次列表面板
class StandingsPanel extends StatelessWidget {
  final RaceState state;

  const StandingsPanel({super.key, required this.state});

  static const _placeColors = [
    Color(0xFFFFD700),
    Color(0xFFC0C0C0),
    Color(0xFFCD7F32),
    Color(0xFF78909C),
  ];

  @override
  Widget build(BuildContext context) {
    final karts = [...state.karts]..sort((a, b) => a.position - b.position);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final k in karts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor:
                          _placeColors[(k.position - 1) % _placeColors.length],
                      child: Text(
                        '${k.position}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(
                        CharacterCatalog.byIndex(k.characterIndex).colorValue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    k.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: k.isPlayer ? const Color(0xFFFFE082) : Colors.white,
                      fontWeight: k.isPlayer ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 中上圈数/计时面板
class LapPanel extends StatelessWidget {
  final RaceState state;
  final double? bestLap;

  const LapPanel({super.key, required this.state, this.bestLap});

  @override
  Widget build(BuildContext context) {
    final player = state.player;
    final lap = math.min(player.lapDisplay, state.totalLaps);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '第 $lap / ${state.totalLaps} 圈',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '本圈 ${formatRaceTime(player.currentLapTime)}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          if (bestLap != null)
            Text(
              '最佳圈 ${formatRaceTime(bestLap!)}',
              style: const TextStyle(fontSize: 10, color: Color(0xFFFFC107)),
            ),
        ],
      ),
    );
  }
}

/// 左下速度表面板
class SpeedometerPanel extends StatelessWidget {
  final double speed;
  final bool boost;

  const SpeedometerPanel({super.key, required this.speed, required this.boost});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 96,
      child: CustomPaint(
        painter: _SpeedoPainter(speed: speed, boost: boost),
      ),
    );
  }
}

class _SpeedoPainter extends CustomPainter {
  final double speed;
  final bool boost;

  const _SpeedoPainter({required this.speed, required this.boost});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.82;
    final r = size.height * 0.66;
    const start = math.pi * 0.78;
    const sweep = math.pi * 1.44;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = Colors.white.withValues(alpha: 0.14),
    );

    final frac =
        (speed / (KartPhysics.baseMaxSpeed * 1.15)).clamp(0.0, 1.0).toDouble();
    if (frac > 0.01) {
      canvas.drawArc(
        rect,
        start,
        sweep * frac,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..color = boost ? const Color(0xFFFF9800) : const Color(0xFF64B5F6),
      );
    }

    // 刻度
    final tick = Paint()
      ..strokeWidth = 1.6
      ..color = Colors.white.withValues(alpha: 0.35);
    for (var i = 0; i <= 4; i++) {
      final a = start + sweep * i / 4;
      canvas.drawLine(
        Offset(cx + math.cos(a) * (r - 2), cy + math.sin(a) * (r - 2)),
        Offset(cx + math.cos(a) * (r + 5), cy + math.sin(a) * (r + 5)),
        tick,
      );
    }

    // 指针
    final na = start + sweep * frac;
    canvas.drawLine(
      Offset(cx - math.cos(na) * 6, cy - math.sin(na) * 6),
      Offset(cx + math.cos(na) * (r - 8), cy + math.sin(na) * (r - 8)),
      Paint()
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = Colors.white,
    );
    canvas.drawCircle(Offset(cx, cy), 3, Paint()..color = Colors.white);

    // 数字
    final kmh = (speed * 0.9).round();
    final tp = TextPainter(
      text: TextSpan(
        text: '$kmh',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - 34));
    final tp2 = TextPainter(
      text: TextSpan(
        text: 'km/h',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 9,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(canvas, Offset(cx - tp2.width / 2, cy - 16));
  }

  @override
  bool shouldRepaint(_SpeedoPainter oldDelegate) =>
      oldDelegate.speed != speed || oldDelegate.boost != boost;
}

/// 桌面端道具槽（移动端道具由触屏按钮承担）
class ItemSlotPanel extends StatelessWidget {
  final ItemType? item;

  const ItemSlotPanel({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ItemIcon(item: item, size: 44),
          const SizedBox(height: 4),
          Text(
            item?.label ?? '无道具',
            style: TextStyle(
              fontSize: 10,
              color: item == null
                  ? Colors.white.withValues(alpha: 0.45)
                  : Colors.white,
            ),
          ),
          Text(
            '按 Ctrl 使用',
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// 中央倒计时 / GO!
class CountdownOverlay extends StatelessWidget {
  final RaceState state;

  const CountdownOverlay({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    String? text;
    Color color = Colors.white;
    if (state.phase == RacePhase.countdown) {
      text = '${math.min(3, state.countdown.ceil())}';
    } else if (state.phase == RacePhase.running && state.raceTime < 0.75) {
      text = 'GO!';
      color = const Color(0xFF66BB6A);
    }
    if (text == null) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: Text(
            text,
            key: ValueKey(text),
            style: TextStyle(
              fontSize: 88,
              fontWeight: FontWeight.bold,
              color: color,
              shadows: const [
                Shadow(blurRadius: 18, color: Colors.black54),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 逆行警告横幅
class WrongWayBanner extends StatelessWidget {
  const WrongWayBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 64),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE53935).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.u_turn_left, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  '行驶方向反了，请掉头！',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 最后一圈横幅
class FinalLapBanner extends StatelessWidget {
  const FinalLapBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Center(
        child: Text(
          '最后一圈！',
          style: TextStyle(
            fontSize: 46,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFC107),
            shadows: [Shadow(blurRadius: 16, color: Colors.black54)],
          ),
        ),
      ),
    );
  }
}

/// 桌面端键位提示（倒计时期间显示）
class DesktopKeysHint extends StatelessWidget {
  const DesktopKeysHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        '↑/W 油门 · ←→/AD 转向 · 空格 漂移(集气) · Ctrl/E 道具 · P/Esc 暂停',
        style: TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}
