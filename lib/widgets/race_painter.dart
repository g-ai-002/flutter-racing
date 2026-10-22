import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/kart_physics.dart';
import '../engine/track_geometry.dart';
import '../models/character.dart';
import '../models/kart_state.dart';
import '../models/race_state.dart';
import '../models/track_def.dart';
import 'static_track_layer.dart';

/// 世界渲染器：俯视角 2D，镜头随玩家车头方向旋转（车头永远朝上）。
class RacePainter extends CustomPainter {
  final RaceState state;
  final TrackGeometry track;
  final TrackDef trackDef;
  final StaticTrackLayer? staticLayer;
  final double camX;
  final double camY;
  final double zoom;

  static bool _paintErrorLogged = false;

  RacePainter({
    required this.state,
    required this.track,
    required this.trackDef,
    required this.staticLayer,
    required this.camX,
    required this.camY,
    required this.zoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    try {
      _paintScene(canvas, size);
    } catch (e, stack) {
      if (!_paintErrorLogged) {
        _paintErrorLogged = true;
        // 走 Flutter 全局错误通道，由 main.dart 统一写入日志文件
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: e,
            stack: stack,
            library: 'flutter_racing',
            context: ErrorDescription('比赛画面渲染'),
          ),
        );
      }
      _paintErrorFallback(canvas, size);
    }
  }

  /// 渲染异常时的保护画面，避免持续黑屏且给出反馈指引
  void _paintErrorFallback(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF11151A),
    );
    final tp = TextPainter(
      text: const TextSpan(
        text: '渲染异常 · 请到 设置 → 查看日志 复制日志反馈',
        style: TextStyle(color: Colors.white70, fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 48);
    tp.paint(canvas, Offset(24, size.height / 2 - tp.height / 2));
  }

  void _paintScene(Canvas canvas, Size size) {
    final player = state.player;
    canvas.save();
    canvas.translate(size.width / 2, size.height * 0.58);
    canvas.rotate(-player.angle - math.pi / 2);
    canvas.scale(zoom);
    canvas.translate(-camX, -camY);

    _paintStatic(canvas, size);
    _paintSkidMarks(canvas);
    _paintPeels(canvas);
    _paintItemBoxes(canvas);
    _paintWaterBombs(canvas);
    _paintMissiles(canvas);
    _paintKarts(canvas);
    _paintParticles(canvas);
    canvas.restore();

    if (staticLayer == null) {
      _paintWorldNotice(canvas, size);
    }
    _paintSpeedLines(canvas, size);
  }

  /// 静态赛道层构建失败时，在屏幕空间给出明确提示（避免无提示黑屏）
  void _paintWorldNotice(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: const TextSpan(
        text: '赛道资源不可用 · 请到 设置 → 查看日志 反馈',
        style: TextStyle(color: Colors.white70, fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 48);
    tp.paint(canvas, const Offset(24, 24));
  }

  void _paintStatic(Canvas canvas, Size size) {
    final layer = staticLayer;
    if (layer != null) {
      canvas.drawPicture(layer.picture);
      return;
    }
    // 静态层构建失败：主题地面色兜底
    final ground = switch (trackDef.theme) {
      TrackTheme.seaside => const Color(0xFF7CB342),
      TrackTheme.desert => const Color(0xFFEDD892),
      TrackTheme.alpine => const Color(0xFFE8F1F5),
    };
    final visible = Rect.fromCircle(
      center: Offset(camX, camY),
      radius: size.longestSide / zoom + 40,
    );
    canvas.drawRect(visible, Paint()..color = ground);
  }

  void _paintSkidMarks(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    for (final sk in state.skidMarks) {
      final alpha = 0.28 * (1 - sk.age / 6);
      if (alpha <= 0.02) {
        continue;
      }
      paint.color = Colors.black.withValues(alpha: alpha);
      canvas.drawLine(Offset(sk.x1, sk.y1), Offset(sk.x2, sk.y2), paint);
    }
  }

  void _paintPeels(Canvas canvas) {
    final peel = Paint()..style = PaintingStyle.fill;
    final tip = Paint()..color = const Color(0xFF6D4C41);
    for (final p in state.peels) {
      final alpha = (p.life / 30).clamp(0.5, 1.0).toDouble();
      peel.color = const Color(0xFFFDD835).withValues(alpha: alpha);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(p.x, p.y), radius: 5),
        0.25,
        math.pi * 0.95,
        true,
        peel,
      );
      canvas.drawCircle(Offset(p.x + 4.4, p.y - 3), 1.1, tip);
    }
  }

  void _paintItemBoxes(Canvas canvas) {
    final time = state.raceTime;
    var i = 0;
    for (final box in state.itemBoxes) {
      if (box.active) {
        final pulse = 0.6 + 0.4 * math.sin(time * 3 + i);
        canvas.drawCircle(
          Offset(box.x, box.y),
          13 + pulse * 2,
          Paint()..color = const Color(0xFFFFC107).withValues(alpha: 0.16),
        );
        canvas.save();
        canvas.translate(box.x, box.y);
        canvas.rotate(time * 1.4 + i);
        canvas.drawRect(
          const Rect.fromLTWH(-8, -8, 16, 16),
          Paint()..color = const Color(0xFFF9A825),
        );
        canvas.drawRect(
          const Rect.fromLTWH(-4.5, -4.5, 9, 9),
          Paint()..color = const Color(0xFFFFE082),
        );
        // 问号意象：两点一竖
        final mark = Paint()..color = const Color(0xFFFF8F00);
        canvas.drawRect(const Rect.fromLTWH(-1.5, -4, 3, 5), mark);
        canvas.drawRect(const Rect.fromLTWH(-1.5, 2, 3, 2), mark);
        canvas.restore();
      } else {
        canvas.drawCircle(
          Offset(box.x, box.y),
          8,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xFFFFC107).withValues(alpha: 0.25),
        );
      }
      i++;
    }
  }

  void _paintWaterBombs(Canvas canvas) {
    for (final w in state.waterBombs) {
      if (w.landed) {
        canvas.drawCircle(
          Offset(w.x, w.y),
          26,
          Paint()..color = const Color(0xFF4FC3F7).withValues(alpha: 0.30),
        );
        final ringT = (4 - w.landTimer) / 4;
        canvas.drawCircle(
          Offset(w.x, w.y),
          8 + 18 * ringT,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = const Color(0xFF81D4FA).withValues(alpha: 0.6 * (1 - ringT)),
        );
      } else {
        canvas.drawCircle(
          Offset(w.x, w.y),
          5,
          Paint()..color = const Color(0xFF4FC3F7),
        );
        canvas.drawCircle(
          Offset(w.x - 1.6, w.y - 1.6),
          1.6,
          Paint()..color = const Color(0xFFE1F5FE),
        );
      }
    }
  }

  void _paintMissiles(Canvas canvas) {
    final time = state.raceTime;
    for (final m in state.missiles) {
      final ang = track.tangentAngleAtS(m.s);
      canvas.save();
      canvas.translate(m.x, m.y);
      canvas.rotate(ang);
      // 尾焰
      final flicker = 0.6 + 0.4 * math.sin(time * 40 + m.s);
      final flame = Paint()..color = const Color(0xFFFF9800).withValues(alpha: 0.85);
      canvas.drawPath(
        Path()
          ..moveTo(-7, -2)
          ..lineTo(-7 - 9 * flicker, 0)
          ..lineTo(-7, 2)
          ..close(),
        flame,
      );
      // 弹体
      canvas.drawRect(
        const Rect.fromLTWH(-7, -2.3, 11, 4.6),
        Paint()..color = const Color(0xFFE53935),
      );
      canvas.drawPath(
        Path()
          ..moveTo(4, -2.3)
          ..lineTo(9, 0)
          ..lineTo(4, 2.3)
          ..close(),
        Paint()..color = const Color(0xFFC62828),
      );
      canvas.drawCircle(
        const Offset(1, 0),
        1.2,
        Paint()..color = const Color(0xFFFFE082),
      );
      canvas.restore();
    }
  }

  void _paintKarts(Canvas canvas) {
    for (final k in state.karts) {
      canvas.drawCircle(
        Offset(k.x + 2, k.y + 3),
        9,
        Paint()..color = Colors.black.withValues(alpha: 0.22),
      );
    }
    for (final k in state.karts) {
      _paintKart(canvas, k);
    }
  }

  void _paintKart(Canvas canvas, KartState k) {
    final char = CharacterCatalog.byIndex(k.characterIndex);
    final color = Color(char.colorValue);
    final driftOffset = k.drifting ? 0.22 * k.driftDir : 0.0;

    canvas.save();
    canvas.translate(k.x, k.y);
    canvas.rotate(k.angle + driftOffset);

    // 车轮（前轮带转向视觉）
    final wheel = Paint()..color = const Color(0xFF212121);
    final wheelRect = Rect.fromCenter(
      center: Offset.zero,
      width: 3.4,
      height: 6.4,
    );
    for (final side in const [-5.0, 5.0]) {
      canvas.save();
      canvas.translate(-5.2, side);
      canvas.drawRect(wheelRect, wheel);
      canvas.restore();
    }
    final steer = k.lastSteer * 0.4;
    for (final side in const [-5.0, 5.0]) {
      canvas.save();
      canvas.translate(4.6, side);
      canvas.rotate(steer);
      canvas.drawRect(wheelRect, wheel);
      canvas.restore();
    }

    // 氮气尾焰
    if (k.boostTimer > 0) {
      final flicker = 0.7 + 0.3 * math.sin(state.raceTime * 42 + k.kartIndex);
      canvas.drawPath(
        Path()
          ..moveTo(-10, -3)
          ..lineTo(-10 - 12 * flicker, 0)
          ..lineTo(-10, 3)
          ..close(),
        Paint()..color = const Color(0xFFFF9800).withValues(alpha: 0.9),
      );
      canvas.drawPath(
        Path()
          ..moveTo(-10, -1.6)
          ..lineTo(-10 - 7 * flicker, 0)
          ..lineTo(-10, 1.6)
          ..close(),
        Paint()..color = const Color(0xFFFFE082),
      );
    }

    // 车身
    final body = Path()
      ..moveTo(8.5, 0)
      ..lineTo(5, -4)
      ..lineTo(-6.5, -4.8)
      ..lineTo(-8, -3)
      ..lineTo(-8, 3)
      ..lineTo(-6.5, 4.8)
      ..lineTo(5, 4)
      ..close();
    canvas.drawPath(body, Paint()..color = color);
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Colors.black.withValues(alpha: 0.35),
    );
    // 尾翼
    canvas.drawRect(
      const Rect.fromLTWH(-9.6, -4.6, 2.6, 9.2),
      Paint()..color = _darken(color),
    );
    // 座舱 + 头盔
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-3.2, -2.6, 6.4, 5.2),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );
    canvas.drawCircle(const Offset(0.6, 0), 2.4, Paint()..color = const Color(0xFFFAFAFA));
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(1.7, 0), radius: 1.5),
      -math.pi / 2,
      math.pi,
      true,
      Paint()..color = const Color(0xFF37474F),
    );

    // 打转星圈
    if (k.spinTimer > 0) {
      final star = Paint()
        ..strokeWidth = 2
        ..color = const Color(0xFFFFEE58);
      for (var i = 0; i < 3; i++) {
        final a = state.raceTime * 14 + i * 2.094;
        final ox = math.cos(a) * 13;
        final oy = math.sin(a) * 13;
        canvas.drawLine(Offset(ox - 2.4, oy), Offset(ox + 2.4, oy), star);
        canvas.drawLine(Offset(ox, oy - 2.4), Offset(ox, oy + 2.4), star);
      }
    }

    canvas.restore();

    // 护盾泡（不随车旋转）
    if (k.shieldTimer > 0) {
      final pulse = 0.5 + 0.3 * math.sin(state.raceTime * 8);
      canvas.drawCircle(
        Offset(k.x, k.y),
        14,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF4FC3F7).withValues(alpha: pulse),
      );
      canvas.drawCircle(
        Offset(k.x, k.y),
        14,
        Paint()..color = const Color(0xFF4FC3F7).withValues(alpha: 0.12),
      );
    }
  }

  void _paintParticles(Canvas canvas) {
    for (final p in state.particles) {
      final t = (p.life / p.maxLife).clamp(0.0, 1.0).toDouble();
      switch (p.kind) {
        case 0: // 烟雾
          canvas.drawCircle(
            Offset(p.x, p.y),
            p.size * (2 - t),
            Paint()..color = Colors.grey.withValues(alpha: 0.30 * t),
          );
        case 1: // 火花
          canvas.drawLine(
            Offset(p.x, p.y),
            Offset(p.x - p.vx * 0.05, p.y - p.vy * 0.05),
            Paint()
              ..strokeWidth = 2
              ..color = const Color(0xFFFFEE58).withValues(alpha: t),
          );
        case 2: // 爆炸
          canvas.drawCircle(
            Offset(p.x, p.y),
            p.size * (2 - t * 0.8),
            Paint()..color = const Color(0xFFFF7043).withValues(alpha: 0.8 * t),
          );
          canvas.drawCircle(
            Offset(p.x, p.y),
            p.size * (2 - t * 0.8) * 0.5,
            Paint()..color = const Color(0xFFFFE082).withValues(alpha: 0.9 * t),
          );
        case 3: // 水花
          canvas.drawCircle(
            Offset(p.x, p.y),
            p.size * (2.2 - t),
            Paint()..color = const Color(0xFF81D4FA).withValues(alpha: 0.5 * t),
          );
      }
    }
  }

  void _paintSpeedLines(Canvas canvas, Size size) {
    final player = state.player;
    final boosting = player.boostTimer > 0;
    final fullSpeed = player.speed / KartPhysics.baseMaxSpeed;
    double intensity;
    if (boosting) {
      intensity = 1.0;
    } else if (fullSpeed > 0.92) {
      intensity = (fullSpeed - 0.92) / 0.08 * 0.5;
    } else {
      return;
    }
    final paint = Paint()
      ..strokeWidth = 2.5
      ..color = Colors.white.withValues(alpha: 0.22 * intensity);
    final cx = size.width / 2;
    final cy = size.height / 2;
    final time = state.raceTime;
    final innerR = size.shortestSide * 0.36;
    final outerR = innerR + 64;
    for (var i = 0; i < 14; i++) {
      final ang = i * math.pi * 2 / 14 +
          (i.isEven ? 0.13 : -0.07) +
          math.sin(time * 30 + i) * 0.02;
      canvas.drawLine(
        Offset(cx + math.cos(ang) * innerR, cy + math.sin(ang) * innerR),
        Offset(cx + math.cos(ang) * outerR, cy + math.sin(ang) * outerR),
        paint,
      );
    }
  }

  static Color _darken(Color c) {
    // 按通道缩放（不使用已弃用的 Color.red/green/blue）
    final v = c.toARGB32();
    return Color.fromARGB(
      255,
      ((v >> 16) & 0xFF) * 62 ~/ 100,
      ((v >> 8) & 0xFF) * 62 ~/ 100,
      (v & 0xFF) * 62 ~/ 100,
    );
  }

  @override
  bool shouldRepaint(RacePainter oldDelegate) => true;
}
