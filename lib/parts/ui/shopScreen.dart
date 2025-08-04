import 'package:flutter/material.dart';
 
import 'package:oyun1/oyun1.dart';

// --- SHOP SCREEN WIDGET ---
class ShopScreen extends StatefulWidget {
  final RotatingArrowGame game;
  ShopScreen({required this.game});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget buildArrowTile(int index, Color color, String name, int price) {
    final game = widget.game;
    final isOwned = game.ownedArrows.contains(index);
    final isSelected = game.currentArrowSkin == index;

    return GestureDetector(
      onTap: () async {
        if (isOwned) {
          setState(() {
            game.currentArrowSkin = index;
          });
        } else if (game.totalScore >= price) {
          setState(() {
            game.totalScore -= price;
            game.ownedArrows.add(index);
            game.currentArrowSkin = index;
          });
          await game.saveCoinScore();
          await game.saveOwnedArrows();
          game.scoreText.text = 'Coins: ${game.totalScore}';
        }
      },
      child: Container(
        margin: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black87,
          border: Border.all(
            color: isSelected ? Colors.yellowAccent : Colors.white,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        width: 100,
        height: 140,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RotationTransition(
              turns: _controller,
              child: Icon(Icons.arrow_right_alt, size: 48, color: color),
            ),
            SizedBox(height: 8),
            Text(name, style: TextStyle(color: Colors.white)),
            SizedBox(height: 4),
            Text(
              isOwned ? 'Owned' : '$price Coins',
              style: TextStyle(
                color: isOwned ? Colors.greenAccent : Colors.yellowAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: Text('Arrow Shop'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          SizedBox(height: 16),
          Text(
            'Coins: ${game.totalScore}',
            style: TextStyle(
              color: Colors.yellowAccent,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              children: [
                buildArrowTile(0, Colors.white, 'Classic', 0),
                buildArrowTile(1, Colors.amber, 'Golden', 500),
                buildArrowTile(2, Colors.grey[800]!, 'Shadow', 1000),
              ],
            ),
          ),
        ],
      ),
    );
  }
}