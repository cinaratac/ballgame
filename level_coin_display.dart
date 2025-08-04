import '../main.dart';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class LevelCoinDisplay extends PositionComponent
    with HasGameRef<RotatingArrowGame> {
  int level;
  int coins;

  LevelCoinDisplay({
    required this.level,
    required this.coins,
    required Vector2 position,
  }) {
    this.position = position;
    size = Vector2(300, 100);
    anchor = Anchor.topCenter;
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y - 100);
    final radius = size.x / 2;

    final paint = Paint()..color = const Color.fromARGB(255, 223, 217, 217);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0, // startAngle
      3.14, // sweepAngle (flip direction)
      true,
      paint,
    );

    final levelPainter = TextPainter(
      text: TextSpan(
        text: '$level',
        style: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurpleAccent,
          shadows: [
            Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 2),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    levelPainter.layout(minWidth: 0, maxWidth: size.x);
    levelPainter.paint(
      canvas,
      Offset((size.x - levelPainter.width) / 2, size.y - radius / 2 + 5),
    );

    final labelPainter = TextPainter(
      text: TextSpan(
        text: 'COINS',
        style: TextStyle(fontSize: 24, color: Colors.black87),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    labelPainter.layout(minWidth: 0, maxWidth: size.x);
    labelPainter.paint(
      canvas,
      Offset((size.x - labelPainter.width) / 2, size.y - radius / 2 + 47),
    );

    final coinsPainter = TextPainter(
      text: TextSpan(
        text: '$coins',
        style: TextStyle(
          fontSize: 26,
          color: Colors.black,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 2),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    coinsPainter.layout(minWidth: 0, maxWidth: size.x);
    coinsPainter.paint(
      canvas,
      Offset((size.x - coinsPainter.width) / 2, size.y - radius / 2 + 71),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    level = gameRef.currentLevel;
    coins = gameRef.totalScore;
  }
}
