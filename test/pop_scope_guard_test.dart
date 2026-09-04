// EVERY PopScope HANDLER HAS TO LOOK AT didPop.
//
// Reported from play as a black screen: open Survival from the home screen,
// press back, and the app shows nothing at all. No exception, no log line.
//
// The cause is a loop that only exists when the guard is missing. Back press
// arrives with didPop false, the handler calls `Navigator.pop`, and that pop
// comes straight back through the same callback with didPop TRUE. Handled a
// second time it pops again, this time taking the screen underneath, and the
// navigator is left empty.
//
// Nothing about that is visible in a widget tree or a unit test of any one
// screen, so it is checked at the source: a handler that never reads didPop
// cannot tell the two cases apart.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no PopScope handler ignores didPop', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('onPopInvokedWithResult')) continue;
        // The guard is always the first thing a correct handler does; a
        // generous window keeps this from tripping over a doc comment.
        final window = lines
            .sublist(i, (i + 14).clamp(0, lines.length))
            .join('\n');
        if (!window.contains('didPop')) {
          offenders.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'these handlers cannot tell a back press from their own pop, which '
          'is how a screen pops twice and blacks out: ${offenders.join(', ')}',
    );
  });
}
