// Standalone device benchmark. The normal app still opens via Settings.
import 'package:flutter/material.dart';
import 'screens/alchemy_chamber_screen.dart';
import 'alchemy_render_probe.dart' show captureAlchemyDeviceRenders;

Future<void> main() async {
  runApp(
    const MaterialApp(
      home: Scaffold(
        backgroundColor: Color(0xFF091116),
        body: Center(
          child: Text(
            'Preparing the capacity test…',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    ),
  );
  await WidgetsBinding.instance.endOfFrame;
  await captureAlchemyDeviceRenders();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AlchemyChamberScreen(benchmark: true),
    ),
  );
}
