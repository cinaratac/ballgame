import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:oyun1/oyun1.dart';

// --- DEATH RING CLASS ---
class DeathRing extends PositionComponent
    with HasGameReference<RotatingArrowGame> {
  final double radius;
  final Color color;

  DeathRing({required this.radius, required this.color}) {
    size = Vector2.all(radius * 2);
    anchor = Anchor.center;
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final center = Offset(size.x / 2, size.y / 2);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  void update(double dt) {
    position = game.size / 2;
  }
}
