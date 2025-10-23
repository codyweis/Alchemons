import 'dart:convert';
import 'dart:ui';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/color_util.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/filter_data_loader.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/creature_dialog.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class InstanceSelectionDialog extends StatefulWidget {
  final Creature creature;

  const InstanceSelectionDialog({super.key, required this.creature});

  @override
  State<InstanceSelectionDialog> createState() =>
      _InstanceSelectionDialogState();

  static Future<void> show(BuildContext context, Creature creature) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => InstanceSelectionDialog(creature: creature),
    );
  }
}

class _InstanceSelectionDialogState extends State<InstanceSelectionDialog> {
  // ✅ Sort state
  String _sortBy = 'Level';
  bool _sortAscending = false;

  // ✅ Filter state
  String? _filterSize;
  String? _filterTint;
  String? _filterNature;
  bool _filterPrismatic = false;

  @override
  Widget build(BuildContext context) {
    final factionSvc = context.read<FactionService>();
    final currentFaction = factionSvc.current;
    final factionColors = getFactionColors(currentFaction);
    final primaryColor = factionColors.$1;

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: const Color(0xFF0B0F14).withOpacity(0.94),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primaryColor.withOpacity(.4), width: 2),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(.25),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                _buildHeader(primaryColor),
                _buildSortAndFilterControls(primaryColor),
                Expanded(child: _buildInstanceGrid(primaryColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.3),
        border: Border(bottom: BorderSide(color: primaryColor.withOpacity(.3))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withOpacity(.3),
                  primaryColor.withOpacity(.2),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.pets_rounded, color: primaryColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.creature.name.toUpperCase()} INSTANCES',
                  style: const TextStyle(
                    color: Color(0xFFE8EAED),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Long press for details • Tap to select',
                  style: TextStyle(
                    color: Color(0xFFB6C0CC),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(.2)),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Color(0xFFE8EAED),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortAndFilterControls(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.2),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(.1))),
      ),
      child: Column(
        children: [
          // Sort row
          Row(
            children: [
              Icon(Icons.sort_rounded, color: primaryColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _SortChip(
                        label: 'Level ↓',
                        isSelected: _sortBy == 'Level' && !_sortAscending,
                        primaryColor: primaryColor,
                        onTap: () => setState(() {
                          _sortBy = 'Level';
                          _sortAscending = false;
                        }),
                      ),
                      const SizedBox(width: 6),
                      _SortChip(
                        label: 'Level ↑',
                        isSelected: _sortBy == 'Level' && _sortAscending,
                        primaryColor: primaryColor,
                        onTap: () => setState(() {
                          _sortBy = 'Level';
                          _sortAscending = true;
                        }),
                      ),
                      const SizedBox(width: 6),
                      _SortChip(
                        label: 'Newest',
                        isSelected: _sortBy == 'Created' && !_sortAscending,
                        primaryColor: primaryColor,
                        onTap: () => setState(() {
                          _sortBy = 'Created';
                          _sortAscending = false;
                        }),
                      ),
                      const SizedBox(width: 6),
                      _SortChip(
                        label: 'Oldest',
                        isSelected: _sortBy == 'Created' && _sortAscending,
                        primaryColor: primaryColor,
                        onTap: () => setState(() {
                          _sortBy = 'Created';
                          _sortAscending = true;
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ✅ Filter row
          Row(
            children: [
              Icon(Icons.filter_list_rounded, color: primaryColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        icon: Icons.auto_awesome,
                        label: 'Prismatic',
                        isSelected: _filterPrismatic,
                        primaryColor: primaryColor,
                        onTap: () => setState(
                          () => _filterPrismatic = !_filterPrismatic,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _FilterDropdown(
                        icon: Icons.straighten_rounded,
                        label: 'Size',
                        value: _filterSize,
                        items: FilterDataLoader.getSizeVariants(),
                        itemLabels: FilterDataLoader.getSizeLabels(),
                        primaryColor: primaryColor,
                        onChanged: (v) => setState(() => _filterSize = v),
                      ),
                      const SizedBox(width: 6),
                      _FilterDropdown(
                        icon: Icons.palette_outlined,
                        label: 'Tint',
                        value: _filterTint,
                        items: FilterDataLoader.getTintingVariants(),
                        itemLabels: FilterDataLoader.getTintingLabels(),
                        primaryColor: primaryColor,
                        onChanged: (v) => setState(() => _filterTint = v),
                      ),
                      const SizedBox(width: 6),
                      _FilterDropdown(
                        icon: Icons.psychology_rounded,
                        label: 'Nature',
                        value: _filterNature,
                        items: FilterDataLoader.getAllNatures(),
                        itemLabels: FilterDataLoader.getNatureLabels(),
                        primaryColor: primaryColor,
                        onChanged: (v) => setState(() => _filterNature = v),
                      ),
                      if (_filterSize != null ||
                          _filterTint != null ||
                          _filterNature != null ||
                          _filterPrismatic) ...[
                        const SizedBox(width: 6),
                        _ClearFiltersButton(
                          primaryColor: primaryColor,
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
      ),
    );
  }

  Widget _buildInstanceGrid(Color primaryColor) {
    return StreamBuilder<List<CreatureInstance>>(
      stream: context.watch<AlchemonsDatabase>().watchAllInstances(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }

        var instances = snapshot.data!
            .where((inst) => inst.baseId == widget.creature.id)
            .toList();

        // ✅ Apply filters
        instances = instances.where((inst) {
          if (_filterPrismatic && inst.isPrismaticSkin != true) return false;

          final genetics = decodeGenetics(inst.geneticsJson);
          if (_filterSize != null && genetics?.get('size') != _filterSize) {
            return false;
          }
          if (_filterTint != null && genetics?.get('tinting') != _filterTint) {
            return false;
          }
          if (_filterNature != null && inst.natureId != _filterNature) {
            return false;
          }

          return true;
        }).toList();

        // Sort instances
        instances.sort((a, b) {
          int comparison = _sortBy == 'Level'
              ? a.level.compareTo(b.level)
              : a.createdAtUtcMs.compareTo(b.createdAtUtcMs);
          return _sortAscending ? comparison : -comparison;
        });

        final hasFilters =
            _filterSize != null ||
            _filterTint != null ||
            _filterNature != null ||
            _filterPrismatic;

        if (instances.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(.15)),
                  ),
                  child: Icon(
                    hasFilters ? Icons.search_off_rounded : Icons.pets_outlined,
                    color: Colors.white.withOpacity(.4),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  hasFilters ? 'No Matching Instances' : 'No Instances Found',
                  style: const TextStyle(
                    color: Color(0xFFE8EAED),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasFilters
                      ? 'Try adjusting your filters'
                      : 'You don\'t own any instances of this species yet',
                  style: const TextStyle(
                    color: Color(0xFFB6C0CC),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.85,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: instances.length,
          itemBuilder: (context, index) {
            return _InstanceCard(
              instance: instances[index],
              creature: widget.creature,
              primaryColor: primaryColor,
              onTap: () async {
                await CreatureDetailsDialog.show(
                  context,
                  widget.creature,
                  true,
                  instanceId: instances[index].instanceId,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _FilterChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(.2)
              : Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? primaryColor.withOpacity(.5)
                : Colors.white.withOpacity(.15),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: isSelected ? primaryColor : const Color(0xFFB6C0CC),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? primaryColor : const Color(0xFFB6C0CC),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final List<String> items;
  final Map<String, String> itemLabels;
  final Color primaryColor;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabels,
    required this.primaryColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await showDialog<String>(
          context: context,
          builder: (context) => _FilterDialog(
            title: label,
            items: items,
            itemLabels: itemLabels,
            currentValue: value,
            primaryColor: primaryColor,
          ),
        );
        if (result != null) {
          onChanged(result == 'clear' ? null : result);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: value != null
              ? primaryColor.withOpacity(.2)
              : Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value != null
                ? primaryColor.withOpacity(.5)
                : Colors.white.withOpacity(.15),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: value != null ? primaryColor : const Color(0xFFB6C0CC),
            ),
            const SizedBox(width: 4),
            Text(
              value != null ? itemLabels[value] ?? value! : label,
              style: TextStyle(
                color: value != null ? primaryColor : const Color(0xFFB6C0CC),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 14,
              color: value != null ? primaryColor : const Color(0xFFB6C0CC),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClearFiltersButton extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onTap;

  const _ClearFiltersButton({required this.primaryColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withOpacity(.4), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.clear_rounded, size: 12, color: Colors.red.shade300),
            const SizedBox(width: 4),
            Text(
              'Clear',
              style: TextStyle(
                color: Colors.red.shade300,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterDialog extends StatelessWidget {
  final String title;
  final List<String> items;
  final Map<String, String> itemLabels;
  final String? currentValue;
  final Color primaryColor;

  const _FilterDialog({
    required this.title,
    required this.items,
    required this.itemLabels,
    required this.currentValue,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6, // ✅ Max height
          maxWidth: 400,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0B0F14).withOpacity(0.92),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: primaryColor.withOpacity(.4),
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min, // ✅ Keep this
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ Header - Fixed at top
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

                  // ✅ Scrollable content area
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
                                    ? primaryColor.withOpacity(.2)
                                    : Colors.white.withOpacity(.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? primaryColor.withOpacity(.5)
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
                                            ? primaryColor
                                            : const Color(0xFFE8EAED),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_rounded,
                                      color: primaryColor,
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
}

// ✅ Add filter widgets from instances_sheet.dart:
// _FilterChip, _FilterDropdown, _FilterDialog, _ClearFiltersButton
class _SortChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(.2)
              : Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? primaryColor.withOpacity(.5)
                : Colors.white.withOpacity(.2),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? primaryColor : const Color(0xFFB6C0CC),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _InstanceCard extends StatelessWidget {
  final CreatureInstance instance;
  final Creature creature;
  final Color primaryColor;
  final VoidCallback onTap;

  const _InstanceCard({
    required this.instance,
    required this.creature,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CreatureRepository>();

    Map<String, String>? genetics;
    if (instance.geneticsJson != null && instance.geneticsJson!.isNotEmpty) {
      try {
        final decoded = jsonDecode(instance.geneticsJson!);
        genetics = Map<String, String>.from(decoded);
      } catch (_) {}
    }

    final sizeVariant = genetics?['size'];
    final tintVariant = genetics?['tinting'];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: primaryColor.withOpacity(.4), width: 1.5),
          boxShadow: [
            BoxShadow(color: primaryColor.withOpacity(.15), blurRadius: 8),
          ],
        ),
        child: Column(
          children: [
            // Sprite area
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.02),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: creature.spriteData != null
                            ? CreatureSprite(
                                spritePath:
                                    creature.spriteData!.spriteSheetPath,
                                totalFrames: creature.spriteData!.totalFrames,
                                rows: creature.spriteData!.rows,
                                frameSize: Vector2(
                                  creature.spriteData!.frameWidth.toDouble(),
                                  creature.spriteData!.frameHeight.toDouble(),
                                ),
                                stepTime:
                                    creature.spriteData!.frameDurationMs /
                                    1000.0,
                                scale: scaleFromGenes(
                                  genetics != null ? Genetics(genetics) : null,
                                ),
                                saturation: satFromGenes(
                                  genetics != null ? Genetics(genetics) : null,
                                ),
                                brightness: briFromGenes(
                                  genetics != null ? Genetics(genetics) : null,
                                ),
                                hueShift: hueFromGenes(
                                  genetics != null ? Genetics(genetics) : null,
                                ),
                                isPrismatic: instance.isPrismaticSkin,
                              )
                            : const Icon(Icons.pets, size: 48),
                      ),
                    ),
                    // Level badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.shade600,
                              Colors.amber.shade700,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withOpacity(.3),
                          ),
                        ),
                        child: Text(
                          'L${instance.level}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    // Prismatic badge
                    if (instance.isPrismaticSkin)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple.shade400,
                                Colors.purple.shade600,
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            '⭐',
                            style: TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Info area
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.3),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // XP
                    Row(
                      children: [
                        Icon(
                          Icons.stars_rounded,
                          size: 12,
                          color: Colors.green.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${instance.xp} XP',
                          style: TextStyle(
                            color: Colors.green.shade400,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Badges
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (instance.natureId != null)
                          _InfoBadge(
                            text: instance.natureId!,
                            color: Colors.purple,
                          ),
                        if (sizeVariant != null && sizeVariant != 'normal')
                          _InfoBadge(
                            text: sizeLabels[sizeVariant] ?? sizeVariant,
                            color: getSizeTextColor(sizeVariant),
                          ),
                        if (tintVariant != null && tintVariant != 'normal')
                          _InfoBadge(
                            text: tintLabels[tintVariant] ?? tintVariant,
                            color: getTintingTextColor(tintVariant),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _InfoBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(.4), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
