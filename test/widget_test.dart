import 'package:flutter_test/flutter_test.dart';
import 'package:oyun1/oyun1.dart';

void main() {
  test('RotatingArrowGame starts from level 1', () {
    final game = RotatingArrowGame();

    expect(game.currentLevel, 1);
  });
}
