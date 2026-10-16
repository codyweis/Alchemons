// lib/screens/debug/bloodborn_vial_debug_screen.dart
//
// DEVELOPER: the Bloodborn Vial without the ending. One Alchemon's vial in
// four chambers at stages of its brew (the last one ready), and EXTRACT to
// play its extraction. Nothing is saved: no vial, no Alchemon.

import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/widgets/animations/bloodborn_extraction.dart';
import 'package:alchemons/widgets/fx/bloodborn_vial.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BloodbornVialDebugScreen extends StatefulWidget {
  const BloodbornVialDebugScreen({super.key, required this.instanceId});

  /// Whose vial: an Alchemon in the save, read and never changed.
  final String instanceId;

  @override
  State<BloodbornVialDebugScreen> createState() =>
      _BloodbornVialDebugScreenState();
}

class _BloodbornVialDebugScreenState extends State<BloodbornVialDebugScreen> {
  Map<String, dynamic>? _payload;
  String? _family;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();
    final inst = await db.creatureDao.getInstance(widget.instanceId);
    if (!mounted || inst == null) return;
    // The payload the rite would write, as far as the look reads it.
    setState(() {
      _payload = {
        'baseId': inst.baseId,
        'source': 'bloodborn',
        'isPrismaticSkin': inst.isPrismaticSkin,
        'genetics': inst.geneticsJson == null
            ? const {}
            : _decode(inst.geneticsJson!),
      };
      _family = catalog.getCreatureById(inst.baseId)?.mutationFamily;
    });
  }

  static Map<String, dynamic> _decode(String raw) {
    try {
      final m = jsonDecode(raw);
      return m is Map<String, dynamic> ? m : const {};
    } catch (_) {
      return const {};
    }
  }

  Future<void> _extract() async {
    final payload = _payload;
    if (payload == null) return;
    final quality = await CinematicQualityService().getQuality();
    if (!mounted) return;
    await playBloodbornExtraction(
      context: context,
      payload: payload,
      mutationFamily: _family,
      quality: quality,
    );
  }

  @override
  Widget build(BuildContext context) {
    final payload = _payload;
    const stages = [(0.0, 'POOL'), (0.3, '30%'), (0.7, '70%'), (1.0, 'READY')];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: const Color(0xFFE4C16A),
        title: const Text('BLOODBORN VIAL'),
      ),
      body: payload == null
          ? const SizedBox()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final (p, label) in stages)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black,
                              border: Border.all(
                                color: const Color(0x55FF6B6B),
                              ),
                            ),
                            child: ClipOval(
                              child: BloodbornVial(
                                payload: payload,
                                progress: p,
                                isReady: p >= 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            style: const TextStyle(
                              color: Color(0xAAE4C16A),
                              fontFamily: 'monospace',
                              letterSpacing: 2,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                Center(
                  child: OutlinedButton(
                    onPressed: _extract,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF6B6B),
                      side: const BorderSide(color: Color(0x88FF6B6B)),
                    ),
                    child: const Text('EXTRACT'),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Hold a finger on a chamber to part the blood. Nothing here '
                  'is saved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
    );
  }
}
