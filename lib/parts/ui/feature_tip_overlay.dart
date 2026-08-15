import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:oyun1/oyun1.dart';

class FeatureTip {
  const FeatureTip({
    required this.key,
    required this.title,
    required this.message,
  });

  final String key;
  final String title;
  final String message;
}

FeatureTip? featureTipForLevel(int level) {
  switch (level) {
    case 1:
      return const FeatureTip(
        key: 'blue_targets',
        title: 'Blue targets',
        message: 'Aim the arrow and hit the blue targets.',
      );
    case 2:
      return const FeatureTip(
        key: 'red_targets',
        title: 'Red targets',
        message: 'Red targets are dangerous. Do not hit them.',
      );
    case 5:
      return const FeatureTip(
        key: 'spinning_targets',
        title: 'Spinning targets',
        message: 'Targets now rotate. Catch the rhythm.',
      );
    case 6:
      return const FeatureTip(
        key: 'extra_life',
        title: 'Green target',
        message: 'Green targets give you an extra life.',
      );
    case 8:
      return const FeatureTip(
        key: 'reverse_spin',
        title: 'Reverse spin',
        message: 'Targets can rotate in the opposite direction.',
      );
    case 13:
      return const FeatureTip(
        key: 'death_ring',
        title: 'Red ring',
        message: 'Touching the red ring will restart the level.',
      );
    case 18:
      return const FeatureTip(
        key: 'direction_swap',
        title: 'Direction swap',
        message: 'Targets can change direction during the level.',
      );
    case 20:
      return const FeatureTip(
        key: 'orange_orb',
        title: 'Orange rush',
        message: 'Hit all 5 orange orbs before any of them reaches the center.',
      );
    case 24:
      return const FeatureTip(
        key: 'fast_direction_swap',
        title: 'Fast swaps',
        message: 'Direction changes now happen more often.',
      );
    case 26:
      return const FeatureTip(
        key: 'memory_mask',
        title: 'Memory',
        message: 'Memorize the targets before their colors hide.',
      );
    case 27:
      return const FeatureTip(
        key: 'moving_memory',
        title: 'Moving memory',
        message: 'Remember the colors while the hidden targets rotate.',
      );
    case 37:
      return const FeatureTip(
        key: 'late_death_ring',
        title: 'Ring returns',
        message: 'Speed stays stable, but the red ring returns.',
      );
    case 40:
      return const FeatureTip(
        key: 'side_movers',
        title: 'Side movers',
        message: 'Targets now move up and down on the sides of the orbit.',
      );
    case 43:
      return const FeatureTip(
        key: 'red_panels',
        title: 'Red panels',
        message: 'Red panels sit behind side targets. Do not hit them.',
      );
  }
  return null;
}

class FeatureTipOverlay extends Component
    with HasGameReference<RotatingArrowGame> {
  FeatureTipOverlay({required this.tip}) {
    priority = 2000;
  }

  final FeatureTip tip;

  @override
  void render(Canvas canvas) {
    final gameSize = game.size;
    final screen = Size(gameSize.x, gameSize.y);
    final maxWidth = min(screen.width - 42, 330.0);
    final titlePainter = TextPainter(
      text: TextSpan(
        text: tip.title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth - 44);

    final messagePainter = TextPainter(
      text: TextSpan(
        text: tip.message,
        style: const TextStyle(
          color: Color(0xFFD6D6DA),
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.25,
          letterSpacing: 0,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 4,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth - 44);

    final height = 118 + titlePainter.height + messagePainter.height;
    final rect = Rect.fromCenter(
      center: Offset(screen.width / 2, screen.height * 0.25),
      width: maxWidth,
      height: height,
    );
    final box = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawRRect(box.shift(const Offset(0, 8)), shadowPaint);

    final boxPaint = Paint()..color = const Color(0xF20D0D11);
    canvas.drawRRect(box, boxPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.88);
    canvas.drawRRect(box, borderPaint);

    final accentPaint = Paint()..color = const Color(0xFFE94B5F);
    canvas.drawCircle(rect.topLeft + const Offset(26, 26), 5, accentPaint);

    var cursor = Offset(rect.left + 22, rect.top + 44);
    titlePainter.paint(canvas, cursor);
    cursor = cursor.translate(0, titlePainter.height + 12);
    messagePainter.paint(canvas, cursor);
  }
}
