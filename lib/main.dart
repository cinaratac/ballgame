import 'package:flame/flame.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

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
