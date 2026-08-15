import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:oyun1/oyun1.dart';

class ArenaBackdrop extends Component with HasGameReference<RotatingArrowGame> {
  ArenaBackdrop() {
    priority = -1000;
  }

  double _time = 0;

  @override
  void update(double dt) {
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final size = game.size;
    final rect = Offset.zero & Size(size.x, size.y);
    final center = Offset(size.x / 2, size.y / 2);

    final basePaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -0.08),
        radius: 0.85,
        colors: [Color(0xFF171820), Color(0xFF090A0D), Color(0xFF030304)],
        stops: [0, 0.55, 1],
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..color = Colors.white.withValues(alpha: 0.075);

    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(center, 54.0 + i * 34, orbitPaint);
    }

    final mainRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.12);
    canvas.drawCircle(center, game.portalRadius, mainRingPaint);

    final tickPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.10);
    final tickRotation = _time * 0.18;
    for (int i = 0; i < 36; i++) {
      final angle = tickRotation + i * 2 * pi / 36;
      final outer = game.portalRadius + (i % 3 == 0 ? 18 : 10);
      final inner = game.portalRadius + 3;
      final start = center + Offset(cos(angle), sin(angle)) * inner;
      final end = center + Offset(cos(angle), sin(angle)) * outer;
      canvas.drawLine(start, end, tickPaint);
    }

    final axisPaint = Paint()
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.045);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.y), axisPaint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.x, center.dy), axisPaint);

    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.11);
    for (int i = 0; i < 42; i++) {
      final x = (sin(i * 2.17) * 0.5 + 0.5) * size.x;
      final y = (cos(i * 1.91) * 0.5 + 0.5) * size.y;
      final distance = (Offset(x, y) - center).distance;
      if (distance < game.portalRadius + 48) continue;
      canvas.drawCircle(Offset(x, y), i % 7 == 0 ? 1.7 : 1.0, dotPaint);
    }
  }
}
