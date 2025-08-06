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
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static _MyAppState? instance;

  bool startGame = false;

  @override
  void initState() {
    super.initState();
    instance = this;
  }

  static void returnToMainMenu() {
    instance?.setState(() {
      instance?.startGame = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (startGame) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: GameWidget(
          game: RotatingArrowGame(),
          initialActiveOverlays: const ['mainMenuButton'],
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
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                      ),
                    );
                  },
                  child: Text('Menü'),
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
            'mainMenuButton': (context, game) {
              return Positioned(
                bottom: 10,
                right: 10,
                child: ElevatedButton(
                  onPressed: () {
                    _MyAppState.returnToMainMenu();
                  },
                  child: Text('Ana Menü'),
                ),
              );
            },
          },
        ),
      );
    } else {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ball Game',
                  style: TextStyle(
                    fontSize: 40,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => setState(() => startGame = true),
                  child: Text('Başla'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}
