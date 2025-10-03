import 'dart:ui';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/models/farm_element.dart' hide HarvestJob;
import 'package:alchemons/widgets/stamina_bar.dart';

// sprite + genetics
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flame/components.dart';
import 'package:alchemons/utils/genetics_util.dart';

Future<String?> pickInstanceForHarvest({
  required BuildContext context,
  required FarmElement element,
  required Duration duration,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _InstancePicker(element: element, duration: duration),
  );
}

class _InstancePicker extends StatefulWidget {
  const _InstancePicker({required this.element, required this.duration});
  final FarmElement element;
  final Duration duration;

  @override
  State<_InstancePicker> createState() => _InstancePickerState();
}

class _InstancePickerState extends State<_InstancePicker> {
  String _speciesQuery = '';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureRepository>();
    final accent = widget.element.color;

    return DraggableScrollableSheet(
      initialChildSize: .88,
      minChildSize: .55,
      maxChildSize: .95,
      expand: false,
      builder: (context, scroll) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0F14).withOpacity(.92),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withOpacity(.35), width: 2),
                  boxShadow: [
                    BoxShadow(color: accent.withOpacity(.2), blurRadius: 24),
                  ],
                ),
                child: StreamBuilder<List<CreatureInstance>>(
                  stream: db.watchAllInstances(),
                  builder: (context, instSnap) {
                    if (!instSnap.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    return StreamBuilder<List<HarvestJob>>(
                      stream: (db.select(db.harvestJobs)).watch(),
                      builder: (context, jobSnap) {
                        final busy = {
                          if (jobSnap.data != null)
                            ...jobSnap.data!.map((j) => j.creatureInstanceId),
                        };

                        // base pool: match farm element + stamina + not busy
                        var pool = instSnap.data!
                            .where((i) => i.staminaBars > 0)
                            .where((i) => !busy.contains(i.instanceId))
                            .where(
                              (i) =>
                                  _matchesFarmElement(repo, i, widget.element),
                            )
                            .toList();

                        // apply species search (name or nickname)
                        if (_speciesQuery.isNotEmpty) {
                          final q = _speciesQuery.toLowerCase();
                          pool = pool.where((i) {
                            final sp = repo.getCreatureById(i.baseId);
                            final name = (sp?.name ?? '').toLowerCase();
                            final nick = (i.nickname ?? '').toLowerCase();
                            return name.contains(q) || nick.contains(q);
                          }).toList();
                        }

                        // sort by best preview rate
                        pool.sort((a, b) {
                          final ra = _previewRate(repo, a, widget.element);
                          final rb = _previewRate(repo, b, widget.element);
                          return rb.compareTo(ra);
                        });

                        // responsive child aspect to reduce overflow
                        final width = MediaQuery.of(context).size.width;
                        final cross = width >= 900
                            ? 4
                            : width >= 700
                            ? 3
                            : 2;
                        final childAspect = width < 380
                            ? 0.64
                            : width < 480
                            ? 0.68
                            : width < 700
                            ? 0.72
                            : 0.78;

                        return CustomScrollView(
                          controller: scroll,
                          slivers: [
                            // header
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  16,
                                  8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      widget.element.icon,
                                      color: accent,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Choose a ${widget.element.label} creature',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFFE8EAED),
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    if (pool.isNotEmpty)
                                      Text(
                                        '${pool.length}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(.7),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            // filters: species search + derived type chips
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  10,
                                ),
                                child: Column(
                                  children: [
                                    // species search
                                    TextField(
                                      controller: _search,
                                      onChanged: (v) =>
                                          setState(() => _speciesQuery = v),
                                      textInputAction: TextInputAction.search,
                                      decoration: InputDecoration(
                                        hintText: 'Search species or nickname…',
                                        hintStyle: const TextStyle(
                                          color: Color(0xFFB6C0CC),
                                        ),
                                        isDense: true,
                                        prefixIcon: const Icon(
                                          Icons.search,
                                          size: 18,
                                          color: Color(0xFFB6C0CC),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(
                                          .06,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.white.withOpacity(
                                              .12,
                                            ),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.white.withOpacity(
                                              .12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      style: const TextStyle(
                                        color: Color(0xFFE8EAED),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            if (pool.isEmpty)
                              const SliverFillRemaining(
                                hasScrollBody: false,
                                child: _EmptyEligible(),
                              )
                            else
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  16,
                                ),
                                sliver: SliverGrid(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: cross,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10,
                                        childAspectRatio: childAspect,
                                      ),
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    i,
                                  ) {
                                    final inst = pool[i];
                                    final sp = repo.getCreatureById(
                                      inst.baseId,
                                    );
                                    final rate = _previewRate(
                                      repo,
                                      inst,
                                      widget.element,
                                    );
                                    final total =
                                        rate * widget.duration.inMinutes;

                                    // genetics for sprite
                                    final g = decodeGenetics(inst.geneticsJson);
                                    final sd = sp?.spriteData; // null-safe

                                    return GestureDetector(
                                      onTap: () => Navigator.pop(
                                        context,
                                        inst.instanceId,
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(.2),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: accent.withOpacity(.4),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // ---------- IMAGE / SPRITE (your block) ----------
                                              Expanded(
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withOpacity(.04),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors.white
                                                            .withOpacity(.12),
                                                      ),
                                                    ),
                                                    child: Center(
                                                      child: ClipRect(
                                                        // crops any overpaint from scale/hue effects
                                                        child: FittedBox(
                                                          // keeps art centered + contained
                                                          fit: BoxFit.contain,
                                                          child: SizedBox(
                                                            width:
                                                                (sd?.frameWidth ??
                                                                        64)
                                                                    .toDouble(),
                                                            height:
                                                                (sd?.frameHeight ??
                                                                        64)
                                                                    .toDouble(),
                                                            child: (sd != null)
                                                                ? CreatureSprite(
                                                                    spritePath:
                                                                        sd!.spriteSheetPath,
                                                                    totalFrames:
                                                                        sd!.totalFrames,
                                                                    rows: sd!
                                                                        .rows,
                                                                    frameSize: Vector2(
                                                                      sd!.frameWidth
                                                                          .toDouble(),
                                                                      sd!.frameHeight
                                                                          .toDouble(),
                                                                    ),
                                                                    stepTime:
                                                                        sd!.frameDurationMs /
                                                                        1000.0,
                                                                    // genetics-driven tweaks
                                                                    scale:
                                                                        scaleFromGenes(
                                                                          g,
                                                                        ),
                                                                    saturation:
                                                                        satFromGenes(
                                                                          g,
                                                                        ),
                                                                    brightness:
                                                                        briFromGenes(
                                                                          g,
                                                                        ),
                                                                    hueShift:
                                                                        hueFromGenes(
                                                                          g,
                                                                        ),
                                                                    isPrismatic:
                                                                        inst.isPrismaticSkin,
                                                                  )
                                                                : (sp?.image !=
                                                                          null
                                                                      ? Image.asset(
                                                                          sp!.image,
                                                                          fit: BoxFit
                                                                              .contain,
                                                                        )
                                                                      : Icon(
                                                                          widget
                                                                              .element
                                                                              .icon,
                                                                          size:
                                                                              28,
                                                                          color: Colors
                                                                              .white
                                                                              .withOpacity(
                                                                                .6,
                                                                              ),
                                                                        )),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 8),

                                              // Stamina
                                              StaminaBadge(
                                                instanceId: inst.instanceId,
                                                showCountdown: true,
                                              ),
                                              const SizedBox(height: 8),

                                              // Name (no overflow)
                                              Text(
                                                (inst.nickname ??
                                                        sp?.name ??
                                                        inst.baseId)
                                                    .toUpperCase(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Color(0xFFE8EAED),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              const SizedBox(height: 4),

                                              // Rate / total chips
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: [
                                                  _Chip(
                                                    icon: Icons.trending_up,
                                                    label: '$rate / min',
                                                    color: accent,
                                                  ),
                                                  _Chip(
                                                    icon: Icons
                                                        .inventory_2_outlined,
                                                    label: '$total total',
                                                    color: accent.withOpacity(
                                                      .9,
                                                    ),
                                                  ),
                                                ],
                                              ),

                                              const SizedBox(height: 6),

                                              // Meta row (tight, no overflow)
                                              Row(
                                                children: [
                                                  _Tiny('LV ${inst.level}'),
                                                  if ((inst.natureId ?? '')
                                                      .isNotEmpty) ...[
                                                    const SizedBox(width: 8),
                                                    _Tiny(inst.natureId!),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }, childCount: pool.length),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Only allow species whose element matches the current farm element.
  bool _matchesFarmElement(
    CreatureRepository repo,
    CreatureInstance inst,
    FarmElement farmEl,
  ) {
    final sp = repo.getCreatureById(inst.baseId);
    if (sp == null) return false;
    final want = farmEl.name.toLowerCase();
    final e1 = (sp.types).toString().toLowerCase();
    final list = (sp.types).map((t) => t.toLowerCase()).toList();
    return (e1 == want) || list.contains(want);
  }

  int _previewRate(
    CreatureRepository repo,
    CreatureInstance inst,
    FarmElement farmEl,
  ) {
    var base = switch (farmEl) {
      FarmElement.fire => 3,
      FarmElement.water => 3,
      FarmElement.air => 2,
      FarmElement.earth => 2,
    };
    base += (inst.level - 1); // level bonus
    base = (base * 1.25)
        .round(); // element synergy (we already filter to matches)
    final nature = (inst.natureId ?? '').toLowerCase();
    final natureBonusPct = switch (nature) {
      'metabolic' => 10,
      'diligent' => 8,
      'sluggish' => -10,
      _ => 0,
    };
    base = (base * (1 + natureBonusPct / 100)).round();
    return base.clamp(1, 999);
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _EmptyEligible extends StatelessWidget {
  const _EmptyEligible();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.block, color: Colors.white54),
          SizedBox(height: 8),
          Text(
            'No eligible creatures for this farm.',
            style: TextStyle(
              color: Color(0xFFE8EAED),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'You need a matching-element creature with at least 1 stamina bar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFB6C0CC),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? color.withOpacity(.22)
            : Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? color : Colors.white.withOpacity(.18),
          width: 2,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: selected ? color : const Color(0xFFE8EAED),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: .5,
        ),
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(.18),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(.6)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _Tiny extends StatelessWidget {
  const _Tiny(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(.06),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Colors.white.withOpacity(.15)),
    ),
    child: Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFFE8EAED),
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: .4,
      ),
    ),
  );
}
