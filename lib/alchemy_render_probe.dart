// Device-only diagnostic: export actual GPU renders of identical frozen fields.
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'games/alchemy/fluid_scene.dart';

void main() {
  runApp(const MaterialApp(home: _Probe()));
}

class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  String status = 'Capturing device GPU renders…';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    try {
      await captureAlchemyDeviceRenders();
      if (mounted) {
        setState(
          () => status =
              'GPU renders captured. Restore the normal app after this diagnostic.',
        );
      }
      debugPrint('ALCHEMY_PROBE_COMPLETE');
    } catch (e, st) {
      debugPrint('ALCHEMY_PROBE_ERROR $e $st');
      if (mounted) setState(() => status = 'Probe failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF091116),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          status,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    ),
  );
}

Future<void> captureAlchemyDeviceRenders() async {
  final dir = await getExternalStorageDirectory();
  if (dir == null) throw StateError('No export directory');
  for (final mixed in [false, true]) {
    final recipes =
        jsonDecode(
              await rootBundle.loadString(
                'assets/data/alchemons_element_recipes.json',
              ),
            )
            as Map<String, dynamic>;
    final scene = FluidScene(recipeJson: recipes);
    if (mixed) {
      scene.seedBenchmark();
    } else {
      for (var y = 180; y < FluidScene.renderH - 3; y++) {
        for (var x = 2; x < FluidScene.renderW - 2; x++) {
          scene.put(x, y, FluidMaterial.water);
        }
      }
    }
    for (var i = 0; i < 180; i++) {
      scene.pour(.48, .6, amount: 24, material: FluidMaterial.fire);
      scene.step(1 / 60);
    }
    final textureReady = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      scene.encode(),
      FluidScene.atlasW,
      FluidScene.renderH,
      ui.PixelFormat.rgba8888,
      textureReady.complete,
    );
    final texture = await textureReady.future;
    {
      const asset = 'alchemy_fluid';
      final shader = (await ui.FragmentProgram.fromAsset(
        'assets/shaders/$asset.frag',
      )).fragmentShader();
      shader.setFloat(0, 600);
      shader.setFloat(1, 900);
      shader.setFloat(2, scene.time);
      shader.setImageSampler(0, texture);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 600, 900),
        Paint()..shader = shader,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(600, 900);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final path =
          '${dir.path}/alchemy-${mixed ? 'mixed' : 'water'}-device.png';
      await File(path).writeAsBytes(bytes!.buffer.asUint8List());
      debugPrint('ALCHEMY_PROBE $path');
      image.dispose();
      picture.dispose();
      shader.dispose();
    }
    texture.dispose();
  }
}
