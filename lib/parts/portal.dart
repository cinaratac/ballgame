import 'dart:math';
import 'dart:async' as dart_async;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:oyun1/oyun1.dart';
import '/parts/effect/death_ring.dart';
import 'effect/growing_circle.dart';
import 'arrow.dart';

class Portal extends PositionComponent
    with HasGameReference<RotatingArrowGame> {
  @override
  double angle;
  final double radius;
  late int score; // burayı late yaptım
  bool isDangerous;

  // --- Green portal property ---
  bool isGreen = false;

  double rotationSpeed = 0;

  bool isMasked = false;

  Portal(this.angle, this.radius, {this.isDangerous = false}) {
    size = Vector2.all(20);
    anchor = Anchor.center;
    // score burada atanmayacak, loadLevel'de atanacak
  }

  @override
  void render(Canvas canvas) {
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
    final center = game.size / 2;
    angle %= 2 * pi;
    position = center + Vector2(cos(angle), sin(angle)) * radius;
  }
}

class Ball extends PositionComponent with HasGameReference<RotatingArrowGame> {
  @override
  double angle; // açısal pozisyon (radyan)
  double radius; // merkezden uzaklık (piksel)
  @override
  final Vector2 center;
  final double radialSpeedRatio; // pixels per arrow-speed unit
  final double angularSpeedRatio; // 1 keeps ball rotation equal to arrow

  bool hit = false;
  double hitTimer = 0.0;
  Color color;

  double trailTimer = 0.0; // Kuyruk yoğunluğunu kontrol eden zamanlayıcı
  static const double _trailLife = 0.42;
  static const int _maxTrailPoints = 18;
  final List<_BallTrailPoint> _trail = [];
  final int _trailSeed = Random().nextInt(10000);

  Ball({
    required this.angle,
    required this.radius,
    required this.center,
    required this.radialSpeedRatio,
    required this.angularSpeedRatio,
    required this.color,
  }) {
    size = Vector2.all(15);
    anchor = Anchor.center;
    position = center + Vector2(cos(angle), sin(angle)) * radius;
  }

  void updatePosition(double dt) {
    _updateTrail(dt);

    if (!hit) {
      final previousPosition = position.clone();
      radius += game.arrow.speed.abs() * radialSpeedRatio * dt;
      angle += game.arrow.speed * angularSpeedRatio * dt;
      position = center + Vector2(cos(angle), sin(angle)) * radius;
      final movement = position - previousPosition;
      trailTimer += dt;
      if (trailTimer >= 0.024) {
        if (movement.length2 > 0.04) {
          _trail.add(_BallTrailPoint(position.clone()));
          if (_trail.length > _maxTrailPoints) {
            _trail.removeAt(0);
          }
        }
        trailTimer = 0.0;
      }
    } else {
      hitTimer += dt;
    }
    // DeathRing collision follows the mapped 90-level progression.
    if (!hit && game.hasDeathRingForLevel(game.currentLevel)) {
      final ballCenter = position;
      final centerToBall = (ballCenter - game.size / 2).length;
      final deathRing = game.children.whereType<DeathRing>().firstOrNull;
      if (deathRing != null) {
        final deathRingVisualRadius = deathRing.size.x / 2;
        if ((centerToBall - deathRingVisualRadius).abs() <= size.x / 2) {
          // Guard: Only hasExtraLife grants immunity
          if (game.hasExtraLife) {
            game.hasExtraLife = false;
            game.orangeOrbImmune = false;
            game.hitMessageText.text = 'Extra life used!';
            game.hitMessageText.textRenderer = TextPaint(
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            );
            game.hitMessageTimer = 0;
            hit = true;
            return; // Do nothing else, ball keeps moving
          } else {
            game.playWrongSound();
            game.add(
              GrowingCircleEffect(
                center: game.size / 2,
                color: const Color.fromARGB(255, 159, 44, 44),
                maxRadius: game.portalRadius + 10,
              ),
            );
            Future.microtask(() => game.loadLevel(game.currentLevel));
          }
        }
      }
    }
  }

  void _updateTrail(double dt) {
    for (final point in _trail) {
      point.age += dt;
    }
    _trail.removeWhere((point) => point.age >= _trailLife);
  }

  void markHit() {
    hit = true;
    hitTimer = 0.0;
  }

