import 'package:alchemons/models/creature.dart';
import 'package:alchemons/providers/selected_party.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/creature_filter_util.dart';
import 'package:alchemons/utils/show_quick_instance_dialog.dart';
import 'package:alchemons/widgets/creature_instances_sheet.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../database/alchemons_db.dart';

class PartyPickerPage extends StatefulWidget {
  const PartyPickerPage({super.key});

  @override
  State<PartyPickerPage> createState() => _PartyPickerPageState();
}

class _PartyPickerPageState extends State<PartyPickerPage> {
  // Selection state
  String? _selectedSpeciesId;

  // Search state
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

  // Helper to build species summary list
  List<Map<String, dynamic>> buildSpeciesListData({
    required List<CreatureInstance> instances,
    required CreatureCatalog repo,
  }) {
    final countBySpecies = <String, int>{};
    for (final inst in instances) {
      countBySpecies[inst.baseId] = (countBySpecies[inst.baseId] ?? 0) + 1;
    }

    final result = <Map<String, dynamic>>[];
    for (final speciesId in countBySpecies.keys) {
      final creature = repo.getCreatureById(speciesId);
      if (creature == null) continue;
      result.add({'creature': creature, 'count': countBySpecies[speciesId]});
    }
    return result;
  }

  bool get _isPickingSpecies => _selectedSpeciesId == null;
  bool get _isPickingInstance => _selectedSpeciesId != null;

