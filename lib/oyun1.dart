import 'dart:math';
import 'dart:async' as dart_async;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flame/input.dart';
import 'package:flame/effects.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'parts/effect/DeathrRing.dart';
import 'parts/arrow.dart';
import 'parts/portal.dart';
import 'parts/ui/level_coin_display.dart';
import 'parts/effect/growingCircle.dart';

class MainOverlays {
  static const String mainMenu = 'MainMenu';
  static const String backToMenu = 'BackToMenu';
}

class RotatingArrowGame extends FlameGame
    with TapDetector, WidgetsBindingObserver {
  bool isLoaded = false;
  // --- PATCH: Shooting allowed flag ---
  bool allowShooting = true;
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
  late TextComponent levelText;

  late TextComponent hitMessageText;
  double hitMessageTimer = 0;

  int currentLevel = 1;
  bool _hasActiveLevel = false; // yüklü/çalışan level var mı?

  int comboCount = 0;

  late final AudioPlayer correctPlayer;
  late final AudioPlayer wrongPlayer;

  int currentArrowSkin = 0; // 0: beyaz, 1: altın, 2: gölgeli

  // --- Extra Life Mechanic ---
  bool hasExtraLife = false;

  // --- Orange Orb Mechanic ---
  bool orangeOrbImmune = false;
  OrangeOrb? activeOrangeOrb;

  dart_async.Timer? directionSwapTimer;

  @override
  Future<void> onLoad() async {
    WidgetsBinding.instance.addObserver(this);
    await loadSavedGameIfAny();
    await super.onLoad();
    final center = size / 2;

    // Ok oluştur ve ekle
    arrow = Arrow(angle: 0, speed: rotationSpeed, center: center);
    arrow.position = center;
    add(arrow);

    // Arrow inventory yükle
    await loadOwnedArrows();

    // Add score and level text for internal tracking (do not add to scene)
    scoreText = TextComponent();
    levelText = TextComponent();
    await loadCoinScore();

    // Add LevelCoinDisplay (handles level and coins display)
    add(
      LevelCoinDisplay(
        level: currentLevel,
        coins: totalScore,
        position: Vector2(size.x / 2, 0),
      ),
    );

    // Restore currentLevel from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    currentLevel = prefs.getInt('currentLevel') ?? currentLevel;

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

    // Açılışta Ana Menü
    pauseEngine();
    overlays.add(MainOverlays.mainMenu);

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
    _setupLevel(level);
  }

  void _setupLevel(int level) async {
    isLoaded = false;
    portals.clear();
    hasExtraLife = false;
    orangeOrbImmune = false;
    // Remove any existing orange orb before new level setup
    if (activeOrangeOrb != null) {
      activeOrangeOrb!.removeFromParent();
      activeOrangeOrb = null;
    }

    for (final child in children.whereType<Portal>().toList()) {
      remove(child);
    }

    // --- PATCH: Remove DeathRing if present ---
    for (final child in children.whereType<DeathRing>().toList()) {
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
        numDangerous = 4;
        break;
      case 26:
        newPortalCount = 4; // 2 blue, 2 red
        numDangerous = 2;
        break;
      case 13:
        newPortalCount = 2;
        numDangerous = 0;
        break;
      case 14:
        newPortalCount = 5;
        numDangerous = 4;
        break;
      case 15:
      case 16:
      case 17:
      case 18:
      case 19:
      case 20:
        newPortalCount = portalCount + level - 15;
        numDangerous = (newPortalCount / 3).round();
        break;
      case 21:
      case 22:
      case 23:
      case 24:
      case 25:
        newPortalCount = portalCount + level - 14;
        numDangerous = (newPortalCount / 3).round();
        break;
      case 27:
      case 28:
      case 29:
      case 30:
      case 31:
      case 32:
      case 33:
      case 34:
      case 35:
      case 36:
      case 37:
      case 38:
      case 39:
      case 40:
        newPortalCount =
            4 + (level - 26) ~/ 2; // gradually increase number of balls
        numDangerous = newPortalCount ~/ 2;
        break;
      default:
        newPortalCount = portalCount + level - 4;
        numDangerous = (newPortalCount / 3)
            .round(); // kırmızı sayısını maviye göre dengeli ayarla
    }

    bool hasThreeAdjacent(Set<int> set, int total) {
      for (int i = 0; i < total; i++) {
        if (set.contains(i) &&
            set.contains((i + 1) % total) &&
            set.contains((i + 2) % total)) {
          return true;
        }
      }
      return false;
    }

    final dangerSet = <int>{};
    int attempts = 0;
    while (attempts < 1000) {
      final candidate = <int>{};
      final indices = List.generate(newPortalCount, (i) => i)..shuffle();
      for (final idx in indices) {
        candidate.add(idx);
        if (candidate.length == numDangerous) break;
      }
      if (!hasThreeAdjacent(candidate, newPortalCount)) {
        dangerSet.addAll(candidate);
        break;
      }
      attempts++;
    }

    double baseSpeed;
    if (level <= 23) {
      baseSpeed = rotationSpeed + level * 0.2;
    } else if (level > 23 && level <= 25) {
      baseSpeed = rotationSpeed + 23 * 0.2;
    } else if (level >= 26 && level <= 29) {
      baseSpeed = rotationSpeed + 5 * 0.2;
    } else if (level >= 30 && level <= 40) {
      baseSpeed = rotationSpeed + (level - 25) * 0.2;
    } else {
      baseSpeed = rotationSpeed; // varsayılan değer, örneğin 2.0
    }

    for (int i = 0; i < newPortalCount; i++) {
      double angle = (2 * pi / newPortalCount) * i;
      final isDanger = dangerSet.contains(i);
      final portal = Portal(angle, portalRadius, isDangerous: isDanger);

      if (isDanger) {
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

      // --- PATCH: Level 5+ spin speed logic, custom for 27-40 ---
      if (level >= 5 && level != 13 && level != 14 && level != 26) {
        double spinSpeed;
        if (level <= 25) {
          spinSpeed = 0.4 + level * 0.035;
        } else if (level >= 27 && level <= 40) {
          spinSpeed =
              0.1 +
              (level - 27) * 0.1; // starts very slow at level 27 and grows
        } else {
          spinSpeed = 0.4 + (level - 25) * 0.02 + 0.4 + 25 * 0.035;
        }
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
        // Only spawn a new orange orb if none is active
        if (!isLoaded || !children.contains(arrow)) return;
        if (activeOrangeOrb != null) return;
        final angle = Random().nextDouble() * 2 * pi;
        final orange = OrangeOrb(angle: angle, center: size / 2);
        activeOrangeOrb = orange;
        add(orange);
      });
    }

    // --- PATCH: Add DeathRing for level 13-20 ---
    if (level >= 13 && level <= 20) {
      final deathRing = DeathRing(
        radius: min(size.x, size.y) / 2,
        color: const Color.fromARGB(255, 159, 44, 44),
      );
      add(deathRing);
    }

    arrow.speed = baseSpeed;
    directionSwapTimer?.cancel();
    if (level >= 18 && level <= 20) {
      directionSwapTimer = dart_async.Timer.periodic(Duration(seconds: 6), (_) {
        startSmoothDirectionSwap(portals);
      });
    } else if (level == 24 || level == 25) {
      directionSwapTimer = dart_async.Timer.periodic(Duration(seconds: 4), (_) {
        startSmoothDirectionSwap(portals);
      });
    } else if (level >= 26 && level <= 35) {
      // No rotation and no direction swap
      // --- PATCH: Level 26 countdown and masking logic ---
      // PATCH: Disallow shooting during countdown
      allowShooting = false;
      final countdownText = TextComponent(
        text: '3',
        position: Vector2(size.x / 2, size.y / 2 - 100),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(
            color: Colors.white,
            fontSize: 60,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      add(countdownText);

      int counter = 3;
      dart_async.Timer.periodic(Duration(seconds: 1), (timer) {
        counter--;
        if (counter > 0) {
          countdownText.text = '$counter';
        } else {
          countdownText.removeFromParent();
          timer.cancel();
          // PATCH: Allow shooting after countdown
          allowShooting = true;
          for (final p in portals) {
            p.isMasked = true;
          }
        }
      });
    } else if (level >= 36 && level <= 40) {
      allowShooting = false;
      final countdownText = TextComponent(
        text: '5',
        position: Vector2(size.x / 2, size.y / 2 - 100),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(
            color: Colors.white,
            fontSize: 60,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      add(countdownText);

      int counter = 5;
      dart_async.Timer.periodic(Duration(seconds: 1), (timer) {
        counter--;
        if (counter > 0) {
          countdownText.text = '$counter';
        } else {
          countdownText.removeFromParent();
          timer.cancel();
          allowShooting = true;
          for (final p in portals) {
            p.isMasked = true;
          }
        }
      });
    }

    scoreText.text = 'Coins: $totalScore';
    levelText.text = 'Level: $currentLevel';
    // Save currentLevel to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('currentLevel', currentLevel);
    isLoaded = true;
  }

  @override
  @override
  void onRemove() {
    WidgetsBinding.instance.removeObserver(this);
    super.onRemove();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // uyg. arka plana atıldı/kapatılıyor -> kaydet
      saveGameState();
    }
  }

  void startGame({int? level}) {
    overlays.remove(MainOverlays.mainMenu);
    overlays.add(MainOverlays.backToMenu);
    resumeEngine();
    if (level != null) {
      currentLevel = level;
    }
    loadLevel(currentLevel);
    _hasActiveLevel = true; // <-- BUNU EKLE
  }

  void continueGame() {
    overlays.remove(MainOverlays.mainMenu);
    overlays.add(MainOverlays.backToMenu);
    if (!_hasActiveLevel) {
      // hiç level yoksa en azından mevcut leveli yükle
      loadLevel(currentLevel);
      _hasActiveLevel = true;
    }
    resumeEngine();
  }

  void goToMenu() {
    pauseEngine();
    overlays.remove(MainOverlays.backToMenu);
    overlays.add(MainOverlays.mainMenu);
    saveGameState();
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
                    color: const Color.fromARGB(255, 159, 44, 44),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                );
                hitMessageTimer = 0;

                add(
                  GrowingCircleEffect(
                    center: size / 2,
                    color: const Color.fromARGB(255, 159, 44, 44),
                    maxRadius: portalRadius + 10,
                  ),
                );

                Future.microtask(() => loadLevel(currentLevel));
                levelText.text = 'Level: $currentLevel';

                remove(balls[i]);
                balls.removeAt(i);
                break;
              } else if (!p.isDangerous && !p.isGreen) {
                // --- Patch: Add guard to prevent double-hitting blue portals ---
                if (p.children.isNotEmpty || !children.contains(p)) {
                  break;
                }
                playCorrectSound();
                // Mavi topa çarpıldığında puan ekle
                comboCount++;
                totalScore += p.score * comboCount;
                saveCoinScore();
                scoreText.text = 'Coins: $totalScore';
                hitMessageText.text = '+${p.score * comboCount} (x$comboCount)';
                hitMessageText.textRenderer = TextPaint(
                  style: TextStyle(
                    color: const Color.fromARGB(255, 20, 72, 162),
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
                      if (children.contains(p)) {
                        p.removeFromParent();
                      }
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
                            color: const Color.fromARGB(255, 20, 72, 162),
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
                // Remove portal from list immediately after effect is added
                portals.remove(p);

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

    // --- Orange Orb collision with Ball ---
    if (activeOrangeOrb != null) {
      for (int i = balls.length - 1; i >= 0; i--) {
        final ball = balls[i];
        final ballPos =
            size / 2 + Vector2(cos(ball.angle), sin(ball.angle)) * ball.radius;
        if ((activeOrangeOrb!.position - ballPos).length < 20) {
          activeOrangeOrb!.removeFromParent();
          activeOrangeOrb = null;
          remove(ball);
          balls.removeAt(i);
          break;
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
    if (!allowShooting) return;

    final center = size / 2;

    double speedRadius;
    if (currentLevel <= 23) {
      speedRadius = 100 + currentLevel * 10;
    } else if (currentLevel > 23 && currentLevel <= 25) {
      speedRadius = 100 + 23 * 10;
    } else if (currentLevel >= 26 && currentLevel <= 29) {
      speedRadius = 100 + 50;
    } else if (currentLevel >= 30 && currentLevel <= 40) {
      speedRadius = 100 + (currentLevel - 25) * 10;
    } else {
      speedRadius = 100; // varsayılan değer
    }

    final ball = Ball(
      angle: arrow.angle,
      radius: 0,
      center: center,
      speedRadius: speedRadius,
      speedAngle: arrow.speed,
      color: Colors.white,
    );

    balls.add(ball);
    add(ball);
  }

  @override
  Color backgroundColor() => const Color.fromARGB(255, 146, 146, 190);

  Future<void> saveGameState() async {
    final prefs = await SharedPreferences.getInstance();

    // Minimum: sadece level
    final data = {
      'currentLevel': currentLevel,
      'hasActive': _hasActiveLevel,

      // İstersen BURAYA ek bilgiler koy:
      // 'arrowAngle': arrow.angle,
      // 'score': score,
      // 'randomSeed': randomSeed,
      // 'balls': balls.map((b) => {'x': b.x, 'y': b.y, 'vx': b.vx, 'vy': b.vy}).toList(),
    };

    await prefs.setString('savegame', jsonEncode(data));
  }

  Future<void> loadSavedGameIfAny() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('savegame');
    if (raw == null) return;

    final data = jsonDecode(raw) as Map<String, dynamic>;

    // Minimum: sadece leveli al
    currentLevel = (data['currentLevel'] as num?)?.toInt() ?? currentLevel;
    _hasActiveLevel = (data['hasActive'] as bool?) ?? false;

    // Eğer tam state sakladıysan BURADA geri ata:
    // arrow.angle = (data['arrowAngle'] as num?)?.toDouble() ?? arrow.angle;
    // score = (data['score'] as num?)?.toInt() ?? 0;
    // randomSeed = (data['randomSeed'] as num?)?.toInt() ?? defaultSeed;
    // balls = (data['balls'] as List).map((m) => Ball.fromJson(m)).toList();

    // Uygulama yeni açıldıysa: aktif level varsa en azından yükle
    if (_hasActiveLevel) {
      // Not: Tam konum/velocity’leri saklamıyorsan level baştan yüklenir.
      // Tam kaldığın anı istiyorsan o alanları da serialize etmen gerekir.
      loadLevel(currentLevel);
    }
  }
}
