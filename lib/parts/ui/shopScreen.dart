import 'dart:math';

import 'package:flutter/material.dart';

import 'package:oyun1/oyun1.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, required this.game});

  final RotatingArrowGame game;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  final List<_ArrowItem> _items = [
    const _ArrowItem(
      index: 0,
      name: 'Classic',
      price: 0,
      color: Colors.white,
      note: 'Clean and sharp',
    ),
    const _ArrowItem(
      index: 1,
      name: 'Gold',
      price: 500,
      color: Color(0xFFFFC83D),
      note: 'Bright hit line',
    ),
    const _ArrowItem(
      index: 2,
      name: 'Shadow',
      price: 1000,
      color: Color(0xFF22242B),
      note: 'Dark precision',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _selectOrBuy(_ArrowItem item) async {
    final game = widget.game;
    final isOwned = game.ownedArrows.contains(item.index);

    if (isOwned) {
      setState(() {
        game.currentArrowSkin = item.index;
      });
      return;
    }

    if (game.totalScore < item.price) return;

    setState(() {
      game.totalScore -= item.price;
      game.ownedArrows.add(item.index);
      game.currentArrowSkin = item.index;
    });

    await game.saveCoinScore();
    await game.saveOwnedArrows();
    game.scoreText.text = 'Coins: ${game.totalScore}';
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;

    return Scaffold(
      backgroundColor: const Color(0xFF050506),
      body: Stack(
        children: [
          const Positioned.fill(child: _ShopBackground()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                  child: _ShopHeader(coins: game.totalScore),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final isOwned = game.ownedArrows.contains(item.index);
                      final isSelected = game.currentArrowSkin == item.index;
                      final canBuy = game.totalScore >= item.price;

                      return _ArrowShopCard(
                        item: item,
                        isOwned: isOwned,
                        isSelected: isSelected,
                        canBuy: canBuy,
                        controller: _controller,
                        onTap: () => _selectOrBuy(item),
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

class _ShopHeader extends StatelessWidget {
  const _ShopHeader({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.pop(context),
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
        const SizedBox(width: 16),
        const Expanded(
          child: Text(
            'SHOP',
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
          constraints: const BoxConstraints(minWidth: 78, minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF121216),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.monetization_on_rounded,
                color: Color(0xFFFFC83D),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                '$coins',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArrowShopCard extends StatelessWidget {
  const _ArrowShopCard({
    required this.item,
    required this.isOwned,
    required this.isSelected,
    required this.canBuy,
    required this.controller,
    required this.onTap,
  });

  final _ArrowItem item;
  final bool isOwned;
  final bool isSelected;
  final bool canBuy;
  final AnimationController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final actionText = isSelected
        ? 'Selected'
        : isOwned
        ? 'Select'
        : '${item.price}';
    final actionColor = isSelected
        ? Colors.white
        : isOwned || canBuy
        ? const Color(0xFFFFC83D)
        : const Color(0xFF777777);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Ink(
          height: 126,
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF1B1B21)
                : const Color(0xEE101014),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.white : const Color(0xFF2C2C34),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Center(
                    child: RotationTransition(
                      turns: controller,
                      child: Icon(
                        Icons.arrow_right_alt,
                        size: 48,
                        color: item.color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF9D9DA5),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (isOwned)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF58D68D),
                              size: 18,
                            )
                          else
                            Icon(
                              Icons.monetization_on_rounded,
                              color: actionColor,
                              size: 18,
                            ),
                          const SizedBox(width: 6),
                          Text(
                            actionText,
                            style: TextStyle(
                              color: actionColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? Colors.white : Colors.white38,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShopBackground extends StatelessWidget {
  const _ShopBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF050506), Color(0xFF111116), Color(0xFF050506)],
        ),
      ),
      child: CustomPaint(painter: _ShopBackgroundPainter()),
    );
  }
}

class _ShopBackgroundPainter extends CustomPainter {
  const _ShopBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.25);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.06);

    for (int i = 0; i < 6; i++) {
      canvas.drawCircle(center, 70.0 + i * 36, ringPaint);
    }

    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.10);
    for (int i = 0; i < 28; i++) {
      final x = (sin(i * 2.31) * 0.5 + 0.5) * size.width;
      final y = (cos(i * 1.79) * 0.5 + 0.5) * size.height;
      canvas.drawCircle(Offset(x, y), i % 7 == 0 ? 1.7 : 1.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArrowItem {
  const _ArrowItem({
    required this.index,
    required this.name,
    required this.price,
    required this.color,
    required this.note,
  });

  final int index;
  final String name;
  final int price;
  final Color color;
  final String note;
}
