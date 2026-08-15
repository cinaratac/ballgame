import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'oyun1.dart';
import 'parts/levels.dart';
import 'parts/tutorial_screen.dart';
import 'parts/ui/game_hud_button.dart';
import 'parts/ui/shop_screen.dart';

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
          'levelNavigationButtons': (context, game) {
            final rotatingGame = game as RotatingArrowGame;
            return Positioned(
              bottom: gameHudButtonBottom + 58,
              left: 0,
              right: 0,
              child: Center(
                child: ValueListenableBuilder<int>(
                  valueListenable: rotatingGame.levelProgressRevision,
                  builder: (context, _, __) {
                    return LevelNavigationButtons(
                      canGoPrevious: rotatingGame.canGoToPreviousLevel,
                      canGoNext: rotatingGame.canGoToNextLevel,
                      onPrevious: () {
                        if (!rotatingGame.canGoToPreviousLevel) return;
                        rotatingGame.loadLevel(rotatingGame.currentLevel - 1);
                      },
                      onNext: () {
                        if (!rotatingGame.canGoToNextLevel) return;
                        rotatingGame.loadLevel(rotatingGame.currentLevel + 1);
                      },
                    );
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
}
