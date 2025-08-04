import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:oyun1/oyun1.dart';
import 'arrow.dart';

class Portal extends PositionComponent with HasGameRef<RotatingArrowGame> {
  double angle;
  final double radius;
  late int score; // burayı late yaptım
  bool isDangerous;

  // --- Green portal property ---
  bool isGreen = false;

  double rotationSpeed = 0;

  // --- PATCH: Add isMasked field ---
  bool isMasked = false;

  Portal(this.angle, this.radius, {this.isDangerous = false}) {
    size = Vector2.all(20);
    anchor = Anchor.center;
    // score burada atanmayacak, loadLevel'de atanacak
  }

  @override
  void render(Canvas canvas) {
    // --- PATCH: Use isMasked for coloring ---
    final Paint paint = Paint()
      ..color = isMasked
          ? Colors.white
          : isGreen
          ? Colors.greenAccent
          : (isDangerous
                ? const Color.fromARGB(255, 159, 44, 44)
                : const Color.fromARGB(255, 20, 72, 162));
    final center = Offset(size.x / 2, size.y / 2);
    canvas.drawCircle(center, 10, paint);

    // Puanı küçük yaz
    final textPainter = TextPainter(
      text: TextSpan(
        text: score.toString(),
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final offset =
        center - Offset(textPainter.width / 2, textPainter.height / 2);
    textPainter.paint(canvas, offset);
  }

  @override
  void update(double dt) {
    if (rotationSpeed != 0) {
      angle += rotationSpeed * dt;
    }
    final center = gameRef.size / 2;
    angle %= 2 * pi;
    position = center + Vector2(cos(angle), sin(angle)) * radius;
  }
}

// --- ORANGE ORB CLASS ---
class OrangeOrb extends PositionComponent {
  final double angle;
  final Vector2 center;
  double speed = 40;

  OrangeOrb({required this.angle, required this.center}) {
    size = Vector2.all(25);
    anchor = Anchor.center;
    position = center + Vector2(cos(angle), sin(angle)) * 600;
  }

  @override
  void update(double dt) {
    final dir = (center - position).normalized();
    position += dir * speed * dt;
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = Colors.orange;
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x / 2, paint);
  }

  bool collidesWithArrow(Arrow arrow) {
    final arrowPos = center + Vector2(cos(arrow.angle), sin(arrow.angle)) * 30;
    return (position - arrowPos).length < 25;
  }
}