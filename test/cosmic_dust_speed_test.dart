import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dust speed spans the former 10 to 40 pickup speeds', () {
    expect(StarDust.speedMultiplier(0), closeTo(1 + 10 / 50, 0.000001));
    expect(StarDust.speedMultiplier(25), closeTo(1.5, 0.000001));
    expect(StarDust.speedMultiplier(50), closeTo(1 + 40 / 50, 0.000001));
    expect(StarDust.speedMultiplier(-1), StarDust.speedMultiplier(0));
    expect(StarDust.speedMultiplier(100), StarDust.speedMultiplier(50));
    for (var count = 1; count <= 50; count++) {
      expect(
        StarDust.speedMultiplier(count),
        greaterThan(StarDust.speedMultiplier(count - 1)),
      );
    }
  });
}
