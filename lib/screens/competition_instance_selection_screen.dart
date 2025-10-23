import 'package:alchemons/models/parent_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flame/extensions.dart';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/competition.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/utils/genetics_util.dart';

/// Push this screen and it will return the chosen instanceId (String)
/// via Navigator.pop<String>(instanceId).
class CompetitionPickerScreen extends StatefulWidget {
  const CompetitionPickerScreen({super.key, required this.biome});

  final CompetitionBiome biome;

  @override
  State<CompetitionPickerScreen> createState() =>
      _CompetitionPickerScreenState();
}

class _CompetitionPickerScreenState extends State<CompetitionPickerScreen> {
  late final String statKey; // e.g. 'statIntelligence' for Earthen
  late final List<String> allowedTypes; // e.g. ['Earth','Mud','Dust','Crystal']

  String _query = '';
  bool _onlyRested = true;

  late Future<List<_Candidate>> _future;

  @override
  void initState() {
    super.initState();
    statKey = widget.biome.type.statKey;
    allowedTypes = widget.biome.allowedTypes;
    _future = _loadCandidates();
  }

  Future<List<_Candidate>> _loadCandidates() async {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureRepository>();

    // Pull all instances
    final instances = await db.listAllInstances();

    final out = <_Candidate>[];
    for (final inst in instances) {
      // Resolve base creature (types and sprite data)
      final base = repo.getCreatureById(inst.baseId);
      if (base == null) continue;

      // Filter by allowed types (if any)
      if (allowedTypes.isNotEmpty) {
        final matches = base.types.any((t) => allowedTypes.contains(t));
        if (!matches) continue;
      }

      // Optionally filter exhausted mons
      if (_onlyRested && inst.staminaBars <= 0) continue;

      // Compute relevant stat
      final relevant = _relevantStatForCompetition(inst, statKey);

      // Build the sprite if available
      Widget? sprite;
      if (base.spriteData != null) {
        final s = base.spriteData!;
        final genes = decodeGenetics(inst.geneticsJson);
        sprite = CreatureSprite(
          spritePath: s.spriteSheetPath,
          totalFrames: s.totalFrames,
          rows: s.rows,
          frameSize: Vector2(s.frameWidth.toDouble(), s.frameHeight.toDouble()),
          stepTime: s.frameDurationMs / 1000.0,
          scale: scaleFromGenes(genes),
          saturation: satFromGenes(genes),
          brightness: briFromGenes(genes),
          hueShift: hueFromGenes(genes),
          isPrismatic: inst.isPrismaticSkin,
        );
      }

      out.add(
        _Candidate(
          instanceId: inst.instanceId,
          displayName: inst.nickname ?? base.name,
          types: base.types,
          level: inst.level,
          staminaBars: inst.staminaBars,
          statSpeed: inst.statSpeed,
          statIntelligence: inst.statIntelligence,
          statStrength: inst.statStrength,
          statBeauty: inst.statBeauty,
          relevantStat: relevant,
          sprite: sprite,
        ),
      );
    }

    // Search filter
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? out
        : out.where((c) => c.displayName.toLowerCase().contains(q)).toList();

    // Sort by relevant stat (desc), then level (desc), then name
    filtered.sort((a, b) {
      final s = b.relevantStat.compareTo(a.relevantStat);
      if (s != 0) return s;
      final l = b.level.compareTo(a.level);
      if (l != 0) return l;
      return a.displayName.compareTo(b.displayName);
    });

    return filtered;
  }

  double _relevantStatForCompetition(CreatureInstance inst, String key) {
    switch (key) {
      case 'statSpeed':
        return inst.statSpeed.clamp(0.0, 10.0);
      case 'statStrength':
        return inst.statStrength.clamp(0.0, 10.0);
      case 'statIntelligence':
        return inst.statIntelligence.clamp(0.0, 10.0);
      case 'statBeauty':
        return inst.statBeauty.clamp(0.0, 10.0);
      case 'all': // Ultimate: average
        final avg =
            (inst.statSpeed +
                inst.statStrength +
                inst.statIntelligence +
                inst.statBeauty) /
            4.0;
        return avg.clamp(0.0, 10.0);
      default:
        return 5.0;
    }
  }

  void _refresh() => setState(() => _future = _loadCandidates());

