// lib/widgets/species_picker_sheet.dart
import 'package:alchemons/database/alchemons_db.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_image.dart';

class SpeciesPickerSheet extends StatefulWidget {
  final Map<String, List<CreatureInstance>> grouped;
  final FactionTheme theme;

  const SpeciesPickerSheet({
    super.key,
    required this.grouped,
    required this.theme,
  });

  @override
  State<SpeciesPickerSheet> createState() => _SpeciesPickerSheetState();
}

class _SpeciesPickerSheetState extends State<SpeciesPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late final ScrollController _speciesScrollCtrl;

  @override
  void initState() {
    super.initState();
    _speciesScrollCtrl = ScrollController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _speciesScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CreatureCatalog>();
    final t = ForgeTokens(widget.theme);

    // Sort all species
    final sortedSpecies = widget.grouped.keys.toList()
      ..sort((a, b) {
        final speciesA = repo.getCreatureById(a);
        final speciesB = repo.getCreatureById(b);
        return (speciesA?.name ?? '').compareTo(speciesB?.name ?? '');
      });

    // Build species data list
    final speciesData = <Map<String, dynamic>>[];
    for (final speciesId in sortedSpecies) {
      final creature = repo.getCreatureById(speciesId);
      if (creature == null) continue;
      speciesData.add({
        'creature': creature,
        'count': widget.grouped[speciesId]!.length,
      });
    }

    // Filter based on search
    final filteredSpeciesData = _searchQuery.isEmpty
        ? speciesData
        : speciesData.where((data) {
            final creature = data['creature'] as Creature;
            final name = creature.name.toLowerCase();
            final types = creature.types.join(' ').toLowerCase();
            final query = _searchQuery.toLowerCase();
            return name.contains(query) || types.contains(query);
          }).toList();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            style: TextStyle(
              fontFamily: 'monospace',
              color: t.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: t.bg2,
              hintText: 'SEARCH SPECIES',
              hintStyle: TextStyle(
                fontFamily: 'monospace',
                color: t.textMuted.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: t.amberDim,
                size: 18,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        color: t.textSecondary,
                        size: 18,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: BorderSide(color: t.borderDim),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: BorderSide(
                  color: t.borderAccent.withValues(alpha: 0.9),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
        ),

        // Results count if searching
        if (_searchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Row(
              children: [
                Icon(Icons.filter_list_rounded, size: 12, color: t.textMuted),
                const SizedBox(width: 6),
                Text(
                  '${filteredSpeciesData.length} result${filteredSpeciesData.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),

        // Either empty "no matches" or list of species
        Expanded(
          child: filteredSpeciesData.isEmpty
              ? _NoResultsFound(theme: widget.theme)
              : ListView.builder(
                  controller: _speciesScrollCtrl,
                  padding: const EdgeInsets.fromLTRB(10, 2, 10, 24),
                  itemCount: filteredSpeciesData.length,
                  itemBuilder: (context, i) {
                    final creature =
                        filteredSpeciesData[i]['creature'] as Creature;
                    final count = filteredSpeciesData[i]['count'] as int;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _SpeciesRow(
                        theme: widget.theme,
                        creature: creature,
                        count: count,
                        onTap: () {
                          Navigator.pop(context, creature.id);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _NoResultsFound extends StatelessWidget {
  final FactionTheme theme;
  const _NoResultsFound({required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            color: t.textMuted.withValues(alpha: 0.7),
            size: 44,
          ),
          const SizedBox(height: 12),
          Text(
            'NO SPECIES FOUND',
            style: TextStyle(
              fontFamily: 'monospace',
              color: t.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different search term',
            style: TextStyle(
              color: t.textMuted.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeciesRow extends StatelessWidget {
  final FactionTheme theme;
  final Creature creature;
  final int count;
  final VoidCallback onTap;

  const _SpeciesRow({
    required this.theme,
    required this.creature,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        splashColor: t.amber.withValues(alpha: 0.15),
        highlightColor: t.amber.withValues(alpha: 0.06),
        child: Container(
          height: 82,
          decoration: BoxDecoration(
            color: t.bg2,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: t.borderDim),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 10,
                bottom: 10,
                child: Container(width: 2, color: t.borderAccent),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: t.bg1,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: t.borderMid),
                      ),
                      child: CreatureImage(c: creature, discovered: true),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            creature.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: t.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            creature.types.join(' / ').toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: t.textSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: t.amber.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                              color: t.amber.withValues(alpha: 0.55),
                            ),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: t.amberBright,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: t.textMuted,
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
