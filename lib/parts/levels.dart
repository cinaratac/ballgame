import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oyun1/oyun1.dart';
import 'tutorial_screen.dart';
import 'ui/game_hud_button.dart';
import 'ui/minimal_aa_background.dart';
import 'ui/shop_screen.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  static const int _levelCount = RotatingArrowGame.maxLevel;

  int _currentLevel = 1;

  @override
  void initState() {
    super.initState();
    _loadCurrentLevel();
  }

  Future<void> _loadCurrentLevel() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLevel = prefs.getInt('currentLevel') ?? 1;
    if (!mounted) return;
    setState(() {
      _currentLevel = savedLevel.clamp(1, _levelCount).toInt();
    });
  }

  Future<void> _openLevel(int level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('currentLevel', level);

    if (!mounted) return;
    setState(() {
      _currentLevel = level;
    });
    final game = RotatingArrowGame()..currentLevel = level;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameWidget(
          game: game,
          overlayBuilderMap: {
            'levelNavigationButtons': (context, game) {
              final rotatingGame = game as RotatingArrowGame;
              return Positioned(
                bottom: gameHudButtonBottom + 58,
                left: 0,
                right: 0,
                child: Center(
                  child: LevelNavigationButtons(
                    onPrevious: () {
                      if (rotatingGame.currentLevel <= 1) return;
                      rotatingGame.loadLevel(rotatingGame.currentLevel - 1);
                    },
                    onNext: () {
                      if (rotatingGame.currentLevel >= _levelCount) return;
                      rotatingGame.loadLevel(rotatingGame.currentLevel + 1);
                    },
                  ),
                ),
              );
            },
            'levelMenuButton': (context, game) {
              return Positioned(
                bottom: gameHudButtonBottom,
                left: hudButtonLeft(context, 0),
                child: GameHudButton(
                  icon: Icons.menu_rounded,
                  tooltip: 'Menu',
                  onPressed: () => Navigator.pop(context),
                ),
              );
            },
            'tutorialButton': (context, game) {
              return Positioned(
                bottom: gameHudButtonBottom,
                left: hudButtonLeft(context, 1),
                child: GameHudButton(
                  icon: Icons.info_outline_rounded,
                  tooltip: 'Tutorial',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const GameTutorialScreen(),
                      ),
                    );
                  },
                ),
              );
            },
            'shopButton': (context, game) {
              return Positioned(
                bottom: gameHudButtonBottom,
                left: hudButtonLeft(context, -1),
                child: GameHudButton(
                  icon: Icons.shopping_bag_rounded,
                  tooltip: 'Shop',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            ShopScreen(game: game as RotatingArrowGame),
                      ),
                    );
                  },
                ),
              );
            },
          },
        ),
      ),
    );
    await _loadCurrentLevel();
  }

  Future<void> _resumeCurrentLevel() {
    return _openLevel(_currentLevel);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 380;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0E),
      body: Stack(
        children: [
          const Positioned.fill(child: MinimalAaBackground()),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 18 : 24,
                      18,
                      compact ? 18 : 24,
                      6,
                    ),
                    child: _Header(
                      currentLevel: _currentLevel,
                      onResume: _resumeCurrentLevel,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 18 : 26,
                    24,
                    compact ? 18 : 26,
                    36,
                  ),
                  sliver: SliverList.builder(
                    itemCount: (_levelCount / 4).ceil(),
                    itemBuilder: (context, rowIndex) {
                      final firstLevel = rowIndex * 4 + 1;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: _LevelRow(
                          firstLevel: firstLevel,
                          levelCount: _levelCount,
                          currentLevel: _currentLevel,
                          onLevelTap: _openLevel,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.currentLevel, required this.onResume});

  final int currentLevel;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onResume,
            child: const SizedBox(
              width: 42,
              height: 42,
              child: Icon(
                Icons.arrow_back_rounded,
                color: Colors.black,
                size: 26,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'LEVELS',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              height: 0.95,
            ),
          ),
        ),
        Container(
          width: 54,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: Text(
            '$currentLevel',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.firstLevel,
    required this.levelCount,
    required this.currentLevel,
    required this.onLevelTap,
  });

  final int firstLevel;
  final int levelCount;
  final int currentLevel;
  final ValueChanged<int> onLevelTap;

  @override
  Widget build(BuildContext context) {
    final levels = List.generate(
      4,
      (index) => firstLevel + index,
    ).where((level) => level <= levelCount).toList();

    return SizedBox(
      height: 86,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: const CustomPaint(painter: _LevelPathPainter()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: levels.map((level) {
              return _LevelNode(
                level: level,
                selected: level == currentLevel,
                onTap: () => onLevelTap(level),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _LevelNode extends StatelessWidget {
  const _LevelNode({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final int level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final markers = _markersForLevel(level);

    return SizedBox(
      width: 74,
      height: 74,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? Colors.white : const Color(0xFF121216),
              border: Border.all(
                color: selected
                    ? Colors.white
                    : markers.isNotEmpty
                    ? const Color(0xFFE3E3E3)
                    : const Color(0xFF8C8C8C),
                width: selected ? 4 : 2,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.26),
                        blurRadius: 22,
                        spreadRadius: 3,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (markers.isNotEmpty)
                  Positioned(
                    bottom: 9,
                    child: _MarkerStrip(markers: markers, selected: selected),
                  ),
                Text(
                  '$level',
                  style: TextStyle(
                    color: selected ? Colors.black : Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_LevelMarker> _markersForLevel(int level) {
    return [
      if (level == 5) _LevelMarker.spin,
      if (level == 8) _LevelMarker.reverse,
      if (level == 13 || level == 37) _LevelMarker.ring,
      if (level == 18 || level == 24) _LevelMarker.swap,
      if (level == 26) _LevelMarker.memory,
      if (level == 40) _LevelMarker.vertical,
      if (level == 43) _LevelMarker.panel,
    ];
  }
}

enum _LevelMarker { spin, reverse, ring, swap, memory, vertical, panel }

class _MarkerStrip extends StatelessWidget {
  const _MarkerStrip({required this.markers, required this.selected});

  final List<_LevelMarker> markers;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: markers.take(3).map((marker) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: Icon(
            _iconForMarker(marker),
            size: 10,
            color: selected ? Colors.black : const Color(0xFFE94B5F),
          ),
        );
      }).toList(),
    );
  }

  IconData _iconForMarker(_LevelMarker marker) {
    switch (marker) {
      case _LevelMarker.spin:
        return Icons.sync_rounded;
      case _LevelMarker.reverse:
        return Icons.keyboard_return_rounded;
      case _LevelMarker.ring:
        return Icons.radio_button_unchecked_rounded;
      case _LevelMarker.swap:
        return Icons.compare_arrows_rounded;
      case _LevelMarker.memory:
        return Icons.visibility_off_rounded;
      case _LevelMarker.vertical:
        return Icons.swap_vert_rounded;
      case _LevelMarker.panel:
        return Icons.view_column_rounded;
    }
  }
}

class _LevelPathPainter extends CustomPainter {
  const _LevelPathPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final pathPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.16);
    final y = size.height / 2;
    final path = Path();

    path
      ..moveTo(0, y)
      ..cubicTo(
        size.width * 0.26,
        y - 22,
        size.width * 0.44,
        y + 22,
        size.width * 0.65,
        y,
      )
      ..cubicTo(
        size.width * 0.8,
        y - 16,
        size.width * 0.92,
        y + 12,
        size.width,
        y,
      );

    canvas.drawPath(path, pathPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
