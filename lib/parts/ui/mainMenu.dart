import 'package:flutter/material.dart';
import '../../oyun1.dart';
import 'shopScreen.dart';
import '../levels.dart';

class MainMenu extends StatelessWidget {
  final RotatingArrowGame game;
  const MainMenu({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Ana Menü',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => game.continueGame(),
            child: const Text('Oyunu Başlat'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LevelSelectScreen(game: game),
                ),
              );
            },
            child: const Text('Levels'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => ShopScreen(game: game)));
            },
            child: const Text('Shop'),
          ),
        ],
      ),
    );
  }
}
