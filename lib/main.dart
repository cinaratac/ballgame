import 'dart:math';
import 'dart:async' as dart_async;
import 'package:flame/flame.dart';
import 'package:flutter/services.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flame/input.dart';
import 'dart:ui';

import 'package:oyun1/oyun1.dart';
import 'parts/levels.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Flame.device.fullScreen();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GameWidget(
        game: RotatingArrowGame(),
        overlayBuilderMap: {
          'levelMenuButton': (context, game) {
            return Positioned(
              top: 10,
              right: 10,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    PageRouteBuilder(
                      transitionDuration: Duration(milliseconds: 400),
                      pageBuilder: (_, __, ___) => LevelSelectScreen(),
                      transitionsBuilder: (_, animation, __, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    ),
                  );
                },
                child: Text('Menü'),
              ),
            );
          },
          // Shop button overlay positioned top left
          'shopButton': (context, game) {
            return Positioned(
              top: 10,
              left: 10,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          ShopScreen(game: game as RotatingArrowGame),
                    ),
                  );
                },
                child: Text('Shop'),
              ),
            );
          },
        },
      ),
    ),
  );
}

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
    if (!hit && gameRef.currentLevel >= 13 && gameRef.currentLevel <= 17) {
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

// --- SHOP SCREEN WIDGET ---
class ShopScreen extends StatefulWidget {
  final RotatingArrowGame game;
  ShopScreen({required this.game});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget buildArrowTile(int index, Color color, String name, int price) {
    final game = widget.game;
    final isOwned = game.ownedArrows.contains(index);
    final isSelected = game.currentArrowSkin == index;

    return GestureDetector(
      onTap: () async {
        if (isOwned) {
          setState(() {
            game.currentArrowSkin = index;
          });
        } else if (game.totalScore >= price) {
          setState(() {
            game.totalScore -= price;
            game.ownedArrows.add(index);
            game.currentArrowSkin = index;
          });
          await game.saveCoinScore();
          await game.saveOwnedArrows();
          game.scoreText.text = 'Coins: ${game.totalScore}';
        }
      },
      child: Container(
        margin: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black87,
          border: Border.all(
            color: isSelected ? Colors.yellowAccent : Colors.white,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        width: 100,
        height: 140,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RotationTransition(
              turns: _controller,
              child: Icon(Icons.arrow_right_alt, size: 48, color: color),
            ),
            SizedBox(height: 8),
            Text(name, style: TextStyle(color: Colors.white)),
            SizedBox(height: 4),
            Text(
              isOwned ? 'Owned' : '$price Coins',
              style: TextStyle(
                color: isOwned ? Colors.greenAccent : Colors.yellowAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: Text('Arrow Shop'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          SizedBox(height: 16),
          Text(
            'Coins: ${game.totalScore}',
            style: TextStyle(
              color: Colors.yellowAccent,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              children: [
                buildArrowTile(0, Colors.white, 'Classic', 0),
                buildArrowTile(1, Colors.amber, 'Golden', 500),
                buildArrowTile(2, Colors.grey[800]!, 'Shadow', 1000),
              ],
            ),
          ),
        ],
      ),
    );
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

// --- DEATH RING CLASS ---
class DeathRing extends PositionComponent with HasGameRef<RotatingArrowGame> {
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
    position = gameRef.size / 2;
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
