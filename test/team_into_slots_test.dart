import 'package:alchemons/screens/party_picker/party_picker.dart';
import 'package:flutter_test/flutter_test.dart';

// The ship crew and the garrison are numbered slots, picked on the team
// picker, which hands back a plain list.
void main() {
  test('who stays keeps their slot', () {
    expect(teamIntoSlots(['a', 'b', 'c'], ['c', 'a', 'b']), ['a', 'b', 'c']);
  });

  test('a newcomer takes the slot that was let go', () {
    expect(teamIntoSlots(['a', 'b', 'c'], ['a', 'c', 'd']), ['a', 'd', 'c']);
  });

  test('newcomers fill empty slots in the order they were picked', () {
    expect(teamIntoSlots([null, 'b', null], ['b', 'x', 'y']), ['x', 'b', 'y']);
  });

  test('taking everyone out leaves every slot empty', () {
    expect(teamIntoSlots(['a', null, 'c'], const []), [null, null, null]);
  });
}
