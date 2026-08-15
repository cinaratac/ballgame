import 'dart:math';
import 'dart:async' as dart_async;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flame/input.dart';
import 'package:flame/effects.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'parts/effect/DeathrRing.dart';
import 'parts/arrow.dart';
import 'parts/portal.dart';
import 'parts/ui/level_coin_display.dart';
import 'parts/effect/growingCircle.dart';

class RotatingArrowGame extends FlameGame with TapDetector {
  @override
  bool isLoaded = false;
  // --- PATCH: Shooting allowed flag ---
  bool allowShooting = true;
  Future<void> init() async {
    await loadCoinScore();
    scoreText.text = 'Coins: $totalScore';
  }

  final int portalCount = 6;
  final double portalRadius = 150;
  static const double ballRadialSpeedPerArrowSpeed = 50.0;
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

  int comboCount = 0;

  final List<AudioPlayer> _activeSoundPlayers = [];

  int currentArrowSkin = 0; // 0: beyaz, 1: altın, 2: gölgeli

  // --- Extra Life Mechanic ---
  bool hasExtraLife = false;

  // --- Orange Orb Mechanic ---
  bool orangeOrbImmune = false;
  OrangeOrb? activeOrangeOrb;

  dart_async.Timer? directionSwapTimer;
  dart_async.Timer? countdownTimer;
  TextComponent? countdownText;
  _FeatureTipOverlay? _activeFeatureTip;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final center = size / 2;

    add(_ArenaBackdrop());

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

    // Overlay menü butonunu göster
    overlays.add('levelMenuButton');
    overlays.add('tutorialButton');
    overlays.add('shopButton');