  String get _currentStage {
    if (_isPickingSpecies) return 'species';
    return 'instance';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final db = context.watch<AlchemonsDatabase>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 0),
                radius: 1.2,
                colors: [
                  theme.surface,
                  theme.surface,
                  theme.surfaceAlt.withOpacity(.6),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _StageHeader(
                    theme: theme,
                    stage: _currentStage,
                    onBack: _handleBack,
                  ),
                  const SizedBox(height: 10),

                  // Main content
                  Expanded(
                    child: StreamBuilder<List<CreatureInstance>>(
                      stream: db.creatureDao.watchAllInstances(),
                      builder: (context, snap) {
                        final instances = snap.data ?? [];
                        return _buildStageContent(theme, instances);
                      },
                    ),
                  ),

                  // Footer with party info
                  _PartyFooter(theme: theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Stage Content Builders ----------

  Widget _buildStageContent(
    FactionTheme theme,
    List<CreatureInstance> instances,
  ) {
    final repo = context.read<CreatureCatalog>();

    if (_isPickingSpecies) {
      return _buildSpeciesStage(theme, instances, repo);
    }

    // Instance selection
    return _buildInstanceStage(theme, repo);
  }

  // Stage 1: Choose species
  Widget _buildSpeciesStage(
    FactionTheme theme,
    List<CreatureInstance> instances,
    CreatureCatalog repo,
  ) {
    final speciesData = buildSpeciesListData(instances: instances, repo: repo);

    // Nothing owned
    if (speciesData.isEmpty) {
      return const _NoSpeciesOwnedWrapper();
    }

    // Filter species based on search query
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
          padding: const EdgeInsets.fromLTRB(5, 0, 5, 5),
          child: Container(
            decoration: BoxDecoration(
              color: theme.surfaceAlt,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: theme.border.withOpacity(.5), width: 1),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: TextStyle(
                color: theme.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Search species...',
                hintStyle: TextStyle(
                  color: theme.textMuted.withOpacity(.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: theme.textMuted,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: theme.textMuted,
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),

        // Results count if searching
        if (_searchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Text(
                  '${filteredSpeciesData.length} result${filteredSpeciesData.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        // Either empty "no matches" or list of species
        Expanded(
          child: filteredSpeciesData.isEmpty
              ? _NoResultsFound(theme: theme)
              : ListView.builder(
                  controller: _speciesScrollCtrl,
                  padding: const EdgeInsets.fromLTRB(5, 0, 5, 24),
                  itemCount: filteredSpeciesData.length,
                  itemBuilder: (context, i) {
                    final creature =
                        filteredSpeciesData[i]['creature'] as Creature;
                    final count = filteredSpeciesData[i]['count'] as int;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: _SpeciesRow(
                        theme: theme,
                        creature: creature,
                        count: count,
                        onTap: () {
                          setState(() {
                            _selectedSpeciesId = creature.id;
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Stage 2: Choose which specific instances to add to party
  Widget _buildInstanceStage(FactionTheme theme, CreatureCatalog repo) {
    final species = repo.getCreatureById(_selectedSpeciesId!);
    if (species == null) {
      return Center(
        child: Text('Species missing', style: TextStyle(color: theme.text)),
      );
    }

    final party = context.watch<SelectedPartyNotifier>();

    return InstancesSheet(
      species: species,
      theme: theme,
      selectionMode: true,
      initialDetailMode: InstanceDetailMode.stats,
      selectedInstanceIds: [
        if (party.members.isNotEmpty) party.members[0].instanceId,
        if (party.members.length > 1) party.members[1].instanceId,
        if (party.members.length > 2) party.members[2].instanceId,
      ],
      onTap: (inst) {
        // Check if trying to add (not remove)
        final isCurrentlySelected = party.members.any(
          (m) => m.instanceId == inst.instanceId,
        );

        context.read<SelectedPartyNotifier>().toggle(inst.instanceId);
      },
    );
  }

  // ---------- Actions ----------

  void _handleBack() {
    setState(() {
      if (_isPickingInstance) {
        _selectedSpeciesId = null;
      }
    });
  }
}

// ---------- Header ----------

class _StageHeader extends StatelessWidget {
  final FactionTheme theme;
  final String stage;
  final VoidCallback onBack;

  const _StageHeader({
    required this.theme,
    required this.stage,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final canGoBack = stage != 'species';
    final (title, subtitle) = _getStageText();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(bottom: BorderSide(color: theme.border)),
      ),
      child: Row(
        children: [
          if (canGoBack)
            GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.border),
                ),
                child: Icon(Icons.arrow_back, color: theme.text, size: 18),
              ),
            ),
          if (canGoBack) const SizedBox(width: 12),

          if (!canGoBack)
            GestureDetector(
              onTap: () => {
                HapticFeedback.lightImpact(),
                Navigator.of(context).maybePop(),
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.border),
                ),
                child: Icon(Icons.arrow_back, color: theme.text, size: 18),
              ),
            ),
          if (!canGoBack) SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (String, String?) _getStageText() {
    switch (stage) {
      case 'species':
        return ('Team Assembly', 'Select species to view specimens');
      case 'instance':
        return ('Choose Specimens', 'Select up to 3 for deployment');
      default:
        return ('', null);
    }
  }
}

// ---------- Footer ----------

class _PartyFooter extends StatelessWidget {
  const _PartyFooter({required this.theme});

  final FactionTheme theme;

  @override
  Widget build(BuildContext context) {
    final party = context.watch<SelectedPartyNotifier>();
    final count = party.members.length;
    final canDeploy = count > 0 && count <= SelectedPartyNotifier.maxSize;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Current team display
          StreamBuilder<List<CreatureInstance>>(
            stream: context
                .watch<AlchemonsDatabase>()
                .creatureDao
                .watchAllInstances(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }

              final allInstances = snapshot.data!;
              final selectedInstances = party.members
                  .map(
                    (m) => allInstances
                        .where((inst) => inst.instanceId == m.instanceId)
                        .cast<CreatureInstance?>()
                        .firstOrNull,
                  )
                  .whereType<CreatureInstance>()
                  .toList();

              if (selectedInstances.isEmpty) {
                return const SizedBox.shrink();
              }

              return Column(
                children: [
                  _TeamDisplay(
                    theme: theme,
                    selectedInstances: selectedInstances,
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),

          // Deploy button
          _DeployButton(
            theme: theme,
            enabled: canDeploy,
            selectedCount: count,
            onTap: canDeploy
                ? () async {
                    // Show the confirmation dialog
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => _DeployConfirmDialog(theme: theme),
                      barrierDismissible: false, // User must make a choice
                    );

                    // Only pop if the user confirmed
                    if (confirmed == true && context.mounted) {
                      Navigator.pop(context, party.members);
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
// [File: party_picker.dart]
// ... (at the very end of the file, after the _SpeciesRow class)

// ---------- DEPLOY CONFIRM DIALOG ----------

class _DeployConfirmDialog extends StatelessWidget {
  const _DeployConfirmDialog({required this.theme});
  final FactionTheme theme;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E27).withOpacity(.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.amber.withOpacity(.5), // Alert color
            width: 1.4,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded, // Warning icon
              color: Colors.amber.withOpacity(.9),
              size: 28,
            ),
            const SizedBox(height: 12),
            Text(
              'Deploy Team?',
              style: TextStyle(
                color: theme.text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Are you sure you want to deploy this team to the wild? Creatures in the wild are unique and will not be there again after leaving.",
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // Cancel button
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, false), // Return false
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(.14),
                          width: 1.4,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'CANCEL',
                        style: TextStyle(
                          color: theme.text,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: .5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Deploy button
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true), // Return true
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.greenAccent.withOpacity(.6),
                          width: 1.4,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'DEPLOY',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: .5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamDisplay extends StatelessWidget {
  final FactionTheme theme;
  final List<CreatureInstance> selectedInstances;

  const _TeamDisplay({required this.theme, required this.selectedInstances});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CreatureCatalog>();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.greenAccent.shade400.withOpacity(.5),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.groups_rounded,
                color: Colors.greenAccent.shade400,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Current Team',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.shade400.withOpacity(.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.greenAccent.shade400.withOpacity(.5),
                  ),
                ),
                child: Text(
                  '${selectedInstances.length} / ${SelectedPartyNotifier.maxSize}',
                  style: TextStyle(
                    color: Colors.greenAccent.shade400,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(SelectedPartyNotifier.maxSize, (i) {
              final inst = i < selectedInstances.length
                  ? selectedInstances[i]
                  : null;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                  child: inst == null
                      ? _TeamSlotEmpty(theme: theme)
                      : _TeamSlotFilled(
                          instance: inst,
                          theme: theme,
                          repo: repo,
                          onRemove: () => context
                              .read<SelectedPartyNotifier>()
                              .toggle(inst.instanceId),
                        ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _TeamSlotFilled extends StatelessWidget {
  const _TeamSlotFilled({
    required this.instance,
    required this.theme,
    required this.repo,
    required this.onRemove,
  });

  final CreatureInstance instance;
  final FactionTheme theme;
  final CreatureCatalog repo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final base = repo.getCreatureById(instance.baseId);
    final typeColor = base != null
        ? CreatureFilterUtils.getTypeColor(base.types.first)
        : theme.textMuted;
    final name = base?.name ?? instance.baseId;

    return GestureDetector(
      onTap: onRemove,
      onLongPress: base == null
          ? null
          : () {
              showQuickInstanceDialog(
                context: context,
                theme: theme,
                creature: base,
                instance: instance,
              );
            },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: base != null
                  ? InstanceSprite(creature: base, instance: instance, size: 28)
                  : Icon(Icons.help_outline, size: 14, color: typeColor),
            ),
            const SizedBox(height: 3),
            Text(
              name,
              style: TextStyle(
                color: theme.text,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'L${instance.level}',
              style: TextStyle(
                color: Colors.amber.shade400,
                fontSize: 7,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamSlotEmpty extends StatelessWidget {
  const _TeamSlotEmpty({required this.theme});
  final FactionTheme theme;

  @override
  Widget build(BuildContext context) {
    final border = theme.border;
    final fg = theme.textMuted;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
            alignment: Alignment.center,
            child: Icon(Icons.add_outlined, size: 14, color: fg),
          ),
          const SizedBox(height: 3),
          Text(
            'Empty',
            style: TextStyle(
              color: fg,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '--',
            style: TextStyle(
              color: fg,
              fontSize: 7,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeployButton extends StatefulWidget {
  final FactionTheme theme;
  final bool enabled;
  final int selectedCount;
  final VoidCallback? onTap;

  const _DeployButton({
    required this.theme,
    required this.enabled,
    required this.selectedCount,
    required this.onTap,
  });

  @override
  State<_DeployButton> createState() => _DeployButtonState();
}

class _DeployButtonState extends State<_DeployButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canTap = widget.enabled;

    return AnimatedBuilder(
      animation: _pressCtrl,
      builder: (context, _) {
        return GestureDetector(
          onTapDown: canTap ? (_) => _pressCtrl.forward() : null,
          onTapUp: canTap ? (_) => _pressCtrl.reverse() : null,
          onTapCancel: canTap ? () => _pressCtrl.reverse() : null,
          onTap: canTap ? widget.onTap : null,
          child: Transform.scale(
            scale: 1.0 - (_pressCtrl.value * 0.05),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: canTap ? Colors.greenAccent : widget.theme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: canTap
                      ? Colors.greenAccent.shade400
                      : widget.theme.border.withOpacity(.8),
                  width: 1.5,
                ),
                boxShadow: canTap
                    ? [
                        BoxShadow(
                          color: Colors.greenAccent.shade400.withOpacity(.4),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    color: canTap ? Colors.white : widget.theme.textMuted,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.selectedCount > 0
                        ? 'Deploy Team (${widget.selectedCount})'
                        : 'Select Team Members',
                    style: TextStyle(
                      color: canTap ? Colors.white : widget.theme.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------- Empty States / Helpers ----------

class _NoSpeciesOwnedWrapper extends StatelessWidget {
  const _NoSpeciesOwnedWrapper();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          "You don't own any creatures yet.",
          style: TextStyle(
            color: theme.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _NoResultsFound extends StatelessWidget {
  final FactionTheme theme;
  const _NoResultsFound({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            color: theme.textMuted.withOpacity(.3),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'No species found',
            style: TextStyle(
              color: theme.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different search term',
            style: TextStyle(
              color: theme.textMuted.withOpacity(.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Species Row ----------

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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 75,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: theme.border),
        ),
        child: Row(
          children: [
            CreatureImage(c: creature, discovered: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    creature.name,
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    creature.types.join(', '),
                    style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                color: theme.primary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
