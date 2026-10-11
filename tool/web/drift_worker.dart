// The browser build's database worker, compiled to web/drift_worker.js by
// tool/build_web.sh. Keep its drift version in step with pubspec.lock.
import 'package:drift/wasm.dart';

void main() => WasmDatabase.workerMainForOpen();
