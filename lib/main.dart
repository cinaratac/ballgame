import 'package:flame/flame.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'parts/ui/mainMenu.dart';
import 'oyun1.dart';
import 'parts/ui/shopScreen.dart';
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
          'MainMenu': (context, game) =>
              MainMenu(game: game as RotatingArrowGame),

          'BackToMenu': (context, game) => SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Material(
                  color: Colors.transparent,
                  child: IconButton(
                    icon: const Icon(Icons.home),
                    tooltip: 'Ana Menü',
                    onPressed: () => (game as RotatingArrowGame).goToMenu(),
                  ),
                ),
              ),
            ),
          ),
        },
      ),
    ),
  );
}
