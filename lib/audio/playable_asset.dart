import 'package:flutter/foundation.dart';

final _lossless = RegExp(r'\.(wav|flac)$');

/// The file to hand the player for [asset].
///
/// The browser build ships every .wav and .flac as an .mp3 beside where it
/// would have been (tool/build_web.sh), about a tenth of the download, so
/// the web asks for those. The phone apps play the originals.
String playableAsset(String asset) =>
    kIsWeb ? asset.replaceFirst(_lossless, '.mp3') : asset;
