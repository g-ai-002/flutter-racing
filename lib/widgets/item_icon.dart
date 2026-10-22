import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/game_enums.dart';

/// 道具图标画笔（HUD 道具槽与触屏道具按钮共用）。
/// 设计坐标归一化到 [-12, 12]，随尺寸缩放。
class ItemIconPainter extends CustomPainter {
  final ItemType? item;

  const ItemIconPainter({required this.item});

  @override
  void paint(Canvas canvas, Size size) {
    final item = this.item;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.width / 24);
    if (item == null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-10, -10, 20, 20),
          const Radius.circular(4),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.35),
      );
      canvas.restore();
      return;
    }
    switch (item) {
      case ItemType.nitro:
        canvas.drawPath(
          Path()
            ..moveTo(-2, -11)
            ..lineTo(4.5, -11)
            ..lineTo(1, -3)
            ..lineTo(5.5, -3)
            ..lineTo(-3.5, 11)
            ..lineTo(-1, 1)
            ..lineTo(-5.5, 1)
            ..close(),
          Paint()..color = const Color(0xFFFFC107),
        );
      case ItemType.missile:
        final body = Paint()..color = const Color(0xFFE53935);
        canvas.drawRect(const Rect.fromLTWH(-9, -3, 12, 6), body);
        canvas.drawPath(
          Path()
            ..moveTo(3, -3)
            ..lineTo(10, 0)
            ..lineTo(3, 3)
            ..close(),
          Paint()..color = const Color(0xFFC62828),
        );
        canvas.drawPath(
          Path()
            ..moveTo(-9, -3)
            ..lineTo(-11.5, -5)
            ..lineTo(-11.5, 5)
            ..lineTo(-9, 3)
            ..close(),
          Paint()..color = const Color(0xFFB71C1C),
        );
        canvas.drawCircle(
          const Offset(-2, 0),
          1.8,
          Paint()..color = const Color(0xFFE3F2FD),
        );
      case ItemType.waterBomb:
        final drop = Paint()..color = const Color(0xFF4FC3F7);
        canvas.drawCircle(const Offset(0, 3), 6.5, drop);
        canvas.drawPath(
          Path()
            ..moveTo(-4, -2)
            ..lineTo(0, -11)
            ..lineTo(4, -2)
            ..close(),
          drop,
        );
        canvas.drawCircle(
          const Offset(-2.2, 2.2),
          1.6,
          Paint()..color = const Color(0xFFE1F5FE),
        );
      case ItemType.banana:
        final peel = Paint()..color = const Color(0xFFFDD835);
        canvas.drawArc(
          const Rect.fromLTWH(-10, -7, 20, 14),
          math.pi * 0.12,
          math.pi * 0.76,
          true,
          peel,
        );
        final tip = Paint()..color = const Color(0xFF6D4C41);
        canvas.drawCircle(const Offset(-7.6, -4.4), 1.4, tip);
        canvas.drawCircle(const Offset(7.6, -4.4), 1.4, tip);
      case ItemType.shield:
        final shield = Paint()..color = const Color(0xFF1E88E5);
        canvas.drawPath(
          Path()
            ..moveTo(-8, -9)
            ..lineTo(8, -9)
            ..lineTo(8, 0)
            ..lineTo(0, 10)
            ..lineTo(-8, 0)
            ..close(),
          shield,
        );
        canvas.drawPath(
          Path()
            ..moveTo(-4, -2)
            ..lineTo(-1, -5)
            ..lineTo(2, 3)
            ..close(),
          Paint()..color = const Color(0xFFE3F2FD),
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ItemIconPainter oldDelegate) => oldDelegate.item != item;
}

class ItemIcon extends StatelessWidget {
  final ItemType? item;
  final double size;

  const ItemIcon({super.key, required this.item, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: ItemIconPainter(item: item)),
    );
  }
}
