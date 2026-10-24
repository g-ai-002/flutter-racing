import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../engine/kart_physics.dart';
import '../../engine/track_geometry.dart';
import '../../models/character.dart';
import '../../models/kart_state.dart';
import '../../models/race_state.dart';
import '../../models/track_def.dart';
import '../../providers/race_provider.dart';

/// 世界层：胎痕、香蕉皮、道具箱、水弹、导弹、卡丁车与粒子。
///
/// 所有绘制都在世界坐标下进行，缩放/旋转/跟随由 CameraComponent 负责。
class RaceWorldLayerComponent extends PositionComponent {
  RaceWorldLayerComponent({
    required this.provider,
    required this.track,
    required this.trackDef,
    super.priority,
  });

  final RaceProvider provider;
  final TrackGeometry track;
  final TrackDef trackDef;

  final Paint _paint = Paint();

  @override
  void render(Canvas canvas) {
    final state = provider.state;
    _drawSkidMarks(canvas, state);
    _drawPeels(canvas, state);
    _drawItemBoxes(canvas, state);
    _drawWaterBombs(canvas, state);
    _drawMissiles(canvas, state);
    _drawKarts(canvas, state);
    _drawParticles(canvas, state);
  }

  void _drawSkidMarks(Canvas canvas, RaceState state) {
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    for (final skid in state.skidMarks) {
      final alpha = 0.28 * (1 - skid.age / 6);
      if (alpha <= 0.02) {
        continue;
      }
      _paint.color = Colors.black.withValues(alpha: alpha);
      canvas.drawLine(
        Offset(skid.x1, skid.y1),
        Offset(skid.x2, skid.y2),
        _paint,
      );
    }
  }

