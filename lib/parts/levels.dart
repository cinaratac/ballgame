import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:oyun1/main.dart';
import 'package:oyun1/oyun1.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
                          SharedPreferences.getInstance().then((prefs) {
                            prefs.setInt('currentLevel', level);
                          });

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