import 'dart:math';
import 'dart:async' as dart_async;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:oyun1/oyun1.dart';
import '/parts/effect/DeathrRing.dart';
import 'effect/growingCircle.dart';
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
    // Ensure counter-clockwise rotation by default
    rotationSpeed = -rotationSpeed.abs();
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

class Ball extends PositionComponent with HasGameRef<RotatingArrowGame> {
  double angle; // açısal pozisyon (radyan)
  double radius; // merkezden uzaklık (piksel)
  final Vector2 center;
  final double speedRadius; // yarıçap artış hızı piksel/sn
  final double speedAngle; // açısal hız radyflutter build apk --debugan/sn

  bool hit = false;
  double hitTimer = 0.0;
  Color color;

  double trailTimer = 0.0; // Kuyruk yoğunluğunu kontrol eden zamanlayıcı

  Ball({
    required this.angle,
    required this.radius,
    required this.center,
    required this.speedRadius,
    required this.speedAngle,
    required this.color,
  }) {
    size = Vector2.all(15);
    anchor = Anchor.center;
  }

  void updatePosition(double dt) {
    if (!hit) {
      radius += speedRadius * dt;
      angle += speedAngle * dt;
      position = center + Vector2(cos(angle), sin(angle)) * radius;
      trailTimer += dt;
      if (trailTimer >= 0.010 &&
          gameRef.children.whereType<CometTrail>().length < 100) {
        gameRef.add(CometTrail(position.clone(), color));
        trailTimer = 0.0;
      }
    } else {
      hitTimer += dt;
    }
    // --- PATCH: DeathRing collision for levels 13-17 (center-based calculation, with extra life handling) ---
    if (!hit && gameRef.currentLevel >= 13 && gameRef.currentLevel <= 20) {
      final ballCenter = position;
      final centerToBall = (ballCenter - gameRef.size / 2).length;
      final deathRing = gameRef.children.whereType<DeathRing>().firstOrNull;
      if (deathRing != null) {
        final deathRingVisualRadius = deathRing.size.x / 2;
        if ((centerToBall - deathRingVisualRadius).abs() <= size.x / 2) {
          // Guard: Only hasExtraLife grants immunity
          if (gameRef.hasExtraLife) {
            gameRef.hasExtraLife = false;
            gameRef.orangeOrbImmune = false;
            gameRef.hitMessageText.text = 'Extra life used!';
            gameRef.hitMessageText.textRenderer = TextPaint(
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            );
            gameRef.hitMessageTimer = 0;
            hit = true;
            return; // Do nothing else, ball keeps moving
          } else {
            gameRef.playWrongSound();
            gameRef.add(
              GrowingCircleEffect(
                center: gameRef.size / 2,
                color: const Color.fromARGB(255, 159, 44, 44),
                maxRadius: gameRef.portalRadius + 10,
              ),
            );
            Future.microtask(() => gameRef.loadLevel(gameRef.currentLevel));
          }
        }
      }
    }
  }

  void markHit() {
    hit = true;
    hitTimer = 0.0;
  }

  bool hasReachedTarget(List<Portal> portals) {
    for (var p in portals) {
      final portalPos = center + Vector2(cos(p.angle), sin(p.angle)) * p.radius;
      final ballPos = center + Vector2(cos(angle), sin(angle)) * radius;

      final distance = (portalPos - ballPos).length;

      final collisionDistance = (p.size.x / 2) + (size.x / 2);

      if (distance < collisionDistance) {
        return true;
      }
    }

    return false;
  }

  bool isOutOfRange(double maxRadius) {
    return radius > maxRadius;
  }

  bool isOffScreen(Vector2 screenSize) {
    final pos = position;
    return pos.x < 0 ||
        pos.y < 0 ||
        pos.x > screenSize.x ||
        pos.y > screenSize.y;
  }

  @override
  void render(Canvas canvas) {
    final Paint paint = Paint()..color = color;
    final center = Offset(size.x / 2, size.y / 2);
    canvas.drawCircle(center, 7, paint);
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

class CometTrail extends PositionComponent {
  final Color trailColor;
  CometTrail(Vector2 pos, this.trailColor) {
    position = pos;
    size = Vector2.all(14);
    anchor = Anchor.center;
    priority = 1000;
  }

  double life = 1.2;

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = trailColor.withOpacity(0.4);
    final center = Offset(size.x / 2, size.y / 2);
    canvas.drawCircle(center, size.x / 2, paint);
  }

  @override
  void update(double dt) {
    life -= dt;
    if (life <= 0) {
      removeFromParent();
    }
  }
}

// Smoothly reverses the direction of all portals' rotation
void startSmoothDirectionSwap(List<Portal> portals) {
  for (var portal in portals) {
    final originalSpeed = portal.rotationSpeed;
    double slowdownStep = originalSpeed / 15;
    int steps = 15;

    dart_async.Timer.periodic(Duration(milliseconds: 100), (timer) {
      portal.rotationSpeed -= slowdownStep;
      steps--;

      if (steps <= 0) {
        timer.cancel();
        portal.rotationSpeed = 0;

        dart_async.Timer(Duration(milliseconds: 200), () {
          int stepsBack = 15;
          double accelerateStep = originalSpeed.abs() / 15;

          dart_async.Timer.periodic(Duration(milliseconds: 100), (revTimer) {
            portal.rotationSpeed += originalSpeed > 0
                ? -accelerateStep
                : accelerateStep;
            stepsBack--;

            if (stepsBack <= 0) {
              revTimer.cancel();
              portal.rotationSpeed = -originalSpeed;
            }
          });
        });
      }
    });
  }
}
