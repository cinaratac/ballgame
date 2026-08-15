import 'package:flutter/material.dart';

const double gameHudButtonBottom = 44;

double hudButtonLeft(BuildContext context, int slot) {
  const buttonSize = 48.0;
  const gap = 16.0;
  final center = MediaQuery.sizeOf(context).width / 2;
  return center - buttonSize / 2 + slot * (buttonSize + gap);
}

class GameHudButton extends StatelessWidget {
  const GameHudButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        iconSize: 32,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        icon: Icon(
          icon,
          color: Colors.white,
          shadows: const [
            Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
      ),
    );
  }
}

class LevelNavigationButtons extends StatelessWidget {
  const LevelNavigationButtons({
    super.key,
    required this.onPrevious,
    required this.onNext,
    this.canGoPrevious = true,
    this.canGoNext = true,
  });

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool canGoPrevious;
  final bool canGoNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LevelArrowButton(
          icon: Icons.keyboard_arrow_left_rounded,
          tooltip: 'Previous level',
          enabled: canGoPrevious,
          onPressed: onPrevious,
        ),
        const SizedBox(width: 15),
        _LevelArrowButton(
          icon: Icons.keyboard_arrow_right_rounded,
          tooltip: 'Next level',
          enabled: canGoNext,
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _LevelArrowButton extends StatelessWidget {
  const _LevelArrowButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: enabled ? onPressed : null,
        iconSize: 52,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 58, height: 58),
        icon: Icon(
          icon,
          color: enabled ? Colors.white : Colors.white24,
          weight: 900,
          shadows: const [
            Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
      ),
    );
  }
}
