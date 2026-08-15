import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ui/minimal_aa_background.dart';

class GameTutorialScreen extends StatefulWidget {
  const GameTutorialScreen({super.key});

  @override
  State<GameTutorialScreen> createState() => _GameTutorialScreenState();
}

class _GameTutorialScreenState extends State<GameTutorialScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const List<_TutorialPageData> _pages = [
    _TutorialPageData(
      title: 'Hit blue',
      body:
          'Blue targets give score. Line up the arrow and send the white ball.',
      type: _TutorialVisualType.blue,
    ),
    _TutorialPageData(
      title: 'Build combo',
      body: 'Consecutive blue hits increase your combo and earn more coins.',
      type: _TutorialVisualType.combo,
    ),
    _TutorialPageData(
      title: 'Avoid red',
      body: 'Red targets remove coins and restart the level flow. Stay clean.',
      type: _TutorialVisualType.red,
    ),
    _TutorialPageData(
      title: 'Watch the ring',
      body:
          'The red ring is deadly. Time your shot so the ball never touches it.',
      type: _TutorialVisualType.ring,
    ),
    _TutorialPageData(
      title: 'Stop orange',
      body:
          'An orange orb may enter the arena. Hit it before it reaches the center.',
      type: _TutorialVisualType.orange,
    ),
    _TutorialPageData(
      title: 'Remember colors',
      body:
          'In memory levels, study the targets before their colors disappear.',
      type: _TutorialVisualType.memory,
    ),
    _TutorialPageData(
      title: 'Read the icons',
      body:
          'Level markers show when a new rule appears: spin, reverse, ring, swap, memory.',
      type: _TutorialVisualType.icons,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050506),
      body: Stack(
        children: [
          const Positioned.fill(child: MinimalAaBackground()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                  child: Row(
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
                          'GUIDE',
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
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (value) => setState(() => _page = value),
                    itemBuilder: (context, index) {
                      return _TutorialPage(data: _pages[index]);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (index) {
                      final selected = index == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: selected ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: selected ? Colors.white : Colors.white24,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    }),
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

class _TutorialPage extends StatelessWidget {
  const _TutorialPage({required this.data});

  final _TutorialPageData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 18, 26, 18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 230,
            height: 230,
            child: CustomPaint(
              painter: _TutorialVisualPainter(type: data.type),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 31,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFD6D6DA),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.28,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialPageData {
  const _TutorialPageData({
    required this.title,
    required this.body,
    required this.type,
  });

  final String title;
  final String body;
  final _TutorialVisualType type;
}

enum _TutorialVisualType { blue, combo, red, ring, orange, memory, icons }

class _TutorialVisualPainter extends CustomPainter {
  const _TutorialVisualPainter({required this.type});

  final _TutorialVisualType type;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.34;
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.18);
    final arrowPaint = Paint()
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    final bluePaint = Paint()..color = const Color(0xFF1E73FF);
    final redPaint = Paint()..color = const Color(0xFFE94B5F);
    final orangePaint = Paint()..color = const Color(0xFFFF9A2F);
    final greenPaint = Paint()..color = const Color(0xFF4DE07A);

    canvas.drawCircle(center, radius, orbitPaint);

    switch (type) {
      case _TutorialVisualType.blue:
        _drawArrow(canvas, center, -0.45, arrowPaint);
        _drawTarget(canvas, center, radius, -0.45, bluePaint, '5');
        _drawTarget(canvas, center, radius, 2.1, bluePaint, '3');
        break;
      case _TutorialVisualType.combo:
        _drawArrow(canvas, center, -0.2, arrowPaint);
        _drawTarget(canvas, center, radius, -0.2, bluePaint, 'x2');
        _drawTarget(canvas, center, radius, 1.5, greenPaint, '+');
        _drawCoin(canvas, center + Offset(0, radius + 28));
        break;
      case _TutorialVisualType.red:
        _drawArrow(canvas, center, 0.3, arrowPaint);
        _drawTarget(canvas, center, radius, 0.3, redPaint, '!');
        _drawTarget(canvas, center, radius, 2.8, bluePaint, '4');
        break;
      case _TutorialVisualType.ring:
        final ringPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = const Color(0xFFE94B5F);
        canvas.drawCircle(center, radius * 1.08, ringPaint);
        _drawArrow(canvas, center, -1.2, arrowPaint);
        _drawTarget(canvas, center, radius, 0.55, bluePaint, '2');
        break;
      case _TutorialVisualType.orange:
        _drawArrow(canvas, center, -1.55, arrowPaint);
        canvas.drawCircle(center + Offset(0, -radius - 35), 14, orangePaint);
        final linePaint = Paint()
          ..strokeWidth = 2
          ..color = orangePaint.color.withValues(alpha: 0.55);
        canvas.drawLine(center + Offset(0, -radius - 18), center, linePaint);
        break;
      case _TutorialVisualType.memory:
        _drawTarget(canvas, center, radius, -0.6, bluePaint, '?');
        _drawTarget(canvas, center, radius, 1.1, redPaint, '?');
        _drawTarget(canvas, center, radius, 2.8, bluePaint, '?');
        final eyePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = Colors.white;
        canvas.drawLine(
          center + const Offset(-34, -34),
          center + const Offset(34, 34),
          eyePaint,
        );
        break;
      case _TutorialVisualType.icons:
        _drawIconRow(canvas, size);
        break;
    }

    canvas.drawCircle(center, 7, Paint()..color = Colors.white);
  }

  void _drawArrow(Canvas canvas, Offset center, double angle, Paint paint) {
    final end = center + Offset(math.cos(angle), math.sin(angle)) * 58;
    canvas.drawLine(center, end, paint);
  }

  void _drawTarget(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    Paint paint,
    String label,
  ) {
    final position = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.drawCircle(position, 17, paint);
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      position - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  void _drawCoin(Canvas canvas, Offset center) {
    final paint = Paint()..color = const Color(0xFFFFC83D);
    canvas.drawCircle(center, 18, paint);
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '+',
        style: TextStyle(
          color: Colors.black,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  void _drawIconRow(Canvas canvas, Size size) {
    final icons = [
      Icons.sync_rounded,
      Icons.keyboard_return_rounded,
      Icons.radio_button_unchecked_rounded,
      Icons.compare_arrows_rounded,
      Icons.visibility_off_rounded,
    ];
    final labels = ['spin', 'reverse', 'ring', 'swap', 'hide'];
    final y = size.height / 2 - 20;
    for (int i = 0; i < icons.length; i++) {
      final x = size.width * (0.13 + i * 0.185);
      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icons[i].codePoint),
          style: TextStyle(
            color: i == 2 ? const Color(0xFFE94B5F) : Colors.white,
            fontSize: 28,
            fontFamily: icons[i].fontFamily,
            package: icons[i].fontPackage,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      iconPainter.paint(canvas, Offset(x - iconPainter.width / 2, y));

      final labelPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: Color(0xFFB7B7BE),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(canvas, Offset(x - labelPainter.width / 2, y + 40));
    }
  }

  @override
  bool shouldRepaint(covariant _TutorialVisualPainter oldDelegate) {
    return oldDelegate.type != type;
  }
}
