import 'dart:js_interop';

/// `window.alchemonsAds`, defined by web/ads/ads.js. Missing when the page
/// was served without it (a plain `flutter run -d chrome`).
@JS('alchemonsAds')
external _Ads? get _ads;

extension type _Ads._(JSObject _) implements JSObject {
  external bool get configured;
  external JSPromise<JSAny?> interstitial(
    JSString placement,
    JSFunction onStart,
    JSFunction onEnd,
  );
  external JSPromise<JSBoolean> rewarded(
    JSString placement,
    JSFunction onStart,
    JSFunction onEnd,
  );
}

bool configured() => _ads?.configured ?? false;

Future<void> interstitial(
  String placement,
  void Function() onStart,
  void Function() onEnd,
) async {
  final ads = _ads;
  if (ads == null) return;
  await ads.interstitial(placement.toJS, onStart.toJS, onEnd.toJS).toDart;
}

Future<bool> rewarded(
  String placement,
  void Function() onStart,
  void Function() onEnd,
) async {
  final ads = _ads;
  if (ads == null) return false;
  final watched = await ads
      .rewarded(placement.toJS, onStart.toJS, onEnd.toJS)
      .toDart;
  return watched.toDart;
}
