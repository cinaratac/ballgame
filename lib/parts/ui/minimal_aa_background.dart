import 'dart:math' as math;

import 'package:flutter/material.dart';

class MinimalAaBackground extends StatelessWidget {
  const MinimalAaBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF050506), Color(0xFF111116), Color(0xFF050506)],
        ),
      ),
      child: CustomPaint(painter: _MinimalAaBackgroundPainter()),
    );
  }
}

class _MinimalAaBackgroundPainter extends CustomPainter {
  const _MinimalAaBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.22);
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.07);

    for (int i = 0; i < 6; i++) {
      canvas.drawCircle(center, 74.0 + i * 42, orbitPaint);
    }

    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.14);
    for (int i = 0; i < 34; i++) {
      final x = (math.sin(i * 2.23) * 0.5 + 0.5) * size.width;
      final y = (math.cos(i * 1.67) * 0.5 + 0.5) * size.height;
      canvas.drawCircle(Offset(x, y), i % 6 == 0 ? 2.0 : 1.1, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
