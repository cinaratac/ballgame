import 'package:flutter_test/flutter_test.dart';
import 'package:oyun1/oyun1.dart';

void main() {
  test('RotatingArrowGame starts from level 1', () {
    final game = RotatingArrowGame();

    expect(game.currentLevel, 1);
  });

  test('doubled progression keeps original levels on even numbers', () {
    expect(RotatingArrowGame.maxLevel, 90);
    expect(RotatingArrowGame.baseLevelFor(1), 1);
    expect(RotatingArrowGame.baseLevelFor(2), 1);
    expect(RotatingArrowGame.baseLevelFor(89), 45);
    expect(RotatingArrowGame.baseLevelFor(90), 45);
    expect(RotatingArrowGame.isEasyVersionLevel(1), isTrue);
    expect(RotatingArrowGame.isEasyVersionLevel(2), isFalse);
  });
}