  @override
  Widget build(BuildContext context) {
    final accent = widget.biome.primaryColor;
    final typeIcon = widget.biome.type.icon;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('${widget.biome.name} • Select Creature'),
        actions: [
          Icon(typeIcon, color: accent),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          // Search + Rested toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: _SearchField(
                    hint: 'Search name…',
                    onChanged: (v) {
                      _query = v;
                      _refresh();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Rested'),
                  selected: _onlyRested,
                  onSelected: (v) {
                    _onlyRested = v;
                    _refresh();
                  },
                ),
              ],
            ),
          ),

          // Allowed type pills
          if (allowedTypes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: allowedTypes
                      .map(
                        (t) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.05),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: accent.withOpacity(.45)),
                          ),
                          child: Text(
                            t.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),

          const SizedBox(height: 6),

          // List
          Expanded(
            child: FutureBuilder<List<_Candidate>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Failed to load creatures',
                      style: TextStyle(color: Colors.red.shade300),
                    ),
                  );
                }
                final items = snap.data ?? const <_Candidate>[];
                if (items.isEmpty) {
                  return const Center(
                    child: Text(
                      'No eligible creatures found.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final c = items[i];
                    return _StatsCard(
                      candidate: c,
                      accent: accent,
                      statKey: statKey,
                      onTap: () =>
                          Navigator.of(context).pop<String>(c.instanceId),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// ——— UI helpers ———

class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(.55)),
        isDense: true,
        filled: true,
        fillColor: Colors.white.withOpacity(.06),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(.14)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(.14)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(.22)),
        ),
        prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 18),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.candidate,
    required this.accent,
    required this.statKey,
    this.onTap,
  });

  final _Candidate candidate;
  final Color accent;
  final String statKey;
  final VoidCallback? onTap;

  String _labelFor(String key) {
    switch (key) {
      case 'statSpeed':
        return 'SPD';
      case 'statStrength':
        return 'STR';
      case 'statIntelligence':
        return 'INT';
      case 'statBeauty':
        return 'BEA';
      case 'all':
        return '★';
      default:
        return key.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rel = candidate.relevantStat;

    Widget bar(double v, {bool strong = false}) {
      return Container(
        height: strong ? 10 : 6,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(999),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: (v / 10).clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, accent.withOpacity(.7)],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(.45), width: 1.6),
          boxShadow: [
            BoxShadow(color: accent.withOpacity(.18), blurRadius: 16),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sprite
            SizedBox(
              width: 76,
              height: 76,
              child: FittedBox(
                child:
                    candidate.sprite ??
                    const Icon(Icons.pets, color: Colors.white70),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + Lv + stamina
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${candidate.displayName}  •  Lv.${candidate.level}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (candidate.staminaBars <= 0)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.battery_alert,
                            color: Colors.redAccent,
                            size: 16,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Types
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: candidate.types.map((t) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.06),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withOpacity(.15),
                          ),
                        ),
                        child: Text(
                          t,
                          style: const TextStyle(
                            color: Color(0xFFE8EAED),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),

                  // Relevant stat emphasized
                  Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text(
                          _labelFor(statKey),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Expanded(child: bar(rel, strong: true)),
                      const SizedBox(width: 8),
                      Text(
                        rel.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),

                  // Sub row of muted other stats (context)
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _MiniStat(label: 'SPD', value: candidate.statSpeed),
                      _MiniStat(label: 'STR', value: candidate.statStrength),
                      _MiniStat(
                        label: 'INT',
                        value: candidate.statIntelligence,
                      ),
                      _MiniStat(label: 'BEA', value: candidate.statBeauty),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white38,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.05),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (value / 10).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Row VM
class _Candidate {
  _Candidate({
    required this.instanceId,
    required this.displayName,
    required this.types,
    required this.level,
    required this.staminaBars,
    required this.statSpeed,
    required this.statIntelligence,
    required this.statStrength,
    required this.statBeauty,
    required this.relevantStat,
    required this.sprite,
  });

  final String instanceId;
  final String displayName;
  final List<String> types;
  final int level;
  final int staminaBars;

  final double statSpeed, statIntelligence, statStrength, statBeauty;
  final double relevantStat;

  final Widget? sprite;
}
