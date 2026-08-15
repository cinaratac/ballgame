import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'oyun1.dart';
import 'parts/levels.dart';
import 'parts/ui/shopScreen.dart';

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
              bottom: 44,
              left: _hudButtonLeft(context, 0),
              child: _GameHudButton(
                icon: Icons.menu_rounded,
                tooltip: 'Menu',
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 400),
                      pageBuilder: (_, __, ___) => const LevelSelectScreen(),
                      transitionsBuilder: (_, animation, __, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    ),
                  );
                },
              ),
            );
          },
          'tutorialButton': (context, game) {
            return Positioned(
              bottom: 44,
              left: _hudButtonLeft(context, 1),
              child: _GameHudButton(
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
              bottom: 44,
              left: _hudButtonLeft(context, -1),
              child: _GameHudButton(
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
}

double _hudButtonLeft(BuildContext context, int slot) {
  const buttonSize = 48.0;
  const gap = 16.0;
  final center = MediaQuery.sizeOf(context).width / 2;
  return center - buttonSize / 2 + slot * (buttonSize + gap);
}

class _GameHudButton extends StatelessWidget {
  const _GameHudButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        iconSize: 32,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        icon: Icon(
          icon,
          color: Colors.white,
          shadows: const [
            Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
      ),
    );
  }
}
