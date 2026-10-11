#!/usr/bin/env bash
# Builds the browser version for alchemons.com/play and, with --site, copies
# it into the website checkout ready for `firebase deploy`.
#
#   tool/build_web.sh                         # build only → build/web_play
#   tool/build_web.sh --site ~/alchemons-web  # build, then copy to <site>/play
#
# Besides `flutter build web` it:
#   - recompiles the database worker (web/drift_worker.js) and refreshes
#     web/sqlite3.wasm from the locked drift version, so both stay in step;
#   - re-encodes every .wav/.flac in the output as .mp3 (about a tenth of the
#     size) and drops the originals. lib/audio/playable_asset.dart asks for
#     the .mp3 on the web. The phone apps keep the originals.
set -euo pipefail

cd "$(dirname "$0")/.."
OUT=build/web_play
SITE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --site) SITE="${2:?--site needs a path}"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
command -v ffmpeg >/dev/null || { echo "ffmpeg is required (brew install ffmpeg)" >&2; exit 1; }

echo "▸ database worker"
DRIFT_VERSION=$(awk '/^  drift:$/{f=1;next} f&&/version:/{gsub(/"/,"",$2);print $2;exit}' pubspec.lock)
WASM="$HOME/.pub-cache/hosted/pub.dev/drift-$DRIFT_VERSION/extension/devtools/build/sqlite3.wasm"
if [[ -f "$WASM" ]]; then
  cp "$WASM" web/sqlite3.wasm
else
  echo "  (no sqlite3.wasm for drift $DRIFT_VERSION in the pub cache; keeping web/sqlite3.wasm)"
fi
dart compile js -O2 -o web/drift_worker.js tool/web/drift_worker.dart >/dev/null
rm -f web/drift_worker.js.deps web/drift_worker.js.map

echo "▸ flutter build web"
flutter build web --release --base-href /play/ --no-wasm-dry-run -o "$OUT"

echo "▸ audio → mp3"
find "$OUT/assets/assets/audio" -type f \( -name '*.wav' -o -name '*.flac' \) -print0 |
  xargs -0 -P 3 -I{} sh -c '
    src="$1"; dst="${src%.*}.mp3"
    ffmpeg -loglevel error -y -i "$src" -codec:a libmp3lame -q:a 2 "$dst" && rm "$src"
  ' _ {}
du -sh "$OUT" "$OUT/assets/assets/audio" | sed 's/^/  /'

if [[ -n "$SITE" ]]; then
  echo "▸ copy to $SITE/play"
  mkdir -p "$SITE/play"
  rsync -a --delete "$OUT/" "$SITE/play/"
  echo "  done. Deploy from the site: (cd $SITE && firebase deploy --only hosting)"
fi
