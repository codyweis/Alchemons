import 'dart:ui';
import 'dart:convert';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/models/harvest_biome.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/widgets/stamina_bar.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flame/components.dart';
import 'package:alchemons/utils/genetics_util.dart';

Future<String?> pickInstanceForHarvest({
  required BuildContext context,
  required List<String> allowedTypes,
  required Duration duration,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _InstancePicker(allowedTypes: allowedTypes, duration: duration),
  );
}

class _InstancePicker extends StatefulWidget {
  const _InstancePicker({required this.allowedTypes, required this.duration});

  final List<String> allowedTypes;
  final Duration duration;

  @override
  State<_InstancePicker> createState() => _InstancePickerState();
}

class _InstancePickerState extends State<_InstancePicker> {
  String _speciesQuery = '';
  final _search = TextEditingController();

  // Filter state
  String? _filterSize;
  String? _filterTint;
  String? _filterNature;
  bool _filterPrismatic = false;
  String _sortBy = 'Rate';
  bool _sortAscending = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();
    final accent = BreedConstants.getTypeColor(widget.allowedTypes.first);

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
                  stream: db.creatureDao.watchAllInstances(),
                  builder: (context, instSnap) {
                    if (!instSnap.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    return StreamBuilder<List<BiomeJob>>(
                      stream: (db.select(db.biomeJobs)).watch(),
                      builder: (context, jobSnap) {
                        final busy = {
                          if (jobSnap.data != null)
                            ...jobSnap.data!.map((j) => j.creatureInstanceId),
                        };

                        var pool = instSnap.data!
                            .where((i) => !busy.contains(i.instanceId))
                            .where(
                              (i) => _matchesAllowedTypes(
                                repo,
                                i,
                                widget.allowedTypes,
                              ),
                            )
                            .toList();

                        // Apply species search
                        if (_speciesQuery.isNotEmpty) {
                          final q = _speciesQuery.toLowerCase();
                          pool = pool.where((i) {
                            final sp = repo.getCreatureById(i.baseId);
                            final name = (sp?.name ?? '').toLowerCase();
                            final nick = (i.nickname ?? '').toLowerCase();
                            return name.contains(q) || nick.contains(q);
                          }).toList();
                        }

                        pool = pool.where((inst) {
                          // Prismatic filter
                          if (_filterPrismatic &&
                              inst.isPrismaticSkin != true) {
                            return false;
                          }

                          // Genetics-based filters
                          final genetics = decodeGenetics(inst.geneticsJson);
                          if (_filterSize != null &&
                              genetics?.size != _filterSize) {
                            return false;
                          }
                          if (_filterTint != null &&
                              genetics?.tinting != _filterTint) {
                            return false;
                          }
                          // Nature filter
                          if (_filterNature != null &&
                              inst.natureId != _filterNature) {
                            return false;
                          }

                          return true;
                        }).toList();

                        // Sort
                        pool.sort((a, b) {
                          int comparison = _sortBy == 'Level'
                              ? a.level.compareTo(b.level)
                              : _previewRate(
                                  repo,
                                  a,
                                ).compareTo(_previewRate(repo, b));
                          return _sortAscending ? comparison : -comparison;
                        });

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
                        final hasFilters =
                            _filterSize != null ||
                            _filterTint != null ||
                            _filterNature != null ||
                            _filterPrismatic;

                        return CustomScrollView(
                          controller: scroll,
                          slivers: [
                            // Header
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
                                      Icons.pets_rounded,
                                      color: accent,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Choose a creature',
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

                            // Search
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  10,
                                ),
                                child: TextField(
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
                                    fillColor: Colors.white.withOpacity(.06),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.white.withOpacity(.12),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.white.withOpacity(.12),
                                      ),
                                    ),
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFFE8EAED),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),

                            // Filters
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  10,
                                ),
                                child: _buildFilters(accent),
                              ),
                            ),

                            if (pool.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: _EmptyEligible(hasFilters: hasFilters),
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
                                    final rate = _previewRate(repo, inst);
                                    final total =
                                        rate * widget.duration.inMinutes;
                                    final g = decodeGenetics(inst.geneticsJson);
                                    final sd = sp?.spriteData;

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
                                                        child: FittedBox(
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
                                                                ? InstanceSprite(
                                                                    creature:
                                                                        sp!,
                                                                    instance:
                                                                        inst,
                                                                    size: 72,
                                                                  )
                                                                : (sp?.image !=
                                                                          null
                                                                      ? Image.asset(
                                                                          sp!.image,
                                                                          fit: BoxFit
                                                                              .contain,
                                                                        )
                                                                      : Icon(
                                                                          Icons
                                                                              .pets_rounded,
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
                                              StaminaBadge(
                                                instanceId: inst.instanceId,
                                                showCountdown: true,
                                              ),
                                              const SizedBox(height: 8),
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

  Widget _buildFilters(Color accent) {
    return Column(
      children: [
        // Sort row
        Row(
          children: [
            Icon(Icons.sort_rounded, size: 14, color: accent.withOpacity(.8)),
            const SizedBox(width: 6),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _SortChip(
                      label: 'Level ↑',
                      isSelected: _sortBy == 'Level' && !_sortAscending,
                      color: accent,
                      onTap: () => setState(() {
                        _sortBy = 'Level';
                        _sortAscending = false;
                      }),
                    ),
                    const SizedBox(width: 6),
                    _SortChip(
                      label: 'Level ↓',
                      isSelected: _sortBy == 'Level' && _sortAscending,
                      color: accent,
                      onTap: () => setState(() {
                        _sortBy = 'Level';
                        _sortAscending = true;
                      }),
                    ),
                    const SizedBox(width: 6),
                    _SortChip(
                      label: 'Rate ↑',
                      isSelected: _sortBy == 'Rate' && !_sortAscending,
                      color: accent,
                      onTap: () => setState(() {
                        _sortBy = 'Rate';
                        _sortAscending = false;
                      }),
                    ),
                    const SizedBox(width: 6),
                    _SortChip(
                      label: 'Rate ↓',
                      isSelected: _sortBy == 'Rate' && _sortAscending,
                      color: accent,
                      onTap: () => setState(() {
                        _sortBy = 'Rate';
                        _sortAscending = true;
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Filter row
        Row(
          children: [
            Icon(
              Icons.filter_list_rounded,
              size: 14,
              color: accent.withOpacity(.8),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      icon: Icons.auto_awesome,
                      label: 'Prismatic',
                      isSelected: _filterPrismatic,
                      color: accent,
                      onTap: () =>
                          setState(() => _filterPrismatic = !_filterPrismatic),
                    ),
                    const SizedBox(width: 6),
                    _FilterDropdown(
                      icon: Icons.straighten_rounded,
                      label: 'Size',
                      value: _filterSize,
                      items: const [
                        'tiny',
                        'small',
                        'normal',
                        'large',
                        'giant',
                      ],
                      itemLabels: const {
                        'tiny': 'Tiny',
                        'small': 'Small',
                        'normal': 'Normal',
                        'large': 'Large',
                        'giant': 'Giant',
                      },
                      color: accent,
                      onChanged: (v) => setState(() => _filterSize = v),
                    ),
                    const SizedBox(width: 6),
                    _FilterDropdown(
                      icon: Icons.palette_outlined,
                      label: 'Tint',
                      value: _filterTint,
                      items: const [
                        'normal',
                        'warm',
                        'cool',
                        'vibrant',
                        'pale',
                        'albino',
                      ],
                      itemLabels: const {
                        'normal': 'Normal',
                        'warm': 'Thermal',
                        'cool': 'Cryogenic',
                        'vibrant': 'Saturated',
                        'pale': 'Diminished',
                        'albino': 'Albino',
                      },
                      color: accent,
                      onChanged: (v) => setState(() => _filterTint = v),
                    ),
                    const SizedBox(width: 6),
                    _FilterDropdown(
                      icon: Icons.psychology_rounded,
                      label: 'Nature',
                      value: _filterNature,
                      items: const [
                        'Metabolic',
                        'Reproductive',
                        'Diligent',
                        'Sluggish',
                      ],
                      itemLabels: const {
                        'Metabolic': 'Metabolic',
                        'Reproductive': 'Reproductive',
                        'Diligent': 'Diligent',
                        'Sluggish': 'Sluggish',
                      },
                      color: accent,
                      onChanged: (v) => setState(() => _filterNature = v),
                    ),
                    if (_filterSize != null ||
                        _filterTint != null ||
                        _filterNature != null ||
                        _filterPrismatic) ...[
                      const SizedBox(width: 6),
                      _ClearButton(
                        color: accent,
                        onTap: () => setState(() {
                          _filterSize = null;
                          _filterTint = null;
                          _filterNature = null;
                          _filterPrismatic = false;
                        }),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _matchesAllowedTypes(
    CreatureCatalog repo,
    CreatureInstance inst,
    List<String> allowedTypes,
  ) {
    final sp = repo.getCreatureById(inst.baseId);
    if (sp == null || sp.types.isEmpty) return false;
    return allowedTypes.contains(sp.types.first);
  }

  int _previewRate(CreatureCatalog repo, CreatureInstance inst) {
    var base = 3;
    base += (inst.level - 1);
    base = (base * 1.25).round();

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

  Map<String, String>? _parseGenetics(CreatureInstance inst) {
    if (inst.geneticsJson == null) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(inst.geneticsJson!));
      return map.map((k, v) => MapEntry(k, v.toString()));
    } catch (e) {
      return null;
    }
  }
}

// Filter widgets
class _SortChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? color.withOpacity(.2)
            : Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected
              ? color.withOpacity(.5)
              : Colors.white.withOpacity(.15),
          width: 1.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? color : const Color(0xFFB6C0CC),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? color.withOpacity(.2)
            : Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected
              ? color.withOpacity(.5)
              : Colors.white.withOpacity(.15),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: isSelected ? color : const Color(0xFFB6C0CC),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? color : const Color(0xFFB6C0CC),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    ),
  );
}

class _FilterDropdown extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final List<String> items;
  final Map<String, String> itemLabels;
  final Color color;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabels,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => _FilterDialog(
          title: label,
          items: items,
          itemLabels: itemLabels,
          currentValue: value,
          color: color,
        ),
      );
      if (result != null) onChanged(result == 'clear' ? null : result);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: value != null
            ? color.withOpacity(.2)
            : Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: value != null
              ? color.withOpacity(.5)
              : Colors.white.withOpacity(.15),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: value != null ? color : const Color(0xFFB6C0CC),
          ),
          const SizedBox(width: 3),
          Text(
            value != null ? itemLabels[value] ?? value! : label,
            style: TextStyle(
              color: value != null ? color : const Color(0xFFB6C0CC),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.arrow_drop_down,
            size: 12,
            color: value != null ? color : const Color(0xFFB6C0CC),
          ),
        ],
      ),
    ),
  );
}

class _ClearButton extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _ClearButton({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red.withOpacity(.4), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.clear_rounded, size: 11, color: Colors.red.shade300),
          const SizedBox(width: 3),
          Text(
            'Clear',
            style: TextStyle(
              color: Colors.red.shade300,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    ),
  );
}

class _FilterDialog extends StatelessWidget {
  final String title;
  final List<String> items;
  final Map<String, String> itemLabels;
  final String? currentValue;
  final Color color;

  const _FilterDialog({
    required this.title,
    required this.items,
    required this.itemLabels,
    required this.currentValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 500, maxWidth: 400),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0B0F14).withOpacity(0.92),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(.4), width: 2),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFE8EAED),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      ...items.map((item) {
                        final isSelected = currentValue == item;
                        return GestureDetector(
                          onTap: () => Navigator.pop(context, item),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withOpacity(.2)
                                  : Colors.white.withOpacity(.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? color.withOpacity(.5)
                                    : Colors.white.withOpacity(.15),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    itemLabels[item] ?? item,
                                    style: TextStyle(
                                      color: isSelected
                                          ? color
                                          : const Color(0xFFE8EAED),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_rounded,
                                    color: color,
                                    size: 18,
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                      if (currentValue != null) ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => Navigator.pop(context, 'clear'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.red.withOpacity(.4),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.clear_rounded,
                                  color: Colors.red.shade300,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Clear Filter',
                                  style: TextStyle(
                                    color: Colors.red.shade300,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _EmptyEligible extends StatelessWidget {
  final bool hasFilters;
  const _EmptyEligible({this.hasFilters = false});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilters ? Icons.search_off_rounded : Icons.block,
            color: Colors.white54,
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? 'No creatures match filters'
                : 'No eligible creatures for this biome.',
            style: const TextStyle(
              color: Color(0xFFE8EAED),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilters
                ? 'Try adjusting your filters'
                : 'You need a matching-element creature with at least 1 stamina bar.',
            textAlign: TextAlign.center,
            style: const TextStyle(
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