    isLoaded = true;
  }

  void playCorrectSound() {
    _playSound('correct.mp3');
  }

  void playWrongSound() {
    _playSound('wrong.mp3');
  }

  void _playSound(String assetPath) {
    final player = AudioPlayer();
    _activeSoundPlayers.add(player);

    if (_activeSoundPlayers.length > 6) {
      final oldestPlayer = _activeSoundPlayers.removeAt(0);
      dart_async.unawaited(oldestPlayer.dispose());
    }

    var isDisposed = false;
    late final dart_async.StreamSubscription<void> completeSubscription;

    void disposePlayer() {
      if (isDisposed) return;
      isDisposed = true;
      dart_async.unawaited(completeSubscription.cancel());
      _activeSoundPlayers.remove(player);
      dart_async.unawaited(player.dispose());
    }

    completeSubscription = player.onPlayerComplete.listen(
      (_) => disposePlayer(),
      onError: (_) => disposePlayer(),
    );

    dart_async.Timer(const Duration(seconds: 3), disposePlayer);

    dart_async.unawaited(
      player
          .play(
            AssetSource(assetPath, mimeType: 'audio/mpeg'),
            mode: PlayerMode.mediaPlayer,
            volume: 1,
          )
          .timeout(const Duration(seconds: 2))
          .catchError((error) {
            debugPrint('Sound playback failed: $error');
            disposePlayer();
            return Future<void>.value();
          }),
    );
  }

  void loadLevel(int level) {
    _setupLevel(level);
  }

  _FeatureTip? _featureTipForLevel(int level) {
    switch (level) {
      case 1:
        return const _FeatureTip(
          key: 'blue_targets',
          title: 'Blue targets',
          message: 'Aim the arrow and hit the blue targets.',
        );
      case 2:
        return const _FeatureTip(
          key: 'red_targets',
          title: 'Red targets',
          message: 'Red targets are dangerous. Do not hit them.',
        );
      case 5:
        return const _FeatureTip(
          key: 'spinning_targets',
          title: 'Spinning targets',
          message: 'Targets now rotate. Catch the rhythm.',
        );
      case 6:
        return const _FeatureTip(
          key: 'extra_life',
          title: 'Green target',
          message: 'Green targets give you an extra life.',
        );
      case 8:
        return const _FeatureTip(
          key: 'reverse_spin',
          title: 'Reverse spin',
          message: 'Targets can rotate in the opposite direction.',
        );
      case 13:
        return const _FeatureTip(
          key: 'death_ring',
          title: 'Red ring',
          message: 'Touching the red ring will restart the level.',
        );
      case 18:
        return const _FeatureTip(
          key: 'direction_swap',
          title: 'Direction swap',
          message: 'Targets can change direction during the level.',
        );
      case 20:
        return const _FeatureTip(
          key: 'orange_orb',
          title: 'Orange threat',
          message: 'Avoid the orange orb when it enters the arena.',
        );
      case 24:
        return const _FeatureTip(
          key: 'fast_direction_swap',
          title: 'Fast swaps',
          message: 'Direction changes now happen more often.',
        );
      case 26:
        return const _FeatureTip(
          key: 'memory_mask',
          title: 'Memory',
          message: 'Memorize the targets before their colors hide.',
        );
      case 27:
        return const _FeatureTip(
          key: 'moving_memory',
          title: 'Moving memory',
          message: 'Remember the colors while the hidden targets rotate.',
        );
      case 37:
        return const _FeatureTip(
          key: 'late_death_ring',
          title: 'Ring returns',
          message: 'Speed stays stable, but the red ring returns.',
        );
    }
    return null;
  }

  Future<void> _showFeatureTipIfNeeded(int level) async {
    final tip = _featureTipForLevel(level);
    if (tip == null) return;

    final prefs = await SharedPreferences.getInstance();
    final storageKey = 'featureTipShown_${tip.key}';
    if (prefs.getBool(storageKey) ?? false) return;
    await prefs.setBool(storageKey, true);
    if (currentLevel != level) return;

    _activeFeatureTip?.removeFromParent();
    _activeFeatureTip = _FeatureTipOverlay(tip: tip);
    add(_activeFeatureTip!);
  }

  void _dismissFeatureTip() {
    _activeFeatureTip?.removeFromParent();
    _activeFeatureTip = null;
  }

  double _arrowSpeedForLevel(int level) {
    final speedLevel = level <= 6 ? 4 : level;
    final speed = speedLevel <= 23
        ? rotationSpeed + speedLevel * 0.2
        : rotationSpeed + 23 * 0.2;
    return level >= 21 ? speed * 0.75 : speed;
  }

  void _clearCountdown() {
    countdownTimer?.cancel();
    countdownTimer = null;
    countdownText?.removeFromParent();
    countdownText = null;
  }

  void _clearActiveBalls() {
    for (final ball in balls.toList()) {
      ball.removeFromParent();
    }
    balls.clear();
  }

  void _startShootingCountdown({int seconds = 3}) {
    _clearCountdown();
    allowShooting = false;

    final text = TextComponent(
      text: '$seconds',
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
    countdownText = text;
    add(text);

    var counter = seconds;
    countdownTimer = dart_async.Timer.periodic(Duration(seconds: 1), (timer) {
      counter--;
      if (counter > 0) {
        text.text = '$counter';
        return;
      }

      timer.cancel();
      if (countdownTimer == timer) {
        countdownTimer = null;
        countdownText = null;
        text.removeFromParent();
        allowShooting = true;
        for (final p in portals) {
          p.isMasked = true;
        }
      }
    });
  }

  void _setupLevel(int level) async {
    isLoaded = false;
    _dismissFeatureTip();
    allowShooting = true;
    _clearCountdown();
    _clearActiveBalls();
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
    int? exactBlueCount;

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
      case 11:
        newPortalCount = portalCount + level - 4;
        exactBlueCount = 2;
        numDangerous = newPortalCount - exactBlueCount;
        break;
      case 12:
        newPortalCount = portalCount + level - 4;
        exactBlueCount = 4;
        numDangerous = newPortalCount - exactBlueCount;
        break;
      case 13:
        newPortalCount = 2;
        numDangerous = 0;
        break;
      case 14:
        final originalPortalCount = portalCount + level - 4;
        final defaultDangerousCount = (originalPortalCount / 3).round();
        final defaultBlueCount = originalPortalCount - defaultDangerousCount;
        exactBlueCount = (defaultBlueCount / 2).round();
        numDangerous = (defaultDangerousCount / 2).round();
        newPortalCount = exactBlueCount + numDangerous;
        break;
      case 15:
      case 16:
      case 17:
      case 18:
      case 19:
      case 20:
      case 21:
      case 22:
      case 23:
      case 24:
      case 25:
        final originalPortalCount = portalCount + level - 4;
        final defaultDangerousCount = (originalPortalCount / 3).round();
        final defaultBlueCount = originalPortalCount - defaultDangerousCount;
        exactBlueCount = (defaultBlueCount / 2).round();
        numDangerous = (defaultDangerousCount / 2).round();
        newPortalCount = exactBlueCount + numDangerous;
        break;
      case 26:
        newPortalCount = 4; // 2 blue, 2 red
        numDangerous = 2;
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
    if (exactBlueCount != null) {
      final blueSet = <int>{};
      for (int i = 0; i < exactBlueCount; i++) {
        blueSet.add((i * newPortalCount / exactBlueCount).floor());
      }
      dangerSet.addAll(
        List.generate(
          newPortalCount,
          (i) => i,
        ).where((i) => !blueSet.contains(i)),
      );
    } else {
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
    }

    final baseSpeed = _arrowSpeedForLevel(level);

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

        final rawPenalty = range > 0
            ? baseMin + Random().nextInt(range)
            : baseMin;
        final reducedPenalty = max(1, (rawPenalty.abs() * 0.85).round());
        portal.score = -reducedPenalty;
      } else {
        portal.score = Random().nextInt(5) + 1;
      }

      // --- PATCH: Level 5+ spin speed logic, custom for 27-40 ---
      if (level >= 5 && level != 13 && level != 14 && level != 26) {
        double spinSpeed;
        if (level <= 25) {
          spinSpeed = 0.4 + level * 0.035;
        } else if (level >= 27 && level <= 40) {
          final spinLevel = min(level, 36);
          spinSpeed = 0.1 + (spinLevel - 27) * 0.1;
          if (level >= 36) {
            spinSpeed *= 0.85;
          }
        } else {
          spinSpeed = 0.4 + (level - 25) * 0.02 + 0.4 + 25 * 0.035;
        }
        if (level >= 15 && level <= 25) {
          spinSpeed *= 0.7;
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

    // --- PATCH: Add DeathRing for level 13-20 and 37+ ---
    if ((level >= 13 && level <= 20) || level > 36) {
      final deathRing = DeathRing(
        radius: min(size.x, size.y) / 2,
        color: const Color.fromARGB(255, 159, 44, 44),
      );
      add(deathRing);
    }

    arrow.speed = baseSpeed;
    directionSwapTimer?.cancel();
    if (level >= 18 && level <= 20) {
      directionSwapTimer = dart_async.Timer.periodic(Duration(seconds: 10), (
        _,
      ) {
        startSmoothDirectionSwap(portals);
      });
    } else if (level == 24 || level == 25) {
      directionSwapTimer = dart_async.Timer.periodic(Duration(seconds: 5), (_) {
        startSmoothDirectionSwap(portals);
      });
    } else if (level == 26) {
      // No rotation and no direction swap
      _startShootingCountdown();
    } else if (level >= 27 && level <= 40) {
      _startShootingCountdown();
    }

    scoreText.text = 'Coins: $totalScore';
    levelText.text = 'Level: $currentLevel';
    // Save currentLevel to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('currentLevel', currentLevel);
    isLoaded = true;
    dart_async.unawaited(_showFeatureTipIfNeeded(level));
  }

  @override
  void onRemove() {
    directionSwapTimer?.cancel();
    _clearCountdown();
    _dismissFeatureTip();
    for (final player in _activeSoundPlayers) {
      dart_async.unawaited(player.dispose());
    }
    _activeSoundPlayers.clear();
    super.onRemove();
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
    if (_activeFeatureTip != null) {
      _dismissFeatureTip();
      return;
    }
    if (!allowShooting) return;

    final center = size / 2;
    final ball = Ball(
      angle: arrow.angle,
      radius: 0,
      center: center,
      radialSpeedRatio: ballRadialSpeedPerArrowSpeed,
      angularSpeedRatio: 1,
      color: Colors.white,
    );
    balls.add(ball);
    add(ball);
  }

  @override
  Color backgroundColor() => const Color(0xFF050506);
}

class _ArenaBackdrop extends Component
    with HasGameReference<RotatingArrowGame> {
  _ArenaBackdrop() {
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

class _FeatureTip {
  const _FeatureTip({
    required this.key,
    required this.title,
    required this.message,
  });

  final String key;
  final String title;
  final String message;
}

class _FeatureTipOverlay extends Component
    with HasGameReference<RotatingArrowGame> {
  _FeatureTipOverlay({required this.tip}) {
    priority = 2000;
  }

  final _FeatureTip tip;

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
