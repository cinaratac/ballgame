import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:oyun1/oyun1.dart';

class Arrow extends PositionComponent with HasGameRef<RotatingArrowGame> {
  double angle;
  double speed;
  final Vector2 center;

  Arrow({required this.angle, required this.speed, required this.center}) {
    size = Vector2.all(60);
    anchor = Anchor.center;
  }

  void updateAngle(double dt) {
    angle += speed * dt;
    angle %= 2 * pi;
  }

  @override
  void render(Canvas canvas) {
    final Paint paint = Paint()
      ..color = gameRef.currentArrowSkin == 0
          ? Colors.white
          : gameRef.currentArrowSkin == 1
          ? Colors.amber
          : Colors.grey[800]!
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final centerOffset = Offset(size.x / 2, size.y / 2);
    final arrowLength = size.x / 2;

    final start = centerOffset;
    final end = Offset(
      centerOffset.dx + arrowLength * cos(angle),
      centerOffset.dy + arrowLength * sin(angle),
    );

    canvas.drawLine(start, end, paint);
  }
}