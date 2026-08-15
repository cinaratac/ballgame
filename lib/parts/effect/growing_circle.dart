import 'package:flame/components.dart';
import 'dart:ui';

// --- GROWING CIRCLE EFFECT ---
class GrowingCircleEffect extends PositionComponent {
  final Color color;
  final double maxRadius;
  double radius = 0;
  final double duration;
  double timer = 0;
  final Paint paint;

  GrowingCircleEffect({
    required Vector2 center,
    required this.color,
    this.maxRadius = 150,
    this.duration = 0.6,
  }) : paint = Paint()
         ..color = color
         ..style = PaintingStyle.stroke
         ..strokeWidth = 6 {
    position = center;
    anchor = Anchor.center;
    size = Vector2.all(maxRadius * 2);
  }

  @override
  void update(double dt) {
    super.update(dt);
    timer += dt;
    radius = lerpDouble(0, maxRadius, (timer / duration).clamp(0, 1))!;
    if (timer >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    canvas.drawCircle(center, radius, paint);
  }
}
