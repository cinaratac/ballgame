import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flame/input.dart';
import 'package:flame/effects.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:ui';
import 'package:flutter/animation.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class RotatingArrowGame extends FlameGame with TapDetector {
  bool isLoaded = false;
  Future<void> init() async {
    await loadCoinScore();
    scoreText.text = 'Coins: $totalScore';
  }

  final int portalCount = 6;
  final double portalRadius = 150;
  final List<Portal> portals = [];
  List<Ball> balls = [];
  late Arrow arrow;

  double rotationSpeed = 2.0; // ok ve topun açısal hızı (radyan/sn)

  int totalScore = 0;
  Future<void> loadCoinScore() async {
    final prefs = await SharedPreferences.getInstance();
    totalScore = prefs.getInt('totalScore') ?? 0;
    if (scoreText != null) {
      scoreText.text = 'Coins: $totalScore';
    }
  }

  Future<void> saveCoinScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('totalScore', totalScore);
  }

  // --- Arrow Inventory ---
  Set<int> ownedArrows = {0};

  Future<void> saveOwnedArrows() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(
      'ownedArrows',
      ownedArrows.map((e) => e.toString()).toList(),
    );
  }

  Future<void> loadOwnedArrows() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('ownedArrows');
    if (list != null) {
      ownedArrows = list.map(int.parse).toSet();
    }
  }

  late TextComponent scoreText;

  late TextComponent hitMessageText;
  double hitMessageTimer = 0;

  int currentLevel = 1;

  late TextComponent levelText;

  int comboCount = 0;

  late final AudioPlayer correctPlayer;
  late final AudioPlayer wrongPlayer;

  int currentArrowSkin = 0; // 0: beyaz, 1: altın, 2: gölgeli

  // --- Extra Life Mechanic ---
  bool hasExtraLife = false;

  // --- Orange Orb Mechanic ---
  bool orangeOrbImmune = false;
  OrangeOrb? activeOrangeOrb;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final center = size / 2;

    // Ok oluştur ve ekle
    arrow = Arrow(angle: 0, speed: rotationSpeed, center: center);
    arrow.position = center;
    add(arrow);

    // Coins yazısı - ekran üst ortada
    scoreText = TextComponent(
      text: 'Coins: 0',
      position: Vector2(center.x, 20),
      anchor: Anchor.topCenter,
      textRenderer: TextPaint(
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(scoreText);
    await loadCoinScore();
    scoreText.text = 'Coins: $totalScore';

    // Arrow inventory yükle
    await loadOwnedArrows();

    // Level göstergesi
    levelText = TextComponent(
      text: 'Level: $currentLevel',
      position: Vector2(center.x, 60), // Puan yazısının biraz altında
      anchor: Anchor.topCenter,
      textRenderer: TextPaint(
        style: TextStyle(
          color: Colors.yellowAccent,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(levelText);

    // Level yükle
    loadLevel(currentLevel);

    // Vuruş mesajı - ekran alt ortada (biraz daha yukarı alındı)
    hitMessageText = TextComponent(
      text: '',
      position: Vector2(size.x / 2, size.y - 140),
      anchor: Anchor.bottomCenter,
      textRenderer: TextPaint(
        style: TextStyle(
          color: Colors.greenAccent,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(hitMessageText);

    // Overlay menü butonunu göster
    overlays.add('levelMenuButton');
    overlays.add('shopButton');

    // Ses oynatıcıları başlat
    correctPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    wrongPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

    await correctPlayer.setSource(AssetSource('correct.mp3'));
    await wrongPlayer.setSource(AssetSource('wrong.mp3'));
    isLoaded = true;
  }

  void playCorrectSound() {
    correctPlayer.seek(Duration.zero);
    correctPlayer.resume();
  }

  void playWrongSound() {
    wrongPlayer.seek(Duration.zero);
    wrongPlayer.resume();
  }

  void loadLevel(int level) {
    // ---- LEVEL 10 SKIP CHECK ----
    if (level == 10) {
      SharedPreferences.getInstance().then((prefs) {
        bool alreadyPlayed = prefs.getBool('coinLevel10Played') ?? false;
        if (alreadyPlayed) {
          currentLevel = 11;
          loadLevel(11);
        } else {
          // Continue to setup level 10 below
          _setupLevel(level);
        }
      });
      return;
    }
    _setupLevel(level);
  }

  void _setupLevel(int level) {
    isLoaded = false;
    portals.clear();
    hasExtraLife = false;
    orangeOrbImmune = false;

    if (activeOrangeOrb != null) {
      activeOrangeOrb!.removeFromParent();
      activeOrangeOrb = null;
    }

    for (final child in children.whereType<Portal>().toList()) {
      remove(child);
    }

    final center = size / 2;

    int newPortalCount;
    int numDangerous = 0;

    switch (level) {
      case 1:
        newPortalCount = 4;
        numDangerous = 0;
        break;
      case 2:
        newPortalCount = 6; // 5 mavi 1 kırmızı
        numDangerous = 1;
        break;
      case 3:
        newPortalCount = 6;
        numDangerous = 2;
        break;
      case 4:
        newPortalCount = 8;
        numDangerous = 3;
        break;
      case 5:
        newPortalCount = 6;
        numDangerous = 2;
        break;
      case 6:
        newPortalCount = 8;
        numDangerous = 3;
        break;
      case 7:
        newPortalCount = 6;
        numDangerous = 3;
        break;
      case 8:
        newPortalCount = 6;
        numDangerous = 2;
        break;
      case 10:
        newPortalCount = 6;
        numDangerous = 0;
        break;
      default:
        newPortalCount = portalCount + level - 1;
        numDangerous = min((newPortalCount / 3).round(), 5);
    }

    final dangerousIndices = List.generate(newPortalCount, (i) => i)..shuffle();
    final dangerSet = dangerousIndices.take(numDangerous).toSet();

    double baseSpeed = rotationSpeed + level * 0.2;
    bool reverseDirection = level >= 8;

    for (int i = 0; i < newPortalCount; i++) {
      double angle = (2 * pi / newPortalCount) * i;
      final isDanger = dangerSet.contains(i);
      final portal = Portal(angle, portalRadius, isDangerous: isDanger);

      if (level == 10) {
        portal.score = 1;
        portal.rotationSpeed = 1.0;
      } else if (isDanger) {
        int baseMax = -5 - level;
        int baseMin = -10 - level;

        if (baseMax < baseMin) {
          final temp = baseMin;
          baseMin = baseMax;
          baseMax = temp;
        }

        int range = baseMax - baseMin + 1;

        portal.score = range > 0 ? baseMin + Random().nextInt(range) : baseMin;
      } else {
        portal.score = Random().nextInt(5) + 1;
      }

      if (level >= 5 && level != 10) {
        double spinSpeed = 0.5 + level * 0.05;
        if (level == 8) {
          portal.rotationSpeed = -spinSpeed; // Sadece level 8 ters döner
        } else {
          portal.rotationSpeed = spinSpeed; // Diğerleri normal döner
        }
      }

      portal.position = center;
      portals.add(portal);
      add(portal);
    }

    // Level 10: coin collection stage
    if (level == 10) {
      // No dangerous portals, all blue, respawn after 2 seconds, 10s countdown
      Future.delayed(Duration(seconds: 10), () async {
        if (currentLevel == 10) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('coinLevel10Played', true);
          currentLevel = 11;
          loadLevel(currentLevel);
        }
      });
    }

    if (currentLevel >= 6 && Random().nextDouble() < 1 / 3 && level != 10) {
      final nonDangerous = portals
          .where((p) => !p.isDangerous && !p.isGreen)
          .toList();
      if (nonDangerous.isNotEmpty) {
        final selected = nonDangerous[Random().nextInt(nonDangerous.length)];
        selected.isGreen = true;
        selected.score = 0;
      }
    }

    if (currentLevel >= 20 && Random().nextDouble() < 1 / 5 && level != 10) {
      Future.delayed(Duration(seconds: Random().nextInt(5) + 2), () {
        if (!isLoaded || !children.contains(arrow)) return;
        final angle = Random().nextDouble() * 2 * pi;
        final orange = OrangeOrb(angle: angle, center: size / 2);
        activeOrangeOrb = orange;
        add(orange);
      });
    }

    arrow.speed = baseSpeed;

    levelText.text = 'Level: $currentLevel';
    isLoaded = true;
  }

  @override
  void update(double dt) {
    if (!isLoaded) return;
    super.update(dt);

    // Oku döndür
    arrow.updateAngle(dt);

    // Tüm topları güncelle
    for (int i = balls.length - 1; i >= 0; i--) {
      balls[i].updatePosition(dt);

      if (balls[i].hasReachedTarget(portals)) {
        if (!balls[i].hit) {
          balls[i].markHit();

          // Hangi portala vurduğunu bul ve puan ekle
          for (var p in portals) {
            final portalPos =
                size / 2 + Vector2(cos(p.angle), sin(p.angle)) * p.radius;
            final ballPos =
                size / 2 +
                Vector2(cos(balls[i].angle), sin(balls[i].angle)) *
                    balls[i].radius;
            final distance = (portalPos - ballPos).length;
            final collisionDistance = (p.size.x / 2) + (balls[i].size.x / 2);

            // --- YENİ BLOK ---
            if (distance < collisionDistance) {
              // Handle green portal (extra life)
              if (p.isGreen && children.contains(p)) {
                hasExtraLife = true;
                hitMessageText.text = 'Extra Life!';
                hitMessageText.textRenderer = TextPaint(
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                );
                hitMessageTimer = 0;

                portals.remove(p);
                p.removeFromParent();

                balls[i].removeFromParent();
                balls.removeAt(i);
                break;
              }
              // Handle dangerous portal (red)
              if (p.isDangerous) {
                if (hasExtraLife) {
                  hasExtraLife = false;
                  orangeOrbImmune = false;
                  hitMessageText.text = 'Extra life used!';
                  hitMessageText.textRenderer = TextPaint(
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                  hitMessageTimer = 0;

                  remove(balls[i]);
                  balls.removeAt(i);
                  break;
                }
                playWrongSound();
                comboCount = 0;
                totalScore -= p.score.abs();
                if (totalScore < 0) totalScore = 0;
                saveCoinScore();
                scoreText.text = 'Coins: $totalScore';
                hitMessageText.text = '-${p.score.abs()}';
                hitMessageText.textRenderer = TextPaint(
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                );
                hitMessageTimer = 0;

                add(
                  GrowingCircleEffect(
                    center: size / 2,
                    color: Colors.redAccent,
                    maxRadius: portalRadius + 10,
                  ),
                );

                Future.microtask(() => loadLevel(currentLevel));
                levelText.text = 'Level: $currentLevel';

                remove(balls[i]);
                balls.removeAt(i);
                break;
              } else {
                playCorrectSound();
                // Mavi topa çarpıldığında puan ekle
                comboCount++;
                totalScore += p.score * comboCount;
                saveCoinScore();
                scoreText.text = 'Coins: $totalScore';
                hitMessageText.text = '+${p.score * comboCount} (x$comboCount)';
                hitMessageText.textRenderer = TextPaint(
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                );
                hitMessageTimer = 0;

                p.add(
                  ScaleEffect.to(
                    Vector2.zero(),
                    EffectController(duration: 0.5, curve: Curves.easeOut),
                    onComplete: () async {
                      remove(p);
                      portals.remove(p);
                      // --- LEVEL ADVANCEMENT HANDLING WITH LEVEL 10 SKIP ---
                      if (portals
                          .where(
                            (portal) => !portal.isDangerous && !portal.isGreen,
                          )
                          .isEmpty) {
                        currentLevel++;
                        final prefs = await SharedPreferences.getInstance();
                        bool level10Played =
                            prefs.getBool('coinLevel10Played') ?? false;
                        if (currentLevel == 10 && level10Played) {
                          currentLevel = 11;
                        }
                        add(
                          GrowingCircleEffect(
                            center: size / 2,
                            color: Colors.blueAccent,
                            maxRadius: portalRadius + 10,
                          ),
                        );
                        Future.microtask(() => loadLevel(currentLevel));
                        hitMessageText.text = 'Level $currentLevel';
                        hitMessageText.textRenderer = TextPaint(
                          style: TextStyle(
                            color: Colors.yellowAccent,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                        hitMessageTimer = 0;
                        levelText.text = 'Level: $currentLevel';
                      }
                    },
                  ),
                );

                remove(balls[i]);
                balls.removeAt(i);
                break;
              }
            }
            // --- YENİ BLOK SONU ---
          }
        }
      }
      // Vurulduktan sonra 0.5 sn bekle, sonra kaldır
      else if (balls[i].hit && balls[i].hitTimer > 0.5) {
        remove(balls[i]);
        balls.removeAt(i);
      }
      // Vurulmadıysa dışarı çıkma ve ekran dışı kontrolü yap, yoksa bırak dönsün
      else if (!balls[i].hit) {
        if (balls[i].isOutOfRange(portalRadius + 150)) {
          // Dışarı çıkınca kaldır (yarıçapı biraz daha büyüttük)
          comboCount = 0;
          remove(balls[i]);
          balls.removeAt(i);
        } else if (balls[i].isOffScreen(size)) {
          comboCount = 0;
          remove(balls[i]);
          balls.removeAt(i);
        }
      }
    }

    // --- Orange Orb collision with Arrow ---
    if (activeOrangeOrb != null && activeOrangeOrb!.collidesWithArrow(arrow)) {
      if (orangeOrbImmune) {
        hasExtraLife = false;
        orangeOrbImmune = false;
      } else {
        playWrongSound();
        Future.microtask(() => loadLevel(currentLevel));
        hitMessageText.text = 'Hit by Orange Orb!';
      }
      activeOrangeOrb!.removeFromParent();
      activeOrangeOrb = null;
    }

    // Vuruş mesajını 1.5 sn göster sonra temizle
    if (hitMessageText.text.isNotEmpty) {
      hitMessageTimer += dt;
      if (hitMessageTimer > 1.5) {
        hitMessageText.text = '';
        hitMessageTimer = 0;
      }
    }
  }

  @override
  void onTap() {
    final center = size / 2;
    final ball = Ball(
      angle: arrow.angle,
      radius: 0,
      center: center,
      speedRadius: 100 + currentLevel * 10,
      speedAngle: arrow.speed,
      color: Colors.white,
    );
    balls.add(ball);
    add(ball);
  }
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

  Portal(this.angle, this.radius, {this.isDangerous = false}) {
    size = Vector2.all(20);
    anchor = Anchor.center;
    // score burada atanmayacak, loadLevel'de atanacak
  }

  @override
  void render(Canvas canvas) {
    final Paint paint = Paint()
      ..color = isGreen
          ? Colors.greenAccent
          : (isDangerous ? Colors.redAccent : Colors.blueAccent);
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
      if (trailTimer >= 0.05 &&
          gameRef.children.whereType<CometTrail>().length < 100) {
        gameRef.add(CometTrail(position.clone(), color));
        trailTimer = 0.0;
      }
    } else {
      hitTimer += dt;
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

class LevelSelectScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color.fromARGB(255, 49, 81, 210),
                Colors.black,
                const Color.fromARGB(255, 169, 32, 32),
              ],
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 40),
                Text(
                  '',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        blurRadius: 8,
                        color: Colors.black54,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 30),
                Container(
                  height: MediaQuery.of(context).size.height * 0.8,
                  child: GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    childAspectRatio: 1.2,
                    padding: EdgeInsets.all(20),
                    children: List.generate(40, (index) {
                      final level = index + 1;
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: CircleBorder(),
                          side: BorderSide(color: Colors.grey, width: 1),
                          padding: EdgeInsets.all(24),
                          textStyle: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          final game = RotatingArrowGame();
                          game.currentLevel = level;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GameWidget(
                                game: game,
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
                                        onPressed: () => Navigator.pop(context),
                                        child: Text('Menu'),
                                      ),
                                    );
                                  },
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
                                          showDialog(
                                            context: context,
                                            builder: (context) => ShopScreen(
                                              game: game as RotatingArrowGame,
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
                        },
                        child: Text('$level'),
                      );
                    }),
                  ),
                ),
                // --- SHOP UI REMOVED FROM HERE ---
                SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
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
