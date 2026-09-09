// The harvest screen used to fly a collect into the "+240" printed on the
// biome chip — the run's projected yield, not a balance, and it read as one.
// The header now carries the player's actual stock of each element, and that
// is what a collect lands on.
//
// Five totals share a phone-width row, so anything past a thousand has to
// abbreviate rather than squeeze its neighbours.

import 'package:alchemons/widgets/element_resource_totals_bar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('totals abbreviate past a thousand', () {
    expect(formatResourceTotal(0), '0');
    expect(formatResourceTotal(240), '240');
    expect(formatResourceTotal(999), '999');
    expect(formatResourceTotal(1000), '1.0k');
    expect(formatResourceTotal(1370), '1.4k');
    expect(formatResourceTotal(24500), '25k');
    expect(formatResourceTotal(987654), '988k');
  });
}