  void _drawPeels(Canvas canvas, RaceState state) {
    for (final peel in state.peels) {
      final alpha = (peel.life / 30).clamp(0.5, 1.0).toDouble();
      _paint
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFDD835).withValues(alpha: alpha);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(peel.x, peel.y), radius: 5),
        0.25,
        math.pi * 0.95,
        true,
        _paint,
      );
      _paint.color = const Color(0xFF6D4C41);
      canvas.drawCircle(Offset(peel.x + 4.4, peel.y - 3), 1.1, _paint);
    }
  }

  void _drawItemBoxes(Canvas canvas, RaceState state) {
    final time = state.raceTime;
    var index = 0;
    for (final box in state.itemBoxes) {
      if (box.active) {
        final pulse = 0.6 + 0.4 * math.sin(time * 3 + index);
        _paint.color = const Color(0xFFFFC107).withValues(alpha: 0.16);
        canvas.drawCircle(Offset(box.x, box.y), 13 + pulse * 2, _paint);

        canvas.save();
        canvas.translate(box.x, box.y);
        canvas.rotate(time * 1.4 + index);
        _paint.color = const Color(0xFFF9A825);
        canvas.drawRect(const Rect.fromLTWH(-8, -8, 16, 16), _paint);
        _paint.color = const Color(0xFFFFE082);
        canvas.drawRect(const Rect.fromLTWH(-4.5, -4.5, 9, 9), _paint);
        _paint.color = const Color(0xFFFF8F00);
        canvas.drawRect(const Rect.fromLTWH(-1.5, -4, 3, 5), _paint);
        canvas.drawRect(const Rect.fromLTWH(-1.5, 2, 3, 2), _paint);
        canvas.restore();
      } else {
        _paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFFFC107).withValues(alpha: 0.25);
        canvas.drawCircle(Offset(box.x, box.y), 8, _paint);
        _paint.style = PaintingStyle.fill;
      }
      index++;
    }
  }

  void _drawWaterBombs(Canvas canvas, RaceState state) {
    for (final bomb in state.waterBombs) {
      if (bomb.landed) {
        _paint.color = const Color(0xFF4FC3F7).withValues(alpha: 0.30);
        canvas.drawCircle(Offset(bomb.x, bomb.y), 26, _paint);
        final ring = (4 - bomb.landTimer) / 4;
        _paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFF81D4FA).withValues(alpha: 0.6 * (1 - ring));
        canvas.drawCircle(Offset(bomb.x, bomb.y), 8 + 18 * ring, _paint);
        _paint.style = PaintingStyle.fill;
      } else {
        _paint.color = const Color(0xFF4FC3F7);
        canvas.drawCircle(Offset(bomb.x, bomb.y), 5, _paint);
        _paint.color = const Color(0xFFE1F5FE);
        canvas.drawCircle(Offset(bomb.x - 1.6, bomb.y - 1.6), 1.6, _paint);
      }
    }
  }

  void _drawMissiles(Canvas canvas, RaceState state) {
    final time = state.raceTime;
    for (final missile in state.missiles) {
      final angle = track.tangentAngleAtS(missile.s);
      canvas.save();
      canvas.translate(missile.x, missile.y);
      canvas.rotate(angle);

      final flicker = 0.6 + 0.4 * math.sin(time * 40 + missile.s);
      _paint.color = const Color(0xFFFF9800).withValues(alpha: 0.85);
      canvas.drawPath(
        Path()
          ..moveTo(-7, -2)
          ..lineTo(-7 - 9 * flicker, 0)
          ..lineTo(-7, 2)
          ..close(),
        _paint,
      );
      _paint.color = const Color(0xFFE53935);
      canvas.drawRect(const Rect.fromLTWH(-7, -2.3, 11, 4.6), _paint);
      _paint.color = const Color(0xFFC62828);
      canvas.drawPath(
        Path()
          ..moveTo(4, -2.3)
          ..lineTo(9, 0)
          ..lineTo(4, 2.3)
          ..close(),
        _paint,
      );
      _paint.color = const Color(0xFFFFE082);
      canvas.drawCircle(const Offset(1, 0), 1.2, _paint);
      canvas.restore();
    }
  }

  void _drawKarts(Canvas canvas, RaceState state) {
    for (final kart in state.karts) {
      _paint.color = Colors.black.withValues(alpha: 0.22);
      canvas.drawCircle(Offset(kart.x + 2, kart.y + 3), 9, _paint);
    }
    for (final kart in state.karts) {
      _drawKart(canvas, state, kart);
    }
  }

  void _drawKart(Canvas canvas, RaceState state, KartState kart) {
    final character = CharacterCatalog.byIndex(kart.characterIndex);
    final color = Color(character.colorValue);
    final driftOffset = kart.drifting ? 0.22 * kart.driftDir : 0.0;

    canvas.save();
    canvas.translate(kart.x, kart.y);
    canvas.rotate(kart.angle + driftOffset);

    _paint.color = const Color(0xFF212121);
    final wheelRect = Rect.fromCenter(
      center: Offset.zero,
      width: 3.4,
      height: 6.4,
    );
    for (final side in const [-5.0, 5.0]) {
      canvas.save();
      canvas.translate(-5.2, side);
      canvas.drawRect(wheelRect, _paint);
      canvas.restore();
    }
    final steer = kart.lastSteer * 0.4;
    for (final side in const [-5.0, 5.0]) {
      canvas.save();
      canvas.translate(4.6, side);
      canvas.rotate(steer);
      canvas.drawRect(wheelRect, _paint);
      canvas.restore();
    }

    if (kart.boostTimer > 0) {
      final flicker = 0.7 + 0.3 * math.sin(state.raceTime * 42 + kart.kartIndex);
      _paint.color = const Color(0xFFFF9800).withValues(alpha: 0.9);
      canvas.drawPath(
        Path()
          ..moveTo(-10, -3)
          ..lineTo(-10 - 12 * flicker, 0)
          ..lineTo(-10, 3)
          ..close(),
        _paint,
      );
      _paint.color = const Color(0xFFFFE082);
      canvas.drawPath(
        Path()
          ..moveTo(-10, -1.6)
          ..lineTo(-10 - 7 * flicker, 0)
          ..lineTo(-10, 1.6)
          ..close(),
        _paint,
      );
    }

    final body = Path()
      ..moveTo(8.5, 0)
      ..lineTo(5, -4)
      ..lineTo(-6.5, -4.8)
      ..lineTo(-8, -3)
      ..lineTo(-8, 3)
      ..lineTo(-6.5, 4.8)
      ..lineTo(5, 4)
      ..close();
    _paint.color = color;
    canvas.drawPath(body, _paint);
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Colors.black.withValues(alpha: 0.35);
    canvas.drawPath(body, _paint);
    _paint.style = PaintingStyle.fill;

    _paint.color = _darken(color);
    canvas.drawRect(const Rect.fromLTWH(-9.6, -4.6, 2.6, 9.2), _paint);

    _paint.color = Colors.black.withValues(alpha: 0.45);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-3.2, -2.6, 6.4, 5.2),
        const Radius.circular(2),
      ),
      _paint,
    );
    _paint.color = const Color(0xFFFAFAFA);
    canvas.drawCircle(const Offset(0.6, 0), 2.4, _paint);
    _paint.color = const Color(0xFF37474F);
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(1.7, 0), radius: 1.5),
      -math.pi / 2,
      math.pi,
      true,
      _paint,
    );

    if (kart.spinTimer > 0) {
      _paint
        ..strokeWidth = 2
        ..color = const Color(0xFFFFEE58);
      for (var i = 0; i < 3; i++) {
        final angle = state.raceTime * 14 + i * 2.094;
        final ox = math.cos(angle) * 13;
        final oy = math.sin(angle) * 13;
        canvas.drawLine(Offset(ox - 2.4, oy), Offset(ox + 2.4, oy), _paint);
        canvas.drawLine(Offset(ox, oy - 2.4), Offset(ox, oy + 2.4), _paint);
      }
      _paint.strokeWidth = 1;
    }

    canvas.restore();

    if (kart.shieldTimer > 0) {
      final pulse = 0.5 + 0.3 * math.sin(state.raceTime * 8);
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF4FC3F7).withValues(alpha: pulse);
      canvas.drawCircle(Offset(kart.x, kart.y), 14, _paint);
      _paint
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF4FC3F7).withValues(alpha: 0.12);
      canvas.drawCircle(Offset(kart.x, kart.y), 14, _paint);
    }
  }

  void _drawParticles(Canvas canvas, RaceState state) {
    for (final particle in state.particles) {
      final t = (particle.life / particle.maxLife).clamp(0.0, 1.0).toDouble();
      switch (particle.kind) {
        case 0:
          _paint.color = Colors.grey.withValues(alpha: 0.30 * t);
          canvas.drawCircle(
            Offset(particle.x, particle.y),
            particle.size * (2 - t),
            _paint,
          );
        case 1:
          _paint
            ..strokeWidth = 2
            ..color = const Color(0xFFFFEE58).withValues(alpha: t);
          canvas.drawLine(
            Offset(particle.x, particle.y),
            Offset(
              particle.x - particle.vx * 0.05,
              particle.y - particle.vy * 0.05,
            ),
            _paint,
          );
        case 2:
          _paint.color = const Color(0xFFFF7043).withValues(alpha: 0.8 * t);
          canvas.drawCircle(
            Offset(particle.x, particle.y),
            particle.size * (2 - t * 0.8),
            _paint,
          );
          _paint.color = const Color(0xFFFFE082).withValues(alpha: 0.9 * t);
          canvas.drawCircle(
            Offset(particle.x, particle.y),
            particle.size * (2 - t * 0.8) * 0.5,
            _paint,
          );
        case 3:
          _paint.color = const Color(0xFF81D4FA).withValues(alpha: 0.5 * t);
          canvas.drawCircle(
            Offset(particle.x, particle.y),
            particle.size * (2.2 - t),
            _paint,
          );
      }
    }
  }

  static Color _darken(Color color) {
    final value = color.toARGB32();
    return Color.fromARGB(
      255,
      ((value >> 16) & 0xFF) * 62 ~/ 100,
      ((value >> 8) & 0xFF) * 62 ~/ 100,
      (value & 0xFF) * 62 ~/ 100,
    );
  }
}

/// 速度线：屏幕空间特效，挂在 camera.viewport 上，不随镜头旋转。
class SpeedLinesComponent extends PositionComponent {
  SpeedLinesComponent({required this.provider, super.priority});

  final RaceProvider provider;
  final Paint _paint = Paint()..strokeWidth = 2.5;

  @override
  void render(Canvas canvas) {
    final game = findGame();
    if (game == null) {
      return;
    }
    final size = game.size;
    final state = provider.state;
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

    _paint.color = Colors.white.withValues(alpha: 0.22 * intensity);
    final cx = size.x / 2;
    final cy = size.y / 2;
    final time = state.raceTime;
    final inner = size.y < size.x ? size.y : size.x;
    final innerR = inner * 0.36;
    final outerR = innerR + 64;
    for (var i = 0; i < 14; i++) {
      final angle = i * math.pi * 2 / 14 +
          (i.isEven ? 0.13 : -0.07) +
          math.sin(time * 30 + i) * 0.02;
      canvas.drawLine(
        Offset(cx + math.cos(angle) * innerR, cy + math.sin(angle) * innerR),
        Offset(cx + math.cos(angle) * outerR, cy + math.sin(angle) * outerR),
        _paint,
      );
    }
  }
}
