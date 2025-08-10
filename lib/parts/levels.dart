import 'package:flutter/material.dart';

import 'package:oyun1/oyun1.dart';

class LevelSelectScreen extends StatelessWidget {
  final RotatingArrowGame game;
  const LevelSelectScreen({super.key, required this.game});
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
                          game.startGame(level: level);
                          Navigator.of(context).pop();
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
