// iOS, Android and tests: no ads.

bool configured() => false;

Future<void> interstitial(
  String placement,
  void Function() onStart,
  void Function() onEnd,
) async {}

Future<bool> rewarded(
  String placement,
  void Function() onStart,
  void Function() onEnd,
) async => false;
