import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'fluid_scene.dart';

/// A single in-flight request bounds memory and prevents simulation work from
/// queuing behind gestures. Transferable buffers avoid copying textures on UI.
class FluidWorker {
  FluidWorker({required this.onFrame, this.benchmark = false});
  final void Function() onFrame;
  final bool benchmark;
  final _receive = ReceivePort();
  final _ready = Completer<void>();
  final _commands = <List<Object>>[];
  Isolate? _isolate;
  SendPort? _send;
  bool _busy = false, _disposed = false, _feeding = false;
  double _pendingTime = 0, time = 0, workMs = 0;
  int particleCount = 0, transformations = 0, fieldFrames = 0;
  String lastReaction = 'Water + Fire → Steam';
  Uint8List? pixels;
  bool get feeding => _feeding;
  set feeding(bool value) {
    _feeding = value;
    _command(['feed', value]);
  }

  Future<void>? _starting;
  Future<void> start(Map<String, dynamic> recipes) =>
      _starting ??= _start(recipes);
  Future<void> _start(Map<String, dynamic> recipes) async {
    _receive.listen((dynamic message) {
      if (_disposed) return;
      if (message is SendPort) {
        _send = message;
        _command(['snapshot']);
        return;
      }
      final m = message as List<dynamic>;
      pixels = (m[0] as TransferableTypedData).materialize().asUint8List();
      time = m[1] as double;
      particleCount = m[2] as int;
      transformations = m[3] as int;
      lastReaction = m[4] as String;
      workMs = m[5] as double;
      fieldFrames++;
      _busy = false;
      if (!_ready.isCompleted) _ready.complete();
      onFrame();
      _flush();
    });
    _isolate = await Isolate.spawn(_run, [
      _receive.sendPort,
      benchmark,
      recipes,
    ]);
    if (_disposed) {
      _isolate?.kill(priority: Isolate.immediate);
      return;
    }
    await _ready.future;
  }

  void _command(List<Object> command) {
    if (_disposed) return;
    if (_commands.length < 128) _commands.add(command);
    scheduleMicrotask(_flush);
  }

  void _flush() {
    if (_disposed ||
        _busy ||
        _send == null ||
        (_pendingTime == 0 && _commands.isEmpty)) {
      return;
    }
    _busy = true;
    _send!.send([_pendingTime, List<List<Object>>.of(_commands)]);
    _pendingTime = 0;
    _commands.clear();
  }

  void step(double dt) {
    _pendingTime = min(.05, _pendingTime + dt);
    _flush();
  }

  void pour(
    double x,
    double y, {
    int amount = 48,
    FluidMaterial material = FluidMaterial.water,
  }) => _command(['pour', x, y, amount, material.index]);
  void erase(double x, double y) => _command(['erase', x, y]);
  void ignite(double x, double y, double dt) => _command(['fire', x, y, dt]);
  void stir(double x, double y, double dx, double dy) =>
      _command(['stir', x, y, dx, dy]);
  void reset() {
    _pendingTime = 0;
    _commands.clear();
    _feeding = false;
    _command(['reset']);
  }

  void clear() {
    _pendingTime = 0;
    _commands.clear();
    _feeding = false;
    _command(['clear']);
  }

  void pause() {
    _pendingTime = 0;
    _commands.clear();
  }

  void dispose() {
    _disposed = true;
    _receive.close();
    _isolate?.kill(priority: Isolate.immediate);
    if (!_ready.isCompleted) _ready.complete();
  }
}

void _run(List<Object> args) {
  final send = args[0] as SendPort,
      benchmark = args[1] as bool,
      receive = ReceivePort();
  final scene = FluidScene(recipeJson: args[2] as Map<String, dynamic>);
  if (benchmark) scene.seedBenchmark();
  send.send(receive.sendPort);
  receive.listen((dynamic message) {
    final timer = Stopwatch()..start();
    final m = message as List<dynamic>;
    for (final dynamic command in m[1]) {
      final c = command as List<dynamic>;
      switch (c[0]) {
        case 'pour':
          scene.pour(
            c[1] as double,
            c[2] as double,
            amount: c[3] as int,
            material: FluidMaterial.values[c[4] as int],
          );
        case 'erase':
          scene.erase(c[1] as double, c[2] as double);
        case 'fire':
          scene.ignite(c[1] as double, c[2] as double, c[3] as double);
        case 'stir':
          scene.stir(
            c[1] as double,
            c[2] as double,
            c[3] as double,
            c[4] as double,
          );
        case 'feed':
          scene.feeding = c[1] as bool;
        case 'reset':
          scene.reset();
        case 'clear':
          scene.clear();
      }
    }
    var remaining = m[0] as double;
    while (remaining >= .00001) {
      final dt = min(1 / 60, remaining), t = scene.time;
      if (benchmark) {
        if (t > 6 && t < 16) {
          scene.pour(
            .25 + sin(t) * .14,
            .4,
            amount: 48,
            material: FluidMaterial.earth,
          );
        }
        if (t > 16 && t < 24) scene.ignite(.6 + sin(t) * .1, 1.2, dt);
        if (t > 24) {
          scene.stir(.5 + sin(t) * .2, 1.25, .007 * cos(t), .006 * sin(t));
        }
      }
      scene.step(dt);
      remaining -= dt;
    }
    final bytes = TransferableTypedData.fromList([scene.encode()]);
    timer.stop();
    send.send([
      bytes,
      scene.time,
      scene.particleCount,
      scene.transformations,
      scene.lastReaction,
      timer.elapsedMicroseconds / 1000,
    ]);
  });
}
