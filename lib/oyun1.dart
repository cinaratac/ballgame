import 'dart:math';
import 'dart:async' as dart_async;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flame/input.dart';
import 'package:flame/effects.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'parts/effect/death_ring.dart';
import 'parts/effect/arena_backdrop.dart';
import 'parts/arrow.dart';
import 'parts/portal.dart';
import 'parts/ui/level_coin_display.dart';
import 'parts/ui/feature_tip_overlay.dart';
import 'parts/effect/growing_circle.dart';
import 'services/ad_service.dart';

class RotatingArrowGame extends FlameGame with TapDetector {
  static const int originalLevelCount = 45;
  static const int maxLevel = originalLevelCount * 2;
  static const int levelProgressVersion = 2;

  static int baseLevelFor(int level) {
    return ((level + 1) ~/ 2).clamp(1, originalLevelCount).toInt();
  }

  static bool isEasyVersionLevel(int level) {
    return level.isOdd;
  }

  static bool isFeatureIntroLevel(int level) {
    return level == baseLevelFor(level) * 2 - 1;
  }

  @override
  bool isLoaded = false;
  bool allowShooting = true;
  Future<void> init() async {
    await loadCoinScore();
    scoreText.text = 'Coins: $totalScore';
  }

  final int portalCount = 6;
  final double portalRadius = 150;
  static const double ballRadialSpeedPerArrowSpeed = 50.0;
  final Random _random = Random();
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
    await prefs.setStringList(
      'ownedArrows',
      ownedArrows.map((e) => e.toString()).toList(),
    );
  }

  Future<void> loadOwnedArrows() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('ownedArrows');
    if (list != null) {
      ownedArrows = {0, ...list.map(int.tryParse).whereType<int>()};
    }
  }

  late TextComponent scoreText;
  late TextComponent levelText;

  late TextComponent hitMessageText;
  double hitMessageTimer = 0;

  int currentLevel = 1;
  int highestUnlockedLevel = 1;
  final ValueNotifier<int> levelProgressRevision = ValueNotifier<int>(0);

  int comboCount = 0;

  final List<AudioPlayer> _activeSoundPlayers = [];

  int currentArrowSkin = 0; // 0: beyaz, 1: altın, 2: gölgeli

  // --- Extra Life Mechanic ---
  bool hasExtraLife = false;

  // --- Orange Orb Mechanic ---
  bool orangeOrbImmune = false;
  OrangeOrb? activeOrangeOrb;
  int _orangeChallengeSpawned = 0;
  int _orangeChallengeHits = 0;
  dart_async.Timer? _orangeChallengeTimer;

  dart_async.Timer? directionSwapTimer;
  dart_async.Timer? countdownTimer;
  TextComponent? countdownText;
  FeatureTipOverlay? _activeFeatureTip;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final center = size / 2;

    add(ArenaBackdrop());

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
    final hasSavedLevel = prefs.containsKey('currentLevel');
    final savedProgressVersion =
        prefs.getInt('levelProgressVersion') ??
        (hasSavedLevel ? 1 : levelProgressVersion);
    var savedLevel = (prefs.getInt('currentLevel') ?? currentLevel)
        .clamp(1, maxLevel)
        .toInt();
    var savedUnlocked = (prefs.getInt('highestUnlockedLevel') ?? savedLevel)
        .clamp(1, maxLevel)
        .toInt();

    if (hasSavedLevel && savedProgressVersion < levelProgressVersion) {
      savedLevel = (savedLevel * 2).clamp(1, maxLevel).toInt();
      savedUnlocked = (savedUnlocked * 2).clamp(1, maxLevel).toInt();
      await prefs.setInt('currentLevel', savedLevel);
      await prefs.setInt('highestUnlockedLevel', savedUnlocked);
    }
    await prefs.setInt('levelProgressVersion', levelProgressVersion);

    highestUnlockedLevel = savedUnlocked;
    currentLevel = savedLevel.clamp(1, highestUnlockedLevel).toInt();
    _notifyLevelProgress();

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
    overlays.add('levelNavigationButtons');
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

  bool isLevelUnlocked(int level) {
    return level >= 1 && level <= highestUnlockedLevel;
  }

  bool get canGoToPreviousLevel => currentLevel > 1;

  bool get canGoToNextLevel {
    return currentLevel < maxLevel && currentLevel < highestUnlockedLevel;
  }

  void _notifyLevelProgress() {
    levelProgressRevision.value++;
  }

  Future<void> _saveCurrentLevel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('currentLevel', currentLevel);
    await prefs.setInt('highestUnlockedLevel', highestUnlockedLevel);
    await prefs.setInt('levelProgressVersion', levelProgressVersion);
    _notifyLevelProgress();
  }

  Future<bool> _unlockThroughLevel(int level) async {
    final clampedLevel = level.clamp(1, maxLevel).toInt();
    if (clampedLevel <= highestUnlockedLevel) return false;
    highestUnlockedLevel = clampedLevel;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('highestUnlockedLevel', highestUnlockedLevel);
    await prefs.setInt('levelProgressVersion', levelProgressVersion);
    _notifyLevelProgress();
    return true;
  }

  Future<void> _showUnlockAdIfNeeded(bool didUnlock, int unlockedLevel) async {
    if (!didUnlock) return;
    await AdService.instance.showAfterLevelUnlockIfReady(unlockedLevel);
  }

  Future<void> unlockAllLevels() async {
    highestUnlockedLevel = maxLevel;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('highestUnlockedLevel', highestUnlockedLevel);
    await prefs.setInt('levelProgressVersion', levelProgressVersion);
    _notifyLevelProgress();
  }

  void loadLevel(int level) {
    final targetLevel = level.clamp(1, maxLevel).toInt();
    if (!isLevelUnlocked(targetLevel)) return;
    _setupLevel(targetLevel);
  }

  Future<void> _showFeatureTipIfNeeded(int level) async {
    final tip = featureTipForLevel(level);
    if (tip == null) return;

    final prefs = await SharedPreferences.getInstance();
    final storageKey = 'featureTipShown_${tip.key}';
    if (prefs.getBool(storageKey) ?? false) return;
    await prefs.setBool(storageKey, true);
    if (currentLevel != level) return;

    _activeFeatureTip?.removeFromParent();
    _activeFeatureTip = FeatureTipOverlay(tip: tip);
    add(_activeFeatureTip!);
  }

  int baseLevelForCurrentLevel() {
    return baseLevelFor(currentLevel);
  }

  bool isEasyVersionForLevel(int level) {
    return isEasyVersionLevel(level);
  }

  bool hasDeathRingForLevel(int level) {
    final baseLevel = baseLevelFor(level);
    if (baseLevel >= 40) return level > 88;
    return (baseLevel >= 13 && baseLevel <= 20) || baseLevel > 36;
  }

  bool _isOrangeChallengeLevel(int level) {
    return baseLevelFor(level) == 20;
  }

  void _dismissFeatureTip() {
    _activeFeatureTip?.removeFromParent();
    _activeFeatureTip = null;
  }

  double _arrowSpeedForLevel(int level) {
    final baseLevel = baseLevelFor(level);
    final speedLevel = baseLevel <= 6 ? 6 : baseLevel;
    final speed = speedLevel <= 23
        ? rotationSpeed + speedLevel * 0.2
        : rotationSpeed + 23 * 0.2;
    final balancedSpeed = baseLevel >= 21 ? speed * 0.75 : speed;
    return isEasyVersionLevel(level) ? balancedSpeed * 0.82 : balancedSpeed;
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

  void _clearOrangeOrbs() {
    _orangeChallengeTimer?.cancel();
    _orangeChallengeTimer = null;
    _orangeChallengeSpawned = 0;
    _orangeChallengeHits = 0;
    activeOrangeOrb = null;
    for (final orb in children.whereType<OrangeOrb>().toList()) {
      orb.removeFromParent();
    }
  }

  void _clearRedPanels() {
    for (final panel in children.whereType<RedPanel>().toList()) {
      panel.removeFromParent();
    }
  }

  void _removeBallAt(int index) {
    final ball = balls[index];
    remove(ball);
    balls.removeAt(index);
  }

  bool _isSideMovementLevel(int level) {
    final baseLevel = baseLevelFor(level);
    return baseLevel >= 40 && baseLevel <= originalLevelCount;
  }

  int _dangerPenaltyForLevel(int level) {
    final baseLevel = baseLevelFor(level);
    final baseMin = -10 - baseLevel;
    final baseMax = -5 - baseLevel;
    final range = baseMax - baseMin + 1;
    final rawPenalty = range > 0 ? baseMin + _random.nextInt(range) : baseMin;
    final penaltyScale = isEasyVersionLevel(level) ? 0.35 : 0.5;
    return -max(1, (rawPenalty.abs() * penaltyScale).round());
  }

  Future<void> _setupSideMovementLevel(int level, Vector2 center) async {
    final baseLevel = baseLevelFor(level);
    final isEasyVersion = isEasyVersionLevel(level);
    final sideDangerIndex = !isEasyVersion && baseLevel == 41 ? 1 : -1;
    final sideMoverCount = isEasyVersion
        ? switch (baseLevel) {
            40 => 2,
            41 => 3,
            _ => 4,
          }
        : 4;

    for (int i = 0; i < sideMoverCount; i++) {
      final side = switch (sideMoverCount) {
        2 => i == 0 ? -1 : 1,
        3 => i == 1 ? 1 : -1,
        _ => i < 2 ? -1 : 1,
      };
      final phase = switch (sideMoverCount) {
        2 => i == 0 ? 0.0 : pi,
        3 => i == 2 ? pi : 0.0,
        _ => i.isEven ? 0.0 : pi,
      };
      final portal = VerticalMovingPortal(
        side: side,
        radius: portalRadius,
        phase: phase,
        isDangerous: i == sideDangerIndex,
      );
      portal.score = portal.isDangerous
          ? _dangerPenaltyForLevel(level)
          : _random.nextInt(5) + 1;
      portal.position = center;
      portals.add(portal);
      add(portal);
    }

    void addOrbitPortal({
      required double angle,
      required bool isDangerous,
      double speed = 0.72,
    }) {
      final portal = Portal(angle, portalRadius, isDangerous: isDangerous)
        ..score = isDangerous
            ? _dangerPenaltyForLevel(level)
            : _random.nextInt(5) + 1
        ..rotationSpeed = isEasyVersion ? speed * 0.72 : speed;
      portals.add(portal);
      add(portal);
    }

    if (level == 81) {
      addOrbitPortal(angle: -pi / 2, isDangerous: true);
    } else if (level == 83) {
      addOrbitPortal(angle: -pi / 2, isDangerous: true);
      addOrbitPortal(angle: pi / 2, isDangerous: true);
    } else if (level == 87) {
      addOrbitPortal(angle: -pi / 2, isDangerous: true);
      addOrbitPortal(angle: pi / 2, isDangerous: false);
    }

    if (!isEasyVersion &&
        (baseLevel == 42 || baseLevel == 44 || baseLevel == 45)) {
      final redOrbit = Portal(-pi / 2, portalRadius, isDangerous: true)
        ..score = _dangerPenaltyForLevel(level)
        ..rotationSpeed = 0.72;
      portals.add(redOrbit);
      add(redOrbit);
    }

    if (baseLevel == 45) {
      final blueOrbit = Portal(pi / 2, portalRadius)
        ..score = _random.nextInt(5) + 1
        ..rotationSpeed = isEasyVersion ? 0.52 : 0.72;
      portals.add(blueOrbit);
      add(blueOrbit);
    }

    if (!hasDeathRingForLevel(level)) {
      if (isEasyVersion && baseLevel == 43) {
        add(RedPanel(side: -1, radius: portalRadius));
      } else if (isEasyVersion && (baseLevel == 44 || baseLevel == 45)) {
        add(RedPanel(side: -1, radius: portalRadius));
        add(RedPanel(side: 1, radius: portalRadius));
      } else if (baseLevel == 43 || baseLevel == 44 || baseLevel == 45) {
        add(RedPanel(side: -1, radius: portalRadius));
        add(RedPanel(side: 1, radius: portalRadius));
      }
    }

    if (hasDeathRingForLevel(level)) {
      add(
        DeathRing(
          radius: min(size.x, size.y) / 2,
          color: const Color.fromARGB(255, 159, 44, 44),
        ),
      );
    }

    arrow.speed = _arrowSpeedForLevel(level);
    scoreText.text = 'Coins: $totalScore';
    levelText.text = 'Level: $currentLevel';

    await _saveCurrentLevel();
    isLoaded = true;
    dart_async.unawaited(_showFeatureTipIfNeeded(level));
  }

  Future<void> _setupOrangeChallengeLevel() async {
    arrow.speed = _arrowSpeedForLevel(currentLevel);
    scoreText.text = 'Coins: $totalScore';
    levelText.text = 'Level: $currentLevel';

    await _saveCurrentLevel();

    isLoaded = true;
    dart_async.unawaited(_showFeatureTipIfNeeded(currentLevel));
    _startOrangeChallenge();
  }

  int _orangeChallengeTargetCountForLevel(int level) {
    return isEasyVersionLevel(level) ? 3 : 5;
  }

  void _startOrangeChallenge() {
    _orangeChallengeTimer?.cancel();
    _orangeChallengeSpawned = 0;
    _orangeChallengeHits = 0;
    final targetCount = _orangeChallengeTargetCountForLevel(currentLevel);
    final intervalMs = (9000 / targetCount).round();

    _spawnOrangeChallengeOrb();
    _orangeChallengeTimer = dart_async.Timer.periodic(
      Duration(milliseconds: intervalMs),
      (timer) {
        if (!isLoaded || !_isOrangeChallengeLevel(currentLevel)) {
          timer.cancel();
          return;
        }
        if (_orangeChallengeSpawned >= targetCount) {
          timer.cancel();
          _orangeChallengeTimer = null;
          return;
        }
        _spawnOrangeChallengeOrb();
      },
    );
  }

  void _spawnOrangeChallengeOrb() {
    if (_orangeChallengeSpawned >=
        _orangeChallengeTargetCountForLevel(currentLevel)) {
      return;
    }
    final orange = OrangeOrb(
      angle: _random.nextDouble() * 2 * pi,
      center: size / 2,
    );
    _orangeChallengeSpawned++;
    add(orange);
  }

  Future<void> _handleOrangeChallengeHit() async {
    _orangeChallengeHits++;
    final targetCount = _orangeChallengeTargetCountForLevel(currentLevel);
    hitMessageText.text = 'Orange $_orangeChallengeHits/$targetCount';
    hitMessageText.textRenderer = TextPaint(
      style: const TextStyle(
        color: Colors.orangeAccent,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
    hitMessageTimer = 0;

    if (_orangeChallengeHits < targetCount) return;

    _orangeChallengeTimer?.cancel();
    _orangeChallengeTimer = null;
    _clearOrangeOrbs();
    final nextLevel = (currentLevel + 1).clamp(1, maxLevel).toInt();
    final didUnlock = await _unlockThroughLevel(nextLevel);
    await _showUnlockAdIfNeeded(didUnlock, nextLevel);
    currentLevel = nextLevel;
    add(
      GrowingCircleEffect(
        center: size / 2,
        color: Colors.orangeAccent,
        maxRadius: portalRadius + 10,
      ),
    );
    Future.microtask(() => loadLevel(currentLevel));
    hitMessageText.text = 'Level $currentLevel';
    hitMessageText.textRenderer = TextPaint(
      style: const TextStyle(
        color: Colors.yellowAccent,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
    hitMessageTimer = 0;
    levelText.text = 'Level: $currentLevel';
  }

  void _restartOrangeChallenge() {
    playWrongSound();
    comboCount = 0;
    hitMessageText.text = 'Orange reached center!';
    hitMessageText.textRenderer = TextPaint(
      style: const TextStyle(
        color: Colors.orangeAccent,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
    hitMessageTimer = 0;
    Future.microtask(() => loadLevel(currentLevel));
  }

  void _restartFromPanelHit() {
    playWrongSound();
    comboCount = 0;
    add(
      GrowingCircleEffect(
        center: size / 2,
        color: const Color.fromARGB(255, 159, 44, 44),
        maxRadius: portalRadius + 10,
      ),
    );
    hitMessageText.text = 'Panel hit!';
    hitMessageText.textRenderer = TextPaint(
      style: const TextStyle(
        color: Color.fromARGB(255, 159, 44, 44),
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
    hitMessageTimer = 0;
    Future.microtask(() => loadLevel(currentLevel));
  }

  bool _ballHitsRedPanel(Ball ball) {
    return children.whereType<RedPanel>().any(
      (panel) => panel.collidesWithBall(ball),
    );
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
    currentLevel = level;
    final baseLevel = baseLevelFor(level);
    final isEasyVersion = isEasyVersionLevel(level);
    _dismissFeatureTip();
    allowShooting = true;
    directionSwapTimer?.cancel();
    directionSwapTimer = null;
    _clearCountdown();
    _clearActiveBalls();
    _clearOrangeOrbs();
    _clearRedPanels();
    portals.clear();
    hasExtraLife = false;
    orangeOrbImmune = false;

    for (final child in children.whereType<Portal>().toList()) {
      remove(child);
    }

    for (final child in children.whereType<DeathRing>().toList()) {
      remove(child);
    }

    if (_isOrangeChallengeLevel(level)) {
      await _setupOrangeChallengeLevel();
      return;
    }

    final center = size / 2;

    if (_isSideMovementLevel(level)) {
      await _setupSideMovementLevel(level, center);
      return;
    }

    int newPortalCount;
    int numDangerous = 0;
    int? exactBlueCount;

    switch (baseLevel) {
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
        newPortalCount = portalCount + baseLevel - 4;
        exactBlueCount = 2;
        numDangerous = newPortalCount - exactBlueCount;
        break;
      case 12:
        newPortalCount = portalCount + baseLevel - 4;
        exactBlueCount = 4;
        numDangerous = newPortalCount - exactBlueCount;
        break;
      case 13:
        newPortalCount = 2;
        numDangerous = 0;
        break;
      case 14:
        final originalPortalCount = portalCount + baseLevel - 4;
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
        final originalPortalCount = portalCount + baseLevel - 4;
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
        newPortalCount =
            4 + (baseLevel - 26) ~/ 2; // gradually increase number of balls
        numDangerous = newPortalCount ~/ 2;
        break;
      default:
        newPortalCount = portalCount + baseLevel - 4;
        numDangerous = (newPortalCount / 3)
            .round(); // kırmızı sayısını maviye göre dengeli ayarla
    }

    if (isEasyVersion) {
      final blueCount = exactBlueCount ?? newPortalCount - numDangerous;
      final easyBlueCount = max(1, (blueCount * 0.72).ceil());
      final easyDangerousCount = numDangerous == 0
          ? 0
          : max(1, (numDangerous * 0.5).floor());
      exactBlueCount = easyBlueCount;
      numDangerous = easyDangerousCount;
      newPortalCount = easyBlueCount + easyDangerousCount;
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
        portal.score = _dangerPenaltyForLevel(level);
      } else {
        portal.score = _random.nextInt(5) + 1;
      }

      if (baseLevel >= 5 &&
          baseLevel != 13 &&
          baseLevel != 14 &&
          baseLevel != 26) {
        double spinSpeed;
        if (baseLevel <= 25) {
          spinSpeed = 0.4 + baseLevel * 0.035;
        } else if (baseLevel >= 27 && baseLevel <= 39) {
          final spinLevel = min(baseLevel, 36);
          spinSpeed = 0.1 + (spinLevel - 27) * 0.1;
          if (baseLevel >= 36) {
            spinSpeed *= 0.85;
          }
        } else {
          spinSpeed = 0.4 + (baseLevel - 25) * 0.02 + 0.4 + 25 * 0.035;
        }
        if (baseLevel >= 15 && baseLevel <= 25) {
          spinSpeed *= 0.7;
        }
        if (isEasyVersion) {
          spinSpeed *= 0.72;
        }
        if (baseLevel == 8) {
          portal.rotationSpeed = -spinSpeed; // Sadece level 8 ters döner
        } else {
          portal.rotationSpeed = spinSpeed; // Diğerleri normal döner
        }
      }

      portal.position = center;
      portals.add(portal);
      add(portal);
    }

    if (baseLevel >= 6 && _random.nextDouble() < 1 / 3 && baseLevel != 10) {
      final nonDangerous = portals
          .where((p) => !p.isDangerous && !p.isGreen)
          .toList();
      if (nonDangerous.isNotEmpty) {
        final selected = nonDangerous[_random.nextInt(nonDangerous.length)];
        selected.isGreen = true;
        selected.score = 0;
      }
    }

    if (baseLevel >= 20 && _random.nextDouble() < 1 / 5 && baseLevel != 10) {
      final scheduledLevel = currentLevel;
      Future.delayed(Duration(seconds: _random.nextInt(5) + 2), () {
        // Only spawn a new orange orb if none is active
        if (!isLoaded || !children.contains(arrow)) return;
        if (currentLevel != scheduledLevel) return;
        if (activeOrangeOrb != null) return;
        final angle = _random.nextDouble() * 2 * pi;
        final orange = OrangeOrb(angle: angle, center: size / 2);
        activeOrangeOrb = orange;
        add(orange);
      });
    }

    if (hasDeathRingForLevel(level)) {
      final deathRing = DeathRing(
        radius: min(size.x, size.y) / 2,
        color: const Color.fromARGB(255, 159, 44, 44),
      );
      add(deathRing);
    }

    arrow.speed = baseSpeed;
    directionSwapTimer?.cancel();
    if (baseLevel >= 18 && baseLevel <= 20) {
      directionSwapTimer = dart_async.Timer.periodic(Duration(seconds: 10), (
        _,
      ) {
        startSmoothDirectionSwap(portals);
      });
    } else if (baseLevel == 24 || baseLevel == 25) {
      directionSwapTimer = dart_async.Timer.periodic(Duration(seconds: 5), (_) {
        startSmoothDirectionSwap(portals);
      });
    } else if (baseLevel == 26) {
      // No rotation and no direction swap
      _startShootingCountdown();
    } else if (baseLevel >= 27 && baseLevel <= 39) {
      _startShootingCountdown();
    }

    scoreText.text = 'Coins: $totalScore';
    levelText.text = 'Level: $currentLevel';
    // Save currentLevel to SharedPreferences
    await _saveCurrentLevel();
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
            final portalPos = p.position;
            final ballPos =
                size / 2 +
                Vector2(cos(balls[i].angle), sin(balls[i].angle)) *
                    balls[i].radius;
            final distance = (portalPos - ballPos).length;
            final collisionDistance = (p.size.x / 2) + (balls[i].size.x / 2);

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

                _removeBallAt(i);
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

                  _removeBallAt(i);
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

                _removeBallAt(i);
                break;
              } else if (!p.isDangerous && !p.isGreen) {
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
                        if (currentLevel >= maxLevel) {
                          hitMessageText.text = 'Completed!';
                          hitMessageText.textRenderer = TextPaint(
                            style: const TextStyle(
                              color: Colors.yellowAccent,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                          hitMessageTimer = 0;
                          return;
                        }
                        final nextLevel = (currentLevel + 1)
                            .clamp(1, maxLevel)
                            .toInt();
                        var didUnlock = await _unlockThroughLevel(nextLevel);
                        currentLevel = nextLevel;
                        final prefs = await SharedPreferences.getInstance();
                        bool level10Played =
                            prefs.getBool('coinLevel10Played') ?? false;
                        if (baseLevelFor(currentLevel) == 10 && level10Played) {
                          final nextBaseLevel = baseLevelFor(currentLevel) + 1;
                          currentLevel = nextBaseLevel * 2 - 1;
                          didUnlock =
                              await _unlockThroughLevel(currentLevel) ||
                              didUnlock;
                        }
                        await _showUnlockAdIfNeeded(didUnlock, currentLevel);
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

                _removeBallAt(i);
                break;
              }
            }
          }
        }
      }
      // Vurulduktan sonra 0.5 sn bekle, sonra kaldır
      else if (balls[i].hit && balls[i].hitTimer > 0.5) {
        _removeBallAt(i);
      }
      // Vurulmadıysa dışarı çıkma ve ekran dışı kontrolü yap, yoksa bırak dönsün
      else if (!balls[i].hit) {
        if (_ballHitsRedPanel(balls[i])) {
          _restartFromPanelHit();
          _removeBallAt(i);
        } else if (balls[i].isOutOfRange(portalRadius + 150)) {
          // Dışarı çıkınca kaldır (yarıçapı biraz daha büyüttük)
          comboCount = 0;
          _removeBallAt(i);
        } else if (balls[i].isOffScreen(size)) {
          comboCount = 0;
          _removeBallAt(i);
        }
      }
    }

    // --- Orange Orb collision with Ball ---
    orangeCollision:
    for (final orangeOrb in children.whereType<OrangeOrb>().toList()) {
      if (!children.contains(orangeOrb)) continue;
      for (int i = balls.length - 1; i >= 0; i--) {
        final ball = balls[i];
        final ballPos =
            size / 2 + Vector2(cos(ball.angle), sin(ball.angle)) * ball.radius;
        if ((orangeOrb.position - ballPos).length >= 20) continue;

        orangeOrb.removeFromParent();
        if (activeOrangeOrb == orangeOrb) {
          activeOrangeOrb = null;
        }
        _removeBallAt(i);
        if (_isOrangeChallengeLevel(currentLevel)) {
          dart_async.unawaited(_handleOrangeChallengeHit());
        }
        break orangeCollision;
      }
    }

    // --- Orange Orb collision with center / Arrow ---
    for (final orangeOrb in children.whereType<OrangeOrb>().toList()) {
      if (!children.contains(orangeOrb)) continue;
      if (_isOrangeChallengeLevel(currentLevel)) {
        if (orangeOrb.hasReachedCenter()) {
          orangeOrb.removeFromParent();
          _restartOrangeChallenge();
          break;
        }
        continue;
      }

      if (activeOrangeOrb != orangeOrb || !orangeOrb.collidesWithArrow(arrow)) {
        continue;
      }
      if (orangeOrbImmune) {
        hasExtraLife = false;
        orangeOrbImmune = false;
      } else {
        playWrongSound();
        Future.microtask(() => loadLevel(currentLevel));
        hitMessageText.text = 'Hit by Orange Orb!';
      }
      orangeOrb.removeFromParent();
      activeOrangeOrb = null;
      break;
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
