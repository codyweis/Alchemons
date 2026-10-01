import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../games/alchemy/fluid_scene.dart';
import '../games/alchemy/fluid_worker.dart';
import '../games/alchemy/fluid_scene_painter.dart';

class AlchemyChamberScreen extends StatefulWidget {
  const AlchemyChamberScreen({super.key, this.benchmark = false});
  final bool benchmark;
  @override
  State<AlchemyChamberScreen> createState() => _AlchemyChamberScreenState();
}

class _AlchemyChamberScreenState extends State<AlchemyChamberScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final FluidWorker _scene;
  final _repaint = ValueNotifier(0);
  final _cpuTimes = <double>[],
      _buildTimes = <double>[],
      _rasterTimes = <double>[];
  late final Ticker _ticker;
  ui.FragmentShader? _shader;
  ui.Image? _field;
  bool _uploading = false,
      _disposed = false,
      _paused = false,
      _foreground = true;
  bool _reported = false;
  String? _error;
  int _tool = 0, _frames = 0;
  FluidMaterial _material = FluidMaterial.water;
  double _accumulator = 0, _hud = 0;
  Duration? _previous;
  Offset? _touch;
  int? _pointer;

  @override
  void initState() {
    super.initState();
    _scene = FluidWorker(
      benchmark: widget.benchmark,
      onFrame: () {
        if (!mounted || _disposed) return;
        if (widget.benchmark && _scene.time > 4 && !_reported) {
          _cpuTimes.add(_scene.workMs);
        }
        if (_shader != null) _upload();
        if (_paused) setState(() {});
      },
    );
    WidgetsBinding.instance.addObserver(this);
    SchedulerBinding.instance.addTimingsCallback(_timings);
    _ticker = createTicker(_frame)..start();
    _load();
  }

  Future<void> _load() async {
    try {
      // Load every canonical recipe before starting the isolated simulation.
      final data = jsonDecode(
        await rootBundle.loadString(
          'assets/data/alchemons_element_recipes.json',
        ),
      );
      await _scene.start(data as Map<String, dynamic>);
      if (!mounted) return;
      final program = await ui.FragmentProgram.fromAsset(
        'assets/shaders/alchemy_fluid.frag',
      );
      if (!mounted) return;
      setState(() {
        _shader = program.fragmentShader();
        _error = null;
      });
      _upload();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = 'The fluid renderer could not start. Please retry.',
        );
      }
      debugPrint('Alchemy renderer: $e');
    }
  }

  void _upload() {
    if (_uploading || _disposed) return;
    _uploading = true;
    final version = _scene.fieldFrames;
    final bytes = _scene.pixels;
    if (bytes == null) {
      _uploading = false;
      return;
    }
    ui.decodeImageFromPixels(
      bytes,
      FluidScene.atlasW,
      FluidScene.renderH,
      ui.PixelFormat.rgba8888,
      (image) {
        _uploading = false;
        if (_disposed) {
          image.dispose();
          return;
        }
        final old = _field;
        _field = image;
        _shader?.setImageSampler(0, image);
        _repaint.value++;
        // The preceding frame has finished using the old immutable image.
        old?.dispose();
        if (old == null && mounted) setState(() {});
        if (_scene.fieldFrames != version) _upload();
      },
    );
  }

  void _timings(List<ui.FrameTiming> timings) {
    if (!widget.benchmark || _scene.time < 4 || _reported) return;
    for (final f in timings) {
      _buildTimes.add(f.buildDuration.inMicroseconds / 1000);
      _rasterTimes.add(f.rasterDuration.inMicroseconds / 1000);
    }
  }

  double _percentile(List<double> values, double q) {
    if (values.isEmpty) return 0;
    final sorted = values.toList()..sort();
    return sorted[((sorted.length - 1) * q).round()];
  }

  void _frame(Duration elapsed) {
    final previous = _previous;
    _previous = elapsed;
    if (previous == null || _paused || !_foreground || _shader == null) return;
    final dt = min(.05, (elapsed - previous).inMicroseconds / 1e6);
    _accumulator += dt;
    _hud += dt;
    while (_accumulator >= 1 / 60) {
      if (_touch != null) _introduce(amount: 48, heat: 1 / 60);
      _scene.step(1 / 60);
      _accumulator -= 1 / 60;
    }
    _repaint.value++;
    _frames++;
    if (_hud > .3) {
      _hud = 0;
      setState(() {});
    }
    if (widget.benchmark && _scene.time >= 32 && !_reported) {
      _reported = true;
      // Machine-readable, actual Flutter frame timings; not estimated FPS.
      debugPrint(
        'ALCHEMY_BENCHMARK ${jsonEncode({'frames': _frames, 'fieldFrames': _scene.fieldFrames, 'samples': _rasterTimes.length, 'workerP95Ms': _percentile(_cpuTimes, .95), 'buildP95Ms': _percentile(_buildTimes, .95), 'rasterP50Ms': _percentile(_rasterTimes, .5), 'rasterP95Ms': _percentile(_rasterTimes, .95), 'buildOver16ms': _buildTimes.where((v) => v > 16.67).length, 'rasterOver16ms': _rasterTimes.where((v) => v > 16.67).length, 'particles': _scene.particleCount, 'reactions': _scene.transformations})}',
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _scene.pause();
    _previous = null;
    _touch = null;
    _pointer = null;
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    SchedulerBinding.instance.removeTimingsCallback(_timings);
    _ticker.dispose();
    _scene.dispose();
    _repaint.dispose();
    _shader?.dispose();
    _field?.dispose();
    super.dispose();
  }

  Offset _position(Offset p, Size size) => Offset(
    (p.dx / size.width).clamp(.03, .97),
    (p.dy / size.height * 1.5).clamp(.03, 1.46),
  );
  void _introduce({int amount = 48, double heat = .04}) {
    final p = _touch;
    if (p == null || _tool == 5) return;
    if (_tool == 6) {
      _scene.erase(p.dx, p.dy);
      return;
    }
    _scene.pour(p.dx, p.dy, amount: amount, material: _material);
  }

  Future<void> _pickElement() async {
    final selected = await showModalBottomSheet<FluidMaterial>(
      context: context,
      backgroundColor: const Color(0xFF101D25),
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Elements',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in FluidMaterial.values)
                        ChoiceChip(
                          label: Text(e.label),
                          selected: _material == e,
                          onSelected: (_) => Navigator.pop(context, e),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Every known recipe reacts on contact.',
                style: TextStyle(color: Color(0xFFA5B6BD)),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _material = selected;
        _tool = 4;
      });
    }
  }

  void _move(Offset next) {
    final old = _touch ?? next;
    if (_tool == 5) {
      _scene.stir(next.dx, next.dy, next.dx - old.dx, next.dy - old.dy);
    }
    _touch = next;
  }

  void _reset() {
    setState(() {
      _scene.reset();
      _paused = false;
      _touch = null;
      _pointer = null;
    });
    _upload();
  }

  @override
  Widget build(BuildContext context) {
    const muted = Color(0xFF8CA7AB),
        ink = Color(0xFFDEEAEB),
        gold = Color(0xFFD8BA86);
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF060D13),
        colorScheme: const ColorScheme.dark(
          primary: gold,
          surface: Color(0xFF14212B),
        ),
      ),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded, color: muted),
                    ),
                    const Expanded(
                      child: Text(
                        'M A T E R I A',
                        style: TextStyle(
                          color: ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                    const Text(
                      'MATERIA 03',
                      style: TextStyle(
                        color: gold,
                        fontSize: 9,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, bounds) {
                    final wide = bounds.maxWidth > 800;
                    final chamber = Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _paused
                                      ? 'SUSPENDED'
                                      : 'THE ELEMENTAL VESSEL',
                                  maxLines: 1,
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 9,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                              Text(
                                '${_scene.transformations} transformations',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (_field != null && _shader != null)
                                    LayoutBuilder(
                                      builder: (context, box) =>
                                          RepaintBoundary(
                                            child: Listener(
                                              key: const Key('alchemy-canvas'),
                                              behavior: HitTestBehavior.opaque,
                                              onPointerDown: (e) {
                                                if (_pointer != null) return;
                                                _pointer = e.pointer;
                                                _move(
                                                  _position(
                                                    e.localPosition,
                                                    box.biggest,
                                                  ),
                                                );
                                                _introduce(
                                                  amount: 72,
                                                  heat: .1,
                                                );
                                                _upload();
                                              },
                                              onPointerMove: (e) {
                                                if (e.pointer == _pointer) {
                                                  _move(
                                                    _position(
                                                      e.localPosition,
                                                      box.biggest,
                                                    ),
                                                  );
                                                  if (_paused) {
                                                    _introduce();
                                                    _upload();
                                                  }
                                                }
                                              },
                                              onPointerUp: (e) {
                                                if (e.pointer == _pointer) {
                                                  _pointer = null;
                                                  _touch = null;
                                                }
                                              },
                                              onPointerCancel: (e) {
                                                if (e.pointer == _pointer) {
                                                  _pointer = null;
                                                  _touch = null;
                                                }
                                              },
                                              child: CustomPaint(
                                                painter: FluidScenePainter(
                                                  _shader!,
                                                  () => _scene.time,
                                                  _repaint,
                                                ),
                                                child: const SizedBox.expand(),
                                              ),
                                            ),
                                          ),
                                    )
                                  else
                                    Center(
                                      child: _error == null
                                          ? const CircularProgressIndicator()
                                          : Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _error!,
                                                  textAlign: TextAlign.center,
                                                ),
                                                TextButton(
                                                  onPressed: _load,
                                                  child: const Text('Retry'),
                                                ),
                                              ],
                                            ),
                                    ),
                                  IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: const Color(0xFF25414B),
                                          width: .7,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Positioned(
                                    left: 18,
                                    bottom: 15,
                                    child: IgnorePointer(
                                      child: Text(
                                        'VESSEL  A—01',
                                        style: TextStyle(
                                          color: Color(0xFF78979D),
                                          fontSize: 8,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                    final controls = Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (wide) ...[
                            const SizedBox(height: 30),
                            const Text(
                              'A study in\ntransformation.',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w300,
                                height: 1.2,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          LayoutBuilder(
                            builder: (context, box) => Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                for (var i = 0; i < 6; i++)
                                  SizedBox(
                                    width: (box.maxWidth - 16) / 3,
                                    child: OutlinedButton(
                                      onPressed: () {
                                        if (i == 4) {
                                          _pickElement();
                                          return;
                                        }
                                        setState(() {
                                          _tool = i;
                                          if (i < 4) {
                                            _material = [
                                              FluidMaterial.water,
                                              FluidMaterial.fire,
                                              FluidMaterial.earth,
                                              FluidMaterial.air,
                                            ][i];
                                          }
                                        });
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 4,
                                        ),
                                        foregroundColor: _tool == i
                                            ? ink
                                            : muted,
                                        backgroundColor: _tool == i
                                            ? const Color(0xFF233A45)
                                            : Colors.transparent,
                                        side: BorderSide(
                                          color: _tool == i
                                              ? const Color(0xFF668F99)
                                              : const Color(0xFF263C45),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        [
                                          'Water',
                                          'Fire',
                                          'Earth',
                                          'Air',
                                          _tool == 4
                                              ? '${_material.label} ▾'
                                              : 'Elements ▾',
                                          'Stir',
                                        ][i],
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _tool == 5
                                ? 'Drag through matter to stir.'
                                : _tool == 6
                                ? 'Drag to remove material.'
                                : _scene.particleCount >= FluidScene.capacity
                                ? 'Vessel full. Erase some material to make room.'
                                : '${_material.label} · Hold to pour. Drag to move the stream.',
                            style: const TextStyle(
                              color: muted,
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: _scene.particleCount / FluidScene.capacity,
                            minHeight: 2,
                            color: gold,
                            backgroundColor: const Color(0xFF263C45),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Vessel ${(_scene.particleCount / FluidScene.capacity * 100).round()}% full',
                            key: const Key('alchemy-capacity'),
                            style: const TextStyle(color: muted, fontSize: 10),
                          ),
                          Text(
                            _scene.lastReaction,
                            key: const Key('alchemy-reaction'),
                            style: const TextStyle(color: gold, fontSize: 11),
                          ),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              FilterChip(
                                label: const Text(
                                  'Source',
                                  style: TextStyle(fontSize: 11),
                                ),
                                selected: _scene.feeding,
                                onSelected: (v) =>
                                    setState(() => _scene.feeding = v),
                              ),
                              IconButton(
                                tooltip: 'Erase',
                                onPressed: () => setState(() => _tool = 6),
                                icon: Icon(
                                  Icons.auto_fix_normal_rounded,
                                  color: _tool == 6 ? gold : muted,
                                  size: 21,
                                ),
                              ),
                              IconButton(
                                tooltip: _paused ? 'Resume' : 'Pause',
                                onPressed: () => setState(() {
                                  _paused = !_paused;
                                  if (_paused) _scene.pause();
                                  _touch = null;
                                  _pointer = null;
                                }),
                                icon: Icon(
                                  _paused
                                      ? Icons.play_arrow_rounded
                                      : Icons.pause_rounded,
                                  color: muted,
                                  size: 21,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Reset study',
                                onPressed: _reset,
                                icon: const Icon(
                                  Icons.restart_alt_rounded,
                                  color: muted,
                                  size: 21,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Clear chamber',
                                onPressed: () {
                                  setState(() {
                                    _scene.clear();
                                    _touch = null;
                                    _pointer = null;
                                  });
                                  _upload();
                                },
                                icon: const Icon(
                                  Icons.layers_clear_outlined,
                                  color: muted,
                                  size: 19,
                                ),
                              ),
                            ],
                          ),
                          if (wide) ...[
                            const SizedBox(height: 25),
                            const Divider(color: Color(0xFF263C45)),
                            const SizedBox(height: 15),
                            Text(
                              _scene.lastReaction,
                              style: TextStyle(color: gold, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Every encounter changes the material.\nNothing here depends on chance.',
                              style: TextStyle(
                                color: muted,
                                fontSize: 11,
                                height: 1.8,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                    return wide
                        ? Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: chamber,
                                ),
                              ),
                              SizedBox(
                                width: 300,
                                child: SingleChildScrollView(child: controls),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(child: chamber),
                              SizedBox(
                                height: min(246, bounds.maxHeight * .46),
                                child: SingleChildScrollView(child: controls),
                              ),
                            ],
                          );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