  bool hasReachedTarget(List<Portal> portals) {
    for (var p in portals) {
      final portalPos = p.position;
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
    _renderCometTail(canvas);

    final center = Offset(size.x / 2, size.y / 2);
    canvas.drawCircle(
      center,
      13,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      center,
      10,
      Paint()..color = Colors.white.withValues(alpha: 0.16),
    );
    final Paint paint = Paint()..color = color;
    canvas.drawCircle(center, 7, paint);
  }

  void _renderCometTail(Canvas canvas) {
    if (_trail.length < 2) return;

    final head = Offset(size.x / 2, size.y / 2);
    final localPoints =
        _trail
            .map((point) => _toLocalTrailOffset(point.position, head))
            .toList(growable: true)
          ..add(head);

    _drawTailBody(canvas, localPoints, maxWidth: 21, maxAlpha: 0.34);
    _drawTailBody(canvas, localPoints, maxWidth: 10, maxAlpha: 0.56);
    _drawTailWisps(canvas, localPoints);
  }

  Offset _toLocalTrailOffset(Vector2 globalPoint, Offset head) {
    return Offset(
      globalPoint.x - position.x + head.dx,
      globalPoint.y - position.y + head.dy,
    );
  }

  void _drawTailBody(
    Canvas canvas,
    List<Offset> points, {
    required double maxWidth,
    required double maxAlpha,
  }) {
    if (points.length < 3) return;

    final upper = <Offset>[];
    final lower = <Offset>[];

    for (int i = 0; i < points.length; i++) {
      final t = i / (points.length - 1);
      final fadeByAge = _trailFadeAt(i);
      final width = maxWidth * pow(t, 1.75) * fadeByAge;
      final previous = points[max(0, i - 1)];
      final next = points[min(points.length - 1, i + 1)];
      final direction = next - previous;
      final length = direction.distance;
      if (length <= 0.1) continue;

      final normal = Offset(-direction.dy / length, direction.dx / length);
      upper.add(points[i] + normal * (width / 2));
      lower.add(points[i] - normal * (width / 2));
    }

    if (upper.length < 2 || lower.length < 2) return;

    final tailPath = Path()..moveTo(upper.first.dx, upper.first.dy);
    for (int i = 1; i < upper.length; i++) {
      tailPath.lineTo(upper[i].dx, upper[i].dy);
    }
    for (int i = lower.length - 1; i >= 0; i--) {
      tailPath.lineTo(lower[i].dx, lower[i].dy);
    }
    tailPath.close();

    canvas.drawPath(
      tailPath,
      Paint()
        ..color = Colors.white.withValues(alpha: maxAlpha)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawTailWisps(Canvas canvas, List<Offset> points) {
    if (points.length < 5) return;

    for (int strand = -1; strand <= 1; strand += 2) {
      if (strand == 0) continue;
      final path = Path();
      bool started = false;

      for (int i = 1; i < points.length; i++) {
        final t = i / (points.length - 1);
        if (t < 0.18) continue;

        final current = points[i];
        final previous = points[i - 1];
        final direction = current - previous;
        final length = direction.distance;
        if (length <= 0.1) continue;

        final normal = Offset(-direction.dy / length, direction.dx / length);
        final wave = sin((_trailSeed + i * 13 + strand * 19) * 0.37);
        final spread = (1 - t) * 14 + 2;
        final offsetPoint =
            current +
            normal *
                strand.sign.toDouble() *
                spread *
                (0.35 + wave.abs() * 0.65);

        if (!started) {
          path.moveTo(offsetPoint.dx, offsetPoint.dy);
          started = true;
        } else {
          path.lineTo(offsetPoint.dx, offsetPoint.dy);
        }
      }

      if (!started) continue;

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, paint);
    }
  }

  double _trailFadeAt(int index) {
    if (index >= _trail.length) return 1;
    return 1 - (_trail[index].age / _trailLife).clamp(0.0, 1.0);
  }
}

class _BallTrailPoint {
  _BallTrailPoint(this.position);

  final Vector2 position;
  double age = 0;
}

class VerticalMovingPortal extends Portal {
  VerticalMovingPortal({
    required this.side,
    required double radius,
    required this.phase,
    super.isDangerous,
  }) : super(0, radius);

  final int side;
  final double phase;
  double _time = 0;

  @override
  void update(double dt) {
    _time += dt;
    final center = game.size / 2;
    final yOffset = sin(_time * 1.45 + phase) * 92;
    position = Vector2(center.x + side * radius, center.y + yOffset);
    angle = atan2(position.y - center.y, position.x - center.x);
  }
}

class RedPanel extends PositionComponent
    with HasGameReference<RotatingArrowGame> {
  RedPanel({required this.side, required this.radius}) {
    size = Vector2(18, 230);
    anchor = Anchor.center;
    priority = -2;
  }

  final int side;
  final double radius;

  @override
  void update(double dt) {
    final center = game.size / 2;
    position = Vector2(center.x + side * (radius + 34), center.y);
  }

  @override
  void render(Canvas canvas) {
    final rect = Offset.zero & Size(size.x, size.y);
    final paint = Paint()..color = const Color.fromARGB(255, 159, 44, 44);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      paint,
    );
  }

  bool collidesWithBall(Ball ball) {
    final panelRect = Rect.fromCenter(
      center: Offset(position.x, position.y),
      width: size.x,
      height: size.y,
    ).inflate(ball.size.x / 2);
    return panelRect.contains(Offset(ball.position.x, ball.position.y));
  }
}

// --- ORANGE ORB CLASS ---
class OrangeOrb extends PositionComponent {
  @override
  final double angle;
  @override
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

  bool hasReachedCenter() {
    return (position - center).length <= size.x / 2;
  }
}

// Smoothly reverses the direction of all portals' rotation
void startSmoothDirectionSwap(List<Portal> portals) {
  for (var portal in portals) {
    final originalSpeed = portal.rotationSpeed;
    double slowdownStep = originalSpeed / 30;
    int steps = 15;
    dart_async.Timer.periodic(Duration(milliseconds: 100), (timer) {
      portal.rotationSpeed -= slowdownStep;
      steps--;
      if (steps == 0) {
        timer.cancel();
        dart_async.Timer(Duration(milliseconds: 200), () {
          int stepsBack = 15;
          double accelerateStep = originalSpeed.abs() / 30;
          dart_async.Timer.periodic(Duration(milliseconds: 100), (revTimer) {
            portal.rotationSpeed -= portal.rotationSpeed > 0
                ? accelerateStep
                : -accelerateStep;
            stepsBack--;
            if (stepsBack == 0) {
              portal.rotationSpeed = -originalSpeed;
              revTimer.cancel();
            }
          });
        });
      }
    });
  }
}
